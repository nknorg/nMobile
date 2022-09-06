import Nkn

class EthResolver : ChannelBase, FlutterStreamHandler {
    static var instance: EthResolver = EthResolver(config: nil)
    let ethResolverQueue = DispatchQueue(label: "org.nkn.mobile/native/nameservice/ethresolver/queue", qos: .default, attributes: .concurrent)
    private var ethResolverItem: DispatchWorkItem?

    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/nameservice/ethresolver"
    var eventSink: FlutterEventSink?
    
    let resolver: EthresolverResolver?
    init(config: EthresolverConfig?) {
        var error: NSError?
        self.resolver = EthresolverNewResolver(config, &error)
    }
    func resolve(_ address: String?, error: NSErrorPointer) -> String {
        return self.resolver!.resolve(address, error: error)
    }
    
    public static func register(controller: FlutterViewController) {
        instance.install(binaryMessenger: controller as! FlutterBinaryMessenger)
    }

    func install(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: METHOD_CHANNEL_NAME, binaryMessenger: binaryMessenger)
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
        case "new":
            new(call, result: result)
        case "resolve":
            resolve(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func new(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let config = args["config"] as! [String: Any]
        
        let ethresolverConfig: EthresolverConfig = EthresolverConfig()
        ethresolverConfig.prefix = config["prefix"] as? String ?? ""
        ethresolverConfig.rpcServer = config["rpcServer"] as! String
        ethresolverConfig.contractAddress = config["contractAddress"] as! String
        
        result(nil)
    }

    private func resolve(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let data = args["data"] as? FlutterStandardTypedData
        let key = args["key"] as? FlutterStandardTypedData
        let nonceSize = args["nonceSize"] as? Int ?? 0

        // todo
//        qryptoWorkItem = DispatchWorkItem {
//            var error: NSError?
//            let cipherText = CryptoGCMEncrypt(data?.data, key?.data, nonceSize, &error)
//            if (error != nil) {
//                self.resultError(result: result, error: error)
//                return
//            }
//
//            self.resultSuccess(result: result, resp: cipherText)
//        }
//        qryptoQueue.async(execute: qryptoWorkItem!)
    }
    
    
}
