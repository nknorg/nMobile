// /*
//  * Copyright (C) NKN Labs, Inc. - All Rights Reserved
//  * Unauthorized copying of this file, via any medium is strictly prohibited
//  * Proprietary and confidential
//  */
//
// import 'dart:async';
// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:nmobile/helpers/global.dart';
// import 'package:nmobile/helpers/hash.dart';
// import 'package:nmobile/helpers/utils.dart';
// import 'package:nmobile/utils/log_tag.dart';
//
// /// @author Chenai
// /// @version 1.0, 09/07/2020
// abstract class ClientEventDispatcher {
//   void onConnect(String myChatId);
//
//   /// Feedback due to exception triggering by `client` and inactive call.
//   void onDisConnect(String myChatId);
//
//   void onMessage(String myChatId, Map data);
// }
//
// class NknClientProxyddd with Tag {
//   final Uint8List _seed;
//   final String pubkey;
//   final String identifier;
//   final String clientUrl;
//   final ClientEventDispatcher _clientEvent;
//   final bool autoStartReceiveMessagesOnConnected;
//
//   NknClientProxyddd(
//     this._seed,
//     this.pubkey,
//     this._clientEvent, {
//     this.identifier,
//     this.clientUrl,
//     this.autoStartReceiveMessagesOnConnected = true,
//   })  : assert(_seed != null),
//         assert(pubkey != null),
//         assert(_clientEvent != null) {
//     assert(identifier == null || identifier.trim().isNotEmpty);
//   }
//
//   String get myChatId => identifier == null ? pubkey : '$identifier.$pubkey';
//
//   String get dbCipherPassphrase => isSeedMocked ? throw "db cipher invalid." : hexEncode(sha256(hexEncode(_seed.toList(growable: false))));
//
//   bool get isSeedMocked => _seed.isEmpty;
//
//   bool _isConnected = false;
//   bool _clientCreated = false;
//
//   void createNKNClient() {
//     Global.debugLog('createNKNClient');
//     _createClient();
//   }
//
//   void nknConnect(){
//     _NknClientPlugin.nknConnect();
//   }
//
//   void disConnect() {
//     Global.debugLog('nkn_client disConnect');
//     _NknClientPlugin.disConnect();
//     onDisConnect();
//     _isConnected = false;
//   }
//
//   Future<Uint8List> sendText(List<String> dests, String data, {int maxHoldingSeconds = Duration.secondsPerDay * 30}) async{
//     assert(_isConnected);
//     return _NknClientPlugin.sendText(dests, data, maxHoldingSeconds: maxHoldingSeconds);
//   }
//
//   Future<Uint8List> publishText(String topicHash, String data, {int maxHoldingSeconds = Duration.secondsPerDay * 30}) {
//     assert(_isConnected);
//     return _NknClientPlugin.publishText(topicHash, data, maxHoldingSeconds: maxHoldingSeconds);
//   }
//
//   Future<String> fetchDeviceToken() async{
//     try {
//       final String deviceToken = await _NknClientPlugin.fetchDeviceToken();
//       return deviceToken;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   Future <bool> getGoogleService() async{
//     try {
//       final bool googleServiceOn = await _NknClientPlugin.googleServiceOn();
//       return googleServiceOn;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   Future <String> fetchDebugInfo() async{
//     try {
//       final String debugInfoString = await _NknClientPlugin.fetchDebugInfo();
//       return debugInfoString;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   Future<String> fetchFCMToken() async{
//     try {
//       final String deviceToken = await _NknClientPlugin.fetchFcmToken();
//       return deviceToken;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // Future<int> getBlockHeight() async{
//   //   try {
//   //     final int blockHeight = await _NknClientPlugin.fetchBlockHeight();
//   //     return blockHeight;
//   //   } catch (e) {
//   //     return null;
//   //   }
//   // }
//
//   Future<String> subscribe({
//     String identifier = '',
//     @required String topicHash,
//     int duration = 400000,
//     String fee = '0',
//     String meta = '',
//   }) {
//     assert(_clientCreated);
//     return _NknClientPlugin.subscribe(
//       identifier: identifier,
//       topicHash: topicHash,
//       duration: duration,
//       fee: fee,
//       meta: meta,
//     );
//   }
//
//   Future<String> unsubscribe({String identifier = '', @required String topicHash, String fee = '0'}) {
//     assert(_clientCreated);
//     return _NknClientPlugin.unsubscribe(identifier: identifier, topicHash: topicHash, fee: fee);
//   }
//
//   Future<int> getSubscribersCount(String topicHash) {
//     assert(_clientCreated);
//     return _NknClientPlugin.getSubscribersCount(topicHash);
//   }
//
//   Future<Map<String, dynamic>> getSubscribers({
//     @required String topicHash,
//     int offset = 0,
//     int limit = 10000,
//     bool meta = true,
//     bool txPool = true,
//   }) {
//     assert(_clientCreated);
//     return _NknClientPlugin.getSubscribers(
//       topicHash: topicHash,
//       offset: offset,
//       limit: limit,
//       meta: meta,
//       txPool: txPool,
//     );
//   }
//
//   Future<Map<String, dynamic>> getSubscription({@required String topicHash, @required String subscriber}) {
//     assert(_clientCreated);
//     return _NknClientPlugin.getSubscription(topicHash: topicHash, subscriber: subscriber);
//   }
//
//   void onConnect(String clientAddr) {
//     print('onConnect Back'+clientAddr+'__'+myChatId);
//     assert(clientAddr == myChatId);
//     _isConnected = true;
//     _clientCreated = true;
//
//     print('onConnect Back');
//
//     _clientEvent.onConnect(myChatId);
//   }
//
//   void backOn(){
//     _NknClientPlugin.backOn();
//   }
//
//   void backOff(){
//     _NknClientPlugin.backOff();
//   }
//
//   void onDisConnect() {
//     _clientCreated = false;
//     final asyncCall = () async {
//       _clientEvent.onDisConnect(myChatId);
//     };
//     asyncCall();
//   }
//
//   void onMessage(Map data) async {
//     _clientEvent.onMessage(myChatId, data);
//   }
//
//   void _createClient() async {
//     // await _NknClientPlugin.registerProxy(this);
//     if (_clientCreated) {
//       _NknClientPlugin.nknConnect();
//     }
//     else{
//       _NknClientPlugin.createClient(_seed, identifier: identifier, clientUrl: clientUrl).then((value) {
//         print('Flutter Client Created');
//         _clientCreated = true;
//       });
//     }
//   }
// }
//
// class _NknClientPlugin {
//
//   static const String METHOD_CHANNEL_NAME = 'org.nkn.sdk/client';
//   static const String EVENT_CHANNEL_NAME = 'org.nkn.sdk/client/event';
//   static const MethodChannel _methodChannel = MethodChannel(METHOD_CHANNEL_NAME);
//   static const EventChannel _eventChannel = EventChannel(EVENT_CHANNEL_NAME);
//
//   static Map<String, Completer> _clientEventQueue = Map<String, Completer>();
//   // static NknClientProxy _clientProxy;
//   static bool _inited = false;
//
//   // static Future<void> registerProxy(NknClientProxy client) async {
//   //   ensureInited();
//   //   if (_clientProxy == client) {
//   //     // nothing...
//   //   } else {
//   //     final prevClient = _clientProxy;
//   //     _clientProxy = client;
//   //
//   //     if (prevClient?.myChatId != client.myChatId) {
//   //       final asyncCall = () async {
//   //         prevClient?.onDisConnect();
//   //       };
//   //       asyncCall();
//   //     }
//   //   }
//   // }
//
//   static ensureInited() {
//     if (!_inited) {
//       _init();
//       _inited = true;
//     }
//   }
//
//   static _init() {
//     return;
//     // _eventChannel.receiveBroadcastStream().listen((res) {
//     //
//     //   final String event = res['event'].toString();
//     //   Global.debugLog('xxxaddListening Receive event: $event');
//     //   switch (event) {
//     //     case 'createClient':
//     //       String key = res['_id'];
//     //       bool success = res['success'] == 1;
//     //       _clientEventQueue[key].complete(success);
//     //       break;
//     //     case 'onConnect':
//     //       final clientAddr = res['client']['address'];
//     //       if (_clientProxy.myChatId == clientAddr) {
//     //         Map node = res['node']; // NodeInfoSchema(address: node['address'], publicKey: node['publicKey'])
//     //         Global.debugLog('onConnect NodeAddress'+node['address'].toString()+'NodePubKey'+node['publicKey'].toString());
//     //         _clientProxy.onConnect(clientAddr);
//     //       }
//     //       break;
//     //     case 'onDisConnect':
//     //       final clientAddr = res['client']['address'];
//     //       if (_clientProxy.myChatId == clientAddr) {
//     //         _clientProxy.onDisConnect();
//     //       }
//     //       break;
//     //     case 'onMessage':
//     //       final clientAddr = res['client']['address'];
//     //       if (_clientProxy.myChatId == clientAddr) {
//     //         _clientProxy.onMessage(res['data']);
//     //       }
//     //       break;
//     //     case 'send':
//     //       String key = res['_id'];
//     //       Uint8List pid = res['pid'];
//     //       _clientEventQueue[key].complete(pid);
//     //       break;
//     //     case 'fetchDeviceToken':
//     //       String key = res['_id'];
//     //       _clientEventQueue[key].complete(true);
//     //       break;
//     //     case 'checkGoogleService':
//     //       String key = res['_id'];
//     //       _clientEventQueue[key].complete(true);
//     //       break;
//     //     case 'getBlockHeight':
//     //       String key = res['_id'];
//     //       Uint8List pid = res['height'];
//     //       _clientEventQueue[key].complete(pid);
//     //       break;
//     //     case 'fetchDebugInfo':
//     //       String key = res['_id'];
//     //       _clientEventQueue[key].complete(true);
//     //       break;
//     //     default:
//     //       Map data = res;
//     //       String key = data['_id'];
//     //       var result;
//     //       if (data.containsKey('result')) {
//     //         result = data['result'];
//     //       } else {
//     //         var keys = data.keys.toList();
//     //         keys.remove('_id');
//     //         result = Map<String, dynamic>();
//     //         for (var key in keys) {
//     //           result[key] = data[key];
//     //         }
//     //       }
//     //       _clientEventQueue[key].complete(result);
//     //       break;
//     //   }
//     // }, onError: (err) {
//     //   if (_clientEventQueue[err.code] != null) {
//     //     _clientEventQueue[err.code].completeError(err.message);
//     //   }
//     // });
//   }
//
//   // static Future<int> fetchBlockHeight() async{
//   //   Completer<Map> completer = Completer<Map>();
//   //   String id = completer.hashCode.toString();
//   //   _clientEventQueue[id] = completer;
//   //   completer.future.whenComplete(() {
//   //     _clientEventQueue.remove(id);
//   //   });
//   //   try {
//   //     _methodChannel.invokeMethod('getBlockHeight', {
//   //       '_id': id,
//   //     });
//   //     Map resp = await completer.future;
//   //     int blockHeight = resp['height'];
//   //     return blockHeight;
//   //   } catch (e) {
//   //     completer.completeError(e);
//   //   }
//   // }
//
//   static Future<String> fetchDeviceToken() async{
//     Completer<Map> completer = Completer<Map>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('fetchDeviceToken', {
//         '_id': id,
//       });
//       Map resp = await completer.future;
//       String deviceToken = resp['device_token'];
//       return deviceToken;
//     } catch (e) {
//       completer.completeError(e);
//     }
//   }
//
//   static Future<bool> googleServiceOn() async{
//     Completer<Map> completer = Completer<Map>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('checkGoogleService', {
//         '_id': id,
//       });
//       Map resp = await completer.future;
//       bool googleServiceOn = resp['googleServiceOn'];
//       print("Resp is E"+resp.toString());
//       return googleServiceOn;
//     } catch (e) {
//       completer.completeError(e);
//     }
//   }
//
//   static Future<String> fetchFcmToken() async{
//     Completer<Map> completer = Completer<Map>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('fetchFcmToken', {
//         '_id': id,
//       });
//       Map resp = await completer.future;
//       String fcmToken = resp['fcm_token'];
//       return fcmToken;
//     } catch (e) {
//       completer.completeError(e);
//     }
//   }
//
//   static Future<String> fetchDebugInfo() async{
//     Completer<Map> completer = Completer<Map>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('fetchDebugInfo', {
//         '_id': id,
//       });
//       Map resp = await completer.future;
//       String debugInfo = resp['debugInfo'];
//       return debugInfo;
//     } catch (e) {
//       completer.completeError(e);
//     }
//   }
//
//   static Future<bool> createClient(Uint8List seed, {String identifier, String clientUrl}) async {
//     Completer<bool> completer = Completer<bool>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       await _methodChannel.invokeMethod('createClient', {
//         '_id': id,
//         'identifier': identifier,
//         'seedBytes': seed,
//         'clientUrl': clientUrl,
//       });
//     } catch (e) {
//       completer.completeError(e);
//     }
//     return completer.future;
//   }
//
//   static Future<void> nknConnect() async {
//     _methodChannel.invokeMethod('connect');
//   }
//
//   // static Future<void> startReceiveMessages() async {
//   //   _LOG.i('startReceiveMessages');
//   //   await _methodChannel.invokeMethod('startReceiveMessages');
//   // }
//
//   static Future<void> backOn() async {
//     _methodChannel.invokeMethod('backOn');
//   }
//
//   static Future<void> backOff() async {
//     _methodChannel.invokeMethod('backOff');
//   }
//
//   static Future<void> disConnect() async {
//     _methodChannel.invokeMethod('disConnect');
//   }
//
//   static Future<Uint8List> sendText(List<String> dests, String data, {int maxHoldingSeconds = -1}) async {
//     Completer<Uint8List> completer = Completer<Uint8List>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('sendText', {
//         '_id': id,
//         'dests': dests,
//         'data': data,
//         'maxHoldingSeconds': maxHoldingSeconds,
//       });
//     } catch (e) {
//       completer.completeError(e);
//     }
//     return completer.future;
//   }
//
//   static Future<Uint8List> publishText(String topicHash, String data, {int maxHoldingSeconds = -1}) async {
//     Completer<Uint8List> completer = Completer<Uint8List>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//     try {
//       _methodChannel.invokeMethod('publishText', {
//         '_id': id,
//         'topicHash': topicHash,
//         'data': data,
//         'maxHoldingSeconds': maxHoldingSeconds,
//       });
//     } catch (e) {
//       completer.completeError(e);
//     }
//     return completer.future;
//   }
//
//   static Future<String> subscribe({
//     String identifier = '',
//     String topicHash,
//     int duration = 400000,
//     String fee = '0',
//     String meta = '',
//   }) async {
//     Completer<String> completer = Completer<String>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     _methodChannel.invokeMethod('subscribe', {
//       '_id': id,
//       'identifier': identifier,
//       'topicHash': topicHash,
//       'duration': duration,
//       'fee': fee,
//       'meta': meta,
//     });
//     return completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//   }
//
//   static Future<String> unsubscribe({String identifier = '', String topicHash, String fee = '0'}) async {
//     Completer<String> completer = Completer<String>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     _methodChannel.invokeMethod('unsubscribe', {
//       '_id': id,
//       'identifier': identifier,
//       'topicHash': topicHash,
//       'fee': fee,
//     });
//     return completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//   }
//
//   static Future<int> getSubscribersCount(String topicHash) async {
//     Completer<int> completer = Completer<int>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     _methodChannel.invokeMethod('getSubscribersCount', {
//       '_id': id,
//       'topicHash': topicHash,
//     });
//     return completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//   }
//
//   static Future<Map<String, dynamic>> getSubscription({String topicHash, String subscriber}) async {
//     Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     _methodChannel.invokeMethod('getSubscription', {
//       '_id': id,
//       'topicHash': topicHash,
//       'subscriber': subscriber,
//     });
//
//     return completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//   }
//
//   static Future<Map<String, dynamic>> getSubscribers({
//     String topicHash,
//     int offset = 0,
//     int limit = 10000,
//     bool meta = true,
//     bool txPool = true,
//   }) async {
//     Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
//     String id = completer.hashCode.toString();
//     _clientEventQueue[id] = completer;
//     _methodChannel.invokeMethod('getSubscribers', {
//       '_id': id,
//       'topicHash': topicHash,
//       'offset': offset,
//       'limit': limit,
//       'meta': meta,
//       'txPool': txPool,
//     });
//
//     return completer.future.whenComplete(() {
//       _clientEventQueue.remove(id);
//     });
//   }
// }
