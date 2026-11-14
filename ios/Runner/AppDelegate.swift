import UIKit
import Flutter
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }

        signal(SIGPIPE, SIG_IGN)
        registerNotification()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let messenger = engineBridge.applicationRegistrar.messenger()
        Common.register(messenger: messenger)
        Crypto.register(messenger: messenger)
        EthResolver.register(messenger: messenger)
        DnsResolver.register(messenger: messenger)
        SearchService.register(messenger: messenger)
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return super.application(app, open: url, options: options)
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
}
