import Nkn

class MapProtocol : NSObject, NknStringMapFuncProtocol {
    var result:[String:Any] = [String:Any]()
    func onVisit(_ p0: String?, p1: String?) -> Bool {
        result[p0!] = p1
        return true;
    }
    
    
}
