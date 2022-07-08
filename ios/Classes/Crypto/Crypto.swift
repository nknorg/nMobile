//
//  Scrypt.swift
//  Runner
//
//  Created by 蒋治国 on 2022/7/8.
//

import Nkn

class Crypto : ChannelBase, FlutterStreamHandler {

    static var instance: Crypto = Crypto()
    let qryptoQueue = DispatchQueue(label: "org.nkn.mobile/native/crypto/queue", qos: .default, attributes: .concurrent)
    private var qryptoWorkItem: DispatchWorkItem?

    var methodChannel: FlutterMethodChannel?
    let METHOD_CHANNEL_NAME = "org.nkn.mobile/native/crypto_method"
    var eventSink: FlutterEventSink?
    
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
        // eventSink = nil
        return nil
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case "gcmEncrypt":
            gcmEncrypt(call, result: result)
        case "gcmDecrypt":
            gcmDecrypt(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func create(_ call: FlutterMethodCall, result: FlutterResult) {
        result(nil)
    }

    private func gcmEncrypt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let data = args["data"] as? FlutterStandardTypedData
        let key = args["key"] as? FlutterStandardTypedData
        let nonceSize = args["nonceSize"] as? Int ?? 0

        qryptoWorkItem = DispatchWorkItem {
            var error: NSError?
            let cipherText = CryptoGCMEncrypt(data?.data, key?.data, nonceSize, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            
            self.resultSuccess(result: result, resp: cipherText)
        }
        qryptoQueue.async(execute: qryptoWorkItem!)
    }
    
    private func gcmDecrypt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        let data = args["data"] as? FlutterStandardTypedData
        let key = args["key"] as? FlutterStandardTypedData
        let nonceSize = args["nonceSize"] as? Int ?? 0

        qryptoWorkItem = DispatchWorkItem {
            var error: NSError?
            let plainText = CryptoGCMDecrypt(data?.data, key?.data, nonceSize, &error)
            if (error != nil) {
                self.resultError(result: result, error: error)
                return
            }
            
            self.resultSuccess(result: result, resp: plainText)
        }
        qryptoQueue.async(execute: qryptoWorkItem!)
    }
    
}
