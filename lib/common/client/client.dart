import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

class ClientConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  // static const int stopping = 3;
}

class ClientCommon with Tag {
  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  String? get address => client?.address;

  Uint8List? get publicKey => client?.publicKey;

  late int status;

  int signInAt = 0; // TODO:GG 用处 ？

  // ignore: close_sinks
  StreamController<int> _statusController = StreamController<int>.broadcast();
  StreamSink<int> get _statusSink => _statusController.sink;
  Stream<int> get statusStream => _statusController.stream;

  // ignore: close_sinks
  StreamController<bool> _connectingVisibleController = StreamController<bool>.broadcast();
  StreamSink<bool> get _connectingVisibleSink => _connectingVisibleController.sink;
  Stream<bool> get connectingVisibleStream => _connectingVisibleController.stream;

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
      if (client != null && event == ClientConnectStatus.connected) {
        signInAt = DateTime.now().millisecondsSinceEpoch;
      }
    });
    onErrorStream.listen((dynamic event) {
      handleError(event);
    });
  }

  /// ******************************************************   Client   ****************************************************** ///

  // need close
  Future<Client?> signIn(WalletSchema? wallet, {String? walletPwd, bool walletFetch = true, Function(bool)? dialogVisible, int tryCount = 1}) async {
    if (wallet == null || wallet.address.isEmpty) return null;
    // if (client != null) await close(); // async boom!!!
    try {
      // login password
      walletPwd = (walletPwd?.isNotEmpty == true) ? walletPwd : (await authorization.getWalletPassword(wallet.address));
      if (walletPwd == null || walletPwd.isEmpty) return null;
      dialogVisible?.call(true);

      // pubKey + seed
      List<String>? seedRpcList;
      String? pubKey;
      String? seed;
      if (walletFetch) {
        String keystore = await walletCommon.getKeystore(wallet.address);
        seedRpcList = await Global.getSeedRpcList(wallet.address);
        Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: walletPwd, seedRPCServerAddr: seedRpcList));
        pubKey = nknWallet.publicKey.isEmpty ? null : hexEncode(nknWallet.publicKey);
        seed = nknWallet.seed.isEmpty ? null : hexEncode(nknWallet.seed);
      } else {
        if (!(await walletCommon.isPasswordRight(wallet.address, walletPwd))) {
          logger.w("$TAG - signIn - password error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          throw Exception("wrong password");
        }
        pubKey = wallet.publicKey;
        seed = await walletCommon.getSeed(wallet.address);
      }
      if (pubKey == null || pubKey.isEmpty || seed == null || seed.isEmpty) {
        dialogVisible?.call(false);
        if (!walletFetch) {
          logger.w("$TAG - signIn - pubKey/seed error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return signIn(wallet, walletPwd: walletPwd, walletFetch: true, dialogVisible: dialogVisible);
        } else {
          logger.w("$TAG - signIn - pubKey/seed error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return null;
        }
      }

      // database open
      if (!(dbCommon.isOpen() == true)) {
        String databasePwd = hexEncode(Uint8List.fromList(sha256(hexDecode(seed))));
        await dbCommon.open(pubKey, databasePwd);
        // wallet
        BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
        // contact
        ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true);
        contactCommon.meUpdateSink.add(me);
      }

      // client status
      _statusSink.add(ClientConnectStatus.connecting);

      // client create
      seedRpcList = seedRpcList ?? (await Global.getSeedRpcList(wallet.address));
      client = await Client.create(hexDecode(seed), config: ClientConfig(seedRPCServerAddr: seedRpcList));

      dialogVisible?.call(false);

      // client error
      _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
        logger.e("$TAG - signIn - onError -> event:${event.toString()}");
        _onErrorSink.add(event);
      });

      // client connect (just listen once)
      Completer completer = Completer();
      _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
        logger.i("$TAG - signIn - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
        SettingsStorage.addSeedRpcServers(event.rpcServers!, prefix: wallet.address);
        _statusSink.add(ClientConnectStatus.connected);
        if (!completer.isCompleted) completer.complete();
      });

      // client receive (looper)
      _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
        logger.i("$TAG - signIn - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
        chatInCommon.onClientMessage(MessageSchema.fromReceive(event)); // TODO:GG 最好也是队列，否则取出来后，后面的队列没有处理，会造成消息丢失?
      });

      // await completer.future;
      return client;
    } catch (e) {
      dialogVisible?.call(false);
      if ((e.toString().contains("password") == true) || (e.toString().contains("keystore") == true)) {
        if (!walletFetch) {
          logger.w("$TAG - signIn - password/keystore error, reSignIn by check - wallet:$wallet");
          return signIn(wallet, walletPwd: walletPwd, walletFetch: true, dialogVisible: dialogVisible);
        }
        handleError(e);
        return null;
      }
      // loop
      if (tryCount < 3) {
        await SettingsStorage.setSeedRpcServers([], prefix: wallet.address);
        await Future.delayed(Duration(seconds: 1));
        return signIn(wallet, walletPwd: walletPwd, walletFetch: walletFetch, dialogVisible: dialogVisible, tryCount: ++tryCount);
      }
      handleError(e);
      return null;
    }
  }

  Future signOut({bool closeDB = true}) async {
    // status
    _statusSink.add(ClientConnectStatus.disconnected);
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    await client?.close();
    client = null;
    // close DB
    if (closeDB) {
      await dbCommon.close();
      BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(null));
    }
  }

  // TODO:GG 1. client出错，登出在登录
  // TODO:GG 2. client没出错，时效性重新登录
  Future<Client?> reSignIn(bool needPwd, {int delayMs = 0}) async {
    if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));

    // wallet + db
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.address.isEmpty) {
      AppScreen.go(Global.appContext);
      await signOut(closeDB: true);
      return null;
    }
    await signOut(closeDB: false);
    await Future.delayed(Duration(milliseconds: 500));

    // client
    String? walletPwd = needPwd ? (await authorization.getWalletPassword(wallet.address)) : (await walletCommon.getPassword(wallet.address));
    return await signIn(wallet, walletPwd: walletPwd, walletFetch: false);
  }

  Future connectCheck() async {
    if (client == null) return;
    _statusSink.add(ClientConnectStatus.connecting);
    await chatOutCommon.sendPing(address, true);
    // loop
    Future.delayed(Duration(seconds: 1), () {
      if ((status == ClientConnectStatus.connecting) && (application.appLifecycleState == AppLifecycleState.resumed)) {
        _connectingVisibleSink.add(true);
        connectCheck();
      }
    });
  }

  Future pingSuccess() async {
    if (client == null || status != ClientConnectStatus.connecting) return;
    _statusSink.add(ClientConnectStatus.connected);
    // visible
    Future.delayed(Duration(milliseconds: 500), () {
      _connectingVisibleSink.add(false);
    });
  }
}
