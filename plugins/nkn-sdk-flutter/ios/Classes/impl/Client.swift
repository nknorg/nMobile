import Nkn

class Client : ChannelBase, IChannelHandler, FlutterStreamHandler {
    let clientQueue = DispatchQueue(label: "org.nkn.sdk/client/queue", qos: .default, attributes: .concurrent)
    let clientSendQueue = DispatchQueue(label: "org.nkn.sdk/client/send/queue", qos: .default, attributes: .concurrent)
    let clientEventQueue = DispatchQueue(label: "org.nkn.sdk/client/event/queue", qos: .default, attributes: .concurrent)
    let clientTransferQueue = DispatchQueue(label: "org.nkn.sdk/client/transfer/queue", qos: .default, attributes: .concurrent)
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    let CHANNEL_NAME = "org.nkn.sdk/client"
    let EVENT_NAME = "org.nkn.sdk/client/event"
    
    var clientMap: [String:NknMultiClient] = [String:NknMultiClient]()
    
    func install(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: binaryMessenger)
        self.methodChannel?.setMethodCallHandler(handle)
        self.eventChannel = FlutterEventChannel(name: EVENT_NAME, binaryMessenger: binaryMessenger)
        self.eventChannel?.setStreamHandler(self)
    }
    
    func uninstall() {
        self.methodChannel?.setMethodCallHandler(nil)
        self.eventChannel?.setStreamHandler(nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func resultError(_ error: NSError?, code: String? = nil) -> FlutterError {
        return FlutterError(code: code ?? String(error?.code ?? 0), message: error?.localizedDescription, details: "")
    }
    private func resultError(_ error: Error?, code: String? = "") -> FlutterError {
        return FlutterError(code: code ?? "", message: error?.localizedDescription, details: "")
    }
    
    private func createClient(account: NknAccount, identifier: String = "", config: NknClientConfig) -> NknMultiClient? {
        let pubKey: String = account.pubKey()!.hexEncode
        let id = identifier.isEmpty ? pubKey : "\(identifier).\(pubKey)"
        
        if (clientMap.keys.contains(id)) {
            closeClient(id: id)
        }
        let client = NknMultiClient(account, baseIdentifier: identifier, numSubClients: 3, originalClient: true, config: config)
        if (client == nil) {
            return nil
        }
        clientMap[client!.address()] = client
        return client!
    }
    
    private func closeClient(id: String) {
        if (!clientMap.keys.contains(id)) {
            return
        }
        do {
            try clientMap[id]?.close()
        } catch let error {
            self.eventSinkError(eventSink: eventSink!, error: error, code: id)
        }
        clientMap.removeValue(forKey: id)
    }
    
    private func onConnect(client: NknMultiClient) {
        guard let node = client.onConnect?.next() else {
            return
        }
        
        var resp: [String: Any] = [String: Any]()
        resp["_id"] = client.address()
        resp["event"] = "onConnect"
        resp["node"] = ["address": node.addr, "publicKey": node.pubKey]
        resp["client"] = ["address": client.address()]
        NSLog("%@", resp)
        self.eventSinkSuccess(eventSink: eventSink!, resp: resp)
    }
    
    private func onMessage(client: NknMultiClient) {
        guard let msg = client.onMessage?.next() else {
            return
        }
        
        var resp: [String: Any] = [String: Any]()
        resp["_id"] = client.address()
        resp["event"] = "onMessage"
        resp["data"] = [
            "src": msg.src,
            "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
            "type": msg.type,
            "encrypted": msg.encrypted,
            "messageId": msg.messageID != nil ? FlutterStandardTypedData(bytes: msg.messageID!) : nil
        ]
        NSLog("%@", resp)
        self.eventSinkSuccess(eventSink: eventSink!, resp: resp)
        self.onMessage(client: client)
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "create":
            create(call, result: result)
        case "close":
            close(call, result: result)
        case "sendText":
            sendText(call, result: result)
        case "publishText":
            publishText(call, result: result)
        case "subscribe":
            subscribe(call, result: result)
        case "unsubscribe":
            unsubscribe(call, result: result)
        case "getSubscribersCount":
            getSubscribersCount(call, result: result)
        case "getSubscribers":
            getSubscribers(call, result: result)
        case "getSubscription":
            getSubscription(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func create(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let identifier = args["identifier"] as? String ?? ""
        let seed = args["seed"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]

        clientQueue.async {
            var error: NSError?
            let config: NknClientConfig = NknClientConfig()
            if(seedRpc != nil){
                config.seedRPCServerAddr = NknStringArray(from: nil)
                for (_, v) in seedRpc!.enumerated() {
                    config.seedRPCServerAddr?.append(v)
                }
            }
            let account = NknNewAccount(seed?.data, &error)!
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            guard let client = self.createClient(account: account, identifier: identifier, config: config) else {
                self.resultError(result: result, code: "", message: "connect fail")
                return
            }

            var resp:[String:Any] = [String:Any]()
            resp["address"] = client.address()
            resp["publicKey"] = client.pubKey()
            resp["seed"] = client.seed()
            self.resultSuccess(result: result, resp: resp)
            self.onConnect(client: client)
            self.onMessage(client: client)
        }
    }
    
    private func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        clientQueue.async {
            self.closeClient(id: _id)
            self.resultSuccess(result: result, resp: nil)
        }
    }
    
    private func sendText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        let noReply = args["noReply"] as? Bool ?? true
        let timeout = args["timeout"] as? Int32 ?? 10000
        
        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }
        
        let nknDests = NknStringArray(from: nil)!
        if(!dests.isEmpty) {
            for dest in dests {
                nknDests.append(dest)
            }
        }
        
        clientSendQueue.async {
            do {
                let config: NknMessageConfig = NknMessageConfig()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                config.noReply = noReply
                
                if (!noReply) {
                    let onMessage: NknOnMessage = try client.sendText(nknDests, data: data, config: config)
                    guard let msg = onMessage.next(withTimeout: timeout) else {
                        self.resultSuccess(result: result, resp: nil)
                        return
                    }
                    
                    var resp: [String: Any] = [String: Any]()
                    resp["src"] = msg.src
                    resp["data"] = String(data: msg.data!, encoding: String.Encoding.utf8)!
                    resp["type"] = msg.type
                    resp["encrypted"] = msg.encrypted
                    resp["messageId"] = msg.messageID != nil ? FlutterStandardTypedData(bytes: msg.messageID!) : nil
                    self.resultSuccess(result: result, resp: resp)
                    return
                } else {
                    try client.sendText(nknDests, data: data, config: config)
                    var resp: [String: Any] = [String: Any]()
                    resp["messageId"] = config.messageID
                    self.resultSuccess(result: result, resp: resp)
                    return
                }
            } catch let error {
                self.resultError(result: result, error: error, code: _id)
            }
        }
    }
    
    private func publishText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        
        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }
        
        clientSendQueue.async {
            do {
                let config: NknMessageConfig = NknMessageConfig()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                
                try client.publishText(topic, data: data, config: config)
                var resp: [String: Any] = [String: Any]()
                resp["messageId"] = config.messageID
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error, code: _id)
            }
        }
    }
    
    private func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        
        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }
        
        clientTransferQueue.async {
            var error: NSError?
            
            let config: NknTransactionConfig = NknTransactionConfig()
            config.fee = fee
            
            let hash = client.subscribe(identifier, topic: topic, duration: duration, meta: meta, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error, code: _id)
                return
            }
            
            self.resultSuccess(result: result, resp: hash)
            return
        }
    }
    
    private func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let fee = args["fee"] as? String ?? "0"
        
        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }
        
        clientTransferQueue.async {
            var error: NSError?
            
            let config: NknTransactionConfig = NknTransactionConfig()
            config.fee = fee
            
            let hash = client.unsubscribe(identifier, topic: topic, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error, code: _id)
                return
            }
            
            self.resultSuccess(result: result, resp: hash)
            return
        }
    }
    
    private func getSubscribers(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 0
        let meta = args["meta"] as? Bool ?? true
        let txPool = args["txPool"] as? Bool ?? true
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData

        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }

        clientTransferQueue.async {
            do {
                let res: NknSubscribers? = try client.getSubscribers(topic, offset: offset, limit: limit, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix?.data)
                let mapPro = MapProtocol()
                res?.subscribers?.range(mapPro)
                self.resultSuccess(result: result, resp: mapPro.result)
                return
            } catch let error {
                self.resultError(result: result, error: error, code: _id)
                return
            }
        }
    }

    private func getSubscribersCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData

        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }

        clientTransferQueue.async {
            do {
                var count: Int = 0
                try client.getSubscribersCount(topic, subscriberHashPrefix: subscriberHashPrefix?.data, ret0_: &count)
                self.resultSuccess(result: result, resp: count)
                return
            } catch let error {
                self.resultError(result: result, error: error, code: _id)
                return
            }
        }
    }
    
    private func getSubscription(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let subscriber = args["subscriber"] as! String
        
        guard (clientMap.keys.contains(_id)) else {
            result(FlutterError(code: "", message: "client is null", details: ""))
            return
        }
        guard let client = clientMap[_id] else{
            return
        }
        
        clientTransferQueue.async {
            do {
                let res: NknSubscription = try client.getSubscription(topic, subscriber: subscriber)
                var resp: [String: Any] = [String: Any]()
                resp["meta"] = res.meta
                resp["expiresAt"] = res.expiresAt
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error, code: _id)
                return
            }
        }
    }
}
