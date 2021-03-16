import Nkn

let walletQueue = DispatchQueue(label: "org.nkn.sdk/wallet/event", qos: .background, attributes: .concurrent)

var walletEventSink: FlutterEventSink?

func createWallet(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let seed = args["seed"] as? String
    let password = args["password"] as? String
    var account:NknAccount?
    if(seed != nil) {
        account = NknAccount.init(Data(hex: seed!))
    } else {
        account = NknAccount.init(nil)
    }
    
    let config = NknWalletConfig.init()
    config.password = password ?? ""
    let wallet = NknWallet.init(account, config: config)
    let json = wallet?.toJSON(nil)
    result(json)
}

func restoreWallet(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
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
    let json = wallet?.toJSON(nil)
    result(json)
}

func getBalance(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let address = args["address"] as? String
    let account = NknAccount.init(nil)
    let config = NknWalletConfig.init()
    
    let measuredRpc = UserDefaults.standard.object(forKey:"nkn_measured_rpcNode")
    if (measuredRpc != nil){
        config.seedRPCServerAddr = NknStringArray.init(from: measuredRpc as? String)
    }
    else{
        config.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
    }
    let wallet = NknWallet.init(account, config: config)
    do {
        let balance: NknAmount? = try wallet?.balance(byAddress: address)
        result(balance?.string())
    } catch let error {
        result(FlutterError.init(code: String(1), message: error.localizedDescription, details: nil))
    }
}

func getBalanceAsync(_ call: FlutterMethodCall, result: FlutterResult) {
    result(nil)
    guard let eventSink = walletEventSink else {
        return
    }
    
    let args = call.arguments as! [String: Any]
    let _id = args["_id"] as? String
    let address = args["address"] as? String

    walletQueue.async {
        do {
            let account = NknAccount.init(nil)
            let wallet = NknWallet.init(account, config: nil)
            
            let balance: NknAmount? = try wallet?.balance(byAddress: address)
            var data:[String:Any] = [String:Any]()
            data["_id"] = _id
            data["result"] = Double(balance!.string())
            eventSink(data)
        } catch let error {
            eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
        }
    }
}

func transferAsync(_ call: FlutterMethodCall, result: FlutterResult) {
        result(nil)
        guard let eventSink = walletEventSink else {
            return
        }

        let args = call.arguments as! [String: Any]
            let keystore = args["keystore"] as? String
            let password = args["password"] as? String
            let _id = args["_id"] as? String
            let address = args["address"] as? String
            let amount = args["amount"] as? String
            let fee = args["fee"] as! String
            let config = NknWalletConfig.init()
        walletQueue.async {
            do {
                config.password = password ?? ""
                let measuredRpc = UserDefaults.standard.object(forKey:"nkn_measured_rpcNode")
                if (measuredRpc != nil){
                    config.seedRPCServerAddr = NknStringArray.init(from: measuredRpc as? String)
                }
                else{
                    config.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
                }
                var error: NSError?
                let wallet = NknWalletFromJSON(keystore, config, &error)
                if (error != nil) {
                       eventSink(FlutterError(code: _id ?? "_id", message: "", details: nil))
                                  return
                 }

                let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
                transactionConfig.fee = fee
                let hash = wallet?.transfer(address, amount: amount, config: transactionConfig, error: &error)
                if (error != nil) {
                      eventSink(FlutterError(code: _id ?? "_id", message: "", details: nil))
                                 return
                }
                var data:[String:Any] = [String:Any]()
                            data["_id"] = _id
                            data["result"] = hash
                eventSink(data)
            } catch let error {
                eventSink(FlutterError(code: _id ?? "_id", message: error.localizedDescription, details: nil))
            }
        }
}

func transfer(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let keystore = args["keystore"] as? String
    let password = args["password"] as? String
    let address = args["address"] as? String
    let amount = args["amount"] as? String
    let fee = args["fee"] as! String
    let config = NknWalletConfig.init()
    config.password = password ?? ""
    let measuredRpc = UserDefaults.standard.object(forKey:"nkn_measured_rpcNode")
    if (measuredRpc != nil){
        config.seedRPCServerAddr = NknStringArray.init(from: measuredRpc as? String)
    }
    else{
        config.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
    }
    var error: NSError?
    let wallet = NknWalletFromJSON(keystore, config, &error)
    if (error != nil) {
        result(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
        return
    }

    let transactionConfig: NknTransactionConfig = NknTransactionConfig.init()
    transactionConfig.fee = fee
    let hash = wallet?.transfer(address, amount: amount, config: transactionConfig, error: &error)
    if(error != nil){
        result(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
        return
    }

    result(hash)
}

func openWallet(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
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
    let json = wallet?.toJSON(nil)
    var data:[String:Any] = [String:Any]()
    data["address"] = wallet?.address()
    data["keystore"] = json
    data["publicKey"] = wallet?.pubKey()?.hexEncode
    
    data["seed"] = wallet?.seed()?.hexEncode
    result(data)
}

func pubKeyToWalletAddr(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as! [String: Any]
    let publicKey = args["publicKey"] as! String
    var error: NSError?
    let address = NknPubKeyToWalletAddr(Data(hex: publicKey), &error)
    if (error != nil) {
        result(FlutterError.init(code: String(error?.code ?? 0), message: error?.localizedDescription, details: nil))
        return
    }
    result(address)
}
