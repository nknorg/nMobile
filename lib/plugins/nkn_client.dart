import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_event.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/utils/nlog_util.dart';

class NknClientPlugin {
  static const String TAG = 'NknClientPlugin';
  static const String EVENT_CHANNEL_NAME = 'org.nkn.sdk/client/event';
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/client');
  static const EventChannel _eventChannel = EventChannel(EVENT_CHANNEL_NAME);
  static final ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();
  static final CDNBloc _cdnBloc = BlocProvider.of<CDNBloc>(Global.appContext);

  static init() {
    _eventChannel.receiveBroadcastStream().listen((res) {
      String event = res['event'].toString();
      NLog.v('====$event====');
      NLog.v(res);
      switch (event) {
        case 'send':
          String key = res['_id'];
          Uint8List pid = res['pid'];
          _clientEventQueue[key].complete(pid);
          break;
        case 'onMessage':
          Map data = res['data'];
          NLog.v(data, tag: 'NknClientPlugin onMessage --> ClientBloc@${_clientBloc.hashCode.toString().substring(0, 3)}');

          try {
            if (jsonDecode(data['data'])['contentType'].toString() == ContentType.text && jsonDecode(data['data'])['content'].toString().startsWith('```')) {
              Map<String, dynamic> content = jsonDecode(jsonDecode(res['data']['data'])['content'].toString().replaceAll('```', ''));
              onMessageNshell(data['src'], content);
            } else {
              _clientBloc.add(
                OnMessage(
                  MessageSchema(from: data['src'], to: Global.currentClient.address, data: data['data'], pid: data['pid']),
                ),
              );
            }
          } catch (e) {
            NLog.v(e.toString(), tag: TAG);
          }
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
      NLog.e(err);
      if (_clientEventQueue[err.code] != null) {
        _clientEventQueue[err.code].completeError(err.message);
      }
    });
  }

  static Future<bool> isConnected() async {
    try {
      NLog.d('isConnected   ');
      return await _methodChannel.invokeMethod('isConnected');
    } catch (e) {
      NLog.d(e);
      throw e;
    }
  }

  static Future<void> createClient(String identifier, String keystore, String password) async {
    try {
      NLog.d('createClient');
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
      NLog.d('disConnect   ');
      var status = await _methodChannel.invokeMethod('disConnect');
      if (status == 1) {
        NLog.d('disConnect  success ');
      } else {
        NLog.d('disConnect  failed ');
      }
    } catch (e) {
      throw e;
    }
  }

  static Future<Uint8List> sendText(List<String> dests, String data, {int maxHoldingSeconds = 0}) async {
    NLog.d('sendText  $data ');
    NLog.d('sendText  $dests ');
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    try {
      var params = {
        '_id': id,
        'dests': dests,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
      };
      await _methodChannel.invokeMethod('sendText', params);
    } catch (e) {
      NLog.e(e);
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
    NLog.d('_id  $id   topic  $topic  data $data');
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
    NLog.v('subscribe', tag: TAG);
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
      NLog.d('subscribe  $data');
      _methodChannel.invokeMethod('subscribe', data);
    } catch (e) {
      NLog.d(e);
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
    NLog.d('unsubscribe');
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
      NLog.e(v);
    }

    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<int> getSubscribersCount(String topic) async {
    NLog.d('getSubscribersCount');
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
    NLog.d('getSubscription    $topic $subscriber');
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
    NLog.d('$topic');
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
    NLog.d('getSubscribers');
    NLog.d('$topicHash  $offset $limit $meta $txPool');
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

  static onMessageNshell(String src, content) async {
    NLog.v(content['Result']);
    NLog.v(content['Type']);
    NLog.v(src);
    var type = content['Type'];
    try {
      if (type != null && type.toString().contains('self_checker.sh')) {
        var cdn = await CdnMiner.getModelFromNshid(src);
        if (cdn != null) {
          cdn.data = content;
          await cdn.insertOrUpdate();
          NLog.v('onMessage add');
          _cdnBloc.add(LoadData(data: cdn));
        }
      }
    } catch (e) {
      NLog.v(e.toString(), tag: TAG + 'onMessage');
    }
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
      NLog.w('----- topic null -------');
      return {};
    }
    Map<String, dynamic> subscribers = await SubscribersSchema.getSubscribersByTopic(topic);
    if (subscribers != null && subscribers.length > 0) {
      NLog.d('$topic  getSubscribers use cache');
      NLog.d(subscribers);
      return subscribers;
    } else {
      return getSubscribersAction(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
    }
  }
}
