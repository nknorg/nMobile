import Nkn

class Client : ChannelBase, IChannelHandler, FlutterStreamHandler {
    
    let CHANNEL_NAME = "org.nkn.sdk/client"
    let EVENT_NAME = "org.nkn.sdk/client/event"
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    
    let clientQueue = DispatchQueue(label: "org.nkn.sdk/client/queue", qos: .default, attributes: .concurrent)
    private var clientWorkItem: DispatchWorkItem?
    
    let clientSendQueue = DispatchQueue(label: "org.nkn.sdk/client/send/queue", qos: .default, attributes: .concurrent)
    private var clientSendWorkItem: DispatchWorkItem?
    
    // let clientReceiveQueue = DispatchQueue(label: "org.nkn.sdk/client/receive/queue", qos: .default, attributes: .concurrent)
    // private var clientReceiveWorkItem: DispatchWorkItem?
    
    let clientEventQueue = DispatchQueue(label: "org.nkn.sdk/client/event/queue", qos: .default, attributes: .concurrent)
    private var clientEventWorkItem: DispatchWorkItem?
    
    var numSubClients = 4
    var client: NknMultiClient?
    
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
        // eventSink = nil
        return nil
    }
    
    private func resultError(_ error: NSError?, code: String? = nil) -> FlutterError {
        return FlutterError(code: code ?? String(error?.code ?? 0), message: error?.localizedDescription, details: "")
    }
    
    private func resultError(_ error: Error?, code: String? = "") -> FlutterError {
        return FlutterError(code: code ?? "", message: error?.localizedDescription, details: "")
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "create":
            create(call, result: result)
        case "reconnect":
            reconnect(call, result: result)
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
        case "getHeight":
            getHeight(call, result: result)
        case "getNonce":
            getNonce(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func create(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let identifier = args["identifier"] as? String ?? ""
        let seed = args["seed"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]
        numSubClients = args["numSubClients"] as? Int ?? 4
        //let ethResolverConfigArray = args["ethResolverConfigArray"] as? [[String: Any]]
        //let dnsResolverConfigArray = args["dnsResolverConfigArray"] as? [[String: Any]]
        
        clientWorkItem = DispatchWorkItem {
            // config
            let config: NknClientConfig = NknClientConfig()
            config.connectRetries = 1
            config.maxReconnectInterval = 5 * 1000
            if(seedRpc != nil) {
                config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
                for (_, v) in seedRpc!.enumerated() {
                    config.seedRPCServerAddr?.append(v)
                }
            }
            // account
            var error: NSError?
            let account = NknNewAccount(seed?.data, &error)!
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            // client
            var error1: NSError?
            self.client = NknNewMultiClient(account, identifier, self.numSubClients, true, config, &error1)
            if ((error1 != nil) || (self.client == nil)) {
                NkngolibAddClientConfigWithDialContext(config)
                var error2: NSError?
                self.client = NknNewMultiClient(account, identifier, self.numSubClients, true, config, &error2)
                if (error2 != nil) {
                    self.resultError(result: result, error: error2)
                    return
                } else if (self.client == nil) {
                    self.resultError(result: result, message: "connect fail", details: "in func create")
                    return
                }
            }
            // result
            var resp:[String:Any] = [String:Any]()
            resp["address"] = self.client?.address()
            resp["publicKey"] = self.client?.pubKey()
            resp["seed"] = self.client?.seed()
            self.resultSuccess(result: result, resp: resp)
            // onListen
            self.onConnect()
            self.onMessage()
        }
        clientQueue.async(execute: clientWorkItem!)
    }
    
    private func onConnect() {
        guard let node = client?.onConnect?.next() else {
            return
        }
        
        var resp: [String: Any] = [String: Any]()
        resp["_id"] = client?.address()
        resp["event"] = "onConnect"
        resp["node"] = ["address": node.addr, "publicKey": node.pubKey]
        resp["client"] = ["address": client?.address()]
        var rpcServers = [String]()
        for i in 0...numSubClients {
            let c = client?.getClient(i)
            let rpcNode = c?.getNode()
            var rpcAddr = rpcNode?.rpcAddr ?? ""
            if (rpcAddr.count > 0) {
                rpcAddr = "http://" + rpcAddr
                if(!rpcServers.contains(rpcAddr)) {
                    rpcServers.append(rpcAddr)
                }
            }
        }
        resp["rpcServers"] = rpcServers
        self.eventSinkSuccess(eventSink: eventSink, resp: resp)
    }
    
    private func onMessage() {
        while (true) {
            guard let msg = client?.onMessage?.next() else {
                continue
            }
            // clientReceiveWorkItem = DispatchWorkItem {
            self.onMessageHandle(msg: msg)
            // }
            // clientReceiveQueue.async(execute: clientReceiveWorkItem!)
        }
    }
    
    private func onMessageHandle(msg: NknMessage) {
        var resp: [String: Any] = [String: Any]()
        resp["_id"] = client?.address()
        resp["event"] = "onMessage"
        resp["data"] = [
            "src": msg.src,
            "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
            "type": msg.type,
            "encrypted": msg.encrypted,
            "messageId": msg.messageID != nil ? FlutterStandardTypedData(bytes: msg.messageID!) : nil
        ]
        //NSLog("onMessage - %@", String(data: msg.data!, encoding: String.Encoding.utf8)!)
        self.eventSinkSuccess(eventSink: eventSink, resp: resp)
    }
    
    private func reconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        clientWorkItem = DispatchWorkItem {
            if (self.client != nil) {
                self.client?.reconnect()
                self.resultSuccess(result: result, resp: nil)
            } else {
                self.resultError(result: result, message: "client is closed", details: "in func reconnect")
            }
        }
        clientQueue.async(execute: clientWorkItem!)
    }
    
    private func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        clientWorkItem = DispatchWorkItem {
            do {
                try self.client?.close()
                self.client = nil
                self.resultSuccess(result: result, resp: nil)
            } catch let error {
                self.resultError(result: result, error: error)
            }
        }
        clientQueue.async(execute: clientWorkItem!)
    }
    
    private func sendText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        let noReply = args["noReply"] as? Bool ?? true
        let timeout = args["timeout"] as? Int32 ?? 10000
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func sendText"))
            return
        }
        
        clientSendWorkItem = DispatchWorkItem {
            do {
                let nknDests: NkngomobileStringArray? = NkngomobileNewStringArrayFromString(nil)
                if(!dests.isEmpty) {
                    for dest in dests {
                        nknDests?.append(dest)
                    }
                }
                
                let config: NknMessageConfig = NknMessageConfig()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                config.noReply = noReply
                
                let onMessage: NknOnMessage? = try self.client?.sendText(nknDests, data: data, config: config)
                if (onMessage == nil) {
                    self.resultSuccess(result: result, resp: nil)
                    return
                }
                if (noReply) {
                    var resp: [String: Any] = [String: Any]()
                    resp["messageId"] = config.messageID
                    self.resultSuccess(result: result, resp: resp)
                    return
                } else {
                    guard let msg = onMessage?.next(withTimeout: timeout) else {
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
                }
            } catch let error {
                self.resultError(result: result, error: error)
            }
        }
        clientSendQueue.async(execute: clientSendWorkItem!)
    }
    
    private func publishText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        let txPool = args["txPool"] as? Bool ?? false
        let offset = args["offset"] as? Int32 ?? 0
        let limit = args["limit"] as? Int32 ?? 1000
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func publishText"))
            return
        }
        
        clientSendWorkItem = DispatchWorkItem {
            do {
                let config: NknMessageConfig = NknMessageConfig()
                config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
                config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
                config.txPool = txPool
                config.offset = offset
                config.limit = limit
                
                try self.client?.publishText(topic, data: data, config: config)
                
                var resp: [String: Any] = [String: Any]()
                resp["messageId"] = config.messageID
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error)
            }
        }
        clientSendQueue.async(execute: clientSendWorkItem!)
    }
    
    private func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func subscribe"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            let config: NknTransactionConfig = NknTransactionConfig()
            config.fee = fee
            if (nonce != nil) {
                config.nonce = Int64(nonce!)
                config.fixNonce = true
            }
            
            var error: NSError?
            let hash = self.client?.subscribe(identifier, topic: topic, duration: duration, meta: meta, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            self.resultSuccess(result: result, resp: hash)
            return
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func unsubscribe"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            let config: NknTransactionConfig = NknTransactionConfig()
            config.fee = fee
            if (nonce != nil) {
                config.nonce = Int64(nonce!)
                config.fixNonce = true
            }
            
            var error: NSError?
            let hash = self.client?.unsubscribe(identifier, topic: topic, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            self.resultSuccess(result: result, resp: hash)
            return
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func getSubscribers(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 0
        let meta = args["meta"] as? Bool ?? true
        let txPool = args["txPool"] as? Bool ?? true
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func getSubscribers"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            do {
                let res: NknSubscribers? = try self.client?.getSubscribers(topic, offset: offset, limit: limit, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix?.data)
                let mapPro = MapProtocol()
                res?.subscribers?.range(mapPro)
                if (txPool) {
                    res?.subscribersInTxPool?.range(mapPro)
                }
                self.resultSuccess(result: result, resp: mapPro.result)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func getSubscribersCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func getSubscribersCount"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            do {
                var count: Int = 0
                try self.client?.getSubscribersCount(topic, subscriberHashPrefix: subscriberHashPrefix?.data, ret0_: &count)
                self.resultSuccess(result: result, resp: count)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func getSubscription(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let subscriber = args["subscriber"] as! String
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func getSubscription"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            do {
                let res: NknSubscription? = try self.client?.getSubscription(topic, subscriber: subscriber)
                
                var resp: [String: Any] = [String: Any]()
                resp["meta"] = res?.meta
                resp["expiresAt"] = res?.expiresAt
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func getHeight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func getHeight"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            do {
                var height: Int32 = 0
                try self.client?.getHeight(&height)
                self.resultSuccess(result: result, resp: height)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
    
    private func getNonce(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let address = args["address"] as! String
        let txPool = args["txPool"] as? Bool ?? true
        
        if ((self.client == nil) || (self.client?.isClosed() == true)) {
            result(FlutterError(code: "", message: "client is closed", details: "in func getNonce"))
            return
        }
        
        clientEventWorkItem = DispatchWorkItem {
            do {
                var nonce: Int64 = 0
                try self.client?.getNonceByAddress(address, txPool: txPool, ret0_: &nonce)
                self.resultSuccess(result: result, resp: nonce)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.async(execute: clientEventWorkItem!)
    }
}
