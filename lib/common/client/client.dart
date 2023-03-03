import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

class ClientConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
// static const int stopping = 3;
}

String? getPubKeyFromTopicOrChatId(String s) {
  final i = s.lastIndexOf('.');
  final pubKey = i >= 0 ? s.substring(i + 1) : s;
  return Validate.isNknPublicKey(pubKey) ? pubKey : null;
}

Future<String?> getPubKeyFromWallet(String? walletAddress, String? walletPwd) async {
  if (walletAddress == null || walletAddress.isEmpty || walletPwd == null || walletPwd.isEmpty) return null;
  try {
    String keystore = await walletCommon.getKeystore(walletAddress);
    List<String> seedRpcList = await Global.getRpcServers(walletAddress, measure: true);
    Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: walletPwd, seedRPCServerAddr: seedRpcList));
    if (nknWallet.publicKey.isEmpty) return null;
    return hexEncode(nknWallet.publicKey);
  } catch (e, st) {
    handleError(e, st);
  }
  return null;
}

class ClientCommon with Tag {
  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  // == chat_id
  String? get address => client?.address;

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

  bool isNetworkOk = true;

  int status = ClientConnectStatus.disconnected;
  bool clientClosing = false;
  bool clientResigning = false;

  int checkTimes = 0;

  ClientCommon() {
    // network
    Connectivity().onConnectivityChanged.listen((status) {
      if (status == ConnectivityResult.none) {
        logger.w("$TAG - onConnectivityChanged - status:$status");
        isNetworkOk = false;
        _statusSink.add(ClientConnectStatus.connecting);
      } else {
        logger.i("$TAG - onConnectivityChanged - status:$status");
        isNetworkOk = true;
        if (isClientCreated) connectCheck(force: true, reconnect: true);
      }
    });
    // client
    status = ClientConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      handleError(event, null);
      reSignIn(false);
    });
    clientClosing = false;
    clientResigning = false;
    // check
    checkTimes = 0;
  }

  String? getPublicKey() {
    Uint8List? pkOriginal = client?.publicKey;
    if ((pkOriginal == null) || pkOriginal.isEmpty) return null;
    try {
      String pk = hexEncode(pkOriginal);
      return pk.isEmpty ? null : pk;
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  // TODO:GG 整改，调整不合格的逻辑
  /// ******************************************************   Client   ****************************************************** ///

  Future<Map<String, dynamic>> signIn(WalletSchema? wallet, {bool fetchRemote = true, Function(bool, int)? loadingVisible, String? password}) {
    return _lock.synchronized(() {
      return _signIn(wallet, fetchRemote: fetchRemote, loadingVisible: loadingVisible, password: password);
    });
  }

  // TODO:GG remove params tryTimes, use retry with subscribe
  // return [client, pwdError]
  Future<Map<String, dynamic>> _signIn(WalletSchema? wallet, {bool fetchRemote = true, Function(bool, int)? loadingVisible, String? password, int tryTimes = 1}) async {
    // if (client != null) await close(); // async boom!!!
    if (wallet == null || wallet.address.isEmpty) return {"client": null, "pwd_error": false};

    // pubKey/seed
    String? pubKey = wallet.publicKey;
    String? seed = await walletCommon.getSeed(wallet.address);

    try {
      // password get
      password = (password?.isNotEmpty == true) ? password : (await authorization.getWalletPassword(wallet.address));
      if (password == null || password.isEmpty) {
        return {"client": null, "pwd_error": true};
      }

      // ui + status
      loadingVisible?.call(true, tryTimes);
      _statusSink.add(ClientConnectStatus.connecting);

      // password check
      if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
        logger.w("$TAG - signIn - password error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
        throw Exception("wrong password");
      }

      // database by cache
      if ((pubKey.isNotEmpty == true) && (seed?.isNotEmpty == true)) {
        if (!(dbCommon.isOpen() == true)) {
          await dbCommon.open(pubKey, seed!);
          // wallet + contact
          BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
          ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true, needWallet: true);
          contactCommon.meUpdateSink.add(me);
        }
      }

      // rpc wallet
      if (fetchRemote) {
        String keystore = await walletCommon.getKeystore(wallet.address);
        Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: password));
        pubKey = nknWallet.publicKey.isEmpty ? null : hexEncode(nknWallet.publicKey);
        seed = nknWallet.seed.isEmpty ? null : hexEncode(nknWallet.seed);
      }

      // check pubKey/seed
      if (pubKey == null || pubKey.isEmpty || seed == null || seed.isEmpty) {
        loadingVisible?.call(false, tryTimes);
        if (!fetchRemote) {
          logger.w("$TAG - signIn - pubKey/seed error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password);
        } else {
          logger.e("$TAG - signIn - pubKey/seed error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          _statusSink.add(ClientConnectStatus.disconnected);
          return {"client": null, "pwd_error": false};
        }
      }

      // database by remote
      if (!(dbCommon.isOpen() == true)) {
        await dbCommon.open(pubKey, seed);
        // wallet + contact
        BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
        ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true, needWallet: true);
        contactCommon.meUpdateSink.add(me);
      }
    } catch (e, st) {
      // password/keystore
      if ((e.toString().contains("password") == true) || (e.toString().contains("keystore") == true)) {
        if (!fetchRemote) {
          logger.w("$TAG - signIn - password/keystore error, reSignIn by check - wallet:$wallet");
          return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password);
        }
        handleError(e, st);
        _statusSink.add(ClientConnectStatus.disconnected);
        return {"client": null, "pwd_error": true};
      }
      await Future.delayed(Duration(seconds: 1));
      return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password);
    }

    try {
      // client create
      if (client == null) {
        chatCommon.reset();
        chatInCommon.reset();
        chatOutCommon.reset();

        List<String> seedRpcList = await Global.getRpcServers(wallet.address, measure: true);
        while (client == null) {
          client = await Client.create(hexDecode(seed), numSubClients: 4, config: ClientConfig(seedRPCServerAddr: seedRpcList));
        }

        loadingVisible?.call(false, tryTimes);

        // client error
        _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
          logger.e("$TAG - signIn - onError -> event:${event.toString()}");
          _onErrorSink.add(event);
        });

        // client connect (just listen once)
        Completer completer = Completer();
        _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
          logger.i("$TAG - signIn - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
          connectSuccess();
          Global.addRpcServers(wallet.address, event.rpcServers ?? []); // await
          if (!completer.isCompleted) completer.complete();
        });

        // client receive (looper)
        _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
          logger.i("$TAG - signIn - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
          connectSuccess();
          chatInCommon.onMessageReceive(MessageSchema.fromReceive(event));
        });
      } else {
        loadingVisible?.call(false, tryTimes);
        client?.reconnect(); // await // no onConnect callback
        connectCheck(force: true);
        // no status update (updated by ping/pang)
      }
      // await completer.future;
      return {"client": client, "pwd_error": false};
    } catch (e, st) {
      loadingVisible?.call(false, tryTimes);
      // toast
      if (Settings.debug || ((tryTimes != 0) && (tryTimes % 2 == 0))) handleError(e, st);
      await Future.delayed(Duration(seconds: tryTimes >= 3 ? 3 : tryTimes));
      // loop login
      await _signOut(clearWallet: false, closeDB: false);
      await Global.setRpcServers(wallet.address, []);
      await Future.delayed(Duration(milliseconds: 500));
      return _signIn(wallet, fetchRemote: true, loadingVisible: loadingVisible, password: password, tryTimes: ++tryTimes);
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
    } catch (e, st) {
      handleError(e, st);
      await Future.delayed(Duration(milliseconds: 200));
      clientClosing = false;
      return _signOut(clearWallet: clearWallet, closeDB: closeDB);
    }
    client = null;
    clientClosing = false;
    if (clearWallet) BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(null));
    if (closeDB) await dbCommon.close();
  }

  Future<Map<String, dynamic>> reSignIn(bool needPwd, {int delayMs = 0}) async {
    clientResigning = true;
    await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;

    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.address.isEmpty) {
      AppScreen.go(Global.appContext);
      await signOut(clearWallet: true, closeDB: true);
      clientResigning = false;
      return {"client": null, "pwd_error": false};
    }

    if (!isClientCreated) {
      logger.i("$TAG - reSignIn - unsubscribe stream when client no created - wallet:$wallet");
      await signOut(clearWallet: false, closeDB: false);
    }

    await Future.delayed(Duration(milliseconds: 200));
    _statusSink.add(ClientConnectStatus.connecting);

    // client
    String? walletPwd = needPwd ? (await authorization.getWalletPassword(wallet.address)) : (await walletCommon.getPassword(wallet.address));
    Map<String, dynamic> result = await signIn(wallet, fetchRemote: false, password: walletPwd);
    clientResigning = false;
    return result;
  }

  void connectCheck({bool force = false, bool reconnect = false}) async {
    if (reconnect) {
      // checkTimes = 0;
      await _connectCheck(force: force, reconnect: reconnect);
    } else if (checkTimes <= 0) {
      await _connectCheck(force: force, reconnect: reconnect);
    }
  }

  Future _connectCheck({bool force = false, bool reconnect = false}) async {
    bool isDisClient = (client == null) && !reconnect;
    bool isDisForce = !force && (status == ClientConnectStatus.connected);
    bool isConnected = (checkTimes > 0) && (status == ClientConnectStatus.connected);
    if (!isNetworkOk || isDisClient || isDisForce || isConnected) {
      logger.d("$TAG - connectCheck - break - checkTimes:$checkTimes - isNetworkOk:$isNetworkOk - isDisClient:$isDisClient - isDisForce:$isDisForce - isConnected:$isConnected");
      checkTimes = 0;
      return;
    }
    if (checkTimes == 0) _statusSink.add(ClientConnectStatus.connecting);
    if (!reconnect) checkTimes++;
    logger.i("$TAG - connectCheck - run - checkTimes:$checkTimes");

    if (checkTimes <= 3) {
      // reconnect
      if (reconnect) {
        if (!clientResigning) reSignIn(false); // await
      } else {
        if (checkTimes == 2) _connectingVisibleSink.add(true);
        if (address?.isNotEmpty == true) chatOutCommon.sendPing([address ?? ""], true); // await tryTimes
        Future.delayed(Duration(seconds: 2), () => _connectCheck());
      }
    } else {
      // create
      WalletSchema? wallet = await walletCommon.getDefault();
      if (wallet == null || wallet.address.isEmpty) {
        AppScreen.go(Global.appContext);
        await signOut(clearWallet: true, closeDB: true);
        return;
      }
      await signOut(clearWallet: false, closeDB: false);
      await Future.delayed(Duration(milliseconds: 200));
      String? walletPwd = await walletCommon.getPassword(wallet.address);
      await signIn(wallet, fetchRemote: true, password: walletPwd);
    }
  }

  void connectSuccess() {
    if (client == null) return;
    if (status != ClientConnectStatus.connected) {
      logger.i("$TAG - connectSuccess - ok - checkTimes:$checkTimes");
      _statusSink.add(ClientConnectStatus.connected);
    }
    _connectingVisibleSink.add(false);
    checkTimes = 0;
  }
}
