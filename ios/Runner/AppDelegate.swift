import UIKit
import Flutter
import BackgroundTasks

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
        
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        
        let walletMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/wallet", binaryMessenger: controller.binaryMessenger)
        walletMethodChannel.setMethodCallHandler(NknWalletPlugin.handle)
        
        let walletEventChannel = FlutterEventChannel(name: "org.nkn.sdk/wallet/event", binaryMessenger: controller.binaryMessenger)
        walletEventChannel.setStreamHandler(NknWalletEventPlugin())
        
        let clientMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/client", binaryMessenger: controller.binaryMessenger)
        clientMethodChannel.setMethodCallHandler(NknClientPlugin.handle)
        
        let clientEventChannel = FlutterEventChannel(name: "org.nkn.sdk/client/event", binaryMessenger: controller.binaryMessenger)
        clientEventChannel.setStreamHandler(NknClientEventPlugin())
       
        
        let nShellClientMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/nshellclient", binaryMessenger: controller.binaryMessenger)
        nShellClientMethodChannel.setMethodCallHandler(NShellClientPlugin.handle)
        
        let nShellClientEventChannel = FlutterEventChannel(name: "org.nkn.sdk/nshellclient/event", binaryMessenger: controller.binaryMessenger)
        nShellClientEventChannel.setStreamHandler(NShellClientEventPlugin())
        
        
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .badge, .sound])
    }
    
}
