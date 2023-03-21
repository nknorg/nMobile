//
//  Common.swift
//  Runner
//
//  Created by 蒋治国 on 2021/6/4.
//
import Nkn
//import FMDB
//import SQLCipher

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
            //        case "resetSQLitePassword":
            //            resetSQLitePassword(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func create(_ call: FlutterMethodCall, result: FlutterResult) {
        result(nil)
    }
    
    private func saveImageToGallery(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
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
        let args = call.arguments as! [String: Any]
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
    
    /*private func encryptBytes(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     let args = call.arguments as! [String: Any]
     let algorithm = args["algorithm"] as? String ?? ""
     let bits = args["bits"] as? Int ?? 1
     let data = args["data"] as! FlutterStandardTypedData
     
     commonQueue.async {
     var encrypted = Encrypt.encrypt(algorithm: algorithm, bits: bits, data: Data([UInt8](data.data)))
     if(encrypted != nil){
     if (encrypted!["key_bytes"] != nil) {
     encrypted!["key_bytes"] = FlutterStandardTypedData(bytes: encrypted!["key_bytes"] as! Data)
     }
     if (encrypted!["iv_bytes"] != nil) {
     encrypted!["iv_bytes"] = FlutterStandardTypedData(bytes: encrypted!["iv_bytes"] as! Data)
     }
     if (encrypted!["cipher_text_bytes"] != nil) {
     encrypted!["cipher_text_bytes"] = FlutterStandardTypedData(bytes: encrypted!["cipher_text_bytes"] as! Data)
     }
     }
     
     var resp: [String: Any] = [String: Any]()
     resp["event"] = "encryptBytes"
     resp["data"] = encrypted
     self.resultSuccess(result: result, resp: resp)
     return
     }
     }*/
    
    /*private func decryptBytes(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     let args = call.arguments as! [String: Any]
     let algorithm = args["algorithm"] as? String ?? ""
     let bits = args["bits"] as? Int ?? 0
     let keyBytes = args["key_bytes"] as! FlutterStandardTypedData
     let ivBytes = args["iv_bytes"] as! FlutterStandardTypedData
     let data = args["data"] as! FlutterStandardTypedData
     
     commonQueue.async {
     let decrypted = Encrypt.decrypt(algorithm: algorithm, bits: bits, keyBytes: Data([UInt8](keyBytes.data)), ivBytes: Data([UInt8](ivBytes.data)), data: Data([UInt8](data.data)))
     
     var resp: [String: Any] = [String: Any]()
     resp["event"] = "decryptBytes"
     resp["data"] = (decrypted != nil) ? FlutterStandardTypedData(bytes: decrypted!) : nil
     self.resultSuccess(result: result, resp: resp)
     return
     
     }
     }*/
    
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
    
    //    private func resetSQLitePassword(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    //        let args = call.arguments as! [String: Any]
    //        let path = args["path"] as! String
    //        let password = args["password"] as! String
    //        let readOnly = args["readOnly"] as? Bool ?? false
    //
    //        FMDatabaseQueue.init(path: path, flags: (readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)))?.inDatabase({ _db in
    //            let success = _db.rekey(password)
    //
    //            var resp: [String: Any] = [String: Any]()
    //            resp["event"] = "resetSQLitePassword"
    //            resp["success"] = success
    //            self.resultSuccess(result: result, resp: resp)
    //        })
    //    }
}
