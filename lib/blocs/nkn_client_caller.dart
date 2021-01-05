/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/message.dart';

class NKNClientCaller{

  factory NKNClientCaller() => _getInstance();
  static NKNClientCaller get instance => _getInstance();
  static NKNClientCaller _instance;
  NKNClientCaller._internal();

  static NKNClientCaller _getInstance() {
    if (_instance == null) {
      _instance = new NKNClientCaller._internal();
      _instance._initChannel();
      _instance.addListening();
    }
    return _instance;
  }

  static const String METHOD_CHANNEL_NAME = 'org.nkn.sdk/client';
  static const String EVENT_CHANNEL_NAME = 'org.nkn.sdk/client/event';
  static MethodChannel _methodChannel;
  static EventChannel _eventChannel;
  _initChannel(){
    _methodChannel = MethodChannel(METHOD_CHANNEL_NAME);
    _eventChannel = EventChannel(EVENT_CHANNEL_NAME);
  }

  static NKNClientBloc clientBloc;
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();

  createClient(Uint8List seed, String identifier, String clientUrl){
    String eventId = _formEventID();
    Completer completer = _clientEventQueue[eventId];
    print('CreateClient Called'+eventId+'__'+seed.toString());
    try {
      _methodChannel.invokeMethod('createClient', {
        '_id': eventId,
        'identifier': identifier,
        'seedBytes': seed,
        'clientUrl': clientUrl,
      });
    } catch (e) {
      Global.debugLog('createClient E:'+e.toString());
      completer.completeError(e);
    }
  }

  static String pubKey = '';
  static String currentChatId = '';

  setPubkeyAndChatId(String pubKey,String chatId){
    NKNClientCaller.pubKey = pubKey;
    NKNClientCaller.currentChatId = chatId;

    Global.debugLog('Change PubKey:'+pubKey+'\n'+'Change chatId:'+chatId);
  }

  static connectNKN(){
    print('methodCalled+connectNKN');
    _methodChannel.invokeMethod('connect');
  }

  static Future<void> disConnect() async {
    _methodChannel.invokeMethod('disConnect');
  }

  static Future<Uint8List> sendText(List<String> dests, String data, {int maxHoldingSeconds = -1}) async {
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
    try {
      _methodChannel.invokeMethod('sendText', {
        '_id': id,
        'dests': dests,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
      });
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }

  /// GroupChat sendText
  static Future<Uint8List> publishText(String topicHash, String data, {int maxHoldingSeconds = -1}) async {
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
    try {
      _methodChannel.invokeMethod('publishText', {
        '_id': id,
        'topicHash': topicHash,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
      });
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }

  /// subscribeTopic
  static Future<String> subscribe({
    String identifier = '',
    String topicHash,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) async {
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('subscribe', {
      '_id': id,
      'identifier': identifier,
      'topicHash': topicHash,
      'duration': duration,
      'fee': fee,
      'meta': meta,
    });
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<String> unsubscribe({String identifier = '', String topicHash, String fee = '0'}) async {
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('unsubscribe', {
      '_id': id,
      'identifier': identifier,
      'topicHash': topicHash,
      'fee': fee,
    });
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<int> getSubscribersCount(String topicHash) async {
    Completer<int> completer = Completer<int>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscribersCount', {
      '_id': id,
      'topicHash': topicHash,
    });
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Map<String, dynamic>> getSubscription({String topicHash, String subscriber}) async {
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscription', {
      '_id': id,
      'topicHash': topicHash,
      'subscriber': subscriber,
    });

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Map<String, dynamic>> getSubscribers({
    String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) async {
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscribers', {
      '_id': id,
      'topicHash': topicHash,
      'offset': offset,
      'limit': limit,
      'meta': meta,
      'txPool': txPool,
    });

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<int> fetchBlockHeight() async{
    String eventId = NKNClientCaller.instance._formEventID();
    Completer completer = _clientEventQueue[eventId];
    try {
      _methodChannel.invokeMethod('getBlockHeight', {
        '_id': eventId,
      });
      Map resp = await completer.future;
      int blockHeight = resp['height'];
      Global.debugLog('fetchBlockHeight height is :'+blockHeight.toString());
      return blockHeight;
    } catch (e) {
      Global.debugLog('fetch fetchBlockHeight E:'+e.toString());
      completer.completeError(e);
      return 0;
    }
  }

  static Future<String> fetchDeviceToken() async{
    String eventId = NKNClientCaller.instance._formEventID();
    Completer completer = _clientEventQueue[eventId];
    try {
      _methodChannel.invokeMethod('fetchDeviceToken', {
        '_id': eventId,
      });
      Map resp = await completer.future;
      String deviceToken = resp['device_token'];
      return deviceToken;
    } catch (e) {
      Global.debugLog('fetch fetchDeviceToken e'+e.toString());
      completer.completeError(e);
      return '';
    }
  }

  static Future<bool> googleServiceOn() async{
    String eventId = NKNClientCaller.instance._formEventID();
    Completer completer = _clientEventQueue[eventId];
    try {
      _methodChannel.invokeMethod('checkGoogleService', {
        '_id': eventId,
      });
      Map resp = await completer.future;
      bool googleServiceOn = resp['googleServiceOn'];
      print("Resp is E"+resp.toString());
      return googleServiceOn;
    } catch (e) {
      Global.debugLog('fetch googleServiceOn e'+e.toString());
      completer.completeError(e);
    }
    return false;
  }

  static Future<String> fetchFcmToken() async{
    String eventId = NKNClientCaller.instance._formEventID();
    Completer completer = _clientEventQueue[eventId];
    try {
      _methodChannel.invokeMethod('fetchFcmToken', {
        '_id': eventId,
      });
      Map resp = await completer.future;
      String fcmToken = resp['fcm_token'];
      return fcmToken;
    } catch (e) {
      Global.debugLog('fetch fcmToken: e'+e.toString());
      completer.completeError(e);
    }
    return '';
  }

  static Future<String> fetchDebugInfo() async{
    String eventId = NKNClientCaller.instance._formEventID();
    Completer completer = _clientEventQueue[eventId];
    try {
      _methodChannel.invokeMethod('fetchDebugInfo', {
        '_id': eventId,
      });
      Map resp = await completer.future;
      String debugInfo = resp['debugInfo'];
      return debugInfo;
    } catch (e) {
      Global.debugLog('fetch debugInfo E'+e.toString());
      completer.completeError(e);
    }
    return '';
  }

  String _formEventID(){
    Completer<Map> completer = Completer<Map>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;
    completer.future.whenComplete(() {
      _clientEventQueue.remove(eventId);
    });
    return eventId;
  }

  addListening(){
    _eventChannel.receiveBroadcastStream().listen((res) async{
      final String event = res['event'].toString();
      switch (event) {
        case 'createClient':
          String key = res['_id'];
          if (_clientEventQueue[key] != null){
            bool success = res['success'] == 1;
            if (success){
              Global.debugLog('CreateClientSuccess');
              Global.upgradedGroupBlockHeight = true;
              Global.clientCreated = true;
            }
          }
          break;
        case 'onConnect':
          final clientAddr = res['client']['address'];
          Global.debugLog('onConnect With ClientAddress__'+clientAddr);
          clientBloc.add(NKNConnectedClientEvent());
          break;
        case 'onDisConnect':
          final clientAddr = res['client']['address'];
          Global.debugLog('DisConnect Client__'+clientAddr);
          clientBloc.add(NKNDisConnectClientEvent());
          break;
        case 'onMessage':
          Map data = res['data'];
          if (clientBloc != null){
            Global.debugLog('ClientBloc not null__\n'+NKNClientCaller.currentChatId);
          }
          Global.debugLog('onMessage Data'+data.toString());
          try{
            MessageSchema messageInfo = MessageSchema(from: data['src'], to: NKNClientCaller.currentChatId, data: data['data'], pid: data['pid']);
            clientBloc.add(NKNOnMessageEvent(messageInfo));
          }
          catch(e){
            Global.debugLog('NKNOnMessageEvent Exception:'+e.toString());
          }
          break;
        case 'send':
          String key = res['_id'];
          Uint8List pid = res['pid'];
          _clientEventQueue[key].complete(pid);
          break;
        case 'fetchDeviceToken':
          Global.debugLog('fetchDeviceToken callback'+res.toString());
          break;
        case 'checkGoogleService':
          Global.debugLog('checkGoogleService callback'+res.toString());
          break;
        case 'getBlockHeight':
          Global.debugLog('getBlockHeight callback'+res.toString());
          break;
        case 'fetchDebugInfo':
          Global.debugLog('fetchDebugInfo callback'+res.toString());
          break;
        default:
          Map data = res;
          String key = data['_id'];
          var result;
          if (data.containsKey('result')) {
            result = data['result'];
          } else {
            var keys = data.keys.toList();
            keys.remove('_id');
            result = Map<String, dynamic>();
            for (var key in keys) {
              result[key] = data[key];
            }
          }
          if (result != null){
            _clientEventQueue[key].complete(result);
          }
          break;
      }
    }, onError: (err) {
      Global.debugLog('_eventChannel.onError'+err.toString());
      if (_clientEventQueue[err.code] != null) {
        _clientEventQueue[err.code].completeError(err.message);
      }
    });
  }
}

