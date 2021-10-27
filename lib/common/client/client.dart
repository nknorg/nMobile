import 'dart:async';
import 'dart:typed_data';

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
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

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

  // == chat_id
  String? get address => client?.address;

  // == wallet publicKey
  Uint8List? get publicKey => client?.publicKey;

  bool get isClientCreated => (client != null) && (client?.address.isNotEmpty == true);

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

  Lock _lock = Lock();

  late int status;
  bool clientClosing = false;
  bool connectChecking = false;

  ClientCommon() {
    status = ClientConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      handleError(event);
      connectCheck(reconnect: true);
    });
    clientClosing = false;
    connectChecking = false;
  }

  /// ******************************************************   Client   ****************************************************** ///

  Future<List> signIn(WalletSchema? wallet, {bool fetchRemote = true, Function(bool, int)? loadingVisible, String? password, int tryCount = 1}) {
    return _lock.synchronized(() {
      return _signIn(wallet, fetchRemote: fetchRemote, loadingVisible: loadingVisible, password: password, tryCount: tryCount);
    });
  }

  // return [client, pwdError]
  Future<List> _signIn(WalletSchema? wallet, {bool fetchRemote = true, Function(bool, int)? loadingVisible, String? password, int tryCount = 1}) async {
    // if (client != null) await close(); // async boom!!!
    if (wallet == null || wallet.address.isEmpty) return [null, false];

    // pubKey/seed
    String? pubKey = wallet.publicKey;
    String? seed = await walletCommon.getSeed(wallet.address);

    try {
      // password get
      password = (password?.isNotEmpty == true) ? password : (await authorization.getWalletPassword(wallet.address));
      if (password == null || password.isEmpty) {
        return [null, true];
      }

      // ui + status
      loadingVisible?.call(true, tryCount);
      _statusSink.add(ClientConnectStatus.connecting);

      // password check
      if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
        logger.w("$TAG - signIn - password error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
        throw Exception("wrong password");
      }

      // database by cache
      if ((pubKey.isNotEmpty == true) && (seed?.isNotEmpty == true)) {
        if (!(dbCommon.isOpen() == true)) {
          try {
            await dbCommon.open(pubKey, seed!);
          } catch (e) {
            handleError(e);
          }
          // wallet + contact
          BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
          ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true);
          contactCommon.meUpdateSink.add(me);
        }
      }

      // rpc wallet
      List<String>? seedRpcList;
      if (fetchRemote) {
        String keystore = await walletCommon.getKeystore(wallet.address);
        seedRpcList = await Global.getSeedRpcList(wallet.address, measure: true);
        Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
        pubKey = nknWallet.publicKey.isEmpty ? null : hexEncode(nknWallet.publicKey);
        seed = nknWallet.seed.isEmpty ? null : hexEncode(nknWallet.seed);
      }

      // check pubKey/seed
      if (pubKey == null || pubKey.isEmpty || seed == null || seed.isEmpty) {
        loadingVisible?.call(false, tryCount);
        if (!fetchRemote) {
          logger.w("$TAG - signIn - pubKey/seed error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password);
        } else {
          logger.e("$TAG - signIn - pubKey/seed error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          _statusSink.add(ClientConnectStatus.disconnected);
          return [null, false];
        }
      }

      // database by remote
      if (!(dbCommon.isOpen() == true)) {
        await dbCommon.open(pubKey, seed);
        // wallet + contact
        BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
        ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true);
        contactCommon.meUpdateSink.add(me);
      }

      // client create
      if (client == null) {
        chatCommon.clear();
        chatInCommon.clear();
        chatOutCommon.clear();

        seedRpcList = seedRpcList ?? (await Global.getSeedRpcList(wallet.address, measure: true));
        List<String> singleRpcList = (seedRpcList.isNotEmpty == true) ? [seedRpcList.first] : [];
        client = await Client.create(hexDecode(seed), config: ClientConfig(seedRPCServerAddr: singleRpcList));

        loadingVisible?.call(false, tryCount);

        // client error
        _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
          logger.e("$TAG - signIn - onError -> event:${event.toString()}");
          _onErrorSink.add(event);
        });

        // client connect (just listen once)
        Completer completer = Completer();
        _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
          logger.i("$TAG - signIn - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
          SettingsStorage.addSeedRpcServers(event.rpcServers ?? [], prefix: wallet.address);
          connectSuccess(force: true);
          if (!completer.isCompleted) completer.complete();
        });

        // client receive (looper)
        _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
          logger.i("$TAG - signIn - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
          chatInCommon.onMessageReceive(MessageSchema.fromReceive(event));
          if (status != ClientConnectStatus.connected) {
            connectSuccess(force: true);
          }
        });
      } else {
        loadingVisible?.call(false, tryCount);
        client?.reconnect(); // await // no onConnect callback
        // no status update (updated by ping/pang)
      }
      // await completer.future;
      return [client, false];
    } catch (e) {
      loadingVisible?.call(false, tryCount);
      // password/keystore
      if ((e.toString().contains("password") == true) || (e.toString().contains("keystore") == true)) {
        if (!fetchRemote) {
          logger.w("$TAG - signIn - password/keystore error, reSignIn by check - wallet:$wallet");
          return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password);
        }
        handleError(e);
        _statusSink.add(ClientConnectStatus.disconnected);
        return [null, true];
      }
      // toast
      if ((tryCount != 0) && (tryCount % 10 == 0)) handleError(e);
      // loop login
      await SettingsStorage.setSeedRpcServers([], prefix: wallet.address);
      await Future.delayed(Duration(seconds: tryCount >= 5 ? 5 : tryCount));
      return _signIn(wallet, fetchRemote: fetchRemote, loadingVisible: loadingVisible, password: password, tryCount: ++tryCount);
    }
  }

  Future signOut({bool clearWallet = true, bool closeDB = true}) {
    return _lock.synchronized(() {
      return _signOut(clearWallet: clearWallet, closeDB: closeDB);
    });
  }

  Future _signOut({bool clearWallet = true, bool closeDB = true}) async {
    clientClosing = true;
    // status
    _statusSink.add(ClientConnectStatus.disconnected);
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    // close
    try {
      await client?.close();
    } catch (e) {
      handleError(e);
      await Future.delayed(Duration(milliseconds: 200));
      clientClosing = false;
      return _signOut(closeDB: closeDB, clearWallet: clearWallet);
    }
    client = null;
    clientClosing = false;
    if (clearWallet) BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(null));
    if (closeDB) await dbCommon.close();
  }

  Future<List> reSignIn(bool needPwd, {int delayMs = 200}) async {
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.address.isEmpty) {
      AppScreen.go(Global.appContext);
      await signOut(closeDB: true, clearWallet: true);
      return [null, false];
    }

    if (!isClientCreated) {
      logger.i("$TAG - reSignIn - unsubscribe stream when client no created - wallet:$wallet");
      await signOut(clearWallet: false, closeDB: false);
    }

    await Future.delayed(Duration(milliseconds: delayMs));
    _statusSink.add(ClientConnectStatus.connecting);

    // client
    String? walletPwd = needPwd ? (await authorization.getWalletPassword(wallet.address)) : (await walletCommon.getPassword(wallet.address));
    return await signIn(wallet, fetchRemote: false, password: walletPwd);
  }

  void connectCheck({bool reconnect = false}) {
    if (application.inBackGround) return;
    if (client == null) return;
    if (connectChecking) return;
    connectChecking = true;
    _statusSink.add(ClientConnectStatus.connecting);

    // reconnect
    if (reconnect) {
      reSignIn(false, delayMs: 0).then((value) {
        chatOutCommon.sendPing([address ?? ""], true);
      });
    } else {
      chatOutCommon.sendPing([address ?? ""], true);
    }

    // loop
    Future.delayed(Duration(milliseconds: 1000), () {
      connectChecking = false;
      if (status == ClientConnectStatus.connecting) {
        _connectingVisibleSink.add(true);
        connectCheck(reconnect: reconnect);
      }
    });
  }

  void connectSuccess({bool force = false}) {
    if (client == null) return;
    if (!force && (status != ClientConnectStatus.connecting)) {
      connectChecking = false;
      _connectingVisibleSink.add(false);
      return;
    }
    _statusSink.add(ClientConnectStatus.connected);
    // visible
    Future.delayed(Duration(milliseconds: 500), () {
      connectChecking = false;
      if (status == ClientConnectStatus.connected) {
        _connectingVisibleSink.add(false);
      }
    });
  }
}
