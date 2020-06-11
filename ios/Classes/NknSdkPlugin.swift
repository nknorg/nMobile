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


public class NknClientPlugin {
    public static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "createClient":
            createClient(call, result: result)
        case "disConnect":
            disConnect(call, result: result)
        case "isConnected":
            isConnected(call, result: result)
        case "sendText":
            sendText(call, result: result)
        case "publish":
            publish(call, result: result)
        case "subscribe":
            subscribe(call, result: result)
        case "unsubscribe":
            unsubscribe(call, result: result)
        case "getSubscribersCount":
            getSubscribersCount(call, result: result)
        case "getSubscription":
            getSubscription(call, result: result)
        case "getSubscribers":
            getSubscribers(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

public class NknClientEventPlugin : NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        clientEventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

public class NShellClientPlugin {
    public static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
     switch call.method {
          case "createClient":
              createNShellClient(call, result: result)
          case "disConnect":
              disConnect(call, result: result)
          case "isConnected":
              isNShellConnected(call, result: result)
          case "sendText":
            sendNShellText(call, result: result)
          default:
              result(FlutterMethodNotImplemented)
          }
    }
}

public class NShellClientEventPlugin : NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        nshellClientEventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

