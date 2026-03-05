# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'mobpay-ios' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
   pod 'SwiftyRSA', '1.7.0'
   pod 'CryptoSwift', '1.7.0'
   pod 'PercentEncoder','1.2.1'
   pod 'CocoaMQTT/WebSockets', :git => 'https://github.com/emqx/CocoaMQTT.git', :tag => '2.1.7'
   pod 'Alamofire','5.10.2'
   pod 'Starscream', '3.1.1'

  # Pods for mobpay-ios

  target 'mobpay-iosTests' do
    inherit! :search_paths
    # Pods for testing
  end

  
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
