import Foundation

let p12FileName = BuildSecrets.apnsP12FileName
let p12FilePasswordd = BuildSecrets.apnsP12Password

public class APNSPusher {
    
    static var apnsClient: Connection? = nil
    
    static func connect() -> Connection? {
        if (p12FileName.isEmpty || p12FilePasswordd.isEmpty) {
            return nil
        }
        var _connection: Connection?
        do {
            _connection = try Connection(p12FileName: p12FileName, passPhrase: p12FilePasswordd)
        } catch let e {
            print("APNSPusher - connect faile - error:\(e.localizedDescription)")
            return nil
        }
        return _connection
    }
    
    static func push(uuid: String, deviceToken: String, topic: String, payload: String, onSuccess: (() -> Void)?, onFailure: ((Int, String) -> Void)?) throws {
        if apnsClient == nil {
            apnsClient = connect();
        }
        if apnsClient == nil {
            onFailure?(-1, "apnsClient is nil on IOS")
            return
        }
        let header = APNsRequest.Header(id: uuid, priority: APNsRequest.Header.Priority.p10, topic: topic)
        let payload = APNsPayload(str: payload)
        let request = APNsRequest(port: APNsPort.p443, server: APNsServer.production, deviceToken: deviceToken, header: header, payload: payload)
        
        try apnsClient?.send(request: request) {
            switch $0 {
            case .success:
                print("APNSPusher - pushed success - deviceToken:\(deviceToken)")
                onSuccess?()
            case .failure(let errorCode, let message):
                print("APNSPusher - pushed Failed - \(errorCode), \(uuid), \(deviceToken), \(message)")
                apnsClient = connect();
                onFailure?(errorCode, message)
            }
        }
        
    }
}
