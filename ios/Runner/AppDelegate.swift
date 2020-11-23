import UIKit
import Flutter
import BackgroundTasks

import Sentry
import Firebase
import Nkn

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate{
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        SentrySDK.start { options in
            options.dsn = "https://e566a6e5c45845dd93e07c41c22c0113@o466976.ingest.sentry.io/5483299"
//            options.debug = true
//            options.environment = "production"
//            options.releaseName = "nMobile"
        }
                
        if(!UserDefaults.standard.bool(forKey: "Notification")) {
            UIApplication.shared.cancelAllLocalNotifications()
            UserDefaults.standard.set(true, forKey: "Notification")
        }
//
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let walletMethodChannel = FlutterMethodChannel(name: "org.nkn.sdk/wallet", binaryMessenger: controller.binaryMessenger)
        walletMethodChannel.setMethodCallHandler(NknWalletPlugin.handle)
        
        let walletEventChannel = FlutterEventChannel(name: "org.nkn.sdk/wallet/event", binaryMessenger: controller.binaryMessenger)
        walletEventChannel.setStreamHandler(NknWalletEventPlugin())

        NknClientPlugin(controller: controller)

        FlutterMethodChannel(name: "org.nkn.nmobile/native/common", binaryMessenger: controller.binaryMessenger)
            .setMethodCallHandler { (call, result) in
                  if "isActive" == call.method{
                     result(application.applicationState != UIApplication.State.background)
                  }else{
                      result(FlutterMethodNotImplemented)
                  }
            }
        GeneratedPluginRegistrant.register(with: self)
        registerNotification()
        
        registerGoogleFCM()
        return true
    }
    
    func registerGoogleFCM(){
        //注册谷歌Firebase Messaging
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        Messaging.messaging().token { token, error in
          if let error = error {
            print("Error fetching FCM registration token: \(error)")
          } else if let token = token {
            print("FCM registration token: \(token)")
          }
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        let dataDict:[String: String] = ["token": fcmToken ?? ""]
        // 存储FCMToken到本地
        UserDefaults.standard.setValue(fcmToken, forKey: "nkn_fcm_token")
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let userInfo = notification.request.content.userInfo
        print("will Present received:","\(userInfo)")
        completionHandler([.alert, .badge, .sound])
    }
    
    ///请求完成后会调用把获取的deviceToken返回给我们
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        //deviceToken = 32 bytes
        print("deviceToken = \(deviceToken)")
        //FIXME:打印推送64位token
        let formatDeviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print("获取DeviceToken", formatDeviceToken)
        // 存储DeviceToken到本地
        UserDefaults.standard.setValue(formatDeviceToken, forKey: "nkn_device_token")
        
        // 发送DeviceToken给谷歌
        Messaging.messaging().apnsToken = deviceToken
        
        let pushService:NKNPushService = NKNPushService.shared();
        pushService.connectAPNS();
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void){
        let userInfo = response.notification.request.content.userInfo
        print("did Received userInfo10:\(userInfo)")
        completionHandler()
    }
    
    private func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("收到新消息Active\(userInfo)")
        if application.applicationState == UIApplication.State.active {
            // 代表从前台接受消息app
        }else{
            // 代表从后台接受消息后进入app
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        UIApplication.shared.applicationIconBadgeNumber = 99
        completionHandler(.newData)
    }
    
    public var deviceTokenDataToString:(_ data:Data)->String = { data in
        var str = "";
        let bytes = [UInt8](data)
        for item in bytes {
            print("__%@__",item.description);
            str += String(format:"%02x", item&0x000000FF)
        }
        return str;
    }
    
    func registerNotification(){
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: UNAuthorizationOptions.alert) { (isSucceseed: Bool, error:Error?) in
            if isSucceseed == true{
                print( "成功")
            }else{
                print( "失败")
                print("error = \(String(describing:error))")
            }
        }
        UIApplication.shared.registerForRemoteNotifications()
    }
}
