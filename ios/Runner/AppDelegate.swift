import UIKit
import Flutter
import Sentry

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        SentrySDK.start { options in
            options.dsn = "https://0d2217601b1c4eb4bf310ca001fabf39@o466976.ingest.sentry.io/5680254"
            let infoDictionary = Bundle.main.infoDictionary
            if let infoDictionary = infoDictionary {
                let appBuild:String = infoDictionary["CFBundleVersion"] as! String
                options.environment = appBuild
            }
            options.releaseName = "nMobile"
        }
        
        registerNotification();
        
        GeneratedPluginRegistrant.register(with: self)
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController;
        Common.register(controller: controller)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
            PushService.shared().connectAPNS();
        }
    }
    
    func registerNotification() {
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.delegate = self as UNUserNotificationCenterDelegate
            center.requestAuthorization(options: UNAuthorizationOptions.alert) { (isSucceseed: Bool, error:Error?) in
                if isSucceseed == true{
                    print( "Application - registerNotification - success")
                }else{
                    print( "Application - registerNotification - fail - error = \(String(describing:error))")
                }
            }
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        NotificationCenter.default.addObserver(self, selector:#selector(becomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(becomeDeath), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func becomeActive(noti:Notification){
        NSLog("NKNClient Enter foreground")
        PushService.shared().connectAPNS()
    }

    @objc func becomeDeath(noti:Notification){
        NSLog("NKNClient Enter background")
        PushService.shared().disConnectAPNS()
    }
    

//    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
//    {
//        let userInfo = notification.request.content.userInfo
//        print("will Present received:","\(userInfo)")
//        completionHandler([.alert, .badge, .sound])
//    }
    
//    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void){
//        let userInfo = response.notification.request.content.userInfo
//        print("did Received userInfo10:\(userInfo)")
//        completionHandler()
//    }
    
//    private func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//        print("收到新消息Active\(userInfo)")
//        if application.applicationState == UIApplication.State.active {
//            // 代表从前台接受消息app
//        }else{
//            // 代表从后台接受消息后进入app
//            UIApplication.shared.applicationIconBadgeNumber = 0
//        }
//        completionHandler(.newData)
//    }
}
