//
//  Common.swift
//  Runner
//
//  Created by 蒋治国 on 2021/6/4.
//
import Nkn

class Common : ChannelBase, FlutterStreamHandler {
    
    static var instance: Common = Common()
    let commonQueue = DispatchQueue(label: "org.nkn.mobile/native/common/queue", qos: .default, attributes: .concurrent)
    
    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/common_method"
    
    var eventChannel: FlutterEventChannel?
    let EVENT_CHANNEL_NAME = "org.nkn.mobile/native/common_event"
    var eventSink: FlutterEventSink?
    
    public static func register(controller: FlutterViewController) {
        instance.install(binaryMessenger: controller as! FlutterBinaryMessenger)
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
        eventSink = nil
        return nil
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "configure":
            create(call, result: result)
        case "getAPNSToken":
            getAPNSToken(call, result: result)
        case "sendPushAPNS":
            sendPushAPNS(call, result: result)
        case "updateBadgeCount":
            updateBadgeCount(call, result: result)
        case "splitPieces":
            splitPieces(call, result: result)
        case "combinePieces":
            combinePieces(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func create(_ call: FlutterMethodCall, result: FlutterResult) {
        result(nil)
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
        let args = call.arguments as! [String: Any]
        let deviceToken = args["deviceToken"] as? String ?? ""
        let pushPayload = args["pushPayload"] as? String ?? ""
        
        commonQueue.async {
            APNSPushService.shared().pushContent(pushPayload, token: deviceToken)
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "sendPushAPNS"
            self.resultSuccess(result: result, resp: resp)
            return
        }
    }
    
    private func updateBadgeCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
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
        let args = call.arguments as! [String: Any]
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
            
            //            var error: NSError?
            //            do {
            //                let encoder = ReedsolomonNewDefault(dataShards, parityShards, &error) ?? ReedsolomonEncoder.init()
            //                let encodeBytes = try encoder.splitBytesArray(dataString.data(using: String.Encoding.utf8))
            //                try encoder.encode(encodeBytes)
            //
            //                guard (error == nil) else {
            //                    self.resultError(result: result, error: error)
            //                    return
            //                }
            //
            //                var returnArray = [FlutterStandardTypedData]()
            //                for index in 0 ..< encodeBytes.len() {
            //                    if let theBytes = encodeBytes.get(index) {
            //                        let fData = FlutterStandardTypedData(bytes: theBytes)
            //                        returnArray.append(fData)
            //                    }
            //                }
            //
            //                var resp: [String: Any] = [String: Any]()
            //                resp["event"] = "splitPieces"
            //                resp["data"] = returnArray
            //                self.resultSuccess(result: result, resp: resp)
            //                return
            //            } catch let error {
            //                self.resultError(result: result, error: error)
            //                return
            //            }
        }
    }
    
    private func combinePieces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
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
            
            //            var error: NSError?
            //            do {
            //                let totalShards = dataShards + parityShards
            //                let encodeDataBytes = ReedsolomonNewBytesArray(totalShards)
            //                var piecesLength = 0
            //                for (index, data) in dataList.enumerated() {
            //                    piecesLength += data.count
            //                    if data.isEmpty {
            //                        encodeDataBytes?.set(index, b: data)
            //                    } else {
            //                        encodeDataBytes?.set(index, b: nil)
            //                    }
            //                }
            //
            //                let encoder = ReedsolomonNewDefault(dataShards, parityShards, &error)
            //                try encoder?.reconstructBytesArray(encodeDataBytes)
            //                // encoder?.verifyBytesArray(<#T##shards: ReedsolomonBytesArray?##ReedsolomonBytesArray?#>, ret0_: <#T##UnsafeMutablePointer<ObjCBool>?#>)
            //
            //                guard (error == nil) else {
            //                    self.resultError(result: result, error: error)
            //                    return
            //                }
            //
            //                var fullDataList = Data.init(count: piecesLength)
            //                for index in 0..<dataShards {
            //                    if let data = encodeDataBytes?.get(index) {
            //                        fullDataList.append(data)
            //                    }
            //                }
            //
            //                let resultLength = fullDataList.count > bytesLength ? bytesLength : fullDataList.count
            //                let resultBytes =  fullDataList.subdata(in: 0..<resultLength)
            //                let combines = String.init(data: resultBytes, encoding: String.Encoding.utf8)
            //
            //                var resp: [String: Any] = [String: Any]()
            //                resp["event"] = "combinePieces"
            //                resp["data"] = combines
            //                self.resultSuccess(result: result, resp: resp)
            //                return
            //            } catch let error {
            //                self.resultError(result: result, error: error)
            //                return
            //            }
        }
    }
}
