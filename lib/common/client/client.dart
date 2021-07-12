import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';

class ClientConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

class ClientCommon with Tag {
  DB? db;

  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  String? get address => client?.address;

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

  ClientCommon() {
    status = ClientConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      // TODO:GG client error
    });
  }

  /// ******************************************************   Client   ****************************************************** ///

  // need close
  Future<Client?> signIn(WalletSchema? schema, {bool walletDefault = false}) async {
    if (schema == null) return null;
    // if (client != null) await close(); // async boom!!!
    try {
      String? pwd = await authorization.getWalletPassword(schema.address);
      if (pwd == null || pwd.isEmpty) return null;
      String keystore = await walletCommon.getKeystoreByAddress(schema.address);

      Wallet wallet = await Wallet.restore(keystore, config: WalletConfig(password: pwd));
      if (wallet.address.isEmpty || wallet.keystore.isEmpty) return null;

      if (walletDefault) BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(schema.address));

      String pubKey = hexEncode(wallet.publicKey);
      String password = hexEncode(Uint8List.fromList(sha256(wallet.seed)));
      if (pubKey.isEmpty || password.isEmpty) return null;

      // open DB
      db = await DB.open(pubKey, password);
      // start client connect (no await)
      return _connect(wallet);
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<Client?> _connect(Wallet? wallet) async {
    if (wallet == null || wallet.seed.isEmpty) return null;
    // client create
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusSink.add(ClientConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);

    // check contact me
    ContactSchema? me = (await contactCommon.getMe()) ?? (await ContactSchema.createByType(client?.address, type: ContactType.me));
    contactCommon.meUpdateSink.add(me);

    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
      logger.e("$TAG - onError -> event:${event.toString()}");
      _onErrorSink.add(event);
    });

    // client connect
    Completer completer = Completer();
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
      logger.i("$TAG - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
      _statusSink.add(ClientConnectStatus.connected);
      SettingsStorage().addSeedRpcServers(event.rpcServers!);
      if (!completer.isCompleted) completer.complete();
    });

    // TODO:GG client disconnect/reconnect listen (action statusSink.add) (effect message send / receive)

    // client messages_receive
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async {
      logger.i("$TAG - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
      await chatInCommon.onClientMessage(MessageSchema.fromReceive(event));
    });

    // await completer.future;
    return client;
  }

  Future signOut() async {
    // status
    _statusSink.add(ClientConnectStatus.disconnected);
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    await client?.close();
    client = null;
    // close DB
    await db?.close();
  }
}
