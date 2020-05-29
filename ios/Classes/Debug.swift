private let requestIdentifier = "debug"
private var id = 0
func debugNotification(_ body: String) {
    
    if #available(iOS 10.0, *) {
        let content = UNMutableNotificationContent()
        content.title = "[debug]"
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        id += 1
        let request = UNNotificationRequest(identifier: requestIdentifier + "/" + String(id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
