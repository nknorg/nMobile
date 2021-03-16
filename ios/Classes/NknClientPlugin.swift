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
    let onConnectQueue = DispatchQueue(label: "org.nkn.sdk/client/event/onmessage", qos: .userInteractive)
    
    // Receive Message Queue
    private var receiveMessageWorkItem: DispatchWorkItem?
    private let receivedMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/receive", qos: .userInteractive)
    
    // Send Message Queue
    private var sendMessageWorkItem: DispatchWorkItem?
    private let sendMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/send", qos: .userInteractive)
    
    // Subscribe Queue
    private var subscriberWorkItem: DispatchWorkItem?
    private let subscriberQueue = DispatchQueue(label: "org.nkn.sdk/client/subscriber", attributes: .concurrent)
    
    let intoPieceQueue = DispatchQueue(label: "org.nkn.sdk/client/event/intoPieceQueue", qos: .userInteractive)
    
    private var isConnected = false
    private var accountPubkeyHex: String?
    
    // 创建需要
    private var accountSeedBytes:FlutterStandardTypedData = FlutterStandardTypedData()
    private var identifierC:String? = ""
    private var clientUrlC:String? = ""
        
    private var fetchRPCClientTimer: DispatchSourceTimer?
    var rpcCountDown:Int = 0
    var clientList = [String]()
    var currentRpcNode:NknNode?
    
    let NKN_METHOD_SEND_TEXT = "sendText"
    let NKN_METHOD_PUBLISH_TEXT = "publishText"
    
    let NKN_METHOD_SUBSCRIBER_TOPIC = "subscribe"
    let NKN_METHOD_UNSUBSCRIBER_TOPIC = "unsubscribe"
    
    let NKN_METHOD_GET_SUBSCRIPTION = "getSubscription"
    let NKN_METHOD_GET_BLOCK_HEIGHT = "getBlockHeight"
    
    let NKN_METHOD_GET_SUBSCRIBER_COUNT = "getSubscribersCount"
    let NKN_METHOD_GET_SUBSCRIBERS = "getSubscribers"
    
    let NKN_METHOD_FETCH_DEVICE_TOKEN = "fetchDeviceToken"
    let NKN_METHOD_FETCH_FCM_TOKEN = "fetchFcmToken"
    
    let NKN_METHOD_INTO_PIECES = "intoPieces"
    let NKN_METHOD_COMBINE_PIECES = "combinePieces"
    
//    var inputPieceString:String = ""
//    var splitsData = [FlutterStandardTypedData]()
    
//    var recoverList = [Data]()
    var combinedData:Data = Data.init()

    init(controller : FlutterViewController) {
        super.init()
        
        FlutterMethodChannel(name: "org.nkn.sdk/client", binaryMessenger: controller.binaryMessenger).setMethodCallHandler(methodCall)
        FlutterEventChannel(name: "org.nkn.sdk/client/event", binaryMessenger: controller.binaryMessenger).setStreamHandler(self)
        
        NotificationCenter.default.addObserver(self, selector:#selector(becomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(becomeDeath), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        clientEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }

    public func methodCall(_ call: FlutterMethodCall, _ result: FlutterResult) {
        NSLog("Method Called"+call.method)
        switch call.method {
            case "createClient":
                createClient(call, result)
            case "connect":
                connectNkn()
            case "disConnect":
                disConnect(call, result)
            case NKN_METHOD_SEND_TEXT:
                sendText(call, result);
            case NKN_METHOD_PUBLISH_TEXT:
                publishText(call, result)
            case NKN_METHOD_SUBSCRIBER_TOPIC:
                subscribe(call, result)
            case NKN_METHOD_UNSUBSCRIBER_TOPIC:
                unsubscribe(call, result)
            case NKN_METHOD_GET_SUBSCRIBER_COUNT:
                getSubscribersCount(call, result)
            case NKN_METHOD_GET_SUBSCRIBERS:
                getSubscribers(call, result)
            case NKN_METHOD_GET_SUBSCRIPTION:
                getSubscription(call, result)
            case NKN_METHOD_FETCH_DEVICE_TOKEN:
                fetchDeviceToken(call, result)
            case NKN_METHOD_GET_BLOCK_HEIGHT:
                getBlockHeight(call, result)
            case NKN_METHOD_FETCH_FCM_TOKEN:
                fetchFCMToken(call, result)
            case NKN_METHOD_INTO_PIECES:
                intoPiece(call, result)
            case NKN_METHOD_COMBINE_PIECES:
                combinePieces(call, result)
            default:
                result(FlutterMethodNotImplemented)
        }
    }
    
    func createClient(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        let seedBytes = args["seedBytes"] as! FlutterStandardTypedData
        let identifier = args["identifier"] as? String
        let clientUrl = args["rpcNodeList"] as? String
        
        self.accountSeedBytes = seedBytes
        self.identifierC = identifier
        self.clientUrlC = clientUrl
                                        
        let clientRpcCount:Int = clientUrl?.count ?? 0
        if (clientRpcCount > 0){
            clientList = clientUrl?.components(separatedBy: ",") ?? [""]
            for rpcNode in clientList{
                NSLog("CreateClient With rpcNode___%@___", rpcNode)
            }
        }
//        if(onConnectWorkItem?.isCancelled == false) {
//            onConnectWorkItem?.cancel()
//        }
        var error: NSError?
        let account = NknNewAccount(seedBytes.data, &error)
        if (error != nil) {
            self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
            return
        }
        
        createClientWorkItem = DispatchWorkItem {
            self.nknClient = self.genNKNClient(account!, identifier)
            if (self.nknClient != nil){
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["event"] = "createClient"
                resp["success"] = (self.nknClient == nil) ? 0 : 1
                self.clientEventSink!(resp)
                self.connectNkn()
            }
            else{
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["event"] = "createClient"
                resp["success"] = (self.nknClient == nil) ? 0 : 1
                self.clientEventSink!(resp)
                NSLog("CreateClient Failed")
            }
        }
        createClientQueue.async(execute: createClientWorkItem!)
    }

    public func connectNkn() {
        if (isConnected) {
            NSLog("Reconnect NKN begin");
            var data: [String: Any] = [String: Any]()
            data["event"] = "onConnect"
            data["node"] = ["address": "reconnect", "publicKey": "node"]
            data["client"] = ["address": self.nknClient?.address()]
            self.clientEventSink?(data)
            return
        }
        if (self.nknClient == nil){
            NSLog("create Client first")
            return
        }
        let node = self.nknClient?.onConnect?.next()
        currentRpcNode = node
        if (node == nil) {
            return
        }
        isConnected = true
        var resp: [String: Any] = [String: Any]()
        resp["event"] = "onConnect"
        resp["node"] = ["address": node?.addr, "publicKey": node?.pubKey]
        resp["client"] = ["address": self.nknClient?.address()]
        self.clientEventSink?(resp)
        
        self.startRPCTimer()
        
        NSLog("Connect NKN end");
        
//        if(onConnectWorkItem?.isCancelled == false) {
//            onConnectWorkItem?.cancel()
//        }
        onAsyncMessageReceive();
    }
    
    @objc func timerFetchRPC() {
        let mClient = self.nknClient?.getClient(-1)
        let mNode = mClient?.getNode() ?? nil
        var mRpcAddress:String = mNode?.rpcAddr ?? ""
        
        if (mRpcAddress.count > 0 && !self.clientList.contains(mRpcAddress)){
            mRpcAddress = "http://"+mRpcAddress
            self.clientList.append(mRpcAddress)
            NSLog("clientListAppend is ___%@____",mRpcAddress)
        }
        for index in 0...3 {
            let client = self.nknClient?.getClient(index)
            let node = client?.getNode() ?? nil
            var rpcAddress:String = node?.rpcAddr ?? ""
            if (rpcAddress.count > 0){
                rpcAddress = "http://"+rpcAddress
                NSLog("clientListAppend isrpcAddress ___%@____",rpcAddress)
                if (!self.clientList.contains(rpcAddress)){
                    self.clientList.append(rpcAddress)
                }
            }
        }
        if (self.clientList.count > 0){
            NSLog("stop RPC called")
            self.stopRPCTimer()
        }
    }
    
    func startRPCTimer(){
        // child operation generator timer
        fetchRPCClientTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
        fetchRPCClientTimer?.schedule(deadline: .now() + .seconds(1), repeating: DispatchTimeInterval.seconds(10), leeway: DispatchTimeInterval.seconds(0))
        fetchRPCClientTimer?.setEventHandler {
            self.timerFetchRPC()
        }
        fetchRPCClientTimer?.resume()
    }
    
    func stopRPCTimer() {
        guard let timer = fetchRPCClientTimer else {
            return
        }
        timer.cancel()
        fetchRPCClientTimer = nil
        
        let clientAddr = nknClient?.address()
        
        var data: [String: Any] = [String: Any]()
        data["event"] = "onSaveNodeAddresses"
        var client: [String: Any] = [String: Any]()
        
        let addressLString = clientList.joined(separator: ",");
        client["nodeAddress"] = addressLString
        client["clientAddress"] = clientAddr
        
        data["client"] = client
        clientEventSink!(data)
    }

    func disConnect(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let clientAddr = nknClient?.address()
        closeNKNClient()
        
        var data: [String: Any] = [String: Any]()
        data["event"] = "disConnect"
        var client: [String: Any] = [String: Any]()
        client["address"] = clientAddr
        data["client"] = client
        clientEventSink!(data)
    }
    
    func combinePieces(_ call: FlutterMethodCall, _ result: FlutterResult){
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        let dataShards = args["dataShards"] as! NSInteger
        let parityShards = args["parityShards"] as! NSInteger
        let bytesLength:NSInteger = args["bytesLength"] as! NSInteger
        let fDataList = args["data"] as! [FlutterStandardTypedData]
        
        var dataList = [Data]()
        for index in 0..<fDataList.count {
            let fData:FlutterStandardTypedData = fDataList[index]
            dataList.append(fData.data)
        }
        
        let combinedString:String = NKNPushService.shared().combinePieces(dataList, dataShard: dataShards, parityShards: parityShards, bytesLength: bytesLength)

        intoPieceQueue.async {
            var resp:[String: Any] = [String: Any]()
            resp["_id"] = _id;
            resp["event"] = self.NKN_METHOD_COMBINE_PIECES;
            
            resp["data"] = combinedString;
            self.clientEventSink!(resp);
//            do{
//
//            }
//            catch let error {
//                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_COMBINE_PIECES, details: error.localizedDescription))
//            }
        }
    }
    
    func intoPiece(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let flutterDataString = args["data"] as! String
    
        let dataShards = args["dataShards"] as! NSInteger
        let parityShards = args["parityShards"] as! NSInteger
    
        intoPieceQueue.async {
            let rArray = NKNPushService.shared().intoPieces(flutterDataString, dataShard: dataShards, parityShards: parityShards)
            var dataBytes = [FlutterStandardTypedData]()
            for index in 0..<rArray.count {
                let fData = FlutterStandardTypedData(bytes: rArray[index])
                dataBytes.append(fData)
            }
            var resp:[String: Any] = [String: Any]()
            resp["_id"] = _id;
            resp["event"] = self.NKN_METHOD_INTO_PIECES;
            resp["data"] = dataBytes;
            self.clientEventSink!(resp);
//            do{
//                try
//            }
//            catch let error {
//                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_INTO_PIECES, details: error.localizedDescription))
//            }
        }
    }

    
    func onAsyncMessageReceive(){
        onConnectWorkItem = DispatchWorkItem {
            self.onMessageListening()
        }
        onConnectQueue.async(execute: onConnectWorkItem!)
    }
    
    func onMessageListening(){
        if (self.nknClient == nil){
            NSLog("onMessageListening multiClient == nil");
            return;
        }
        let onMessage: NknOnMessage? = self.nknClient?.onMessage
        guard let msg = onMessage?.next() else{
            NSLog("on No Message")
            return
        }
        var data: [String: Any] = [String: Any]()
        
        if (msg.data == nil){
            let noDataString = "world"
            msg.data = noDataString.data(using: .utf8)!
            NSLog("onMessageListening msg.data == nil")
        }

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
        NSLog("onMessageListening onMessage");
        
        self.onAsyncMessageReceive()
    }

    func sendText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let msgId = args["msgId"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
        
        sendMessageWorkItem = DispatchWorkItem{
            let config: NknMessageConfig = NknMessageConfig.init()
            config.maxHoldingSeconds = maxHoldingSeconds < 0 ? Int32.max : maxHoldingSeconds
            config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
            config.noReply = true
            
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_SEND_TEXT, details: "noClient"))
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
                resp["event"] = self.NKN_METHOD_SEND_TEXT
                resp["pid"] = config.messageID
                resp["msgId"] = msgId
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_SEND_TEXT, details: error.localizedDescription))
            }
            
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
                                NSLog("after drop Fcm token is",dropFcmToken);
                                pushService.pushContent(content, token: dropFcmToken);
                            }
                        }
                    }
                }
            }
        }
        sendMessageQueue.async(execute: sendMessageWorkItem!)
    }

    func publishText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
        
        sendMessageWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_PUBLISH_TEXT, details: "noClient"))
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
                    resp["event"] = self.NKN_METHOD_PUBLISH_TEXT
                    resp["pid"] = config.messageID
                    self.clientEventSink!(resp)
                } catch let error {
                    self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_PUBLISH_TEXT, details: error.localizedDescription))
                }
        }
        
        sendMessageQueue.async(execute: sendMessageWorkItem!)
    }

    func subscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topicHash = args["topicHash"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        
        subscriberWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message:self.NKN_METHOD_SUBSCRIBER_TOPIC, details: "noClient"))
                return
            }
            
            let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
            transactionConfig.fee = fee

            var error: NSError?
            
            let hash = client.subscribe(identifier, topic: topicHash, duration: duration, meta: meta, config: transactionConfig, error: &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_SUBSCRIBER_TOPIC, details: error!.localizedDescription))
                return
            }
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["data"] = hash
            resp["event"] = self.NKN_METHOD_SUBSCRIBER_TOPIC
            self.clientEventSink!(resp)
        }
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func unsubscribe(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topicHash = args["topicHash"] as! String
        let fee = args["fee"] as? String ?? "0"
        
        subscriberWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_UNSUBSCRIBER_TOPIC, details: "noClient"))
                return
            }

            let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
            transactionConfig.fee = fee

            var error: NSError?
            
            let hash = client.unsubscribe(identifier, topic: topicHash, config: transactionConfig, error: &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_UNSUBSCRIBER_TOPIC, details: error!.localizedDescription))
                return
            }
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = self.NKN_METHOD_UNSUBSCRIBER_TOPIC
            resp["data"] = hash
            self.clientEventSink!(resp)
        }
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscribers(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 0
        let meta = args["meta"] as? Bool ?? true
        let txPool = args["txPool"] as? Bool ?? true
        
        subscriberWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_GET_SUBSCRIBERS, details: "noClient"))
                return
            }
            do{
                let res: NknSubscribers? = try client.getSubscribers(topicHash, offset: offset, limit: limit, meta: meta, txPool: txPool)
                
                var resp: [String: Any] = [String: Any]()
                resp["event"] = self.NKN_METHOD_GET_SUBSCRIBERS;
                resp["_id"] = _id
                
                let mapPro = MapProtocol.init()
                res?.subscribersInTxPool?.range(mapPro)
                res?.subscribers?.range(mapPro)
                resp["data"] = mapPro.result
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_GET_SUBSCRIBERS, details: error.localizedDescription))
            }
        }
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscription(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        let subscriber = args["subscriber"] as! String
        
        subscriberWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_GET_SUBSCRIPTION, details: "noClient"))
                return
            }

            do{
                let res: NknSubscription? = try client.getSubscription(topicHash, subscriber: subscriber)
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["meta"] = res?.meta
                resp["expiresAt"] = res?.expiresAt
                resp["event"] = self.NKN_METHOD_GET_SUBSCRIPTION
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_GET_SUBSCRIPTION, details: error.localizedDescription))
            }
        }
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func getSubscribersCount(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topicHash = args["topicHash"] as! String
        
        subscriberWorkItem = DispatchWorkItem{
            guard let client = self.nknClient else {
                self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_GET_SUBSCRIBER_COUNT, details: "noClient"))
                return
            }
            do {
                var count: Int = 0
                try client.getSubscribersCount(topicHash, ret0_: &count)
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = _id
                resp["data"] = count
                resp["event"] = self.NKN_METHOD_GET_SUBSCRIBER_COUNT
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_GET_SUBSCRIBER_COUNT, details: error.localizedDescription))
            }
        }
        subscriberQueue.async(execute: subscriberWorkItem!)
    }

    func genNKNClient(_ account: NknAccount, _ identifier: String?) -> NknMultiClient? {
        var clientConfig:NknClientConfig = NknClientConfig()
        var rpcString:NknStringArray?
        for index in 0..<clientList.count {
            let rpcAddress:String = clientList[index]
            if (index == 0){
                NSLog("NknStringArray.init__%@", rpcAddress);
                rpcString = NknStringArray.init(from: rpcAddress)!
            }
            else{
                NSLog("NknStringArray.append__%@", rpcAddress);
                rpcString?.append(rpcAddress)
            }
        }
        if (rpcString!.len() > 1){
            var measureError: NSError?
            let measuredRpcArray = NknMeasureSeedRPCServer(rpcString, 1500, &measureError)
            if (measureError != nil){
                NSLog("measureError is____%@", measureError!.localizedDescription)
            }
            if ((measuredRpcArray?.len())! > 0){
                let measuredRpcString:String = (measuredRpcArray?.randomElem())! as String
                NSLog("measureString is____%@",measuredRpcString)
                UserDefaults.standard.setValue(measuredRpcString, forKey: "nkn_measured_rpcNode")
            }
            clientConfig.seedRPCServerAddr = measuredRpcArray;
        }
        else{
            clientConfig = NknGetDefaultClientConfig()!
        }
        clientConfig.wsWriteTimeout = 20000
        var error: NSError?
        var client = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        if (error != nil){
            NSLog("Error is____%@", error!.localizedDescription)
            if (client == nil){
                let defaultClient:NknClientConfig = NknGetDefaultClientConfig()!
                defaultClient.wsWriteTimeout = 20000
                client = NknMultiClient.init(account, baseIdentifier: identifier, numSubClients: 3, originalClient: true, config: defaultClient)
            }
        }
        return client;
    }

    func closeNKNClient() {
        NSLog("Client on close called");
        do {
            try nknClient?.close()
        }
        catch {
            
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
                    self.clientEventSink?(FlutterError.init(code: _id, message: self.NKN_METHOD_GET_BLOCK_HEIGHT, details: "noClient"))
                    return
                }
                var height: Int32 = 0
                try client.getHeight(&height);
                var resp: [String: Any] = [String: Any]()
                resp["event"] = self.NKN_METHOD_GET_BLOCK_HEIGHT
                resp["_id"] = _id
                resp["height"] = height
                self.clientEventSink!(resp)
            } catch let error {
                self.clientEventSink!(FlutterError(code: _id, message: self.NKN_METHOD_GET_BLOCK_HEIGHT, details: error.localizedDescription))
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
            resp["device_token"] = deviceToken
            resp["event"] = self.NKN_METHOD_FETCH_DEVICE_TOKEN
        self.clientEventSink!(resp)
    }
    
    func fetchFCMToken(_ call: FlutterMethodCall, _ result: FlutterResult){
        let fcmToken = UserDefaults.standard.object(forKey: "nkn_fcm_token");
        let args = call.arguments as! [String:Any]
        let _id = args["_id"] as! String;
        
        var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = self.NKN_METHOD_FETCH_FCM_TOKEN
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
    
//    func closeCurrentConnect(){
//        closeClientIfExists()
//        NKNPushService.shared().disConnectAPNS()
//        sendMessageWorkItem?.cancel()
//        receiveMessageWorkItem?.cancel()
//        subscriberWorkItem?.cancel()
//        createClientWorkItem?.cancel()
////        onConnectWorkItem?.cancel()
//    }
    
    
    @objc func becomeActive(noti:Notification){
//        guard self.accountSeedBytes.elementSize != 0 else {
//            return
//        }
//
//        reCreateClient()
//        connectNkn()
//        onAsyncMessageReceive()
        NSLog("NKNClient Enter foreground")
        NKNPushService.shared().connectAPNS()
    }

    @objc func becomeDeath(noti:Notification){
        NSLog("NKNClient Enter background")
//        closeNKNClient()
        NKNPushService.shared().disConnectAPNS()
        
//        sendMessageWorkItem?.cancel()
//        receiveMessageWorkItem?.cancel()
//        subscriberWorkItem?.cancel()
//        createClientWorkItem?.cancel()
//        onConnectWorkItem?.cancel()
    }
}

extension Data {
    var toHex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
