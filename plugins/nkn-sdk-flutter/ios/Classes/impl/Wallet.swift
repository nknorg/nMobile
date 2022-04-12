import Nkn

class Wallet : ChannelBase, IChannelHandler, FlutterStreamHandler {

    let CHANNEL_NAME = "org.nkn.sdk/wallet"
    var methodChannel: FlutterMethodChannel?
    var eventSink: FlutterEventSink?

    let walletQueue = DispatchQueue(label: "org.nkn.sdk/wallet/queue", qos: .default, attributes: .concurrent)
    private var walletWorkItem: DispatchWorkItem?

    let walletMoneyQueue = DispatchQueue(label: "org.nkn.sdk/wallet/money/queue", qos: .default, attributes: .concurrent)
    private var walletMoneyWorkItem: DispatchWorkItem?

    let walletEventQueue = DispatchQueue(label: "org.nkn.sdk/wallet/event/queue", qos: .default, attributes: .concurrent)
    private var walletEventWorkItem: DispatchWorkItem?

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
        // eventSink = nil
        return nil
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "measureSeedRPCServer":
            measureSeedRPCServer(call, result: result)
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

    private func measureSeedRPCServer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seedRpc = args["seedRpc"] as? [String]
        let timeout = args["timeout"] as? Int32 ?? 3000

        walletWorkItem = DispatchWorkItem {
            var seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                seedRPCServerAddr?.append(v)
            }
            seedRPCServerAddr = NknMeasureSeedRPCServer(seedRPCServerAddr as! NkngomobileStringArray, timeout, nil)

            var seedRPCServerAddrs = [String]()
            let elements = seedRPCServerAddr?.join(",").split(separator: ",")
            if elements != nil && !(elements!.isEmpty) {
                for element in elements! {
                    if !(element.isEmpty) {
                        seedRPCServerAddrs.append("\(element)")
                    }
                }
            }

            var resp:[String:Any] = [String:Any]()
            resp["seedRPCServerAddrList"] = seedRPCServerAddrs
            self.resultSuccess(result: result, resp: resp)
        }
        walletQueue.async(execute: walletWorkItem!)
    }

    private func create(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let password = args["password"] as? String ?? ""
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        config.password = password
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileStringArray(from: nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletWorkItem = DispatchWorkItem {
            var error: NSError?
            let account:NknAccount? = NknNewAccount(seed?.data, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            let wallet = NknWallet(account, config: config)

            var resp:[String:Any] = [String:Any]()
            resp["address"] = wallet?.address()
            resp["keystore"] = wallet?.toJSON(nil)
            resp["publicKey"] = wallet?.pubKey()
            resp["seed"] = wallet?.seed()
            self.resultSuccess(result: result, resp: resp)
        }
        walletQueue.async(execute: walletWorkItem!)
    }

    private func restore(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let keystore = args["keystore"] as? String
        let password = args["password"] as? String ?? ""
        let seedRpc = args["seedRpc"] as? [String]

        if(keystore == nil) {
            result(nil)
            return
        }

        let config = NknWalletConfig()
        config.password = password
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletWorkItem = DispatchWorkItem {
            var error: NSError?
            let wallet = NknWalletFromJSON(keystore, config, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            var resp:[String:Any] = [String:Any]()
            resp["address"] = wallet?.address()
            resp["keystore"] = wallet?.toJSON(nil)
            resp["publicKey"] = wallet?.pubKey()
            resp["seed"] = wallet?.seed()
            self.resultSuccess(result: result, resp: resp)
        }
        walletQueue.async(execute: walletWorkItem!)
    }

    private func pubKeyToWalletAddr(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let publicKey = args["publicKey"] as! String

        walletWorkItem = DispatchWorkItem {
            var error: NSError?
            let address = NknPubKeyToWalletAddr(Data(hex: publicKey), &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            self.resultSuccess(result: result, resp: address)
        }
        walletQueue.async(execute: walletWorkItem!)
    }

    func getBalance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let address = args["address"] as? String
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // else {
        //     config.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
        // }
        // config.rpcConcurrency = 4

        walletMoneyWorkItem = DispatchWorkItem {
            var error: NSError?
            let account = NknAccount(NknRandomBytes(32, &error))
            if(error != nil) {
                self.resultError(result: result, error: error)
                return
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
        walletMoneyQueue.async(execute: walletMoneyWorkItem!)
    }

    func transfer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let address = args["address"] as? String
        let amount = args["amount"] as? String
        let fee = args["fee"] as! String
        let nonce = args["nonce"] as? Int
        let attributes = args["attributes"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // else {
        //     config.seedRPCServerAddr = NknStringArray.init(from: "https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
        // }
        // config.rpcConcurrency = 4

        walletMoneyWorkItem = DispatchWorkItem {
            var error: NSError?
            let account:NknAccount? = NknNewAccount(seed?.data, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            let wallet = NknNewWallet(account, config, &error)
            if (error != nil) {
                self.resultError(result: result,error: error)
                return
            }

            let transactionConfig: NknTransactionConfig = NknTransactionConfig()
            transactionConfig.fee = fee
            if (nonce != nil) {
                transactionConfig.nonce = Int64(nonce!)
                transactionConfig.fixNonce = true
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
        walletMoneyQueue.async(execute: walletMoneyWorkItem!)
    }

    func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let duration = args["duration"] as! Int
        let meta = args["meta"] as? String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletMoneyWorkItem = DispatchWorkItem {
            var error: NSError?
            let account:NknAccount? = NknNewAccount(seed?.data, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            let wallet = NknNewWallet(account, config, &error)
            if (error != nil) {
                self.resultError(result: result,error: error)
                return
            }

            let transactionConfig: NknTransactionConfig = NknTransactionConfig()
            transactionConfig.fee = fee
            if (nonce != nil) {
                transactionConfig.nonce = Int64(nonce!)
                transactionConfig.fixNonce = true
            }


            let hash = wallet?.subscribe(identifier, topic: topic, duration: duration, meta: meta, config: transactionConfig, error: &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            self.resultSuccess(result: result, resp: hash)
            return
        }
        walletMoneyQueue.async(execute: walletMoneyWorkItem!)
    }

    func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seed = args["seed"] as? FlutterStandardTypedData
        let identifier = args["identifier"] as? String ?? ""
        let topic = args["topic"] as! String
        let fee = args["fee"] as? String ?? "0"
        let nonce = args["nonce"] as? Int
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletMoneyWorkItem = DispatchWorkItem {
            var error: NSError?
            let account:NknAccount? = NknNewAccount(seed?.data, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            let wallet = NknNewWallet(account, config, &error)
            if (error != nil) {
                self.resultError(result: result,error: error)
                return
            }

            let transactionConfig: NknTransactionConfig = NknTransactionConfig()
            transactionConfig.fee = fee
            if (nonce != nil) {
                transactionConfig.nonce = Int64(nonce!)
                transactionConfig.fixNonce = true
            }


            let hash = wallet?.unsubscribe(identifier, topic: topic, config: transactionConfig, error: &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            self.resultSuccess(result: result, resp: hash)
            return
        }
        walletMoneyQueue.async(execute: walletMoneyWorkItem!)
    }

    private func getSubscribers(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let offset = args["offset"] as? Int ?? 0
        let limit = args["limit"] as? Int ?? 0
        let meta = args["meta"] as? Bool ?? true
        let txPool = args["txPool"] as? Bool ?? true
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletEventWorkItem = DispatchWorkItem {
            var error: NSError?
            let res: NknSubscribers? = NknGetSubscribers(topic, offset, limit, meta, txPool, subscriberHashPrefix?.data, config, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            let mapPro = MapProtocol()
            res?.subscribers?.range(mapPro)

            self.resultSuccess(result: result, resp: mapPro.result)
            return
        }
        walletEventQueue.async(execute: walletEventWorkItem!)
    }

    private func getSubscribersCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let topic = args["topic"] as! String
        let subscriberHashPrefix = args["subscriberHashPrefix"] as? FlutterStandardTypedData
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletEventWorkItem = DispatchWorkItem {
            var count: Int = 0
            var error: NSError?
            NknGetSubscribersCount(topic, subscriberHashPrefix?.data, config, &count, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            self.resultSuccess(result: result, resp: count)
            return
        }
        walletEventQueue.async(execute: walletEventWorkItem!)
    }

    private func getSubscription(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        // let _id = args["_id"] as! String
        let topic = args["topic"] as! String
        let subscriber = args["subscriber"] as! String
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletEventWorkItem = DispatchWorkItem {
            var error: NSError?
            let res: NknSubscription? = NknGetSubscription(topic, subscriber, config, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            var resp: [String: Any] = [String: Any]()
            resp["meta"] = res?.meta
            resp["expiresAt"] = res?.expiresAt
            self.resultSuccess(result: result, resp: resp)
            return
        }
        walletEventQueue.async(execute: walletEventWorkItem!)
    }

    private func getHeight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletEventWorkItem = DispatchWorkItem {
            var height: Int32 = 0
            var error: NSError?
            NknGetHeight(config, &height, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            self.resultSuccess(result: result, resp: height)
            return
        }
        walletEventQueue.async(execute: walletEventWorkItem!)
    }

    private func getNonce(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let address = args["address"] as! String
        let txPool = args["txPool"] as? Bool ?? true
        let seedRpc = args["seedRpc"] as? [String]

        let config = NknWalletConfig()
        if(seedRpc != nil) {
            config.seedRPCServerAddr = NkngomobileNewStringArrayFromString(nil)
            for (_, v) in seedRpc!.enumerated() {
                config.seedRPCServerAddr?.append(v)
            }
        }
        // config.rpcConcurrency = 4

        walletEventWorkItem = DispatchWorkItem {
            var nonce: Int64 = 0
            var error: NSError?
            NknGetNonce(address, txPool, config, &nonce, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }

            self.resultSuccess(result: result, resp: nonce)
            return
        }
        walletEventQueue.async(execute: walletEventWorkItem!)
    }
}
