import Nkn

class SearchService : ChannelBase, FlutterStreamHandler {
    static var instance: SearchService = SearchService()
    let searchQueue = DispatchQueue(label: "org.nkn.mobile/native/search/queue", qos: .default, attributes: .concurrent)
    
    // High priority queue for CPU-intensive PoW calculations
    // Use userInitiated QoS to ensure maximum CPU resources
    let powQueue = DispatchQueue(label: "org.nkn.mobile/native/search/pow", qos: .userInitiated, attributes: .concurrent)
    
    private var searchItem: DispatchWorkItem?
    
    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/search"
    var eventSink: FlutterEventSink?
    
    // Store search client instances by ID
    private var clients: [String: SearchSearchClient] = [:]
    private let clientsLock = NSLock()
    
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
        switch call.method {
        case "newSearchClient":
            newSearchClient(call, result: result)
        case "newSearchClientWithAuth":
            newSearchClientWithAuth(call, result: result)
        case "query":
            query(call, result: result)
        case "submitUserData":
            submitUserData(call, result: result)
        case "verify":
            verify(call, result: result)
        case "queryByID":
            queryByID(call, result: result)
        case "getMyInfo":
            getMyInfo(call, result: result)
        case "getPublicKeyHex":
            getPublicKeyHex(call, result: result)
        case "getAddress":
            getAddress(call, result: result)
        case "isVerified":
            isVerified(call, result: result)
        case "disposeClient":
            disposeClient(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Create a query-only search client
    private func newSearchClient(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let apiBase = args["apiBase"] as? String ?? ""
        
        var error: NSError?
        guard let client = SearchNewSearchClient(apiBase, &error) else {
            self.resultError(result: result, error: error, code: "CREATE_CLIENT_FAILED")
            return
        }
        
        // Generate unique ID for this client
        let clientId = UUID().uuidString
        
        clientsLock.lock()
        clients[clientId] = client
        clientsLock.unlock()
        
        let response: [String: Any] = [
            "clientId": clientId
        ]
        
        self.resultSuccess(result: result, resp: response)
    }
    
    // Create an authenticated search client
    private func newSearchClientWithAuth(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let apiBase = args["apiBase"] as? String ?? ""
        guard let seedData = args["seed"] as? FlutterStandardTypedData else {
            self.resultError(result: result, code: "INVALID_SEED", message: "Seed must be provided")
            return
        }
        
        let seed = seedData.data
        if seed.count != 32 {
            self.resultError(result: result, code: "INVALID_SEED", message: "Seed must be exactly 32 bytes")
            return
        }
        
        var error: NSError?
        guard let client = SearchNewSearchClientWithAuth(apiBase, seed, &error) else {
            self.resultError(result: result, error: error, code: "CREATE_AUTH_CLIENT_FAILED")
            return
        }
        
        // Generate unique ID for this client
        let clientId = UUID().uuidString
        
        clientsLock.lock()
        clients[clientId] = client
        clientsLock.unlock()
        
        let response: [String: Any] = [
            "clientId": clientId
        ]
        
        self.resultSuccess(result: result, resp: response)
    }
    
    // Query data by keyword
    private func query(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        let keyword = args["keyword"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        searchQueue.async {
            var error: NSError?
            let response = client.query(keyword, error: &error)
            
            if let error = error {
                self.resultError(result: result, error: error, code: "QUERY_FAILED")
                return
            }
            
            self.resultSuccess(result: result, resp: response)
        }
    }
    
    // Submit user data
    private func submitUserData(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        var nknAddress = args["nknAddress"] as? String ?? ""
        let customId = args["customId"] as? String ?? ""
        let nickname = args["nickname"] as? String ?? ""
        let phoneNumber = args["phoneNumber"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        // Use high-priority queue for CPU-intensive PoW calculation
        let queueItem = DispatchWorkItem {
            // Process nknAddress: if empty, use publicKey
            let publicKeyHex = client.getPublicKeyHex()
            
            if nknAddress.isEmpty {
                nknAddress = publicKeyHex
            } else {
                // Validate format if contains dot
                if nknAddress.contains(".") {
                    let parts = nknAddress.components(separatedBy: ".")
                    if parts.count != 2 {
                        self.resultError(result: result, code: "INVALID_PARAMETER", 
                                       message: "Invalid nknAddress format. Expected: identifier.publickey")
                        return
                    }
                    let providedPubKey = parts[1]
                    if providedPubKey.lowercased() != publicKeyHex.lowercased() {
                        self.resultError(result: result, code: "INVALID_PARAMETER", 
                                       message: "nknAddress publickey suffix must match your actual publicKey")
                        return
                    }
                } else {
                    // If no dot, must equal publicKey
                    if nknAddress.lowercased() != publicKeyHex.lowercased() {
                        self.resultError(result: result, code: "INVALID_PARAMETER", 
                                       message: "nknAddress must be either \"identifier.publickey\" format or equal to publicKey")
                        return
                    }
                }
            }
            
            // Validate customId if provided
            if !customId.isEmpty && customId.count < 3 {
                self.resultError(result: result, code: "INVALID_PARAMETER", 
                               message: "customId must be at least 3 characters if provided")
                return
            }
            
            do {
                // PoW calculation happens here - runs on high priority background thread
                try client.submitUserData(nknAddress, customId: customId, nickname: nickname, phoneNumber: phoneNumber)
                self.resultSuccess(result: result, resp: ["success": true])
            } catch let error as NSError {
                self.resultError(result: result, error: error, code: "SUBMIT_FAILED")
            }
        }
        powQueue.async(execute: queueItem)
    }
    
    // Verify the client (optional, for query operations)
    private func verify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        // Use high-priority queue for CPU-intensive PoW calculation
        powQueue.async {
            do {
                // PoW calculation happens here - runs on high priority background thread
                try client.verify()
                self.resultSuccess(result: result, resp: ["success": true])
            } catch let error as NSError {
                self.resultError(result: result, error: error, code: "VERIFY_FAILED")
            }
        }
    }
    
    // Query by ID
    private func queryByID(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        let id = args["id"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        searchQueue.async {
            var error: NSError?
            let response = client.query(byID: id, error: &error)
            
            if let error = error {
                self.resultError(result: result, error: error, code: "QUERY_BY_ID_FAILED")
                return
            }
            
            self.resultSuccess(result: result, resp: response)
        }
    }
    
    // Get my info by nknAddress
    private func getMyInfo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        let address = args["address"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        searchQueue.async {
            var error: NSError?
            let response = client.getMyInfo(address, error: &error)
            
            if let error = error {
                self.resultError(result: result, error: error, code: "GET_MY_INFO_FAILED")
                return
            }
            
            self.resultSuccess(result: result, resp: response)
        }
    }
    
    // Get public key hex
    private func getPublicKeyHex(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        let publicKeyHex = client.getPublicKeyHex()
        self.resultSuccess(result: result, resp: publicKeyHex)
    }
    
    // Get wallet address
    private func getAddress(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        let address = client.getAddress()
        self.resultSuccess(result: result, resp: address)
    }
    
    // Check if verified
    private func isVerified(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        
        clientsLock.lock()
        guard let client = clients[clientId] else {
            clientsLock.unlock()
            self.resultError(result: result, code: "CLIENT_NOT_FOUND", message: "Search client not found")
            return
        }
        clientsLock.unlock()
        
        let verified = client.isVerified()
        self.resultSuccess(result: result, resp: verified)
    }
    
    // Dispose client
    private func disposeClient(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let clientId = args["clientId"] as? String ?? ""
        
        clientsLock.lock()
        clients.removeValue(forKey: clientId)
        clientsLock.unlock()
        
        self.resultSuccess(result: result, resp: ["success": true])
    }
}
