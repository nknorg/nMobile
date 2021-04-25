import Nkn

class Wallet : ChannelBase, IChannelHandler, FlutterStreamHandler {
    let walletQueue = DispatchQueue(label: "org.nkn.sdk/wallet/queue", qos: .default, attributes: .concurrent)
    var methodChannel: FlutterMethodChannel?
    var eventSink: FlutterEventSink?
    let CHANNEL_NAME = "org.nkn.sdk/wallet"
    
    func install(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: binaryMessenger)
        self.methodChannel?.setMethodCallHandler(handle)
    }
    
    func uninstall() {
        self.methodChannel?.setMethodCallHandler(nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "create":
            create(call, result: result)
        case "restore" :
            restore(call, result: result)
        case "pubKeyToWalletAddr":
            pubKeyToWalletAddr(call, result: result)
        case "getBalance" :
            getBalance(call, result: result)
        case "transfer":
            transfer(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func create(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let password = args["password"] as? String ?? ""
        var error: NSError?
        let account:NknAccount? = NknNewAccount(seed?.data, &error)
        let config = NknWalletConfig()
        config.password = password
        let wallet = NknWallet(account, config: config)
        let json = wallet?.toJSON(nil)
        var resp:[String:Any] = [String:Any]()
        resp["address"] = wallet?.address()
        resp["keystore"] = json
        resp["publicKey"] = wallet?.pubKey()
        resp["seed"] = wallet?.seed()
        result(resp)
    }
    
    private func restore(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let keystore = args["keystore"] as? String
        let password = args["password"] as? String ?? ""
        if(keystore == nil) {
            result(nil)
            return
        }
        let config = NknWalletConfig()
        config.password = password
        var error: NSError?
        let wallet = NknWalletFromJSON(keystore, config, &error)
        if (error != nil) {
            resultError(result: result, error: error)
            return
        }
        let json = wallet?.toJSON(nil)
        var resp:[String:Any] = [String:Any]()
        resp["address"] = wallet?.address()
        resp["keystore"] = json
        resp["publicKey"] = wallet?.pubKey()
        resp["seed"] = wallet?.seed()
        result(resp)
    }
    
    private func pubKeyToWalletAddr(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let publicKey = args["publicKey"] as! String
        var error: NSError?
        let address = NknPubKeyToWalletAddr(Data(hex: publicKey), &error)
        if (error != nil) {
            resultError(result: result, error: error)
            return
        }
        result(address)
    }
    
    func getBalance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let address = args["address"] as? String
        let seedRpc = args["seedRpc"] as? String
        
        walletQueue.async {
            var error: NSError?
            let account = NknAccount(NknRandomBytes(32, &error))
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            let config = NknWalletConfig()
            if(seedRpc != nil) {
                config.seedRPCServerAddr = NknStringArray(from: seedRpc)
            }
            let wallet = NknWallet(account, config: config)
            do {
                let balance: NknAmount? = try wallet?.balance(byAddress: address)
                self.resultSuccess(result: result, resp: Double(balance!.string()))
                return
            } catch let error {
                self.resultError(result: result, error: error)
                return
            }
        }
    }
    
    func transfer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let address = args["address"] as? String
        let amount = args["amount"] as? String
        let fee = args["fee"] as! String
        let nonce = args["nonce"] as? Int64
        let attributes = args["attributes"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]
        
        walletQueue.async {
            var error: NSError?
            let account:NknAccount? = NknNewAccount(seed?.data, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            let config = NknWalletConfig()
            if(seedRpc != nil) {
                config.seedRPCServerAddr = NknStringArray(from: nil)
                for (_, v) in seedRpc!.enumerated() {
                    config.seedRPCServerAddr?.append(v)
                }
            }
            let wallet = NknNewWallet(account, config, &error)
            if (error != nil) {
                self.resultError(result: result,error: error)
                return
            }
            
            let transactionConfig: NknTransactionConfig = NknTransactionConfig()
            transactionConfig.fee = fee
            if (nonce != nil) {
                transactionConfig.nonce = nonce!
            }
            if(attributes != nil){
                transactionConfig.attributes = attributes?.data
            }
            
            let hash = wallet?.transfer(address, amount: amount, config: transactionConfig, error: &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            self.resultSuccess(result: result, resp: hash)
            return
        }
    }
}
