import Foundation

public struct APNsRequest {
    public struct Header {
        public enum Priority: String {
            case p5 = "5", p10 = "10"
        }
        
        public let id: String
        public let expiration: Date
        public let priority: Priority
        public let topic: String?
        public let collapseId: String?
        
        public init(id: String = UUID().uuidString,
                    expiration: Date = Date(timeIntervalSince1970: 0),
                    priority: Priority = .p10,
                    topic: String? = nil,
                    collapseId: String? = nil) {
            self.id = id
            self.expiration = expiration
            self.priority = .p10
            self.topic = topic
            self.collapseId = collapseId
        }
    }
    
    public var port: APNsPort
    public var server: APNsServer
    public var deviceToken: String
    public var header: Header
    public var payload: APNsPayload
    
    public static let method = "POST"
    
    public init(port: APNsPort, server: APNsServer, deviceToken: String, header: Header = Header(), payload: APNsPayload) {
        self.port = port
        self.server = server
        self.deviceToken = deviceToken
        self.header = header
        self.payload = payload
    }
    
    public var url: URL? {
        let urlString = "https://" + server.rawValue + ":\(port.rawValue)" + "/3/device/" + deviceToken
        return URL(string: urlString)
    }
    
    public var urlRequest: URLRequest? {
        guard let url = url else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue(for: header)
        request.httpMethod = APNsRequest.method
        request.httpBody = payload.data
        return request
    }
}

private extension URLRequest {
    mutating func setValue(for header: APNsRequest.Header) {
        self.addValue(header.id, forHTTPHeaderField: "apns-id")
        self.addValue("\(Int(header.expiration.timeIntervalSince1970))", forHTTPHeaderField: "apns-expiration")
        self.addValue(header.priority.rawValue, forHTTPHeaderField: "apns-priority")
        
        if let topic = header.topic {
            self.addValue(topic, forHTTPHeaderField: "apns-topic")
        }
        
        if let collapseId = header.collapseId {
            self.addValue(collapseId, forHTTPHeaderField: "apns-collapse-id")
        }
    }
}
