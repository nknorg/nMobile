import UIKit
import Flutter
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        FirebaseApp.configure()
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        
        signal(SIGPIPE, SIG_IGN)
        
        GeneratedPluginRegistrant.register(with: self)
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController;
        Common.register(controller: controller)
        Crypto.register(controller: controller)
        EthResolver.register(controller: controller)
        DnsResolver.register(controller: controller)
        SearchService.register(controller: controller)

        registerNotification();

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return super.application(app, open: url, options:options)
    }

    func registerNotification() {
        if(!UserDefaults.standard.bool(forKey: "Notification")) {
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
            UserDefaults.standard.set(true, forKey: "Notification")
        }
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (isSucceseed: Bool, error:Error?) in
            if isSucceseed == true {
                print("Application - registerNotification - success")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("Application - registerNotification - fail - error = \(String(describing:error))")
            }
        }
    }
    
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // deviceToken = 32 bytes
        let formatDeviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print("Application - GetDeviceToken - token = \(formatDeviceToken)")
        UserDefaults.standard.setValue(formatDeviceToken, forKey: "nkn_device_token")
    }
    
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
    }
    
    override func applicationWillResignActive(_ application: UIApplication) {
        window?.addSubview(self.visualEffectView)
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        // UIApplication.shared.applicationIconBadgeNumber = 0
        self.visualEffectView.removeFromSuperview()
    }
    
    lazy var visualEffectView: UIVisualEffectView = {
           let blur = UIBlurEffect.init(style: UIBlurEffect.Style.light)
           let view = UIVisualEffectView.init(effect: blur)
           view.frame = UIScreen.main.bounds
           return view
       }()
}
