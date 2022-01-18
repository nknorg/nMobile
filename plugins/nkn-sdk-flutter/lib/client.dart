import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';

/// NKN message's PayloadType
class MessageType {
  static const int BINARY = 0;
  static const int TEXT = 1;
  static const int ACK = 2;
  static const int SESSION = 3;
}

/// Event emitting channel when client connects to node and becomes ready to send messages.
class OnConnect {
  /// Connected remote node
  ///
  /// [address] is remote host
  /// [publicKey] is NKN public key
  Map? node;

  /// Subclient's rpcServers
  List<String>? rpcServers;

  OnConnect({this.node, this.rpcServers});
}

/// Event emitting channel when client receives a message (not including reply or ACK).
class OnMessage {
  /// Message ID.
  Uint8List messageId;

  /// Sender's NKN client address
  String? src;

  /// Message data.
  String? data;

  /// Message data type.
  int? type;

  /// Whether message is encrypted.
  bool? encrypted;

  OnMessage({
    required this.messageId,
    required this.data,
    required this.src,
    required this.type,
    required this.encrypted,
  });
}

/// Client config
class ClientConfig {
  /// Seed RPC server address that client uses to find its node and make RPC requests (e.g. get subscribers).
  final List<String>? seedRPCServerAddr;

  ClientConfig({this.seedRPCServerAddr});
}

/// Client sends and receives data between any NKN clients regardless their
/// network condition without setting up a server or relying on any third party
/// services. Data are end to end encrypted by default.
class Client {
  static const MethodChannel _methodChannel =
      MethodChannel('org.nkn.sdk/client');
  static const EventChannel _eventChannel =
      EventChannel('org.nkn.sdk/client/event');

  static Stream? _stream;

  /// Need to [install] before use.
  static install() {
    _stream = _eventChannel.receiveBroadcastStream();
  }

  /// NKN client address
  late String address;

  /// NKN wallet seed
  late Uint8List seed;

  /// NKN wallet public key
  late Uint8List publicKey;

  ClientConfig? clientConfig;

  StreamController<OnConnect> _onConnectStreamController =
      StreamController<OnConnect>.broadcast();

  StreamSink<OnConnect> get _onConnectStreamSink =>
      _onConnectStreamController.sink;

  Stream<OnConnect> get onConnect => _onConnectStreamController.stream;

  StreamController<OnMessage> _onMessageStreamController =
      StreamController<OnMessage>.broadcast();

  StreamSink<OnMessage> get _onMessageStreamSink =>
      _onMessageStreamController.sink;

  Stream<OnMessage> get onMessage => _onMessageStreamController.stream;

  StreamController<dynamic> _onErrorStreamController =
      StreamController<dynamic>.broadcast();

  StreamSink<dynamic> get _onErrorStreamSink => _onErrorStreamController.sink;

  Stream<dynamic> get onError => _onErrorStreamController.stream;

  late StreamSubscription eventChannelStreamSubscription;

  Client({this.clientConfig});

  /// [create] creates a multiclient with an account, an optional identifier,
  /// number of sub clients to create, whether to create original client without
  /// identifier prefix, and a optional client config that will be applied to all
  /// clients created. For any zero value field in config, the default client
  /// config value will be used. If config is nil, the default client config will
  /// be used.
  static Future<Client> create(Uint8List seed,
      {String identifier = '', int? numSubClients, ClientConfig? config}) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('create', {
        'identifier': identifier,
        'seed': seed,
        'numSubClients': numSubClients,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : null,
      });
      Client client = Client();
      client.address = resp['address'];
      client.publicKey = resp['publicKey'];
      client.seed = resp['seed'];

      client.eventChannelStreamSubscription =
          _stream!.where((res) => res['_id'] == client.address).listen((res) {
        if (res['_id'] != client.address) {
          return;
        }
        switch (res['event']) {
          case 'onConnect':
            client._onConnectStreamSink.add(OnConnect(
                node: res['node'],
                rpcServers: res['rpcServers']?.cast<String>()));
            break;
          case 'onMessage':
            Map data = res['data'];
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

  /// [reconnect] reconnect the multiclient
  Future<void> reconnect() async {
    if (!(this.address.isNotEmpty == true)) {
      return;
    }
    await _methodChannel.invokeMethod('reconnect', {'_id': this.address});
  }

  /// [close] closes the multiclient, including all clients it created and all
  /// sessions dialed and accepted. Calling close multiple times is allowed and
  /// will not have any effect.
  Future<void> close() async {
    if (!(this.address.isNotEmpty == true)) {
      return;
    }
    await _methodChannel.invokeMethod('close', {'_id': this.address});
    _onConnectStreamController.close();
    _onMessageStreamController.close();
    _onErrorStreamController.close();
    eventChannelStreamSubscription.cancel();
  }

  /// [sendText] sends bytes or string data to one or multiple destinations with an
  /// optional config. Returned [OnMessage] will emit if a reply or ACK for
  /// this message is received.
  Future<OnMessage> sendText(List<String> dests, String data,
      {int maxHoldingSeconds = 8640000, noReply = true}) async {
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

  /// [publishText] sends bytes or string data to all subscribers of a topic with an
  /// optional config.
  Future<OnMessage> publishText(String topic, String data,
      {int maxHoldingSeconds = 8640000, bool txPool = false, int offset = 0, int limit = 1000}) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('publishText', {
        '_id': this.address,
        'topic': topic,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
        'txPool': txPool,
        'offset': offset,
        'limit': limit,
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

  /// [subscribe] to a topic with an identifier for a number of blocks. Client
  /// using the same key pair and identifier will be able to receive messages from
  /// this topic. If this (identifier, public key) pair is already subscribed to
  /// this topic, the subscription expiration will be extended to current block
  /// height + duration. The signerRPCClient can be a client, multiclient or
  /// wallet.
  Future<String> subscribe({
    String identifier = '',
    required String topic,
    int duration = 400000,
    String fee = '0',
    String meta = '',
    int? nonce,
  }) async {
    try {
      String hash = await _methodChannel.invokeMethod('subscribe', {
        '_id': this.address,
        'identifier': identifier,
        'topic': topic,
        'duration': duration,
        'fee': fee,
        'meta': meta,
        'nonce': nonce,
      });
      return hash;
    } catch (e) {
      throw e;
    }
  }

  /// [unsubscribe] from a topic for an identifier. Client using the same key
  /// pair and identifier will no longer receive messages from this topic. The
  /// signerRPCClient can be a client, multiclient or wallet.
  Future<String> unsubscribe({
    String identifier = '',
    required String topic,
    String fee = '0',
    int? nonce,
  }) async {
    try {
      String hash = await _methodChannel.invokeMethod('unsubscribe', {
        '_id': this.address,
        'identifier': identifier,
        'topic': topic,
        'fee': fee,
        'nonce': nonce,
      });
      return hash;
    } catch (e) {
      throw e;
    }
  }

  /// [getSubscribersCount] RPC returns the number of subscribers of a topic
  /// (not including txPool). If [subscriberHashPrefix] is not empty, only subscriber
  /// whose sha256(pubkey+identifier) contains this prefix will be counted. Each
  /// prefix byte will reduce result count to about 1/256, and also reduce response
  /// time to about 1/256 if there are a lot of subscribers. This is a good way to
  /// sample subscribers randomly with low cost.
  Future<int> getSubscribersCount(
      {required String topic, Uint8List? subscriberHashPrefix}) async {
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

  /// [getSubscription] RPC gets the subscription details of a subscriber in a topic.
  Future<Map<String, dynamic>?> getSubscription(
      {required String topic, required String subscriber}) async {
    try {
      Map? resp = await _methodChannel.invokeMethod('getSubscription', {
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

  /// [getSubscribers] RPC returns the number of subscribers of a topic
  /// (not including txPool). If [subscriberHashPrefix] is not empty, only subscriber
  /// whose sha256(pubkey+identifier) contains this prefix will be counted. Each
  /// prefix byte will reduce result count to about 1/256, and also reduce response
  /// time to about 1/256 if there are a lot of subscribers. This is a good way to
  /// sample subscribers randomly with low cost.
  Future<Map<String, dynamic>?> getSubscribers({
    required String topic,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    try {
      Map? resp = await _methodChannel.invokeMethod('getSubscribers', {
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

  /// [getHeight] RPC returns the latest block height.
  Future<int?> getHeight() async {
    try {
      int? resp =
          await _methodChannel.invokeMethod('getHeight', {'_id': this.address});
      return resp;
    } catch (e) {
      throw e;
    }
  }

  /// [getNonce] RPC gets the next nonce to use of an address. If txPool is
  /// false, result only counts transactions in ledger; if txPool is true,
  /// transactions in txPool are also counted.
  Future<int?> getNonce({bool txPool = true}) async {
    if (this.publicKey == null || this.publicKey.isEmpty) return null;
    try {
      String? walletAddr =
          await Wallet.pubKeyToWalletAddr(hexEncode(this.publicKey));
      int? resp = await _methodChannel.invokeMethod('getNonce', {
        '_id': this.address,
        'address': walletAddr,
        'txPool': txPool,
      });
      return resp;
    } catch (e) {
      throw e;
    }
  }

  /// [getNonceByAddress] is the same as [getNonce]
  Future<int?> getNonceByAddress(String address, {bool txPool = true}) async {
    try {
      int? resp = await _methodChannel.invokeMethod('getNonce', {
        '_id': this.address,
        'address': address,
        'txPool': txPool,
      });
      return resp;
    } catch (e) {
      throw e;
    }
  }
}
