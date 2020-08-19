import Flutter
import UIKit
import Nkn

public class NknClientPlugin : NSObject, FlutterStreamHandler {
    init(controller : FlutterViewController) {
        super.init()
        FlutterMethodChannel(name: "org.nkn.sdk/client", binaryMessenger: controller.binaryMessenger).setMethodCallHandler(handle)
        FlutterEventChannel(name: "org.nkn.sdk/client/event", binaryMessenger: controller.binaryMessenger).setStreamHandler(self)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        clientEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }

    public func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
        switch call.method {
            case "createClient":
                createClient(call, result)
            case "connect":
                connect()
                result(nil)
            case "startReceiveMessages":
                receiveMessages()
                result(nil)
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
            default:
                result(FlutterMethodNotImplemented)
        }
    }
    
    private let clientConnectQueue = DispatchQueue(label: "org.nkn.sdk/client/connect", qos: .userInteractive)
//    private let clientMessageQueue = DispatchQueue(label: "org.nkn.sdk/client/message", qos: .background)
    private let clientSendQueue = DispatchQueue(label: "org.nkn.sdk/client/send", qos: .userInteractive)
    private let subscriberQueue = DispatchQueue(label: "org.nkn.sdk/client/subscriber", qos: .userInteractive)

//    private var onMessageWorkItem: DispatchWorkItem?
//    private var onConnectWorkItem: DispatchWorkItem?
    private var receiveMessageQueue = OperationQueue();

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

        clientSendQueue.async {
            var error: NSError?
            let account = NknNewAccount(seedBytes.data, &error)
            if (error != nil) {
                self.clientEventSink!(FlutterError(code: _id, message: error!.localizedDescription, details: nil))
                return
            }
            self.accountPubkeyHex = self.ensureSameAccount(account!)
            let client = self.genClientIfNotExists(account!, identifier, clientUrl)
            var resp: [String: Any] = [String: Any]()
            resp["_id"] = _id
            resp["event"] = "createClient"
            resp["success"] = client == nil ? 0 : 1
            self.clientEventSink!(resp)
        }
    }

    func connect() {
        if (isConnected) {
            return
        }
        let client = multiClient!
        let node = client.onConnect?.next()
        if (node == nil) {
            return
        }
        receiveMessageQueue.cancelAllOperations()
        isConnected = true
        var data: [String: Any] = [String: Any]()
        data["event"] = "onConnect"
        data["node"] = ["address": node!.addr, "publicKey": node!.pubKey]
        data["client"] = ["address": client.address()]
        clientEventSink!(data)
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

    func receiveMessages() {
        receiveMessageQueue.cancelAllOperations()
        receiveMessageQueue.addOperation(buildBlockOperation())
    }

    func buildBlockOperation() -> BlockOperation {
        let blockOperation = BlockOperation()
        blockOperation.addExecutionBlock{
            guard let client = self.multiClient else {
                return
            }
            guard let msg = client.onMessage?.next() else {
                return
            }
            var data: [String: Any] = [String: Any]()
            data["event"] = "onMessage"
            data["data"] = [
                "src": msg.src,
                "data": String(data: msg.data!, encoding: String.Encoding.utf8)!,
                "type": msg.type,
                "encrypted": msg.encrypted,
                "pid": FlutterStandardTypedData(bytes: msg.messageID!)
            ]
            var client1: [String: Any] = [String: Any]()
            client1["address"] = client.address()
            data["client"] = client1
            self.clientEventSink!(data)
            self.receiveMessages()
        }
        return blockOperation
    }

    func sendText(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let _id = args["_id"] as! String
        let dests = args["dests"] as! [String]
        let data = args["data"] as! String
        let maxHoldingSeconds = args["maxHoldingSeconds"] as! Int32
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

        clientSendQueue.async {
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
        clientSendQueue.async {
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
        let client = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
        if (error != nil) {
            closeClientIfExists()
            clientEventSink!(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
            return nil
        } else {
            multiClient = client
            return client
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

    //func createClient(_ call: FlutterMethodCall, _ result: FlutterResult) {
    //    if(client != nil) {
    //        do {
    //             receiveMessageQueue.cancelAllOperations();
    //            try client?.close()
    //            client = nil;
    //        } catch {
    //             client = nil;
    //
    //        }
    //    }
    //    let args = call.arguments as! [String: Any]
    //    let identifier = args["identifier"] as? String
    //    let keystore = args["keystore"] as? String
    //    let password = args["password"] as? String
    //
    //    let config = NknWalletConfig.init()
    //    config.password = password ?? ""
    //    var error: NSError?
    //    let wallet = NknWalletFromJSON(keystore, config, &error)
    //    if (error != nil) {
    //        result(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
    //        return
    //    }
    //    result(nil)
    //
    //    if(onconnectWorkItem?.isCancelled == false) {
    //        onconnectWorkItem?.cancel()
    //    }
    //    onconnectWorkItem = DispatchWorkItem {
    //        let account = NknNewAccount(wallet?.seed(), &error)
    //        if (error != nil) {
    //            clientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
    //            return
    //        }
    //
    //        let clientConfig = NknClientConfig()
    ////        clientConfig.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
    //        client = NknNewMultiClient(account, identifier, 3, true, clientConfig, &error)
    //        if (error != nil) {
    //            clientEventSink?(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
    //            return
    //        }
    //        onConnect(client)
    //    }
    //    clientOnconnectQueue.async(execute: onconnectWorkItem!)
    //}
}

extension Data {
    var toHex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
