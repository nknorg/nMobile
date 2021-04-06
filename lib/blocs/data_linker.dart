import 'package:flutter/services.dart';
import 'dart:convert' as convert;

typedef GetObject = Function(Map backInfo);
typedef PostObject = Function(dynamic object);

class RequestTag {
  static String listenOnMessages = 'event';
}

class DataLinker {
  factory DataLinker() => _getInstance();

  static DataLinker get instance => _getInstance();
  static DataLinker _instance;

  static Map<String, dynamic> postNameMap = Map<String, dynamic>();
  static Map<String, Map> sendDataMap = Map<String, Map>();

  static Map<String, dynamic> postEventListening = Map<String, dynamic>();

  DataLinker._internal();

  static DataLinker _getInstance() {
    if (_instance == null) {
      _instance = new DataLinker._internal();
    }
    return _instance;
  }

  static const methodChannel = const MethodChannel('org.nkn.sdk/client');

  static const EventChannel eventChannel =
      const EventChannel('org.nkn.sdk/client/event');

  postData(Object object, String tag) {
    methodChannel.invokeMethod("invokeMethod", object);
    sendDataMap[tag] = object;
    print("【flutter send 】Tag" + object.toString());
  }

  invokeMethod(String methodName, Map invokeMap) {
    methodChannel.invokeMethod(methodName, invokeMap);
  }

  GetObject getObject;
  PostObject postObject;

  addObserver(String postName, object(Map backInfo)) {
    eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
    getObject = object;
    postNameMap[postName] = getObject;
  }

  onListeningEvent(String postName, object(Map backInfo)) {
    eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
    getObject = object;
    postEventListening[postName] = getObject;
  }

  void _onEvent(Object event) {
    String resultString = event.toString();
    Map resultMap;
    resultMap = convert.jsonDecode(event.toString());
    print('_onEvent result' + resultString);
    postNotification(resultMap["Tag"].toString(), resultMap);
  }

  void _onError(Object error) {
    PlatformException exception = error;
    if (exception.code == "500") {
      String tag = exception.details;
      Object object = sendDataMap[tag];
      if (object != null) {
        methodChannel.invokeMethod("resendMessage", object);
        sendDataMap[tag] = object;
        print("【resend send 】Tag" + object.toString());
        postNotification(tag, object);
      }
    }
    print(error.toString());
  }

  postNotification(String postName, Map backInfo) {
    if (postNameMap.containsKey(postName)) {
      GetObject getObject = postNameMap[postName];
      getObject(backInfo);

      _getInstance().removeNotification(postName);
    } else if (postEventListening.containsKey(postName)) {
      GetObject getObject = postEventListening[postName];
      getObject(backInfo);
    }
  }

  removeNotification(String postName) {
    if (postNameMap.containsKey(postName)) {
      postNameMap.remove(postName);
    }
  }

  static Future<void> connect() async {
    await methodChannel.invokeMethod('connect');
  }

  static Future<void> backOn() async {
    await methodChannel.invokeMethod('backOn');
  }

  static Future<void> backOff() async {
    await methodChannel.invokeMethod('backOff');
  }

  static Future<void> disConnect() async {
    await methodChannel.invokeMethod('disConnect');
  }
}
