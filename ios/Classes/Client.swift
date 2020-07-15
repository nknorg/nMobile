import Nkn

var client: NknMultiClient?
let clientOnconnectQueue = DispatchQueue(label: "org.nkn.sdk/client/event/onconnect", qos: .userInteractive)
let clientOnmessageQueue = DispatchQueue(label: "org.nkn.sdk/client/event/onmessage", qos: .userInitiated)
let clientSendQueue = DispatchQueue(label: "org.nkn.sdk/client/event/send", qos: .userInitiated)
var clientEventSink: FlutterEventSink?

private var onmessageWorkItem: DispatchWorkItem?
private var onconnectWorkItem: DispatchWorkItem?

//let onmessageOperationQueue = OperationQueue()
private var onmessageOperationItem: BlockOperation?

var receiveMessageQueue = OperationQueue();


func onConnect(_ client: NknMultiClient?) {
    receiveMessageQueue.cancelAllOperations();
    let node = client?.onConnect?.next()
    var data:[String:Any] = [String:Any]()
    data["event"] = "onConnect"
    data["node"] = ["address": node?.addr, "publicKey": node?.pubKey]
    data["client"] = ["address": client?.address()]
    clientEventSink?(data)
    onMessage(client);
}

func onMessage(_ client: NknMultiClient?) {
     receiveMessageQueue.cancelAllOperations();
    
    let blockOperation = BlockOperation()
           blockOperation.addExecutionBlock{
               let message = client?.onMessage?.next()
                   guard let msg = message else {
               //        Thread.sleep(forTimeInterval: 2)
               //        onMessage()
                       return
                   }
                   var data:[String:Any] = [String:Any]()
                   data["event"] = "onMessage"
                   data["data"] = [
                       "src": msg.src,
                       "data": String(data: msg.data!, encoding: String.Encoding.utf8) ?? "",
                       "type": msg.type,
                       "encrypted": msg.encrypted,
                       "pid": msg.messageID
                   ]
                   clientEventSink?(data)

                   onMessage(client)
           }
    receiveMessageQueue.addOperation(blockOperation)
}

func isConnected(_ call: FlutterMethodCall, result: FlutterResult) {
    if(client != nil) {
        result(true)
    } else {
        result(false)
    }
}

func disConnect(_ call: FlutterMethodCall, result: FlutterResult){
    
    receiveMessageQueue.cancelAllOperations();
    
    if(client == nil){
         result(1)
    }else{
        do {
            try client?.close()
            client = nil;
            result(1)
        } catch {
           result(0)
             client = nil;
        }
    }
}

func createClient(_ call: FlutterMethodCall, result: FlutterResult) {
    
    if(client != nil) {
        do {
             receiveMessageQueue.cancelAllOperations();
            try client?.close()
            client = nil;
        } catch {
             client = nil;
            
        }
    }
    let args = call.arguments as! [String: Any]
    let identifier = args["identifier"] as? String
    let keystore = args["keystore"] as? String
    let password = args["password"] as? String

    let config = NknWalletConfig.init()
    config.password = password ?? ""
    var error: NSError?
    let wallet = NknWalletFromJSON(keystore, config, &error)
    if (error != nil) {
        result(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
        return
    }
    result(nil)

    if(onconnectWorkItem?.isCancelled == false) {
        onconnectWorkItem?.cancel()
    }
    onconnectWorkItem = DispatchWorkItem {
        let account = NknNewAccount(wallet?.seed(), &error)
        if (error != nil) {
            clientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return
        }

        let clientConfig = NknClientConfig()
//        clientConfig.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
        client = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        if (error != nil) {
            clientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return
        }
        onConnect(client)
    }
    clientOnconnectQueue.async(execute: onconnectWorkItem!)
}

func sendText(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let dests = args["dests"] as? [String]
    let data = args["data"] as? String
    let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int
    result(nil)
    
    guard let eventSink = clientEventSink else {
        return
    }
    
    let nknDests = NknStringArray.init(from: nil)
    
    if(dests != nil) {
        for dest in dests! {
            nknDests?.append(dest)
        }
    }
    
    let config: NknMessageConfig = NknMessageConfig.init()
    config.maxHoldingSeconds = maxHoldingSeconds == 1 ? Int32.init(0) : Int32.max
    config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
    config.noReply = true
    clientSendQueue.async {
        do {
            try client?.sendText(nknDests, data: data, config: config)
            var data:[String:Any] = [String:Any]()
            data["_id"] = _id
            data["event"] = "send"
            data["pid"] = config.messageID
            eventSink(data)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
        
    }
}

func publish(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let topic = args["topic"] as? String
    let data = args["data"] as? String
    result(nil)
    
    guard let eventSink = clientEventSink else {
        return
    }
    
    let config: NknMessageConfig = NknMessageConfig.init()
    config.maxHoldingSeconds = Int32.max
    config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
    config.noReply = true
    clientSendQueue.async {
        do {
            try client?.publishText(topic, data: data, config: config)
            var data:[String:Any] = [String:Any]()
            data["_id"] = _id
            data["event"] = "send"
            data["pid"] = config.messageID
            eventSink(data)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
        
    }
}

func subscribe(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let identifier = args["identifier"] as? String
    let topic = args["topic"] as? String
    let duration = args["duration"] as! Int
    let meta = args["meta"] as? String
    let fee = args["fee"] as! String

    var error: NSError?
    result(nil)
    guard let eventSink = clientEventSink else {
        return
    }
    clientSendQueue.async {
        let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
        transactionConfig.fee = fee
        let hash = client?.subscribe(identifier, topic: topic, duration: duration, meta: meta, config: transactionConfig, error: &error)
        if (error != nil) {
            eventSink(FlutterError(code: _id ?? "_id", message: error?.localizedDescription, details: nil))
            return
        }
        var data:[String:Any] = [String:Any]()
        data["_id"] = _id
        data["result"] = hash
        eventSink(data)
    }
}

func unsubscribe(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let identifier = args["identifier"] as? String
    let topic = args["topic"] as? String
    let fee = args["fee"] as! String

    var error: NSError?
    result(nil)
    guard let eventSink = clientEventSink else {
        return
    }
    clientSendQueue.async {
        let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
        transactionConfig.fee = fee
        let hash = client?.unsubscribe(identifier, topic: topic, config: transactionConfig, error: &error)
        if (error != nil) {
            eventSink(FlutterError(code: _id ?? "_id", message: error?.localizedDescription, details: nil))
            return
        }
        var data:[String:Any] = [String:Any]()
        data["_id"] = _id
        data["result"] = hash
        eventSink(data)
    }
}

func getSubscribersCount(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let topic = args["topic"] as? String

    result(nil)
    guard let eventSink = clientEventSink else {
        return
    }
    clientSendQueue.async {
        var count: Int = 0
        do {
            try client?.getSubscribersCount(topic, ret0_: &count)

            var data:[String:Any] = [String:Any]()
            data["_id"] = _id
            data["result"] = count
            eventSink(data)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
    }
}

func getSubscription(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let topic = args["topic"] as? String
    let subscriber = args["subscriber"] as? String

    result(nil)
    guard let eventSink = clientEventSink else {
        return
    }
    clientSendQueue.async {
        do{
            let res: NknSubscription? = try client?.getSubscription(topic, subscriber: subscriber)

            var data:[String:Any] = [String:Any]()
            data["_id"] = _id
            data["meta"] = res?.meta
            data["expiresAt"] = res?.expiresAt
            eventSink(data)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
    }
}

func getSubscribers(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let topic = args["topic"] as? String
    let offset = args["offset"] as! Int
    let limit = args["limit"] as! Int
    let meta = args["meta"] as! Bool
    let txPool = args["txPool"] as! Bool

    result(nil)
    guard let eventSink = clientEventSink else {
        return
    }
    clientSendQueue.async {
        do{
            let res: NknSubscribers? = try client?.getSubscribers(topic, offset: offset, limit: limit, meta: meta, txPool: txPool)
            let mapPro = MapProtocol.init()
            res?.subscribers?.range(mapPro)
            mapPro.result["_id"] = _id
            eventSink(mapPro.result)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
    }
}

