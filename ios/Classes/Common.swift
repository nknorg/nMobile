import Nkn
import PhotosUI
import UniformTypeIdentifiers


class Common : ChannelBase, FlutterStreamHandler {
    
    static var instance: Common = Common()
    let commonQueue = DispatchQueue(label: "org.nkn.mobile/native/common/queue", qos: .default, attributes: .concurrent)
    
    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/common_method"
    private var imagePickSession: SerialImagePickSession?
    
    var eventChannel: FlutterEventChannel?
    let EVENT_CHANNEL_NAME = "org.nkn.mobile/native/common_event"
    var eventSink: FlutterEventSink?
    
    public static func register(messenger: FlutterBinaryMessenger) {
        instance.install(binaryMessenger: messenger)
    }
    
    public static func eventAdd(name: String, map: [String: Any]) {
        if(instance.eventSink == nil) {
            return
        }
        var resultMap: [String: Any] = [String: Any]()
        resultMap["event"] = name
        resultMap.merge(map){ (current, _) in current }
        instance.eventSink!(resultMap)
    }
    
    public static func eventAdd(name: String, result: Any) {
        if(instance.eventSink == nil) {
            return
        }
        var resultMap: [String: Any] = [String: Any]()
        resultMap["event"] = name
        resultMap["result"] = result
        instance.eventSink!(resultMap)
    }
    
    func install(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: METHOD_CHANNEL_NAME, binaryMessenger: binaryMessenger)
        self.methodChannel?.setMethodCallHandler(handle)
        self.eventChannel = FlutterEventChannel(name: EVENT_CHANNEL_NAME, binaryMessenger: binaryMessenger)
        self.eventChannel?.setStreamHandler(self)
    }
    
    func uninstall() {
        self.methodChannel?.setMethodCallHandler(nil)
        self.eventChannel?.setStreamHandler(nil)
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
        case "configure":
            create(call, result: result)
        case "saveImageToGallery":
            saveImageToGallery(call, result: result)
        case "getAPNSToken":
            getAPNSToken(call, result: result)
        case "sendPushAPNS":
            sendPushAPNS(call, result: result)
        case "updateBadgeCount":
            updateBadgeCount(call, result: result)
            //case "encryptBytes":
            //    encryptBytes(call, result: result)
            //case "decryptBytes":
            //    decryptBytes(call, result: result)
        case "splitPieces":
            splitPieces(call, result: result)
        case "combinePieces":
            combinePieces(call, result: result)
        case "pickImages":
            pickImages(call, result: result)
            //        case "resetSQLitePassword":
            //            resetSQLitePassword(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func pickImages(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if imagePickSession != nil {
            result([])
            return
        }
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        var limit = args["limit"] as? Int ?? 9
        if limit < 1 { limit = 1 }
        if limit > 9 { limit = 9 }
        let session = SerialImagePickSession(limit: limit) { [weak self] paths in
            self?.imagePickSession = nil
            result(paths)
        }
        imagePickSession = session
        DispatchQueue.main.async {
            session.present()
        }
    }

    private func create(_ call: FlutterMethodCall, result: FlutterResult) {
        result(nil)
    }
    
    private func saveImageToGallery(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let imageData = args["imageData"] as! FlutterStandardTypedData
        let imageName = args["imageName"] as! String
        let albumName = args["albumName"] as! String
        
        commonQueue.async {
            CommonOc.init().saveImage(withImageName: imageName, imageData: imageData, albumName: albumName, overwriteFile: true)
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "saveImageToGallery"
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
    
    private func getAPNSToken(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        commonQueue.async {
            let deviceToken = UserDefaults.standard.object(forKey: "nkn_device_token");
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "getAPNSToken"
            resp["token"] = deviceToken
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
    
    private func sendPushAPNS(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let uuid = args["uuid"] as? String ?? ""
        let deviceToken = args["deviceToken"] as? String ?? ""
        let topic = args["topic"] as? String ?? ""
        let pushPayload = args["pushPayload"] as? String ?? ""
        
        commonQueue.async {
            do {
                try APNSPusher.push(uuid: uuid, deviceToken: deviceToken, topic: topic, payload: pushPayload, onSuccess: { () -> Void in
                    var resp: [String: Any] = [String: Any]()
                    resp["event"] = "sendPushAPNS"
                    self.resultSuccess(result: result, resp: resp)
                }, onFailure: { (errCode, reason) -> Void in
                    var resp: [String: Any] = [String: Any]()
                    resp["event"] = "sendPushAPNS"
                    resp["errCode"] = errCode
                    resp["errMsg"] = reason
                    self.resultSuccess(result: result, resp: resp)
                })
            } catch let e {
                print("APNSPusher - send faile - err:\(e.localizedDescription)")
                self.resultError(result: result, error: e)
            }
            // APNSPushService.shared().pushContent(pushPayload, token: deviceToken)
        }
    }
    
    private func updateBadgeCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let badgeCount = args["badge_count"] as? Int ?? 0
        
        DispatchQueue.main.async { // run on UIThread
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }
        commonQueue.async {
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "updateBadgeCount"
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
    
    private func splitPieces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let flutterDataString = args["data"] as? String ?? ""
        let dataShards = args["dataShards"] as? Int ?? 0
        let parityShards = args["parityShards"] as? Int ?? 0
        
        commonQueue.async {
            let rArray = CommonOc.init().intoPieces(flutterDataString, dataShard: dataShards, parityShards: parityShards)
            var dataBytes = [FlutterStandardTypedData]()
            for index in 0..<rArray.count {
                let fData = FlutterStandardTypedData(bytes: rArray[index])
                dataBytes.append(fData)
            }
            
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "splitPieces"
            resp["data"] = dataBytes
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
    
    private func combinePieces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        let fDataList = args["data"] as? [FlutterStandardTypedData] ?? []
        let dataShards = args["dataShards"] as? Int ?? 0
        let parityShards = args["parityShards"] as? Int ?? 0
        let bytesLength = args["bytesLength"] as? Int ?? 0
        
        commonQueue.async {
            var dataList = [Data]()
            for index in 0..<fDataList.count {
                let fData:FlutterStandardTypedData = fDataList[index]
                dataList.append(fData.data)
            }
            
            let combinedString:String = CommonOc.init().combinePieces(dataList, dataShard: dataShards, parityShards: parityShards, bytesLength: bytesLength)
            
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "combinePieces"
            resp["data"] = combinedString
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
}

// Saves one picked item at a time. UIImage JPEG encoding is not safe to run
// concurrently, which is what turns a multi-select into black thumbnails.
private class SerialImagePickSession: NSObject, PHPickerViewControllerDelegate {
    let limit: Int
    let onComplete: ([String]) -> Void
    let saveQueue = DispatchQueue(label: "org.nkn.nmobile/image_pick_save")
    var finished = false
    var results: [PHPickerResult] = []
    var saved: [String] = []
    var index = 0

    init(limit: Int, onComplete: @escaping ([String]) -> Void) {
        self.limit = limit
        self.onComplete = onComplete
    }

    func present() {
        var config = PHPickerConfiguration()
        config.selectionLimit = limit
        config.filter = PHPickerFilter.any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        guard let root = SerialImagePickSession.topViewController() else {
            finish([])
            return
        }
        root.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if results.isEmpty {
                self.finish([])
                return
            }
            self.results = Array(results.prefix(self.limit))
            self.index = 0
            self.saved = []
            self.saveQueue.async {
                self.saveCurrent()
            }
        }
    }

    func saveCurrent() {
        if index >= results.count {
            let paths = saved
            DispatchQueue.main.async {
                self.finish(paths)
            }
            return
        }
        let provider = results[index].itemProvider
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                self.saveQueue.async {
                    if let data = data, let path = self.writeImage(data) {
                        self.saved.append(path)
                    }
                    self.index += 1
                    self.saveCurrent()
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                var copied: String?
                if let url = url {
                    copied = self.copyFile(url, fallbackExt: "mp4")
                }
                self.saveQueue.async {
                    if let copied = copied {
                        self.saved.append(copied)
                    }
                    self.index += 1
                    self.saveCurrent()
                }
            }
        } else {
            index += 1
            saveCurrent()
        }
    }

    func writeImage(_ data: Data) -> String? {
        let kind = SerialImagePickSession.imageKind(data)
        if kind == "jpg" || kind == "png" || kind == "gif" {
            return writeBytes(data, ext: kind)
        }
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 1) else {
            return nil
        }
        return writeBytes(jpeg, ext: "jpg")
    }

    func copyFile(_ url: URL, fallbackExt: String) -> String? {
        let ext = url.pathExtension.isEmpty ? fallbackExt : url.pathExtension
        let dest = SerialImagePickSession.tempPath(ext)
        do {
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: dest))
            return dest
        } catch {
            return nil
        }
    }

    func writeBytes(_ data: Data, ext: String) -> String? {
        let dest = SerialImagePickSession.tempPath(ext)
        do {
            try data.write(to: URL(fileURLWithPath: dest))
            return dest
        } catch {
            return nil
        }
    }

    static func tempPath(_ ext: String) -> String {
        let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("nm_pick")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return (dir as NSString).appendingPathComponent(UUID().uuidString + "." + ext)
    }

    static func imageKind(_ data: Data) -> String {
        if data.count >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
            return "jpg"
        }
        if data.count >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return "png"
        }
        if data.count >= 6 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
            return "gif"
        }
        return ""
    }

    func finish(_ paths: [String]) {
        if finished { return }
        finished = true
        onComplete(paths)
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
