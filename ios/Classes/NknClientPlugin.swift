import Flutter
import UIKit
import Nkn

public class NknClientPlugin : NSObject, FlutterStreamHandler {
    
    private let receivedMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/receive",qos: .default)
    private let sendMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/send",qos: .default)
    private let subscriberQueue = DispatchQueue(label: "org.nkn.sdk/client/subscriber", qos: .default)
    
    // 创建需要
    private var accountSeedBytes:FlutterStandardTypedData = FlutterStandardTypedData()
    private var identifierC:String? = ""
    private var clientUrlC:String? = ""

    init(controller : FlutterViewController) {
        super.init()
        FlutterMethodChannel(name: "org.nkn.sdk/client", binaryMessenger: controller.binaryMessenger).setMethodCallHandler(methodCall)
        FlutterEventChannel(name: "org.nkn.sdk/client/event", binaryMessenger: controller.binaryMessenger).setStreamHandler(self)
        
        NotificationCenter.default.addObserver(self, selector:#selector(becomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(becomeDeath), name: UIApplication.willResignActiveNotification, object: nil)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        clientEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }

    public func methodCall(_ call: FlutterMethodCall, _ result: FlutterResult) {
        switch call.method {
            case "createClient":
                createClient(call, result)
            case "connect":
                connect()
                onAsyncMessageReceive()
                result(nil)
            case "backOn":
                onBackgroundOpen()
            case "backOff":
                onBackgroundClose()
            case "isConnected":
                isConnected(call, result)
            case "disConnect":
                disConnect(call, result, true)
            case "sendText":
                sendText(call, result)
            case "publishText":
                publishText(call, result)
            case "subscribe":
                subscribe(call, result)
            case "unsubscribe":
                unsubscribe(call, result)
            case "getSubscribersCount":
                getSubscribersCount(call, result)
            case "getSubscribers":
                getSubscribers(call, result)
            case "getSubscription":
                getSubscription(call, result)
            case "fetchDeviceToken":
                fetchDeviceToken(call, result)
            case "getBlockHeight":
                getBlockHeight(call, result)
            case "fetchFcmToken":
                fetchFCMToken(call, result)
            default:
                result(FlutterMethodNotImplemented)
        }
    }

    private var clientEventSink: FlutterEventSink?
    private var multiClient: NknMultiClient?
    private var accountPubkeyHex: String?
    private var isConnected = false

    func createClient(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String
        let seedBytes = args["seedBytes"] as! FlutterStandardTypedData
        let clientUrl = args["clientUrl"] as? String
                
        result(nil)

        self.sendMessageQueue.async {
            var error: NSError?
            let account = NknNewAccount(seedBytes.data, &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
                return
            }
            self.accountPubkeyHex = self.ensureSameAccount(account!)
            self.multiClient = self.genClientIfNotExists(account!, identifier, clientUrl)
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = "createClient"
            resp["success"] = (self.multiClient == nil) ? 0 : 1
            self.clientEventSink!(resp)
        }
        
        accountSeedBytes = seedBytes
        self.identifierC = args["identifier"] as? String
        self.clientUrlC = args["clientUrl"] as? String
    }

    public func connect() {
        if (isConnected) {
            return
        }
        if (self.multiClient == nil){
            print("create Client first")
            return
        }
        let node = self.multiClient?.onConnect?.next()
        if (node == nil) {
            return
        }
        isConnected = true
        var data: [String: Any] = [String: Any]()
        data["event"] = "onConnect"
        data["node"] = ["address": node?.addr, "publicKey": node?.pubKey]
        data["client"] = ["address": self.multiClient?.address()]
        self.clientEventSink?(data)
    }

    //@Deprecated(message = "No longer needed.")
    func isConnected(_ call: FlutterMethodCall, _ result: FlutterResult) {
        if (multiClient != nil) {
            result(isConnected)
        } else {
            result(false)
        }
    }

    func disConnect(_ call: FlutterMethodCall, _ result: FlutterResult, _ callFromDart: Bool) {
        result(nil)
        let clientAddr = multiClient?.address()
        closeClientIfExists()
        if (!callFromDart) {
            var data: [String: Any] = [String: Any]()
            data["event"] = "onDisConnect"
            var client: [String: Any] = [String: Any]()
            client["address"] = clientAddr
            data["client"] = client
            clientEventSink!(data)
        }
    }
    
    func onAsyncMessageReceive(){
        print("Test onAsyncMessageReceive");
        self.receivedMessageQueue.async {
            self.onMessageListening()
//            self.addQueueToRunloop()
        }
    }
    
    // 启用定时器
    func onMessageListening(){
        print("Test onMessageListening");
        if (self.multiClient == nil){
            return;
        }
        let onMessage: NknOnMessage? = self.multiClient?.onMessage
        guard let msg = onMessage?.next() else{
            print("on No Message")
            return
        }
        
        var data: [String: Any] = [String: Any]()
        data["event"] = "onMessage"
        data["data"] = [
            "src": msg.src,
            "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
            "type": msg.type,
            "encryptedx": msg.encrypted,
            "pid": FlutterStandardTypedData(bytes: msg.messageID!)
        ]
        var client1: [String: Any] = [String: Any]()
        client1["address"] = self.multiClient?.address()
        data["client"] = client1
        self.clientEventSink!(data)
        
        self.onAsyncMessageReceive()
    }
    
    func onMessages(){
        print("onMessages call begin","call Timer")
        if (self.multiClient == nil){
            return;
        }
        while let msg = self.multiClient?.onMessage?.next(){
            var data: [String: Any] = [String: Any]()
            data["event"] = "onMessage"
            data["data"] = [
                "src": msg.src,
                "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
                "type": msg.type,
                "encryptedx": msg.encrypted,
                "pid": FlutterStandardTypedData(bytes: msg.messageID!)
            ]
            var client1: [String: Any] = [String: Any]()
            client1["address"] = self.multiClient?.address()
            data["client"] = client1
            self.clientEventSink!(data)
        }
    }

    func sendText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
        
        print("arge is ",args.description);
        let dataInfo = getDictionaryFromJSONString(jsonString: data)
        if (dataInfo["deviceToken"] != nil){
            let deviceToken = dataInfo["deviceToken"] as! String;
            if (deviceToken.count > 0){
                let content = dataInfo["pushContent"] as! String;
                if (content.count > 0){
                    let pushService:NKNPushService = NKNPushService.shared();
                    // 需要发送给Android设备通知 通过FCM
                    if (deviceToken.count == 64){
                        pushService.pushContent(content, token: deviceToken);
                    }
                    else if (deviceToken.count > 64){
                        if (deviceToken.count == 163){
                            pushService.pushContent(toFCM: content, byToken: deviceToken)
                        }
                        else if (deviceToken.count > 163){
                            let fcmGapString = "__FCMToken__:"
                            let sList = deviceToken.components(separatedBy: fcmGapString)
                            let dropFcmToken = sList[0]
                            print("after drop Fcm token is",dropFcmToken);
                            pushService.pushContent(content, token: dropFcmToken);
                        }
                    }
                    
                }
            }
            print("deviceToken length is",deviceToken.count)
            print("deviceToken str is",deviceToken)
        }
        let debugStr = "dc26bf230d38aaec48eaa7a0fd916d2585da6bf7b85e95d9fe73a248866199dc"
        print("debugStr length is",debugStr.count)
        
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        let nknDests = NknStringArray.init(from: nil)!
        if(!dests.isEmpty) {
            for dest in dests {
                nknDests.append(dest)
            }
        }

        sendMessageQueue.async {
            do {
                let config: NknMessageConfig = NknMessageConfig.init()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? Int32.max : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                config.noReply = true

                try client.sendText(nknDests, data: data, config: config)
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["event"] = "send"
                resp["pid"] = config.messageID
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
            }
        }
    }
    
    func addQueueToRunloop(){
        let port = Port()
        RunLoop.current.add(port, forMode: .default)
        RunLoop.current.run(mode: .default, before: Date.distantFuture)
    }

    func publishText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        sendMessageQueue.async {
            do {
                let config: NknMessageConfig = NknMessageConfig.init()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? Int32.max : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                config.noReply = true

                try client.publishText(topicHash, data: data, config: config)
                var resp: [String: Any] = [String: Any]()
                    resp["_id"] = _id
                    resp["event"] = "send"
                    resp["pid"] = config.messageID
                    self.clientEventSink!(resp)
                } catch let error {
                    self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
                }
        }
    }

    func subscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topicHash = args["topicHash"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        subscriberQueue.async {
            let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
            transactionConfig.fee = fee

            var error: NSError?
            let hash = client.subscribe(identifier, topic: topicHash, duration: duration, meta: meta, config: transactionConfig, error: &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
                return
            }
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["result"] = hash
            self.clientEventSink!(resp)
        }
    }

    func unsubscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topicHash = args["topicHash"] as! String
        let fee = args["fee"] as? String ?? "0"
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        subscriberQueue.async {
            let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
            transactionConfig.fee = fee

            var error: NSError?
            let hash = client.unsubscribe(identifier, topic: topicHash, config: transactionConfig, error: &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
                return
            }
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["result"] = hash
            self.clientEventSink!(resp)
        }
    }

    func getSubscribers(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 0
        let meta = args["meta"] as? Bool ?? true
        let txPool = args["txPool"] as? Bool ?? true
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        subscriberQueue.async {
            do{
                let res: NknSubscribers? = try client.getSubscribers(topicHash, offset: offset, limit: limit, meta: meta, txPool: txPool)
                let mapPro = MapProtocol.init()
                mapPro.result["_id"] = _id
                res?.subscribersInTxPool?.range(mapPro)
                res?.subscribers?.range(mapPro)
                self.clientEventSink!(mapPro.result)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
            }
        }
    }

    func getSubscription(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let subscriber = args["subscriber"] as! String
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        subscriberQueue.async {
            do{
                let res: NknSubscription? = try client.getSubscription(topicHash, subscriber: subscriber)
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["meta"] = res?.meta
                resp["expiresAt"] = res?.expiresAt
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
            }
        }
    }

    func getSubscribersCount(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        result(nil)

        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        subscriberQueue.async {
            do {
                var count: Int = 0
                try client.getSubscribersCount(topicHash, ret0_: &count)
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["result"] = count
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
            }
        }
    }

    func genClientIfNotExists(_ account: NknAccount, _ identifier: String?, _ customClientUrl: String?) -> NknMultiClient? {
        let clientConfig = NknClientConfig()
        if (customClientUrl != nil) {
            clientConfig.seedRPCServerAddr = NknStringArray.init(from: customClientUrl)
        }
        var error: NSError?
        
        if (self.multiClient == nil){
            self.multiClient = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        }
        if (error != nil) {
            closeClientIfExists()
            clientEventSink!(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return nil
        } else {
            return self.multiClient
        }
    }

    func ensureSameAccount(_ account: NknAccount?) -> String? {
        if (account == nil) {
            closeClientIfExists()
            return nil
        } else {
            let pubkey = account!.pubKey()?.toHex
            if (accountPubkeyHex != pubkey) {
                closeClientIfExists()
            }
            return pubkey
        }
    }

    func closeClientIfExists() {
        do {
            try multiClient?.close()
        } catch {
        }
        multiClient = nil
        isConnected = false
    }
    
    func getBlockHeight(_ call: FlutterMethodCall, _ result: FlutterResult){
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        guard let client = self.multiClient else {
            clientEventSink?(FlutterError.init(code: _id, message: "no client", details: nil))
            return
        }
        sendMessageQueue.async {
            do {
                var height: Int32 = 0
                try client.getHeight(&height);
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["height"] = height
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: error.localizedDescription, details: nil))
            }
        }
    }
    
    func fetchDeviceToken(_ call: FlutterMethodCall, _ result: FlutterResult){
        let deviceToken = UserDefaults.standard.object(forKey: "nkn_device_token");
        let args = call.arguments as! [String:Any]
        let _id = args["_id"] as! String;
        
        var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = "fetch_device_token"
            resp["device_token"] = deviceToken
        self.clientEventSink!(resp)
    }
    
    func fetchFCMToken(_ call: FlutterMethodCall, _ result: FlutterResult){
        let fcmToken = UserDefaults.standard.object(forKey: "nkn_fcm_token");
        let args = call.arguments as! [String:Any]
        let _id = args["_id"] as! String;
        
        var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = "fetch_fcm_token"
            resp["fcm_token"] = fcmToken
        self.clientEventSink!(resp)
    }
    
    func getDictionaryFromJSONString(jsonString:String) ->NSDictionary{
        let jsonData:Data = jsonString.data(using: .utf8)!
        let dict = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
        if dict != nil {
            return dict as! NSDictionary
        }
        return NSDictionary()
    }
    
    func onBackgroundOpen(){
        print("后台启动任务")
        guard self.accountSeedBytes.elementSize != 0 else {
            return
        }
        var error: NSError?
        let account = NknNewAccount(accountSeedBytes.data, &error)
        self.multiClient = genClientIfNotExists(account!,self.identifierC, self.identifierC)
        connect()
        onAsyncMessageReceive()
    }
    
    func onBackgroundClose(){
        print("关闭后台任务")
        closeClientIfExists()
    }
    
    @objc func becomeActive(noti:Notification){
        guard self.accountSeedBytes.elementSize != 0 else {
            return
        }
        var error: NSError?
        let account = NknNewAccount(accountSeedBytes.data, &error)
        self.multiClient = genClientIfNotExists(account!,self.identifierC, self.identifierC)
        print("NKNClient进入前台")
        connect()
        onAsyncMessageReceive()
    }
    
    @objc func becomeDeath(noti:Notification){
        print("NKNClient进入后台")
        closeClientIfExists()
    }
}

extension Data {
    var toHex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
