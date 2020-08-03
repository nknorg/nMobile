import UIKit
import Flutter
import BackgroundTasks
import Bugly

var backgroundChatTask: UIBackgroundTaskIdentifier! = nil

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        if(!UserDefaults.standard.bool(forKey: "Notification")) {
            UIApplication.shared.cancelAllLocalNotifications()
            UserDefaults.standard.set(true, forKey: "Notification")
        }
        Bugly.start(withAppId: "169cabe790")
        
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let walletMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/wallet", binaryMessenger: controller.binaryMessenger)
        walletMethodChannel.setMethodCallHandler(NknWalletPlugin.handle)
        
        let walletEventChannel = FlutterEventChannel(name: "org.nkn.sdk/wallet/event", binaryMessenger: controller.binaryMessenger)
        walletEventChannel.setStreamHandler(NknWalletEventPlugin())

        NknClientPlugin(controller: controller)

//        let clientMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/client", binaryMessenger: controller.binaryMessenger)
//        clientMethodChannel.setMethodCallHandler(NknClientPlugin.handle)
//
//        let clientEventChannel = FlutterEventChannel(name: "org.nkn.sdk/client/event", binaryMessenger: controller.binaryMessenger)
//        clientEventChannel.setStreamHandler(NknClientEventPlugin())

        let nShellClientMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/nshellclient", binaryMessenger: controller.binaryMessenger)
        nShellClientMethodChannel.setMethodCallHandler(NShellClientPlugin.handle)

        let nShellClientEventChannel = FlutterEventChannel(name: "org.nkn.sdk/nshellclient/event", binaryMessenger: controller.binaryMessenger)
        nShellClientEventChannel.setStreamHandler(NShellClientEventPlugin())
        
       let commontChannel = FlutterMethodChannel(name: "ios/nmobile/native/common", binaryMessenger: controller.binaryMessenger)
        commontChannel.setMethodCallHandler { (call, result) in
              if "isActive" == call.method{
                 result(application.applicationState != UIApplication.State.background)
              }else{
                  result(FlutterMethodNotImplemented)
              }
          }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .badge, .sound])
    }
    
}
