import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class MessageType {
  static const int BINARY = 0;
  static const int TEXT = 1;
  static const int ACK = 2;
  static const int SESSION = 3;
}

class OnConnect {
  Map node;
  List<String> rpcServers;

  OnConnect({this.node, this.rpcServers});
}

class OnMessage {
  Uint8List messageId;
  String src;
  String data;
  int type;
  bool encrypted;

  OnMessage({this.messageId, this.data, this.src, this.type, this.encrypted});
}

class ClientConfig {
  final List<String> seedRPCServerAddr;

  ClientConfig({this.seedRPCServerAddr});
}

class Client {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/client');
  static const EventChannel _eventChannel = EventChannel('org.nkn.sdk/client/event');

  static Stream _stream;

  static install() {
    _stream = _eventChannel.receiveBroadcastStream();
  }

  String address;
  Uint8List seed;
  Uint8List publicKey;

  ClientConfig clientConfig;

  StreamController<OnConnect> _onConnectStreamController = StreamController<OnConnect>.broadcast();

  StreamSink<OnConnect> get _onConnectStreamSink => _onConnectStreamController.sink;

  Stream<OnConnect> get onConnect => _onConnectStreamController.stream;

  StreamController<OnMessage> _onMessageStreamController = StreamController<OnMessage>.broadcast();

  StreamSink<OnMessage> get _onMessageStreamSink => _onMessageStreamController.sink;

  Stream<OnMessage> get onMessage => _onMessageStreamController.stream;

  StreamController<dynamic> _onErrorStreamController = StreamController<dynamic>.broadcast();

  StreamSink<dynamic> get _onErrorStreamSink => _onErrorStreamController.sink;

  Stream<dynamic> get onError => _onErrorStreamController.stream;

  StreamSubscription eventChannelStreamSubscription;

  Client({this.clientConfig});

  static Future<Client> create(Uint8List seed, {String identifier = '', ClientConfig config}) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('create', {
        'identifier': identifier,
        'seed': seed,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true ? config.seedRPCServerAddr : null,
      });
      Client client = Client();
      client.address = resp['address'];
      client.publicKey = resp['publicKey'];
      client.seed = resp['seed'];

      client.eventChannelStreamSubscription = _stream.where((res) => res['_id'] == client.address).listen((res) {
        Map data = res['data'];
        if (res['_id'] != client.address) {
          return;
        }
        switch (res['event']) {
          case 'onConnect':
            client._onConnectStreamSink.add(OnConnect(node: res['node'], rpcServers: res['rpcServers']?.cast<String>()));
            break;
          case 'onMessage':
            client._onMessageStreamSink.add(OnMessage(
              src: data['src'],
              type: data['type'],
              messageId: data['messageId'],
              data: data['data'],
              encrypted: data['encrypted'],
            ));
            break;
          default:
            break;
        }
      }, onError: (err) {
        if (err.code != client.address) {
          return;
        }
        client._onErrorStreamSink.add(err);
      });
      return client;
    } catch (e) {
      throw e;
    }
  }

  Future<void> close() async {
    if (!(this.address?.isNotEmpty == true)) {
      return;
    }
    await _methodChannel.invokeMethod('close', {'_id': this.address});
    _onConnectStreamController?.close();
    _onMessageStreamController?.close();
    _onErrorStreamController?.close();
    eventChannelStreamSubscription?.cancel();
  }

  Future<OnMessage> sendText(List<String> dests, String data, {int maxHoldingSeconds = 8640000, noReply = true}) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('sendText', {
        '_id': this.address,
        'dests': dests,
        'data': data,
        'noReply': noReply,
        'maxHoldingSeconds': maxHoldingSeconds,
      });
      OnMessage message = OnMessage(
        messageId: resp['messageId'],
        data: resp['data'],
        type: resp['type'],
        encrypted: resp['encrypted'],
        src: resp['src'],
      );
      return message;
    } catch (e) {
      throw e;
    }
  }

  Future<OnMessage> publishText(String topic, String data, {int maxHoldingSeconds = 8640000}) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('publishText', {
        '_id': this.address,
        'topic': topic,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
      });
      OnMessage message = OnMessage(
        messageId: resp['messageId'],
        data: resp['data'],
        type: resp['type'],
        encrypted: resp['encrypted'],
        src: resp['src'],
      );
      return message;
    } catch (e) {
      throw e;
    }
  }

  Future<String> subscribe({
    String identifier = '',
    String topic,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) async {
    try {
      String hash = await _methodChannel.invokeMethod('subscribe', {
        '_id': this.address,
        'identifier': identifier,
        'topic': topic,
        'duration': duration,
        'fee': fee,
        'meta': meta,
      });
      return hash;
    } catch (e) {
      throw e;
    }
  }

  Future<String> unsubscribe({String identifier = '', String topic, String fee = '0'}) async {
    try {
      String hash = await _methodChannel.invokeMethod('unsubscribe', {
        '_id': this.address,
        'identifier': identifier,
        'topic': topic,
        'fee': fee,
      });
      return hash;
    } catch (e) {
      throw e;
    }
  }

  Future<int> getSubscribersCount({String topic, Uint8List subscriberHashPrefix}) async {
    try {
      int count = await _methodChannel.invokeMethod('getSubscribersCount', {
        '_id': this.address,
        'topic': topic,
        'subscriberHashPrefix': subscriberHashPrefix,
      });
      return count;
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, dynamic>> getSubscription({String topic, String subscriber}) async {
    try {
      Map resp = await _methodChannel.invokeMethod('getSubscription', {
        '_id': this.address,
        'topic': topic,
        'subscriber': subscriber,
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, dynamic>> getSubscribers({
    String topic,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
    Uint8List subscriberHashPrefix,
  }) async {
    try {
      Map resp = await _methodChannel.invokeMethod('getSubscribers', {
        '_id': this.address,
        'topic': topic,
        'offset': offset,
        'limit': limit,
        'meta': meta,
        'txPool': txPool,
        'subscriberHashPrefix': subscriberHashPrefix,
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }
}
