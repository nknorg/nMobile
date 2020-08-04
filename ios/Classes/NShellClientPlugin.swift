import Flutter
import UIKit
import Nkn

public class NShellClientPlugin {
    public static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "createClient":
            createNShellClient(call, result: result)
        case "isConnected":
            isNShellConnected(call, result: result)
        case "disConnect":
            disNShellConnect(call, result: result)
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
