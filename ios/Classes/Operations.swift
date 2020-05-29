let backgroundChatQueue = DispatchQueue(label: "org.nkn.sdk/background/chat", qos: .background)

class BackgroundChatOperation: Operation {
    override func main() {
//        backgroundChatQueue.async {
            onMessage()
//        }
    }
}
