import Nkn

class Client : ChannelBase, IChannelHandler, FlutterStreamHandler {
    
    let CHANNEL_NAME = "org.nkn.sdk/client"
    let EVENT_NAME = "org.nkn.sdk/client/event"
    
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    
    let clientQueue = DispatchQueue(label: "org.nkn.sdk/client/queue", qos: .default)
    let clientMapQueue = DispatchQueue(label: "org.nkn.sdk/client/map/queue", qos: .default)
    let clientListenQueue = DispatchQueue(label: "org.nkn.sdk/client/listen/queue", qos: .default, attributes: .concurrent)
    let clientEventQueue = DispatchQueue(label: "org.nkn.sdk/client/event/queue", qos: .default, attributes: .concurrent)
    
    var clientMap = Dictionary<String, NknMultiClient>()
    
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
    
    private func getClient(id: String) -> NknMultiClient? {
        var client :NknMultiClient?
        clientMapQueue.sync {
            client = self.clientMap.keys.contains(id) ? self.clientMap[id] : nil
        }
        return client
    }
    
    private func setClient(id: String, client: NknMultiClient) {
        clientMapQueue.sync {
            self.clientMap.updateValue(client, forKey: id)
        }
    }
    
    private func removeClient(id: String) {
        clientMapQueue.sync {
            self.clientMap.removeValue(forKey: id)
        }
    }
    
    private func getClientConfig(seedRpc: [String]?, connectRetries: Int32, maxReconnectInterval: Int32, ethResolverConfigArray: [[String: Any]]?, dnsResolverConfigArray: [[String: Any]]?) -> NknClientConfig {
        let config: NknClientConfig = NknClientConfig()
        
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        
        config.connectRetries = connectRetries
        config.maxReconnectInterval = maxReconnectInterval
        
        if (ethResolverConfigArray != nil) {
            for (_, cfg) in ethResolverConfigArray!.enumerated() {
                let ethResolverConfig: EthresolverConfig = EthresolverConfig()
                ethResolverConfig.prefix = cfg["prefix"] as? String ?? ""
                ethResolverConfig.rpcServer = cfg["rpcServer"] as! String
                ethResolverConfig.contractAddress = cfg["contractAddress"] as! String
                if (config.resolvers == nil) {
                    config.resolvers = NkngomobileNewResolverArrayFromResolver(EthResolver(config: ethResolverConfig))
                } else {
                    config.resolvers?.append(EthResolver(config: ethResolverConfig))
                }
            }
        }
        
        if (dnsResolverConfigArray != nil) {
            for (_, cfg) in dnsResolverConfigArray!.enumerated() {
                let dnsResolverConfig: DnsresolverConfig = DnsresolverConfig()
                dnsResolverConfig.dnsServer = cfg["dnsServer"] as! String
                if (config.resolvers == nil) {
                    config.resolvers = NkngomobileNewResolverArrayFromResolver(DnsResolver(config: dnsResolverConfig))
                } else {
                    config.resolvers?.append(DnsResolver(config: dnsResolverConfig))
                }
            }
        }
        return config
    }
    
    private func createClient(account: NknAccount, identifier: String = "", numSubClients: Int = 3, config: NknClientConfig) throws -> NknMultiClient? {
        let pubKey: String = account.pubKey()!.hexEncode
        let id = identifier.isEmpty ? pubKey : "\(identifier).\(pubKey)"
        
        try closeClient(id: id)
        
        guard let client = NknMultiClient(account, baseIdentifier: identifier, numSubClients: numSubClients, originalClient: true, config: config) else {
            return nil
        }
        self.setClient(id: client.address(), client: client)
        return client
    }
    
    private func closeClient(id: String) throws {
        guard let client = self.getClient(id: id) else {
            return
        }
        if(!client.isClosed()) {
            try client.close()
        }
        self.removeClient(id: id)
    }
    
    private func recreateClient(id: String, account: NknAccount, identifier: String = "", numSubClients: Int = 3, config: NknClientConfig) throws -> NknMultiClient? {
        guard let newClient = try NknMultiClient(account, baseIdentifier: identifier, numSubClients: numSubClients, originalClient: true, config: config) else {
            return nil
        }
        let oldClient = self.getClient(id: id)
        if((oldClient != nil) && !(oldClient?.isClosed() == true)) {
            try oldClient?.close()
        }
        self.setClient(id: newClient.address(), client: newClient)
        return newClient
    }
    
    private func onConnect(_id: String, numSubClients: Int) {
        do {
            guard let client = self.getClient(id: _id) else {
                return
            }
            guard (!client.isClosed()) else{
                return
            }
            guard let node = try client.onConnect?.next() else {
                return
            }
            
            var rpcServers = [String]()
            for i in 0...numSubClients {
                let c = client.getClient(i)
                let rpcNode = c?.getNode()
                var rpcAddr = rpcNode?.rpcAddr ?? ""
                if (rpcAddr.count > 0) {
                    rpcAddr = "http://" + rpcAddr
                    if(!rpcServers.contains(rpcAddr)) {
                        rpcServers.append(rpcAddr)
                    }
                }
            }
            
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = client.address()
            resp["event"] = "onConnect"
            resp["node"] = ["address": node.addr, "publicKey": node.pubKey]
            resp["client"] = ["address": client.address()]
            resp["rpcServers"] = rpcServers
            //NSLog("%@", resp)
            self.eventSinkSuccess(eventSink: self.eventSink, resp: resp)
            return
        } catch let error {
            self.eventSinkError(eventSink: self.eventSink, error: error, code: _id)
            return
        }
    }
    
    private func onMessage(_id: String) {
        while(true) {
            do {
                guard let client = self.getClient(id: _id) else {
                    break
                }
                if (client.isClosed()) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onMessage(_id: _id)
                    }
                    break
                }
                guard let msg = try client.onMessage?.next(withTimeout: 5 * 1000) else {
                    continue
                }
                
                var resp: [String: Any] = [String: Any]()
                resp["_id"] = client.address()
                resp["event"] = "onMessage"
                resp["data"] = [
                    "src": msg.src,
                    "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
                    "type": msg.type,
                    "encrypted": msg.encrypted,
                    "messageId": msg.messageID != nil ? FlutterStandardTypedData(bytes: msg.messageID!) : nil,
                    "noReply": msg.noReply
                ]
                //NSLog("%@", resp)
                self.eventSinkSuccess(eventSink: self.eventSink, resp: resp)
                //return
            } catch let error {
                self.eventSinkError(eventSink: self.eventSink, error: error, code: _id)
                //return
            }
        }
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "create":
            create(call, result: result)
        case "recreate":
            recreate(call, result: result)
        case "reconnect":
            reconnect(call, result: result)
        case "close":
            close(call, result: result)
        case "replyText":
            replyText(call, result: result)
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
        let numSubClients = args["numSubClients"] as? Int ?? 3
        let connectRetries = args["connectRetries"] as? Int32 ?? -1
        let maxReconnectInterval = args["maxReconnectInterval"] as? Int32 ?? 5000
        let ethResolverConfigArray = args["ethResolverConfigArray"] as? [[String: Any]]
        let dnsResolverConfigArray = args["dnsResolverConfigArray"] as? [[String: Any]]
        
        let config: NknClientConfig = getClientConfig(seedRpc: seedRpc, connectRetries: connectRetries, maxReconnectInterval: maxReconnectInterval, ethResolverConfigArray: ethResolverConfigArray, dnsResolverConfigArray: dnsResolverConfigArray)
        
        var cAddress: String = ""
        
        let queueItem = DispatchWorkItem {
            do {
                var error: NSError?
                guard let account = NknNewAccount(seed?.data, &error) else {
                    self.resultError(result: result, code: "", message: "new account fail", details: "create")
                    return
                }
                if (error != nil) {
                    self.resultError(result: result, error: error)
                    return
                }
                
                var client: NknMultiClient?
                do {
                    client = try self.createClient(account: account, identifier: identifier, numSubClients: numSubClients, config: config)
                } catch _ {
                }
                if (client == nil) {
                    NkngolibAddClientConfigWithDialContext(config)
                    client = try self.createClient(account: account, identifier: identifier, numSubClients: numSubClients, config: config)
                }
                if (client == nil) {
                    self.resultError(result: result, code: "", message: "client create fail", details: "create")
                    return
                }
                
                guard let clientAddress = client?.address() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "create_address")
                    return
                }
                guard let clientPubKey = client?.pubKey() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "create_pubkey")
                    return
                }
                guard let clientSeed = client?.seed() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "create_seed")
                    return
                }
                cAddress = clientAddress
                
                var resp:[String:Any] = [String:Any]()
                resp["address"] = clientAddress
                resp["publicKey"] = clientPubKey
                resp["seed"] = clientSeed
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientQueue.sync(execute: queueItem)
        
        // listen
        if(!cAddress.isEmpty) {
            clientListenQueue.async {
                self.onConnect(_id: cAddress, numSubClients: numSubClients)
            }
            clientListenQueue.async {
                self.onMessage(_id: cAddress)
            }
        }
    }
    
    private func recreate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let seed = args["seed"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]
        let numSubClients = args["numSubClients"] as? Int ?? 3
        let connectRetries = args["connectRetries"] as? Int32 ?? -1
        let maxReconnectInterval = args["maxReconnectInterval"] as? Int32 ?? 5000
        let ethResolverConfigArray = args["ethResolverConfigArray"] as? [[String: Any]]
        let dnsResolverConfigArray = args["dnsResolverConfigArray"] as? [[String: Any]]
        
        let config: NknClientConfig = getClientConfig(seedRpc: seedRpc, connectRetries: connectRetries, maxReconnectInterval: maxReconnectInterval, ethResolverConfigArray: ethResolverConfigArray, dnsResolverConfigArray: dnsResolverConfigArray)
        
        var cAddress: String = ""
        
        let queueItem = DispatchWorkItem {
            do {
                var error: NSError?
                guard let account = NknNewAccount(seed?.data, &error) else {
                    self.resultError(result: result, code: "", message: "new account fail", details: "recreate")
                    return
                }
                if (error != nil) {
                    self.resultError(result: result, error: error)
                    return
                }
                
                var client: NknMultiClient?
                do {
                    client = try self.recreateClient(id: _id, account: account, identifier: identifier, numSubClients: numSubClients, config: config)
                } catch _ {
                }
                if (client == nil) {
                    NkngolibAddClientConfigWithDialContext(config)
                    client = try self.recreateClient(id: _id, account: account, identifier: identifier, numSubClients: numSubClients, config: config)
                }
                if (client == nil) {
                    self.resultError(result: result, code: "", message: "client create fail", details: "recreate")
                    return
                }
                
                guard let clientAddress = client?.address() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "recreate_address")
                    return
                }
                guard let clientPubKey = client?.pubKey() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "recreate_pubkey")
                    return
                }
                guard let clientSeed = client?.seed() ?? nil else {
                    self.resultError(result: result, code: "", message: "client create fail", details: "recreate_seed")
                    return
                }
                cAddress = clientAddress
                
                var resp:[String:Any] = [String:Any]()
                resp["address"] = clientAddress
                resp["publicKey"] = clientPubKey
                resp["seed"] = clientSeed
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientQueue.sync(execute: queueItem)
        
        // listen
        if(!cAddress.isEmpty) {
            clientListenQueue.async {
                self.onConnect(_id: cAddress, numSubClients: numSubClients)
            }
        }
    }
    
    private func reconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "reconnect")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "reconnect")
            return
        }
        
        let queueItem = DispatchWorkItem {
            client.reconnect()
            
            self.resultSuccess(result: result, resp: nil)
            return
        }
        clientQueue.sync(execute: queueItem)
    }
    
    private func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "close")
            return
        }
        guard (!client.isClosed()) else{
            self.resultSuccess(result: result, resp: nil)
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                try self.closeClient(id: _id)
                
                self.resultSuccess(result: result, resp: nil)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientQueue.sync(execute: queueItem)
    }
    
    private func replyText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let messageId = args["messageId"] as? FlutterStandardTypedData
        let dest = args["dest"] as! String
        let data = args["data"] as! String
        let encrypted = args["encrypted"] as? Bool ?? true
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "replyText")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "replyText")
            return
        }
        
        let msg = NknMessage()
        msg.messageID = messageId?.data
        msg.src = dest
        
        let queueItem = DispatchWorkItem {
            var error:NSError?
            NkngolibReply(client, msg, data, encrypted, maxHoldingSeconds, &error)
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func sendText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        let noReply = args["noReply"] as? Bool ?? true
        let timeout = args["timeout"] as? Int32 ?? 10000
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "sendText")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "sendText")
            return
        }
        
        let nknDests: NkngomobileStringArray? = NkngomobileNewStringArrayFromString(nil)
        if(!dests.isEmpty) {
            for dest in dests {
                nknDests?.append(dest)
            }
        }
        if(dests.isEmpty) {
            self.resultError(result: result, code: "", message: "dests is empty", details: "sendText")
            return
        }
        
        let config: NknMessageConfig = NknMessageConfig()
        config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
        config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
        config.noReply = noReply
        
        let queueItem = DispatchWorkItem {
            do {
                if (!noReply) {
                    guard let onMessage: NknOnMessage? = try client.sendText(nknDests, data: data, config: config) else {
                        self.resultError(result: result, code: "", message: "onMessage is null", details: "sendText")
                        return
                    }
                    guard let msg = onMessage?.next(withTimeout: timeout) else {
                        self.resultError(result: result, code: "", message: "wait reply timeout", details: "sendText")
                        return
                    }
                    
                    var resp: [String: Any] = [String: Any]()
                    resp["src"] = msg.src
                    resp["data"] = String(data: msg.data!, encoding: String.Encoding.utf8)!
                    resp["type"] = msg.type
                    resp["encrypted"] = msg.encrypted
                    resp["messageId"] = msg.messageID != nil ? FlutterStandardTypedData(bytes: msg.messageID!) : nil
                    resp["noReply"] = msg.noReply
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
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func publishText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as? Int32 ?? 0
        let txPool = args["txPool"] as? Bool ?? false
        let offset = args["offset"] as? Int32 ?? 0
        let limit = args["limit"] as? Int32 ?? 1000
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "publishText")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "publishText")
            return
        }
        
        let config: NknMessageConfig = NknMessageConfig()
        config.maxHoldingSeconds = maxHoldingSeconds < 0 ? 0 : maxHoldingSeconds
        config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
        config.txPool = txPool
        config.offset = offset
        config.limit = limit
        
        let queueItem = DispatchWorkItem {
            do {
                try client.publishText(topic, data: data, config: config)
                
                var resp: [String: Any] = [String: Any]()
                resp["messageId"] = config.messageID
                self.resultSuccess(result: result, resp: resp)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "subscribe")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "subscribe")
            return
        }
        
        let config: NknTransactionConfig = NknTransactionConfig()
        config.fee = fee
        if (nonce != nil) {
            config.nonce = Int64(nonce!)
            config.fixNonce = true
        }
        
        let queueItem = DispatchWorkItem {
            var error: NSError?
            let hash = client.subscribe(identifier, topic: topic, duration: duration, meta: meta, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            
            self.resultSuccess(result: result, resp: hash)
            return
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "unsubscribe")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "unsubscribe")
            return
        }
        
        let config: NknTransactionConfig = NknTransactionConfig()
        config.fee = fee
        if (nonce != nil) {
            config.nonce = Int64(nonce!)
            config.fixNonce = true
        }
        
        let queueItem = DispatchWorkItem {
            var error: NSError?
            let hash = client.unsubscribe(identifier, topic: topic, config: config, error: &error)
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            
            self.resultSuccess(result: result, resp: hash)
            return
        }
        clientEventQueue.sync(execute: queueItem)
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
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "getSubscribers")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "getSubscribers")
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                let res: NknSubscribers? = try client.getSubscribers(topic, offset: offset, limit: limit, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix?.data)
                
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
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func getSubscribersCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "getSubscribersCount")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "getSubscribersCount")
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                var count: Int = 0
                try client.getSubscribersCount(topic, subscriberHashPrefix: subscriberHashPrefix?.data, ret0_: &count)
                
                self.resultSuccess(result: result, resp: count)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func getSubscription(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let subscriber = args["subscriber"] as! String
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "getSubscription")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "getSubscription")
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                let res: NknSubscription? = try client.getSubscription(topic, subscriber: subscriber)
                
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
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func getHeight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "getHeight")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "getHeight")
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                var height: Int32 = 0
                try client.getHeight(&height)
                
                self.resultSuccess(result: result, resp: height)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
    
    private func getNonce(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let address = args["address"] as! String
        let txPool = args["txPool"] as? Bool ?? true
        
        guard let client = self.getClient(id: _id) else {
            self.resultError(result: result, code: "", message: "client is null", details: "getNonce")
            return
        }
        guard (!client.isClosed()) else{
            self.resultError(result: result, code: "", message: "client is closed", details: "getNonce")
            return
        }
        
        let queueItem = DispatchWorkItem {
            do {
                var nonce: Int64 = 0
                try client.getNonceByAddress(address, txPool: txPool, ret0_: &nonce)
                
                self.resultSuccess(result: result, resp: nonce)
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
        clientEventQueue.sync(execute: queueItem)
    }
}
