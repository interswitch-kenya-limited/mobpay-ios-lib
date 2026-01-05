# MobPay - An iOS library for integrating card and mobile payments through Interswitch

This Pod enables you to integrate Interswitch payments to your mobile app

## Adding MobpayiOS to a project

## CocoaPods
CocoaPods is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Mobpay into your Xcode project using CocoaPods, specify it in your Podfile:
To get the library add the following dependency to your podfile:

```ruby
pod 'MobpayiOS'
```

Then run the following command
``` shell
pod install
```

Don't forget to use the .xcworkspace file to open your project in Xcode, instead of the .xcodeproj file, from here on out.

In the future, to update to the latest version of the SDK, just run:

```shell
pod update MobpayiOS
```

## Usage examples

Get an interswitch client Id and client secret for your interswitch merchant account then instantiate a mobpay object by doing the following:

```swift

import MobpayiOS


let card = Card(pan: "4111111111111111", cvv: "123", expiryYear: "20", expiryMonth: "02", tokenize: false)
let payment = Payment(amount: "100", transactionRef: "66809285644", orderId: "OID123453", terminalType: "MOBILE", terminalId: "3TLP0001", paymentItem: "CRD", currency: "KES")
let customer = Customer(customerId: "12", firstName: "Allan", secondName: "Mageto", email: "test@gmail.com", mobile: "0712345678", city: "NBI", country: "KE", postalCode: "00200", street: "WESTLANDS", state: "NBI")
let merchant = Merchant(merchantId: "your merchant id", domain: "your domain")             
```

### Card Payment         
To make a card payment :
```swift
try!Mobpay.instance.submitCardPayment(card: cardInput, merchant: merchantInput, payment: paymentInput, customer: customerInput, clientId: self.clientId,clientSecret: self.clientSecret,previousUIViewController: self){(completion) in
                        self.showResponse(message: completion)
                    }
```
where the previous view controller is the controller youre calling the function from

### Card Token Payment
To make a card token payment: 

```swift
try!Mobpay.instance.submitTokenPayment(cardToken: cardToken, merchant: merchantInput, payment: paymentInput, customer: customerInput, clientId: self.clientId,clientSecret: self.clientSecret,previousUIViewController: self){
                        (completion) in
                        self.showResponse(message: completion)
}
```

### Mobile Money Payment
To make a mobile money payment:

```swift
try!Mobpay.instance.makeMobileMoneyPayment(mobile: mobileInput, merchant: merchantInput, payment: paymentInput, customer: customerInput, clientId: self.clientId, clientSecret:self.clientSecret)
{ 
    (completion) in self.showResponse(message: completion)
}
```

### Confirm Mobile Money Payment
To confirm if a mobile money payment was successful or not:

```swift
 try!Mobpay.instance.confirmMobileMoneyPayment(orderId: self.orderId, clientId: self.clientId,clientSecret: self.clientSecret){
      (completion) in self.showResponse(message: completion)
      }
```
## Source code

Visit https://github.com/Immanuel007/mobpay-ios-example to get the source code and releases of this project if you want to try a manual integration process.
