/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/pure_retry.dart';

/// @author Chenai
/// @version 1.0, 09/07/2020
abstract class ClientEventDispatcher {
  void onConnect(String myChatId);

  /// Feedback due to exception triggering by `client` and inactive call.
  void onDisConnect(String myChatId);

//      "data" to hashMapOf(
//          "src" to msgNkn.src,
//          "data" to json,
//          "type" to msgNkn.type,
//          "encrypted" to msgNkn.encrypted,
//          "pid" to msgNkn.messageID
//      )
  void onMessage(String myChatId, Map data);
}

class NknClientProxy with Tag {
  final Uint8List _seed;
  final String pubkey;
  final String identifier;
  final String clientUrl;
  final ClientEventDispatcher _clientEvent;
  final bool autoStartReceiveMessagesOnConnected;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  NknClientProxy(
    this._seed,
    this.pubkey,
    this._clientEvent, {
    this.identifier,
    this.clientUrl,
    this.autoStartReceiveMessagesOnConnected = true,
  })  : assert(_seed != null),
        assert(pubkey != null),
        assert(_clientEvent != null) {
    assert(identifier == null || identifier.trim().isNotEmpty);
    _LOG = LOG(tag);
  }

  String get myChatId => identifier == null ? pubkey : '$identifier.$pubkey';

  String get dbCipherPassphrase => isSeedMocked ? throw "db cipher invalid." : hexEncode(sha256(hexEncode(_seed.toList(growable: false))));

  bool get isSeedMocked => _seed.isEmpty;
///////////////////////////////////////////////////////////////////////////
  bool _isConnected = false;
  bool _disConnect = true;
  bool _clientCreated = false;

  void connect() {
    _LOG.i('>>>connect>>>');
    _disConnect = false;
    _ensureConnect();
  }

  void disConnect() {
    if (_disConnect) return;
    _LOG.i('<<<disConnect<<<');
    _NknClientPlugin.disConnect();
    onDisConnect();
    // must after `onDisConnect()`.
    _disConnect = true;
  }

  bool startReceiveMessages() {
    _ensureConnect();
    if (_isConnected && !_disConnect) {
      _NknClientPlugin.startReceiveMessages();
      return true;
    } else {
      return false;
    }
  }

  Future<Uint8List> sendText(List<String> dests, String data) {
    assert(_isConnected);
    return _NknClientPlugin.sendText(dests, data);
  }

  Future<Uint8List> publishText(String topicHash, String data) {
    assert(_isConnected);
    return _NknClientPlugin.publishText(topicHash, data);
  }

  Future<String> subscribe({
    String identifier,
    @required String topicHash,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) {
    assert(_clientCreated);
    return _NknClientPlugin.subscribe(
      identifier: identifier,
      topic: topicHash,
      duration: duration,
      fee: fee,
      meta: meta,
    );
  }

  Future<String> unsubscribe({String identifier, @required String topicHash, String fee = '0'}) {
    assert(_clientCreated);
    return _NknClientPlugin.unsubscribe(identifier: identifier, topic: topicHash, fee: fee);
  }

  Future<int> getSubscribersCount(String topicHashed) {
    assert(_clientCreated);
    return _NknClientPlugin.getSubscribersCount(topicHashed);
  }

  Future<Map<String, dynamic>> getSubscribers({
    @required String topic,
    @required String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) {
    assert(_clientCreated);
    return _NknClientPlugin.getSubscribersAction(
      topic: topic,
      topicHash: topicHash,
      offset: offset,
      limit: limit,
      meta: meta,
      txPool: txPool,
    );
  }

  Future<Map<String, dynamic>> getSubscription({@required String topicHash, @required String subscriber}) {
    assert(_clientCreated);
    return _NknClientPlugin.getSubscription(topic: topicHash, subscriber: subscriber);
  }

///////////////////////////////////////////////////////////////////////////

  void onConnect(String clientAddr, String nodeAddr, String nodePubkey) {
    _LOG.i('onConnect(clientAddr: $clientAddr, nodeAddr: $nodeAddr, nodePubkey: $nodePubkey)');
    assert(clientAddr == myChatId);
    _isConnected = true;
    _clientCreated = true;
    final asyncCall = () async {
      _clientEvent.onConnect(myChatId);
    };
    asyncCall();
    if (autoStartReceiveMessagesOnConnected) {
      startReceiveMessages();
    }
  }

  void onDisConnect() {
    _LOG.i('onDisConnect');
    _isConnected = false;
    _clientCreated = false;
    // An error occurred, not proactive call.
    // _disConnect = true;
    if (_disConnect) return;
    final asyncCall = () async {
      _clientEvent.onDisConnect(myChatId);
    };
    asyncCall();
  }

  void onMessage(Map data) async {
    _clientEvent.onMessage(myChatId, data);
  }

///////////////////////////////////////////////////////////////////////////

  void _ensureConnect() async {
    _LOG.i('_ensureConnect');
    if (_isConnected || _disConnect) return;

    await _NknClientPlugin.registerProxy(this);
    _clientCreated = await _NknClientPlugin.createClient(_seed, identifier: identifier, clientUrl: clientUrl);
    if (!_clientCreated) return;

    retryForceful(
        delayMillis: 3000,
        increase: 2000,
        action: (times) {
          if (!_isConnected && !_disConnect) {
            _NknClientPlugin.connect();
          }
          return _isConnected || _disConnect; // stop retry.
        });
  }
///////////////////////////////////////////////////////////////////////////
}

class _NknClientPlugin {
  // ignore: non_constant_identifier_names
  static LOG _LOG = LOG('_NknClientPlugin');

  static const String METHOD_CHANNEL_NAME = 'org.nkn.sdk/client';
  static const String EVENT_CHANNEL_NAME = 'org.nkn.sdk/client/event';
  static const MethodChannel _methodChannel = MethodChannel(METHOD_CHANNEL_NAME);
  static const EventChannel _eventChannel = EventChannel(EVENT_CHANNEL_NAME);

//  static final ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();
  static NknClientProxy _clientProxy;
  static bool _inited = false;

  static Future<void> registerProxy(NknClientProxy client) async {
    ensureInited();
    if (_clientProxy == client) {
      // nothing...
    } else {
      _LOG.w('registerProxy | prevClient: $_clientProxy');
      _NknClientPlugin.disConnect();

      final prevClient = _clientProxy;
      _clientProxy = client;

      if (prevClient?.myChatId != client.myChatId) {
        final asyncCall = () async {
          prevClient?.onDisConnect();
        };
        asyncCall();
      }
    }
  }

  static ensureInited() {
    if (!_inited) {
      _init();
      _inited = true;
    }
  }

  static _init() {
    _eventChannel.receiveBroadcastStream().listen((res) {
      _LOG.i('--------------------------------------------------------------');
      _LOG.i('${_clientProxy.tag} | ${_clientProxy.myChatId}');

      final String event = res['event'].toString();
      _LOG.i('event: $event');

      switch (event) {
        case 'onConnect':
          final clientAddr = res['client']['address'];
          if (_clientProxy.myChatId == clientAddr) {
            Map node = res['node']; // NodeInfoSchema(address: node['address'], publicKey: node['publicKey'])
            _clientProxy.onConnect(clientAddr, node['address'], node['publicKey']);
          } else {
            _LOG.w('_clientProxy.myChatId != clientAddr: $clientAddr');
          }
          break;
        case 'onDisConnect':
          final clientAddr = res['client']['address'];
          if (_clientProxy.myChatId == clientAddr) {
            _clientProxy.onDisConnect();
          } else {
            _LOG.w('_clientProxy.myChatId != clientAddr: $clientAddr');
          }
          break;
        case 'onMessage':
          _LOG.i('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
          final clientAddr = res['client']['address'];
          if (_clientProxy.myChatId == clientAddr) {
            _clientProxy.onMessage(res['data']);
            _LOG.i('<<<<<<<<< onMessage <<<<<<<<< DONE <<<<<<<<<');
          } else {
            _LOG.w('_clientProxy.myChatId != clientAddr: $clientAddr');
          }
          break;
        case 'send':
          String key = res['_id'];
          Uint8List pid = res['pid'];
          _LOG.i('send, pid: $pid');
          _clientEventQueue[key].complete(pid);
          break;
        default:
          Map data = res;
          _LOG.i('default, data: $data');
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
          _LOG.i('<<<<<<<<< default, data: $data <<<<<<<<< DONE <<<<<<<<<');
          break;
      }
    }, onError: (err) {
      _LOG.e('_eventChannel.onError', err);
      if (_clientEventQueue[err.code] != null) {
        _clientEventQueue[err.code].completeError(err.message);
      }
    });
  }

  @deprecated
  static Future<bool> isConnected() async {
    _LOG.i('isConnected');
    return await _methodChannel.invokeMethod('isConnected');
  }

  static Future<bool> createClient(Uint8List seed, {String identifier, String clientUrl}) async {
    _LOG.i('createClient');
    final status = await _methodChannel.invokeMethod('createClient', {
      'identifier': identifier,
      'seedBytes': seed,
      'clientUrl': clientUrl,
    });
    return status == 1;
  }

  static Future<void> connect() async {
    _LOG.i('connect');
    await _methodChannel.invokeMethod('connect');
  }

  static Future<void> startReceiveMessages() async {
    _LOG.i('startReceiveMessages');
    await _methodChannel.invokeMethod('startReceiveMessages');
  }

  static Future<void> disConnect() async {
    _LOG.i('disConnect');
    await _methodChannel.invokeMethod('disConnect');
  }

  static Future<Uint8List> sendText(List<String> dests, String data) async {
    _LOG.i('sendText($dests, $data)');
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
    try {
      await _methodChannel.invokeMethod('sendText', {
        '_id': id,
        'dests': dests,
        'data': data,
      });
    } catch (e) {
      _LOG.e('sendText', e);
      completer.completeError(e);
//      throw e;
    }
    return completer.future;
  }

  static Future<Uint8List> publishText(String topic, String data) async {
    _LOG.i('topic: $topic, data: $data');
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
    try {
      await _methodChannel.invokeMethod('publishText', {
        '_id': id,
        'topic': topic,
        'data': data,
      });
    } catch (e) {
      _LOG.e('publish', e);
      completer.completeError(e);
    }
    return completer.future;
  }

  static Future<String> subscribe({
    String identifier = '',
    String topic,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) async {
    _LOG.i('subscribe($identifier, $topic, $duration, $fee, $meta)');
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('subscribe', {
      '_id': id,
      'identifier': identifier,
      'topic': topic,
      'duration': duration,
      'fee': fee,
      'meta': meta,
    });
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<String> unsubscribe({String identifier, String topic, String fee = '0'}) async {
    _LOG.i('unsubscribe($identifier, $topic, $fee)');
    Completer<String> completer = Completer<String>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    _methodChannel.invokeMethod('unsubscribe', {
      '_id': id,
      'identifier': identifier,
      'topic': topic,
      'fee': fee,
    });
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }

  static Future<int> getSubscribersCount(String topic) async {
    _LOG.i('getSubscribersCount($topic)');
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

  static Future<Map<String, dynamic>> getSubscription({String topic, String subscriber}) async {
    _LOG.i('getSubscription($topic, $subscriber)');
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
    _LOG.i('getSubscribersAction($topic, $topicHash, $offset, $limit, $meta, $txPool)');
    Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    String id = completer.hashCode.toString();
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
}
