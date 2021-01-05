import Flutter
import UIKit
import Nkn

public class NknClientPlugin : NSObject, FlutterStreamHandler {
    var clientEventSink: FlutterEventSink?
    
    // Client Queue
    var nknClient: NknMultiClient?
    let createClientQueue = DispatchQueue(label: "org.nkn.sdk/client/event/onconnect", attributes: .concurrent)
    private var createClientWorkItem: DispatchWorkItem?
    
    // Connect Queue
    private var onConnectWorkItem: DispatchWorkItem?
    let onConnectQueue = DispatchQueue(label: "org.nkn.sdk/client/event/onmessage", qos: .default)
    
    // Receive Message Queue
    private var receiveMessageWorkItem: DispatchWorkItem?
    private let receivedMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/receive", qos: .default)
    
    // Send Message Queue
    private var sendMessageWorkItem: DispatchWorkItem?
    private let sendMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/send", qos: .default)
    
    // Subscribe Queue
    private var subscriberWorkItem: DispatchWorkItem?
    private let subscriberQueue = DispatchQueue(label: "org.nkn.sdk/client/subscriber", attributes: .concurrent)
    
    private var isConnected = false
    private var accountPubkeyHex: String?
    
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
        print("Method Called"+call.method)
        switch call.method {
            case "createClient":
                result(nil)
                createClient(call, result)
            case "connect":
                print("called onConnect")
                result(nil)
                connectNkn()
            case "disConnect":
                disConnect(call, result, true)
            case "sendText":
                sendText(call, result);
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

    func createClient(_ call: FlutterMethodCall, _ result: FlutterResult) {
        if (nknClient != nil){
            self.connectNkn()
            return;
        }
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let seedBytes = args["seedBytes"] as! FlutterStandardTypedData
        
        let identifier = args["identifier"] as? String
        let clientUrl = args["clientUrl"] as? String
        
        if(onConnectWorkItem?.isCancelled == false) {
            onConnectWorkItem?.cancel()
        }
        createClientWorkItem = DispatchWorkItem {
            var error: NSError?
            let account = NknNewAccount(seedBytes.data, &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
                return
            }
            self.accountPubkeyHex = self.ensureSameAccount(account!)
            self.nknClient = self.genClientIfNotExists(account!, identifier, clientUrl)
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = "createClient"
            resp["success"] = (self.nknClient == nil) ? 0 : 1
            self.clientEventSink!(resp)
            
            print("CreateClient End")
            self.connectNkn()
        }
        createClientQueue.async(execute: createClientWorkItem!)
    }

    public func connectNkn() {
        print("Connect NKN begin");
        if (isConnected) {
            print("Reconnect NKN begin");
            var data: [String: Any] = [String: Any]()
            data["event"] = "onConnect"
            data["node"] = ["address": "reconnect", "publicKey": "node"]
            data["client"] = ["address": self.nknClient?.address()]
            self.clientEventSink?(data)
            return
        }
        if (self.nknClient == nil){
            print("create Client first")
            return
        }
        let node = self.nknClient?.onConnect?.next()
        if (node == nil) {
            return
        }
        isConnected = true
        var resp: [String: Any] = [String: Any]()
        resp["event"] = "onConnect"
        resp["node"] = ["address": node?.addr, "publicKey": node?.pubKey]
        resp["client"] = ["address": self.nknClient?.address()]
        self.clientEventSink?(resp)
        
        print("Connect NKN end");
        
        if(onConnectWorkItem?.isCancelled == false) {
            onConnectWorkItem?.cancel()
        }
        onAsyncMessageReceive();
    }

    func disConnect(_ call: FlutterMethodCall, _ result: FlutterResult, _ callFromDart: Bool) {
        let clientAddr = nknClient?.address()
        print("Disconnect","disConnect called close")
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
        onConnectWorkItem = DispatchWorkItem {
            self.onMessageListening()
        }
        onConnectQueue.async(execute: onConnectWorkItem!)
    }
    
    // 启用定时器
    func onMessageListening(){
        print("Test onMessageListening");
        if (self.nknClient == nil){
            print("onMessageListening multiClient == nil");
            return;
        }
        let onMessage: NknOnMessage? = self.nknClient?.onMessage
        guard let msg = onMessage?.next() else{
            print("on No Message")
            return
        }
        print("onMessageListening onMessage");
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
        client1["address"] = self.nknClient?.address()
        data["client"] = client1
        self.clientEventSink!(data)
        print("onMessageListening onMessage");
        
        self.onAsyncMessageReceive()
    }

    func sendText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        sendMessageWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let dests = args["dests"] as! [String]
            let data = args["data"] as! String
            let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
            
            let dataInfo = self.getDictionaryFromJSONString(jsonString: data)
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
            }
            
            let config: NknMessageConfig = NknMessageConfig.init()
            config.maxHoldingSeconds = maxHoldingSeconds < 0 ? Int32.max : maxHoldingSeconds
            config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
            config.noReply = true
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "sendText no client", details: nil))
                return
            }

            let nknDests = NknStringArray.init(from: nil)!
            if(!dests.isEmpty) {
                for dest in dests {
                    nknDests.append(dest)
                }
            }

            do {
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
        sendMessageQueue.async(execute: sendMessageWorkItem!)
    }

    func publishText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        sendMessageWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let topicHash = args["topicHash"] as! String
            let data = args["data"] as! String
            let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
            
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "publishText no client", details: nil))
                return
            }
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
        sendMessageQueue.async(execute: sendMessageWorkItem!)
    }

    func subscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        subscriberWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let identifier = args["identifier"] as? String ?? ""
            let topicHash = args["topicHash"] as! String
            let duration = args["duration"] as! Int
            let meta = args["meta"] as? String
            let fee = args["fee"] as? String ?? "0"
        
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "subscribe no client", details: nil))
                return
            }
            
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
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func unsubscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        subscriberWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let identifier = args["identifier"] as? String ?? ""
            let topicHash = args["topicHash"] as! String
            let fee = args["fee"] as? String ?? "0"
            
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "unsubscribe no client", details: nil))
                return
            }

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
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscribers(_ call: FlutterMethodCall, _ result: FlutterResult) {
        subscriberWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let topicHash = args["topicHash"] as! String
            let offset = args["offset"] as? Int ?? 0
            let limit = args["limit"] as? Int ?? 0
            let meta = args["meta"] as? Bool ?? true
            let txPool = args["txPool"] as? Bool ?? true
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "getSubscribers no client", details: nil))
                return
            }

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
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscription(_ call: FlutterMethodCall, _ result: FlutterResult) {
        subscriberWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let topicHash = args["topicHash"] as! String
            let subscriber = args["subscriber"] as! String
            
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "getSubscription no client", details: nil))
                return
            }

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
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscribersCount(_ call: FlutterMethodCall, _ result: FlutterResult) {
        subscriberWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            let topicHash = args["topicHash"] as! String
            
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: "getSubscribersCount no client", details: nil))
                return
            }
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
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func genClientIfNotExists(_ account: NknAccount, _ identifier: String?, _ customClientUrl: String?) -> NknMultiClient? {
        let clientConfig:NknClientConfig;
        if (identifier != nil && customClientUrl != nil){
            clientConfig = NknClientConfig()
            clientConfig.seedRPCServerAddr = NknStringArray.init(from: customClientUrl)
        }
        else{
            clientConfig = NknGetDefaultClientConfig() ?? NknClientConfig()
        }
        var error: NSError?
        
        let client = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        if (error != nil) {
            closeClientIfExists()
            clientEventSink!(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return nil
        } else {
            self.nknClient = client
            return client
        }
    }

    func ensureSameAccount(_ account: NknAccount?) -> String? {
        if (account == nil) {
            closeClientIfExists()
            return nil
        } else {
            let pubkey = account!.pubKey()?.toHex
            if (pubkey == nil){
                return nil;
            }
            if (accountPubkeyHex == nil){
                return pubkey;
            }
            if (accountPubkeyHex != pubkey) {
                closeClientIfExists()
            }
            return pubkey
        }
    }

    func closeClientIfExists() {
        print("Client on close called");
        do {
            try nknClient?.close()
        } catch {
        }
        nknClient = nil
        isConnected = false
    }
    
    func getBlockHeight(_ call: FlutterMethodCall, _ result: FlutterResult){
        sendMessageWorkItem = DispatchWorkItem{
            let args = call.arguments as! [String: Any]
            let _id = args["_id"] as! String
            
            do {
                guard let client = self.nknClient else {
                    self.clientEventSink?(FlutterError.init(code: _id, message: "getBlockHeight no client", details: nil))
                    return
                }
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
        sendMessageQueue.async(execute: sendMessageWorkItem!)
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
    
    func closeCurrentConnect(){
        closeClientIfExists()
        NKNPushService.shared().disConnectAPNS()
        sendMessageWorkItem?.cancel()
        receiveMessageWorkItem?.cancel()
        subscriberWorkItem?.cancel()
        createClientWorkItem?.cancel()
        onConnectWorkItem?.cancel()
    }
    
    @objc func becomeActive(noti:Notification){
//        guard self.accountSeedBytes.elementSize != 0 else {
//            return
//        }
//        var error: NSError?
//        let account = NknNewAccount(accountSeedBytes.data, &error)
//        self.nknClient = genClientIfNotExists(account!,self.identifierC, self.identifierC)
//        connectNkn()
//        onAsyncMessageReceive()
        print("NKNClient进入前台")
        NKNPushService.shared().connectAPNS()
    }

    @objc func becomeDeath(noti:Notification){
        print("NKNClient进入后台")
//        closeClientIfExists()
        NKNPushService.shared().disConnectAPNS()
        sendMessageWorkItem?.cancel()
        receiveMessageWorkItem?.cancel()
        subscriberWorkItem?.cancel()
        createClientWorkItem?.cancel()
        onConnectWorkItem?.cancel()
    }
}

extension Data {
    var toHex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
