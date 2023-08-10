import Nkn

class DnsResolver : ChannelBase, FlutterStreamHandler {
    static var instance: DnsResolver = DnsResolver()
    let dnsResolverQueue = DispatchQueue(label: "org.nkn.mobile/native/nameservice/dnsresolver/queue", qos: .default, attributes: .concurrent)
    private var dnsResolverItem: DispatchWorkItem?
    
    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/nameservice/dnsresolver"
    var eventSink: FlutterEventSink?
    
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
        eventSink = nil
        return nil
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "resolve":
            resolve(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func resolve(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let config = args["config"] as? [String: Any] ?? [String: Any]()
        let address = args["address"] as? String ?? ""

        let dnsResolverConfig: DnsresolverConfig = DnsresolverConfig()
        dnsResolverConfig.dnsServer = config["dnsServer"] as? String ?? ""

        var error: NSError?
        let dnsResolver: DnsresolverResolver? = DnsresolverNewResolver(dnsResolverConfig, &error)
        if (error != nil) {
            self.resultError(result: result, error: error)
            return
        }
        var error1: NSError?
        let res = dnsResolver?.resolve(address, error: &error1)
        if (error1 != nil) {
            self.resultError(result: result, error: error1)
            return
        }
        result(res)
    }
    
    
}
