import Nkn

class Crypto : ChannelBase, IChannelHandler, FlutterStreamHandler {
    
    let CHANNEL_NAME = "org.nkn.sdk/crypto"
    let EVENT_NAME = "org.nkn.sdk/crypto/event"
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    
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
        case "getPublicKeyFromPrivateKey":
            getPublicKeyFromPrivateKey(call, result: result)
        case "getPrivateKeyFromSeed":
            getPrivateKeyFromSeed(call, result: result)
        case "getSeedFromPrivateKey":
            getSeedFromPrivateKey(call, result: result)
        case "sign":
            sign(call, result: result)
        case "verify":
            verify(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getPublicKeyFromPrivateKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let privateKey = args["privateKey"] as? FlutterStandardTypedData
        
        let publicKey = CryptoGetPublicKeyFromPrivateKey(privateKey?.data)
        result(publicKey)
    }
    
    private func getPrivateKeyFromSeed(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let seed = args["seed"] as? FlutterStandardTypedData
        
        let privateKey = CryptoGetPrivateKeyFromSeed(seed?.data)
        result(privateKey)
    }
    
    private func getSeedFromPrivateKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let privateKey = args["privateKey"] as? FlutterStandardTypedData
        
        let seed = CryptoGetSeedFromPrivateKey(privateKey?.data)
        result(seed)
    }
    
    private func sign(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let privateKey = args["privateKey"] as? FlutterStandardTypedData
        let data = args["data"] as? FlutterStandardTypedData
        
        var error: NSError?
        let signature = CryptoSign(privateKey?.data, data?.data, &error)
        if (error != nil) {
            self.resultError(result: result, error: error)
            return
        }
        result(signature)
    }
    
    private func verify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let publicKey = args["publicKey"] as? FlutterStandardTypedData
        let data = args["data"] as? FlutterStandardTypedData
        let signature = args["signature"] as? FlutterStandardTypedData
        var error: NSError?
        
        CryptoVerify(publicKey?.data, data?.data, signature?.data, &error)
        if (error != nil) {
            //NSLog("%@", error!)
            result(false)
            return
        }
        result(true)
    }
}
