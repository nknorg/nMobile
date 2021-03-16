import UIKit
import Flutter
//import BackgroundTasks

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
            let infoDictionary = Bundle.main.infoDictionary
            if let infoDictionary = infoDictionary {
                let appVersion = infoDictionary["CFBundleShortVersionString"]
                let appBuild:String = infoDictionary["CFBundleVersion"] as! String
                options.environment = appBuild
            }
            options.releaseName = "nMobile"
        }
        signal(SIGPIPE, SIG_IGN)
             
        GeneratedPluginRegistrant.register(with: self)
        
        if(!UserDefaults.standard.bool(forKey: "Notification")) {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
        
        isFcmAvailable()
        registerNotification()

        return true
    }
    
    func isFcmAvailable(){
        let urlString = "http://ip-api.com/json"
        let requestUrl = URL(string: urlString)
        let task = URLSession.shared.dataTask(with: requestUrl!) { data, response, error in
                guard error == nil else {
                    print("ERROR: HTTP REQUEST ERROR!")
                    return
                }
                guard let data = data else {
                    print("ERROR: Empty data!")
                    return
                }
            let responseString = NSString(data: data,encoding: String.Encoding.utf8.rawValue)! as String
            let jsonData = responseString.data(using: String.Encoding.utf8, allowLossyConversion: false) ?? Data()
            guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String:AnyObject] else {
                 return
            }
            let countryCode  = json["countryCode"] as! String
            if (countryCode == "CN"){
                return
            }
            else{
                print("self.registerGoogleFCM()")
                self.registerGoogleFCM()
            }
        }
        task.resume()
    }
    
    func registerGoogleFCM(){
        //注册谷歌Firebase Messaging
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        Messaging.messaging().token { token, error in
          if let error = error {
            print("Error fetching FCM registration token: \(error)")
            if let app = FirebaseApp.app() {
                app.delete({ _  in })
                Messaging.messaging().delegate = nil
            }
          } else if let token = token {
            print("FCM registration token: \(token)")
          }
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        // Save fcm Token to local
        UserDefaults.standard.setValue(fcmToken, forKey: "nkn_fcm_token")
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let userInfo = notification.request.content.userInfo
        print("will Present received:","\(userInfo)")
        completionHandler([.alert, .badge, .sound])
    }
    
    // Request for deviceToken
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        //deviceToken = 32 bytes
        let formatDeviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print("Get DeviceToken", formatDeviceToken)
        // Save Device Token to local
        UserDefaults.standard.setValue(formatDeviceToken, forKey: "nkn_device_token")
        
        // Send DeviceToken to Google FCM
        Messaging.messaging().apnsToken = deviceToken
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
            NKNPushService.shared().connectAPNS();
            print("NKNPushService.shared().connectAPNS();");
        }
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
