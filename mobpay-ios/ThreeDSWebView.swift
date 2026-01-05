//  MobilePayment.swift
//  mobpay-ios
//
//  Created by Allan Mageto on 18/06/2019.
//  Copyright © 2019 Allan Mageto. All rights reserved.

import UIKit
import WebKit

class ThreeDSWebView: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    
    var webView: WKWebView!
    var webCardinalURL: URL!
    var completion: ((String) -> Void)?
    
    // Track navigation state
    private var isOnBlankScreen = false
    private var blankScreenTimer: Timer?
    private var popupWebView: WKWebView?
    
    convenience init(webCardinalURL: URL) {
        self.init()
        self.webCardinalURL = webCardinalURL
    }
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.preferences.javaScriptEnabled = true
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let source = """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.getElementsByTagName('head')[0].appendChild(meta);
            
            (function() {
                const originalPostMessage = window.postMessage;
                window.postMessage = function(message, targetOrigin) {
                    console.log('postMessage:', message);
                    try {
                        window.webkit.messageHandlers.paymentMessage.postMessage(JSON.stringify(message));
                    } catch(e) {}
                    return originalPostMessage.apply(this, arguments);
                };
                
                window.addEventListener('message', function(event) {
                    console.log('Message event:', event.data);
                    try {
                        window.webkit.messageHandlers.paymentMessage.postMessage(JSON.stringify(event.data));
                    } catch(e) {}
                });
                
                window.close = function() {
                    console.log('🚪 Window.close()');
                    window.webkit.messageHandlers.paymentClose.postMessage('close');
                };
                
                console.log('Payment interceptor ready');
            })();
        """
        
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webConfiguration.userContentController.addUserScript(script)
        webConfiguration.userContentController.add(self, name: "paymentMessage")
        webConfiguration.userContentController.add(self, name: "paymentClose")
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        print("Loading payment URL: \(webCardinalURL.absoluteString)")
        webView.load(URLRequest(url: webCardinalURL))
    }
    
    @objc func cancelTapped() {
        print("User cancelled payment")
        blankScreenTimer?.invalidate()
        navigationController?.popViewController(animated: true)
        completion?("{\"status\":\"cancelled\",\"message\":\"User cancelled payment\"}")
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        print("========================================")
        print("POPUP REQUESTED!")
        print("URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("targetFrame is nil?: \(navigationAction.targetFrame == nil)")
        print("========================================")
        
        print("POPUP REQUESTED! targetFrame nil? \(navigationAction.targetFrame == nil) url=\(navigationAction.request.url?.absoluteString ?? "nil")")


        // If it's not a new window request, don't create anything
        guard navigationAction.targetFrame == nil else {
            return nil
        }

        // Create popup webview
        let popup = WKWebView(frame: view.bounds, configuration: configuration)
        popup.uiDelegate = self
        popup.navigationDelegate = self
        popup.allowsBackForwardNavigationGestures = false
        popup.allowsLinkPreview = false
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.popupWebView = popup
        view.addSubview(popup)

        // Load the request in the popup
        popup.load(navigationAction.request)

        return popup
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true, completion: nil)
    }

    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    
        
        if message.name == "paymentMessage" {
            handlePaymentMessage(message.body)
        } else if message.name == "paymentClose" {
            print("🚪 Payment window close requested")
            handlePaymentClose()
        }
    }
    
    func handlePaymentMessage(_ body: Any) {
        var messageString = ""
        
        if let dict = body as? [String: Any] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                messageString = jsonString
            }
        } else if let string = body as? String {
            messageString = string
        }
        
//        print("Message: \(messageString)")
        
        let lowercased = messageString.lowercased()
        if lowercased.contains("success") || lowercased.contains("approved") {
            handlePaymentCompletion(result: messageString)
        } else if lowercased.contains("failed") || lowercased.contains("declined") {
            handlePaymentCompletion(result: messageString)
        }
    }
    
    func handlePaymentClose() {
//        print("Payment window closed - waiting for MQTT...")
        
        // When the payment window closes, wait a bit for MQTT
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.completion != nil {
                print("No result after 3 seconds")
                // MQTT should have fired by now
            }
        }
    }
    
    func handlePaymentCompletion(result: String) {
//        print("Payment completion: \(result)")
        
        blankScreenTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.popupWebView?.removeFromSuperview()
            self.popupWebView = nil
            self.navigationController?.popViewController(animated: true)
            self.completion?(result)
            self.completion = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.completion != nil {
                    print("No result after 3 seconds")
                }
            }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            let urlString = url.absoluteString
            
//            print("Navigation: \(urlString)")
            
            
            // about:blank is where 3DS challenge loads
            if urlString == "about:blank" {
//                print("Allowing about:blank (expecting 3DS or completion)")
                isOnBlankScreen = true
                
                // Start timer - if blank screen persists for 20 seconds, something is wrong
                blankScreenTimer?.invalidate()
                blankScreenTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
//                    print("Blank screen timeout - payment may have completed via MQTT")
//                    print("If you're still seeing blank screen, payment processing may have issues")
                }
                
                decisionHandler(.allow)
                return
            }
            
            // Check for success/failure in URL
            let lowercased = urlString.lowercased()
            
            if lowercased.contains("/success") ||
               lowercased.contains("status=success") ||
               lowercased.contains("status=00") {
                
                print("SUCCESS DETECTED IN URL!")
                
                var result: [String: Any] = ["status": "success", "url": urlString]
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    for item in queryItems {
                        result[item.name] = item.value ?? ""
                    }
                }
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: result),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    handlePaymentCompletion(result: jsonString)
                }
                
                decisionHandler(.cancel)
                return
            }
            
            if lowercased.contains("/failed") || lowercased.contains("status=failed") {
                print("FAILURE DETECTED IN URL!")
                handlePaymentCompletion(result: "{\"status\":\"failed\",\"url\":\"\(urlString)\"}")
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            print("Page loaded: \(url.absoluteString)")
            
            if url.absoluteString == "about:blank" && isOnBlankScreen {
//                print("On blank screen - waiting for MQTT or content to load...")
//                
                // Check if blank screen has any content
                webView.evaluateJavaScript("document.body.innerHTML") { result, error in
                    if let html = result as? String {
                        print("Blank screen HTML length: \(html.count) characters")
                        if html.count > 100 {
                            print("Blank screen has content:")
                            print(html.prefix(200))
                            
                            
                        }
                    }
                }
            }
        }
        
        webView.evaluateJavaScript("document.title") { result, error in
            if let title = result as? String {
                print("Title: \(title)")
            }
        }
        
        webView.evaluateJavaScript("document.body.innerHTML.length") { result, error in
            if let length = result as? Int {
                print("Content length: \(length) characters")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }
    
    deinit {
        blankScreenTimer?.invalidate()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "paymentMessage")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "paymentClose")
    }
}
