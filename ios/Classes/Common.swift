//
//  Common.swift
//  Runner
//
//  Created by 蒋治国 on 2021/6/4.
//
import Nkn

class Common : ChannelBase, FlutterStreamHandler {
    
    let commonQueue = DispatchQueue(label: "org.nkn.mobile/native/common/queue", qos: .default, attributes: .concurrent)
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    let CHANNEL_NAME = "org.nkn.mobile/native/common"
    
    public static func register(controller: FlutterViewController) {
        Common().install(binaryMessenger: controller as! FlutterBinaryMessenger)
    }
    
    func install(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: binaryMessenger)
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
        case "configure":
            create(call, result: result)
        case "sendPush":
            sendPush(call, result: result)
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
    
    private func sendPush(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let deviceToken = args["deviceToken"] as? String ?? ""
        let pushContent = args["pushContent"] as? String ?? ""
        
        commonQueue.async {
            PushService.shared().pushContent(pushContent, token: deviceToken)
            var resp: [String: Any] = [String: Any]()
            resp["event"] = "splitPieces"
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
