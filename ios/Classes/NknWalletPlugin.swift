import Flutter
import UIKit
import Nkn

public class NknWalletPlugin {
    public static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "createWallet":
            createWallet(call, result: result)
        case "restoreWallet":
            restoreWallet(call, result: result)
        case "getBalance":
            getBalance(call, result: result)
        case "getBalanceAsync":
            getBalanceAsync(call, result: result)
        case "transfer":
            transfer(call, result: result)
        case "transferAsync":
            transferAsync(call, result: result)
        case "openWallet":
            openWallet(call, result: result)
        case "pubKeyToWalletAddr":
            pubKeyToWalletAddr(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

public class NknWalletEventPlugin : NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        walletEventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
