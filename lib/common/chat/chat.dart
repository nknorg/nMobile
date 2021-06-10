import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';

class ChatConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

class ChatCommon with Tag {
  DB? db;

  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  String? get id => client?.address;

  Uint8List? get publicKey => client?.publicKey;

  late int status;

  // ignore: close_sinks
  StreamController<int> _statusController = StreamController<int>.broadcast();
  StreamSink<int> get _statusSink => _statusController.sink;
  Stream<int> get statusStream => _statusController.stream;

  // ignore: close_sinks
  StreamController<dynamic> _onErrorController = StreamController<dynamic>.broadcast();
  StreamSink<dynamic> get _onErrorSink => _onErrorController.sink;
  Stream<dynamic> get onErrorStream => _onErrorController.stream;

  StreamSubscription? _onErrorStreamSubscription;
  StreamSubscription? _onConnectStreamSubscription;
  StreamSubscription? _onMessageStreamSubscription;

  MessageStorage _messageStorage = MessageStorage();

  ChatCommon() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      // TODO:GG client error
    });
  }

  // need close
  Future<bool> signIn(WalletSchema? schema, {bool walletDefault = false}) async {
    if (schema == null) return false;
    // if (client != null) await close(); // async boom!!!
    try {
      String? pwd = await authorization.getWalletPassword(schema.address);
      if (pwd == null || pwd.isEmpty) return false;
      String keystore = await walletCommon.getKeystoreByAddress(schema.address);

      Wallet wallet = await Wallet.restore(keystore, config: WalletConfig(password: pwd));
      if (wallet.address.isEmpty || wallet.keystore.isEmpty) return false;

      if (walletDefault) BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(schema.address));

      String pubKey = hexEncode(wallet.publicKey);
      String password = hexEncode(Uint8List.fromList(sha256(wallet.seed)));
      if (pubKey.isEmpty || password.isEmpty) return false;

      // open DB
      db = await DB.open(pubKey, password);
      // set currentUser
      await contactCommon.refreshCurrentUser(pubKey);
      // start client connect (no await)
      connect(wallet); // await
    } catch (e) {
      handleError(e);
    }
    return true;
  }

  Future connect(Wallet? wallet) async {
    if (wallet == null || wallet.seed.isEmpty) return;
    // client create
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);

    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
      logger.e("$TAG - onError -> event:${event.toString()}");
      _onErrorSink.add(event);
    });

    // client connect
    Completer completer = Completer();
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
      logger.i("$TAG - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
      _statusSink.add(ChatConnectStatus.connected);
      SettingsStorage().addSeedRpcServers(event.rpcServers!);
      completer.complete();
    });

    // TODO:GG client disconnect/reconnect listen (action statusSink.add)

    // client messages_receive
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async {
      logger.i("$TAG - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
      await receiveMessage.onClientMessage(MessageSchema.fromReceive(event));
    });
    await completer.future;
  }

  signOut() async {
    // status
    _statusSink.add(ChatConnectStatus.disconnected);
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    await client?.close();
    client = null;
    // clear currentUser
    await contactCommon.refreshCurrentUser(null, notify: true);
    // close DB
    await db?.close();
  }

  Future<List<MessageSchema>> queryListAndReadByTargetId(
    String? targetId, {
    int offset = 0,
    int limit = 20,
    int? unread,
    bool handleBurn = true,
  }) async {
    List<MessageSchema> list = await _messageStorage.queryListCanReadByTargetId(targetId, offset: offset, limit: limit);
    // unread
    if (offset == 0 && (unread == null || unread > 0)) {
      List<MessageSchema> unreadList = await _messageStorage.queryListUnReadByTargetId(targetId);
      unreadList.asMap().forEach((index, MessageSchema element) {
        receiveMessage.read(element); // await
        if (index >= unreadList.length - 1) {
          sessionCommon.setUnReadCount(element.targetId, 0, notify: true);
        }
      });
      list = list.map((e) => e.isOutbound == false ? MessageStatus.set(e, MessageStatus.ReceivedRead) : e).toList(); // fake read
    }
    return list;
  }

  Future<OnMessage?> sendMessage(String dest, String data) async {
    return await this.client?.sendText([dest], data);
  }

  Future<OnMessage?> publishMessage(String topic, String data) async {
    return await this.client?.publishText(topic, data);
  }
}
