import Nkn

class MapProtocol : NSObject, NkngomobileStringMapFuncProtocol {
    var result:[String:Any] = [String:Any]()
    func onVisit(_ p0: String?, p1: String?) -> Bool {
        result[p0!] = p1
        return true;
    }
}

class EthResolver : NSObject, NkngomobileResolverProtocol{
    let resolver: EthresolverResolver?
    init(config: EthresolverConfig?) {
        var error: NSError?
        self.resolver = EthresolverNewResolver(config, &error)
    }
    func resolve(_ address: String?, error: NSErrorPointer) -> String {
        return self.resolver!.resolve(address, error: error)
    }
}

class DnsResolver : NSObject, NkngomobileResolverProtocol{
    let resolver: DnsresolverResolver?
    init(config: DnsresolverConfig?) {
        var error: NSError?
        self.resolver = DnsresolverNewResolver(config, &error)
    }
    func resolve(_ address: String?, error: NSErrorPointer) -> String {
        return self.resolver!.resolve(address, error: error)
    }
}
