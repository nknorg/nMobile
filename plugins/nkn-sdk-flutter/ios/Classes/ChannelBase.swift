class ChannelBase: NSObject {
    func resultSuccess(result: @escaping FlutterResult, resp: Any?) {
        DispatchQueue.main.async{
            result(resp)
        }
    }
    
    func resultError(result: @escaping FlutterResult, error: NSError?, code: String? = "") {
        DispatchQueue.main.async{
            result(FlutterError(code: code ?? "", message: error?.localizedDescription, details: ""))
        }
    }
    func resultError(result: @escaping FlutterResult, error: Error?, code: String? = "") {
        DispatchQueue.main.async{
            result(FlutterError(code: code ?? "", message: error?.localizedDescription, details: ""))
        }
    }
    func resultError(result: @escaping FlutterResult, code: String? = "", message: String? = "", details: String? = "") {
        DispatchQueue.main.async{
            result(FlutterError(code: code ?? "", message: message, details: details))
        }
    }
    
    func eventSinkSuccess(eventSink: @escaping FlutterEventSink, resp: Any?) {
        DispatchQueue.main.async {
            eventSink(resp)
        }
    }
    func eventSinkError(eventSink: @escaping FlutterEventSink, error: NSError?, code: String? = "") {
        DispatchQueue.main.async {
            eventSink(FlutterError(code: code ?? "", message: error?.localizedDescription, details: ""))
        }
    }
    func eventSinkError(eventSink: @escaping FlutterEventSink, error: Error?, code: String? = "") {
        DispatchQueue.main.async {
            eventSink(FlutterError(code: code ?? "", message: error?.localizedDescription, details: ""))
        }
    }
    func eventSinkError(eventSink: @escaping FlutterEventSink, code: String? = "", message: String? = "", details: String? = "") {
        DispatchQueue.main.async {
            eventSink(FlutterError(code: code ?? "", message: message, details: details))
        }
    }
}
