import 'dart:async';
import 'dart:typed_data';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/subscribers.dart';

class NknClientPlugin {
  static const String TAG = 'NknClientPlugin';
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/client');
  static const EventChannel _eventChannel = EventChannel('org.nkn.sdk/client/event');
  static final ClientBloc _clientBloc = BlocProvider.of(Global.appContext);
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();

  static init() {
    _eventChannel.receiveBroadcastStream().listen((res) {
      String event = res['event'].toString();
      LogUtil.v('====$event====', tag: TAG);
      LogUtil.v(res, tag: TAG);
      switch (event) {
        case 'send':
          String key = res['_id'];
          Uint8List pid = res['pid'];
          _clientEventQueue[key].complete(pid);
          break;
        case 'onMessage':
          Map data = res['data'];
          LogUtil.v(data, tag: 'NknClientPlugin onMessage');
          _clientBloc.add(
            OnMessage(
              // FIXME: wei.chou on 16/06/2020
              // `to` The value of the field is very problematic,
              // there will be problems with hot switching of multiple wallets.
              MessageSchema(from: data['src'], to: Global.currentClient.address, data: data['data'], pid: data['pid']),
            ),
          );
          break;
        case 'onConnect':
          Map node = res['node'];
          Map client = res['client'];
          _clientBloc.add(ConnectedClient());
          _clientBloc.add(
            OnConnect(
              ClientSchema(
                nodeInfo: NodeInfoSchema(address: node['address'], publicKey: node['publicKey']),
                address: client['address'],
                publicKey: getPublicKeyByClientAddr(client['address']),
              ),
            ),
          );
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
          _clientEventQueue[key].complete(result);
          break;
      }
    }, onError: (err) {
      LogUtil.e(err, tag: 'ClientEventChannel');
      if (_clientEventQueue[err.code] != null) {
        _clientEventQueue[err.code].completeError(err.message);
      }
    });
  }

  static Future<bool> isConnected() async {
    try {
      LogUtil.v('isConnected   ', tag: TAG);
      return await _methodChannel.invokeMethod('isConnected');
    } catch (e) {
      throw e;
    }
  }

  static Future<void> createClient(String identifier, String keystore, String password) async {
    try {
      LogUtil.v('createClient   ', tag: TAG);
      await _methodChannel.invokeMethod('createClient', {
        'identifier': identifier,
        'keystore': keystore,
        'password': password,
      });
    } catch (e) {
      throw e;
    }
  }

  static Future<void> disConnect() async {
    try {
      LogUtil.v('disConnect   ', tag: TAG);
      var status = await _methodChannel.invokeMethod('disConnect');
      if (status == 1) {
        LogUtil.v('disConnect  success ', tag: TAG);
      } else {
        LogUtil.v('disConnect  failed ', tag: TAG);
      }
    } catch (e) {
      throw e;
    }
  }

  static Future<Uint8List> sendText(List<String> dests, String data) async {
    LogUtil.v('sendText  $data ', tag: TAG);
    LogUtil.v('sendText  $dests ', tag: TAG);
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    try {
      await _methodChannel.invokeMethod('sendText', {
        '_id': id,
        'dests': dests,
        'data': data,
      });
    } catch (e) {
      LogUtil.v('send fault');
      throw e;
    }
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Uint8List> publish(String topic, String data) async {
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    LogUtil.v('publish   ', tag: TAG);
    LogUtil.v('_id  $id   topic  $topic  data $data', tag: TAG);
    LogUtil.v('publish   ', tag: TAG);
    try {
      await _methodChannel.invokeMethod('publish', {
        '_id': id,
        'topic': topic,
        'data': data,
      });
    } catch (e) {
      throw e;
    }

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<String> subscribe({
    String identifier = '',
    String topic,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) async {
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    try {
      var data = {
        '_id': id,
        'identifier': identifier,
        'topic': topic,
        'duration': duration,
        'fee': fee,
        'meta': meta,
      };
      LogUtil.v('subscribe  $data', tag: TAG);
      _methodChannel.invokeMethod('subscribe', data);
    } catch (e) {
      LogUtil.v('subscribe fault');
    }
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<String> unsubscribe({
    String identifier = '',
    String topic,
    String fee = '0',
  }) async {
    LogUtil.v('unsubscribe', tag: TAG);
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    try {
      _methodChannel.invokeMethod('unsubscribe', {
        '_id': id,
        'identifier': identifier,
        'topic': topic,
        'fee': fee,
      });
    } catch (v) {
      LogUtil.v('unsubscribe fault');
    }

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<int> getSubscribersCount(String topic) async {
    LogUtil.v('getSubscribersCount', tag: TAG);
    Completer<int> completer = Completer<int>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscribersCount', {
      '_id': id,
      'topic': topic,
    });

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Map<String, dynamic>> getSubscription({
    String topic,
    String subscriber,
  }) async {
    LogUtil.v('getSubscription    $topic $subscriber', tag: TAG);
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscription', {
      '_id': id,
      'topic': topic,
      'subscriber': subscriber,
    });

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Map<String, dynamic>> getSubscribersAction({
    String topic,
    String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) async {
    LogUtil.v('$topic  getSubscribers 没有缓存');
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    LogUtil.v('getSubscribers   $topicHash  $offset $limit $meta $txPool', tag: TAG);
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('getSubscribers', {
      '_id': id,
      'topic': topicHash,
      'offset': offset,
      'limit': limit,
      'meta': meta,
      'txPool': txPool,
    });

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<Map<String, dynamic>> getSubscribers({
    String topic,
    String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) async {
    if (topic == null || topicHash == null) {
      LogUtil.v('----- topic null -------');
      return {};
    }

    if (!Global.isLoadSubscribers(topic)) {
      Map<String, dynamic> subscribers = await SubscribersSchema.getSubscribersByTopic(topic);
      if (subscribers != null && subscribers.length > 0) {
        LogUtil.v('$topic  getSubscribers 使用缓存');
        getSubscribersAction(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
        return subscribers;
      }
    }
    return getSubscribersAction(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
  }
}
