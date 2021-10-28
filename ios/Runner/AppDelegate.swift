import UIKit
import Flutter
import Sentry

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        SentrySDK.start { options in
            options.dsn = "https://0d2217601b1c4eb4bf310ca001fabf39@o466976.ingest.sentry.io/5680254"
            let infoDictionary = Bundle.main.infoDictionary
            if let infoDictionary = infoDictionary {
                let appBuild:String = infoDictionary["CFBundleVersion"] as! String
                options.environment = appBuild
            }
            options.releaseName = "nMobile"
        }
        
        signal(SIGPIPE, SIG_IGN)
        
        GeneratedPluginRegistrant.register(with: self)
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController;
        Common.register(controller: controller)
        
        registerNotification();
        
        NotificationCenter.default.addObserver(self, selector:#selector(becomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(becomeDeath), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        //return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        return true;
    }
    
    func registerNotification() {
        if(!UserDefaults.standard.bool(forKey: "Notification")) {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UserDefaults.standard.set(true, forKey: "Notification")
        }
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (isSucceseed: Bool, error:Error?) in
            if isSucceseed == true{
                print("Application - registerNotification - success")
            } else {
                print("Application - registerNotification - fail - error = \(String(describing:error))")
            }
        }
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    @objc func becomeActive(noti:Notification) {
        APNSPushService.shared().connectAPNS()
    }
    
    @objc func becomeDeath(noti:Notification) {
        APNSPushService.shared().disConnectAPNS()
    }
    
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // deviceToken = 32 bytes
        let formatDeviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print("Application - GetDeviceToken - token = \(formatDeviceToken)")
        UserDefaults.standard.setValue(formatDeviceToken, forKey: "nkn_device_token")
        
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
//            APNSPushService.shared().connectAPNS();
//        }
    }
    
//    override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//        print("Application - didReceiveRemoteNotification - onReceive - userInfo = \(userInfo)")
//        let aps = userInfo["aps"] as? [String: Any]
//        let alert = aps?["alert"] as? [String: Any]
//        var resultMap: [String: Any] = [String: Any]()
//        resultMap["title"] = alert?["title"]
//        resultMap["content"] = alert?["body"]
//        resultMap["isApplicationForeground"] = application.applicationState == UIApplication.State.active
//        Common.eventAdd(name: "onRemoteMessageReceived", map: resultMap)
//    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let userInfo = notification.request.content.userInfo
        print("Application - userNotificationCenter - onReceive - userInfo = \(userInfo)")
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        var resultMap: [String: Any] = [String: Any]()
        resultMap["title"] = alert?["title"]
        resultMap["content"] = alert?["body"]
        resultMap["isApplicationForeground"] = UIApplication.shared.applicationState == UIApplication.State.active
        Common.eventAdd(name: "onRemoteMessageReceived", map: resultMap)
        // completionHandler([.alert, .badge, .sound]) // show notification on flutter, not here
    }
    
//    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        let userInfo = response.notification.request.content.userInfo
//        print("Application - userNotificationCenter - onClick - userInfo = \(userInfo)")
//        let aps = userInfo["aps"] as? [String: Any]
//        let alert = aps?["alert"] as? [String: Any]
//        var resultMap: [String: Any] = [String: Any]()
//        resultMap["title"] = alert?["title"]
//        resultMap["content"] = alert?["body"]
//        resultMap["isApplicationForeground"] = UIApplication.shared.applicationState == UIApplication.State.active
//        Common.eventAdd(name: "onNotificationClick", map: resultMap)
//        completionHandler()
//    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        //UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
}
