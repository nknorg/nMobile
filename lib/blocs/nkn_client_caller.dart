/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flustars/flustars.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/nlog_util.dart';

class NKNClientCaller {
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
  _initChannel() {
    _methodChannel = MethodChannel(METHOD_CHANNEL_NAME);
    _eventChannel = EventChannel(EVENT_CHANNEL_NAME);
  }

  static NKNClientBloc clientBloc;
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();

  // static Map<String, Map> _clientEventData = Map<String, Map>();

  createClient(Uint8List seed, String identifier, String clientAddress) {
    Completer<String> completer = Completer<String>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    String saveKey =
        LocalStorage.NKN_RPC_NODE_LIST + '_' + clientAddress.toString();
    String rpcNodeListString = SpUtil.getString(saveKey);

    if (rpcNodeListString == null) {
      rpcNodeListString = '';
    } else {
      if (rpcNodeListString.length > 0) {
        if (rpcNodeListString.substring(0, 1) == ',') {
          rpcNodeListString = rpcNodeListString.substring(1);
        }
        rpcNodeListString = rpcNodeListString + ',http://seed.nkn.org:30003';
      } else {
        rpcNodeListString = 'http://seed.nkn.org:30003';
      }
    }
    NLog.w('rpcNodeListString is_____' + rpcNodeListString.toString());

    NLog.w('CreateClient Called');
    try {
      _methodChannel.invokeMethod('createClient', {
        '_id': eventId,
        'identifier': identifier,
        'seedBytes': seed,
        'rpcNodeList': rpcNodeListString,
      });
    } catch (e) {
      NLog.w('createClient E:' + e.toString());
      completer.completeError(e);
    }
  }

  // static String pubKey = '';
  static String currentChatId = '';

  setChatId(String chatId) {
    // NKNClientCaller.pubKey = pubKey;
    NKNClientCaller.currentChatId = chatId;
  }

  static connectNKN() {
    print('methodCalled+connectNKN');
    _methodChannel.invokeMethod('connect');
  }

  static Future<void> disConnect() async {
    _methodChannel.invokeMethod('disConnect');
  }

  static Future<Uint8List> sendText(
      List<String> dests, String data, String messageId) async {
    Completer<Uint8List> completer = Completer<Uint8List>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    Map sendData = {
      '_id': eventId,
      'dests': dests,
      'data': data,
      'maxHoldingSeconds': -1,
      'msgId': messageId,
    };
    // _clientEventData[eventId] = sendData;

    try {
      _methodChannel.invokeMethod('sendText', sendData);
    } catch (e) {
      NLog.w('sendText completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<List> intoPieces(
      String dataBytesString, int dataShards, int parityShards) async {
    Completer<List> completer = Completer<List>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    NLog.w('B eventId is___' + eventId.toString());
    Map sendData = {
      '_id': eventId,
      'data': dataBytesString,
      'dataShards': dataShards,
      'parityShards': parityShards,
    };
    // _clientEventData[eventId] = sendData;

    try {
      _methodChannel.invokeMethod('intoPieces', sendData);
    } catch (e) {
      NLog.w('intoPieces completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> combinePieces(
      List dataList, int dataShards, int parityShards, int bytesLength) async {
    Completer<String> completer = Completer<String>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    Map sendData = {
      '_id': eventId,
      'data': dataList,
      'dataShards': dataShards,
      'parityShards': parityShards,
      'bytesLength': bytesLength,
    };
    // _clientEventData[eventId] = sendData;

    try {
      _methodChannel.invokeMethod('combinePieces', sendData);
    } catch (e) {
      NLog.w('combinePieces completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  /// GroupChat sendText
  static Future<Uint8List> publishText(String topicHash, String data) async {
    Completer<Uint8List> completer = Completer<Uint8List>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    Map publishData = {
      '_id': eventId,
      'topicHash': topicHash,
      'data': data,
      'maxHoldingSeconds': -1,
    };
    // _clientEventData[eventId] = publishData;
    try {
      _methodChannel.invokeMethod('publishText', publishData);
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

    Map dataInfo = {
      '_id': id,
      'identifier': identifier,
      'topicHash': topicHash,
      'duration': duration,
      'fee': fee,
      'meta': meta,
    };
    try {
      _methodChannel.invokeMethod('subscribe', dataInfo);
    } catch (e) {
      NLog.w('subscribe completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> unsubscribe(
      {String identifier = '', String topicHash, String fee = '0'}) async {
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;

    Map dataInfo = {
      '_id': id,
      'identifier': identifier,
      'topicHash': topicHash,
      'fee': fee,
    };
    try {
      _methodChannel.invokeMethod('unsubscribe', dataInfo);
    } catch (e) {
      NLog.w('unsubscribe completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<int> getSubscribersCount(String topicHash) async {
    Completer<int> completer = Completer<int>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;

    Map dataInfo = {
      '_id': id,
      'topicHash': topicHash,
    };
    try {
      _methodChannel.invokeMethod('getSubscribersCount', dataInfo);
    } catch (e) {
      NLog.w('getSubscribersCount completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<Map> getSubscription(
      {String topicHash, String subscriber}) async {
    Completer<Map> completer =
        Completer<Map>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;

    Map dataInfo = {
      '_id': id,
      'topicHash': topicHash,
      'subscriber': subscriber,
    };

    try {
      _methodChannel.invokeListMethod('getSubscription', dataInfo);
    } catch (e) {
      NLog.w('getSubscription completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<Map<String, dynamic>> getSubscribers({
    String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) async {
    Completer<Map<String, dynamic>> completer =
        Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    Map dataInfo = {
      '_id': id,
      'topicHash': topicHash,
      'offset': offset,
      'limit': limit,
      'meta': meta,
      'txPool': txPool,
    };
    try {
      _methodChannel.invokeMethod('getSubscribers', dataInfo);
    } catch (e) {
      NLog.w('getSubscribers completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<int> fetchBlockHeight() async {
    Completer<int> completer = Completer<int>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;
    Map dataInfo = {
      '_id': eventId,
    };
    try {
      _methodChannel.invokeMethod('getBlockHeight', dataInfo);
    } catch (e) {
      NLog.w('fetchBlockHeight complete E:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> fetchDeviceToken() async {
    Completer<String> completer = Completer<String>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;
    Map dataInfo = {
      '_id': eventId,
    };
    try {
      _methodChannel.invokeMethod('fetchDeviceToken', dataInfo);
    } catch (e) {
      NLog.w('fetchDeviceToken E:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<bool> googleServiceOn() async {
    Completer<bool> completer = Completer<bool>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    Map dataInfo = {
      '_id': eventId,
    };
    try {
      _methodChannel.invokeMethod('checkGoogleService', dataInfo);
    } catch (e) {
      NLog.w('googleServiceOn completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> fetchFcmToken() async {
    Completer<String> completer = Completer<String>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;
    Map dataInfo = {
      '_id': eventId,
    };
    try {
      _methodChannel.invokeMethod('fetchFcmToken', dataInfo);
    } catch (e) {
      NLog.w('fetchFcmToken completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> fetchDebugInfo() async {
    Completer<String> completer = Completer<String>();
    String eventId = completer.hashCode.toString();
    _clientEventQueue[eventId] = completer;

    Map dataInfo = {
      '_id': eventId,
    };
    try {
      _methodChannel.invokeMethod('fetchDebugInfo', dataInfo);
    } catch (e) {
      NLog.w('fetchDebugInfo completeE:' + e.toString());
      completer.completeError(e);
    }
    return completer.future;
  }

  addListening() {
    _eventChannel.receiveBroadcastStream().listen((res) async {
      final String event = res['event'].toString();
      String eventKey = res['_id'];

      switch (event) {
        case 'createClient':
          String key = res['_id'];
          NLog.w('CreateClient Success___' + res.toString());
          if (_clientEventQueue[key] != null) {
            bool success = res['success'] == 1;
            if (success) {
              Global.upgradedGroupBlockHeight = true;
              Global.clientCreated = true;
            }
          }
          break;
        case 'onSaveNodeAddresses':
          String rpcNodeAddress = res['client']['nodeAddress'];
          String clientAddress = res['client']['clientAddress'];
          print('onSaveNodeAddresses is __' + rpcNodeAddress.toString());

          String saveKey =
              LocalStorage.NKN_RPC_NODE_LIST + '_' + clientAddress.toString();
          String savedRpcNodeList = SpUtil.getString(saveKey);

          if (savedRpcNodeList != null) {
            List savedList = List();
            if (savedRpcNodeList.length > 0) {
              savedList = savedRpcNodeList.split(',');
            }
            if (savedList.length > 10) {
              if (savedList.length > 10) {
                savedList.removeRange(0, savedList.length - 10);
              }
            }
            List savingList = rpcNodeAddress.split(',');
            for (int i = 0; i < savingList.length; i++) {
              String savingNode = savingList[i];
              if (savingNode != null && savingNode.length > 0) {
                if (!savedList.contains(savingList[i])) {
                  if (savingList.length > 0) {
                    savedList.add(savingList[i]);
                  }
                } else {
                  NLog.w('duplicate saved Node__' + savingNode.toString());
                }
              }
            }
            NLog.w('savedList count is____' + savedList.length.toString());
            rpcNodeAddress = savedList.join(',');
          }

          if (rpcNodeAddress != null) {
            NLog.w('rpcNodeList save is__' + rpcNodeAddress);
            SpUtil.putString(saveKey, rpcNodeAddress);
          }
          break;
        case 'onConnect':
          final clientAddr = res['client']['address'];
          clientBloc.add(NKNConnectedClientEvent());
          break;
        case 'disConnect':
          NLog.w('disConnect Native to dart___' + res.toString());
          break;
        case 'onMessage':
          Map data = res['data'];
          if (clientBloc != null) {
            NLog.w('ClientBloc not null__\n' + NKNClientCaller.currentChatId);
          }
          try {
            MessageSchema messageInfo = MessageSchema(
                from: data['src'],
                to: NKNClientCaller.currentChatId,
                data: data['data'],
                pid: data['pid']);
            if (data['data'] != null) {
              NLog.w('onMessage Data' + data.toString());
            }
            if (data['src'] != null && data['pid'] != null) {
              if (NKNClientCaller.currentChatId != null) {
                NLog.w('currentChatId is__' +
                    NKNClientCaller.currentChatId +
                    '\nfrom__' +
                    data['src'].toString() +
                    '\npid__' +
                    data['pid'].toString());
              } else {
                NLog.w('currentChatId is null');
              }
            } else {
              NLog.w('src or pid is null');
            }
            clientBloc.add(NKNOnMessageEvent(messageInfo));
          } catch (e) {
            NLog.w('NKNOnMessageEvent Exception:' + e.toString());
          }
          break;

        case 'sendText':
          Uint8List pid = res['pid'];
          _clientEventQueue[eventKey].complete(pid);
          break;
        case 'publishText':
          NLog.w('publishText Success!!!!' + res.toString());
          Uint8List pid = res['pid'];
          _clientEventQueue[eventKey].complete(pid);
          break;

        case 'subscribe':
          String result = res['data'];
          NLog.w('subscribe result is__' + result.toString());
          _clientEventQueue[eventKey].complete(result);
          break;
        case 'unsubscribe':
          String result = res['data'];
          _clientEventQueue[eventKey].complete(result);
          break;

        case 'getSubscribersCount':
          int count = res['data'];
          _clientEventQueue[eventKey].complete(count);
          break;
        case 'getSubscription':
          Map dataInfo = res['data'];

          // Map result = Map<String, dynamic>();
          // // result['expiresAt'] = res['expiresAt'];
          NLog.w('getSubscription is____'+res.toString());
          NLog.w('GetSubscription Res is___'+dataInfo.runtimeType.toString());
          NLog.w('GetSubscription dataInfo is___'+dataInfo.toString());

          _clientEventQueue[eventKey].complete(dataInfo);
          break;

        case 'getSubscribers':
          Map dataMap = res['data'];
          Map subscriberMap = new Map<String, dynamic>();
          for (String key in dataMap.keys) {
            subscriberMap[key] = '1';
          }
          _clientEventQueue[eventKey].complete(subscriberMap);
          break;

        case 'getBlockHeight':
          int blockHeight = res['height'];
          _clientEventQueue[eventKey].complete(blockHeight);
          break;

        case 'fetchDeviceToken':
          String deviceToken = res['device_token'];
          _clientEventQueue[eventKey].complete(deviceToken);
          break;

        /// AndroidCheck
        case 'checkGoogleService':
          bool googleServiceOn = res['googleServiceOn'];
          _clientEventQueue[eventKey].complete(googleServiceOn);
          break;

        /// iOS fetch to Match Android FCM
        case 'fetchFcmToken':
          String fcmToken = res['fcm_token'];
          _clientEventQueue[eventKey].complete(fcmToken);
          break;
        case 'intoPieces':
          List dataList = res['data'];
          _clientEventQueue[eventKey].complete(dataList);
          break;
        case 'combinePieces':
          NLog.w('combinePieces is_____' + res.toString());
          String recoverString = res['data'];
          NLog.w(
              'recoverString length is____' + recoverString.length.toString());

          _clientEventQueue[eventKey].complete(recoverString);
          break;
        case 'fetchDebugInfo':
          NLog.w('debugInfo is__' + res.toString());
          break;

        default:
          NLog.w('Missed kind___' + res.toString());
          break;
      }
      _removeEventIdByKey(eventKey);
    }, onError: (err) {
      String errMsg = err.message.toString();
      String errDetail = err.details.toString();
      String errCode = err.code.toString();
      if (errMsg.length > 0) {
        // if (errMsg == 'sendText' || errMsg == 'publishText') {
        //   // Map info = _clientEventData[errCode];
        //   // if (info != null) {
        //   //   _clientEventQueue[errCode].completeError(errMsg);
        //   // }
        // } else
        if (errMsg == 'subscribe' || errMsg == 'unsubscribe') {
          _clientEventQueue[errCode].completeError(errDetail);
          _removeEventIdByKey(errCode);
          return;
        } else {
          NLog.w('Wrong!!! E:event__' + errMsg.toString());
          NLog.w('Wrong!!! E:detail__' + errDetail.toString());
        }
      }
      _clientEventQueue[errCode].completeError(errMsg);
      _removeEventIdByKey(errCode);
    });
  }

  _removeEventIdByKey(String key) {
    // if (_clientEventData.containsKey(key)) {
    //   _clientEventData.remove(key);
    // }
    if (_clientEventQueue.containsKey(key)) {
      _clientEventQueue.remove(key);
    }
  }
}
