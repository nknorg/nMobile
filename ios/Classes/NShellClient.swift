import Nkn

var nshellClient: NknMultiClient?
let nshellClientOnconnectQueue = DispatchQueue(label: "org.nkn.sdk/nshellClient/event/onconnect", qos: .userInteractive)
let nshellClientOnmessageQueue = DispatchQueue(label: "org.nkn.sdk/nshellClient/event/onmessage", qos: .userInitiated)
let nshellClientSendQueue = DispatchQueue(label: "org.nkn.sdk/nshellClient/event/send", qos: .userInitiated)
var nshellClientEventSink: FlutterEventSink?

private var onmessageWorkItem: DispatchWorkItem?
private var onconnectWorkItem: DispatchWorkItem?

//let onmessageOperationQueue = OperationQueue()
private var onmessageOperationItem: BlockOperation?

var nshellReceiveMessageQueue = OperationQueue();


func onNShellConnect() {
    nshellReceiveMessageQueue.cancelAllOperations();
    let node = nshellClient?.onConnect?.next()
    var data:[String:Any] = [String:Any]()
    data["event"] = "onConnect"
    data["node"] = ["address": node?.addr, "publicKey": node?.pubKey]
    data["client"] = ["address": nshellClient?.address()]
    nshellClientEventSink?(data)
    onNShellMessage();
}

func onNShellMessage() {
     nshellReceiveMessageQueue.cancelAllOperations();
    
    let blockOperation = BlockOperation()
           blockOperation.addExecutionBlock{
               let message = nshellClient?.onMessage?.next()
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
                   nshellClientEventSink?(data)

                   onNShellMessage()
           }
    nshellReceiveMessageQueue.addOperation(blockOperation)
}

func isNShellConnected(_ call: FlutterMethodCall, result: FlutterResult) {
    if(nshellClient != nil) {
        result(true)
    } else {
        result(false)
    }
}

func disNShellConnect(call: FlutterMethodCall, result: FlutterResult){
    
    nshellReceiveMessageQueue.cancelAllOperations();
    
    if(nshellClient == nil){
         result(1)
    }else{
        do {
            try nshellClient?.close()
            nshellClient = nil;
            result(1)
        } catch {
           result(0)
             nshellClient = nil;
        }
    }
}

func createNShellClient(_ call: FlutterMethodCall, result: FlutterResult) {
    
    if(nshellClient != nil) {
        do {
             nshellReceiveMessageQueue.cancelAllOperations();
            try nshellClient?.close()
            nshellClient = nil;
        } catch {
             nshellClient = nil;
            
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
            nshellClientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return
        }

        let clientConfig = NknClientConfig()
//        clientConfig.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
        nshellClient = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        if (error != nil) {
            nshellClientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return
        }
        onNShellConnect()
    }
    nshellClientOnconnectQueue.async(execute: onconnectWorkItem!)
}

func sendNShellText(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let dests = args["dests"] as? [String]
    let data = args["data"] as? String
    result(nil)
    
    guard let eventSink = nshellClientEventSink else {
        return
    }
    
    let nknDests = NknStringArray.init(from: nil)
    
    if(dests != nil) {
        for dest in dests! {
            nknDests?.append(dest)
        }
    }
    
    let config: NknMessageConfig = NknMessageConfig.init()
    config.maxHoldingSeconds = Int32.max
    config.messageID = NknRandomBytes(Int(NknMessageIDSize), nil)
    config.noReply = true
    nshellClientSendQueue.async {
        do {
            try nshellClient?.sendText(nknDests, data: data, config: config)
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

