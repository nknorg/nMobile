import Foundation

public struct APNsPayload {
    let title: String?
    let body: String
    let titleLocKey: String?
    let titleLocArgs: [String]?
    let actionLocKey: String?
    let locKey: String?
    let locArgs: [String]?
    let launchImage: String?
    
    let badge: Int?
    let sound: String?
    let contentAvailable: Int?
    let mutableContent: Int?
    let category: String?
    let threadId: String?
    
    let custom: [String: Any]?
    
    let str: String?
    
    public init(str: String) {
        self.str = str
        
        self.title = nil
        self.body = ""
        self.titleLocKey = nil
        self.titleLocArgs = nil
        self.actionLocKey = nil
        self.locKey = nil
        self.locArgs = nil
        self.launchImage = nil
        
        self.badge = nil
        self.sound = nil
        self.contentAvailable = nil
        self.mutableContent = nil
        self.category = nil
        self.threadId = nil
        
        self.custom = nil
    }
    
    public init(
        title: String? = nil,
        body: String,
        titleLocKey: String? = nil,
        titleLocArgs: [String]? = nil,
        actionLocKey: String? = nil,
        locKey: String? = nil,
        locArgs: [String]? = nil,
        launchImage: String? = nil,
        
        badge: Int? = nil,
        sound: String? = nil,
        contentAvailable: Int? = nil,
        mutableContent: Int? = nil,
        category: String? = nil,
        threadId: String? = nil,
        
        custom: [String: Any]? = nil) {
        self.title = title
        self.body = body
        self.titleLocKey = titleLocKey
        self.titleLocArgs = titleLocArgs
        self.actionLocKey = actionLocKey
        self.locKey = locKey
        self.locArgs = locArgs
        self.launchImage = launchImage
        
        self.badge = badge
        self.sound = sound
        self.contentAvailable = contentAvailable
        self.mutableContent = mutableContent
        self.category = category
        self.threadId = threadId
        
        self.custom = custom
        
        self.str = nil
    }
    
    public var dictionary: [String: Any] {
        // Alert
        var alert: [String: Any] = ["body": body]
        
        if let title = title {
            alert["title"] = title
        }
        
        if let titleLocKey = titleLocKey {
            alert["title-loc-key"] = titleLocKey
        }
        
        if let titleLocArgs = titleLocArgs {
            alert["title-loc-args"] = titleLocArgs
        }
        
        if let actionLocKey = actionLocKey {
            alert["action-loc-key"] = actionLocKey
        }
        
        if let locKey = locKey {
            alert["loc-key"] = locKey
        }
        
        if let locArgs = locArgs {
            alert["loc-args"] = locArgs
        }
        
        if let launchImage = launchImage {
            alert["launch-image"] = launchImage
        }
        
        // APS
        var dictionary: [String: Any] = ["alert": alert]
        
        if let badge = badge {
            dictionary["badge"] = badge
        }
        
        if let sound = sound {
            dictionary["sound"] = sound
        }
        
        if let contentAvailable = contentAvailable {
            dictionary["content-available"] = contentAvailable
        }
        
        if let mutableContent = mutableContent {
            dictionary["mutable-content"] = mutableContent
        }
        
        if let category = category {
            dictionary["category"] = category
        }
        
        if let threadId = threadId {
            dictionary["thread-id"] = threadId
        }
        
        var payload: [String: Any] = ["aps": dictionary]
        
        // Custom
        custom?.forEach {
            payload[$0] = $1
        }
        
        return payload
    }
    
    public static func convert(parameters: Any) -> String {
        if let dictionary = parameters as? [String: Any] {
            return "{" + dictionary.map { "\"\($0.key)\":" + convert(parameters: $0.value) }.joined(separator: ",") + "}"
        } else if let array = parameters as? [String] {
            return "[" + array.joined(separator: ",") + "]"
        } else if let int = parameters as? Int {
            return "\(int)"
        } else {
            return "\"\(parameters)\""
        }
    }
    
    public var data: Data? {
        if (str != nil) {
            return str!.data(using: .unicode)
        }
        return APNsPayload.convert(parameters: dictionary).data(using: .unicode)
    }
}
