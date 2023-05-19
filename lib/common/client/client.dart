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
import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
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
  static const int disconnecting = 3;
}

String? getPubKeyFromTopicOrChatId(String s) {
  final i = s.lastIndexOf('.');
  final pubKey = (i >= 0) ? s.substring(i + 1) : s;
  return Validate.isNknPublicKey(pubKey) ? pubKey : null;
}

Future<String?> getPubKeyFromWallet(String? walletAddress, String? walletPwd) async {
  if (walletAddress == null || walletAddress.isEmpty || walletPwd == null || walletPwd.isEmpty) return null;
  try {
    String keystore = await walletCommon.getKeystore(walletAddress);
    List<String> seedRpcList = await RPC.getRpcServers(walletAddress, measure: true);
    Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: walletPwd, seedRPCServerAddr: seedRpcList));
    if (nknWallet.publicKey.isEmpty) return null;
    return hexEncode(nknWallet.publicKey);
  } catch (e, st) {
    handleError(e, st);
  }
  return null;
}

class ClientCommon with Tag {
  // ignore: close_sinks
  StreamController<int> _statusController = StreamController<int>.broadcast();
  StreamSink<int> get _statusSink => _statusController.sink;
  Stream<int> get statusStream => _statusController.stream;

  StreamSubscription? _onErrorStreamSubscription;
  StreamSubscription? _onConnectStreamSubscription;
  StreamSubscription? _onMessageStreamSubscription;

  Lock _lock = new Lock();

  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  // address
  String? get address => client?.address ?? _lastAddress; // == chat_id / wallet.publicKey
  String? _lastAddress;

  // status
  int status = ClientConnectStatus.disconnected;
  bool get isClientConnecting => (client == null) && ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected));
  bool get isClientOK => (client != null) && ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected));
  bool get isClientStop => (status == ClientConnectStatus.disconnecting) || (status == ClientConnectStatus.disconnected);

  // complete
  Completer? reconnectCompleter;
  Completer? pingCompleter;

  // tag
  bool isNetworkOk = true;

  ClientCommon() {
    // network
    Connectivity().onConnectivityChanged.listen((status) {
      if (status == ConnectivityResult.none) {
        logger.w("$TAG - onConnectivityChanged - none - status:$status");
      } else {
        logger.i("$TAG - onConnectivityChanged - okay - status:$status");
      }
      isNetworkOk = status != ConnectivityResult.none;
      ping(status: true, maxWaitTimes: 1);
    });
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

  /// **************************************************************************************** ///
  /// ***************************************   Sign   *************************************** ///
  /// **************************************************************************************** ///

  Future<bool> signIn(WalletSchema? wallet, String? password, {bool toast = false, Function(bool, bool)? loading}) async {
    if ((wallet == null) || wallet.address.isEmpty) return false;
    // status (just updated(connecting) in this func)
    if (status == ClientConnectStatus.connecting) return false;
    loading?.call(true, false);
    await waitReconnect(); // before set status
    status = ClientConnectStatus.connecting;
    _statusSink.add(ClientConnectStatus.connecting);
    // client
    bool success = await _lock.synchronized(() async {
      bool success = false;
      int tryTimes = 0;
      while (true) {
        Map<String, dynamic> result = await _signIn(wallet, password, onDatabaseOpen: () => loading?.call(true, true));
        Client? c = result["client"];
        bool canTry = result["canTry"];
        password = result["password"]?.toString();
        String text = result["text"]?.toString() ?? "";
        if (toast && text.isNotEmpty) {
          if (!canTry || (tryTimes % 3 == 0)) {
            Toast.show(text);
          }
        }
        if (c != null) {
          logger.i("$TAG - signIn - try success - tryTimes:$tryTimes - address:${c.address} - wallet:$wallet - password:$password");
          success = true;
          client = c;
          _startListen(wallet);
          ping(); // await
          break;
        } else if (!canTry) {
          logger.e("$TAG - signIn - try broken - tryTimes:$tryTimes - address:${c?.address} - wallet:$wallet - password:$password");
          await signOut(clearWallet: true, closeDB: true, lock: false);
          break;
        }
        logger.w("$TAG - signIn - try again - tryTimes:$tryTimes - wallet:$wallet - password:$password");
        if ((tryTimes > 0) && isNetworkOk) await RPC.setRpcServers(wallet.address, []);
        tryTimes++;
        _statusSink.add(ClientConnectStatus.connecting); // need flush
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
      }
      return success;
    });
    // status (set when onMessageReceive)
    loading?.call(false, true);
    return success;
  }

  Future<Map<String, dynamic>> _signIn(WalletSchema wallet, String? password, {Function? onDatabaseOpen}) async {
    // password
    try {
      password = (password?.isNotEmpty == true) ? password : (await authorization.getWalletPassword(wallet.address));
      if ((password == null) || password.isEmpty) {
        logger.w("$TAG - _signIn - password is null - wallet:$wallet");
        return {"client": null, "canTry": false}; // , "text": "password empty"
      }
      if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
        logger.w("$TAG - _signIn - password error - wallet:$wallet");
        return {"client": null, "canTry": false, "text": "password wrong"};
      }
    } catch (e, st) {
      handleError(e, st, toast: false, upload: false);
      return {"client": null, "canTry": false, "text": "password error"};
    }
    // wallet
    String? pubKey = wallet.publicKey;
    String? seed = await walletCommon.getSeed(wallet.address);
    try {
      String keystore = await walletCommon.getKeystore(wallet.address);
      Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: password));
      pubKey = nknWallet.publicKey.isEmpty ? null : hexEncode(nknWallet.publicKey);
      seed = nknWallet.seed.isEmpty ? null : hexEncode(nknWallet.seed);
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": false, "password": password, "text": "wallet error"};
    }
    if ((pubKey == null) || pubKey.isEmpty || (seed == null) || seed.isEmpty) {
      logger.e("$TAG - _signIn - wallet restore error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
      return {"client": null, "canTry": false, "password": password, "text": "wallet info empty"};
    }
    // database
    try {
      if (!dbCommon.isOpen()) {
        await dbCommon.open(pubKey, seed);
      }
      if (!dbCommon.isOpen()) {
        logger.e("$TAG - _signIn - database opened fail - wallet:$wallet - pubKey:$pubKey - seed:$seed");
        return {"client": null, "canTry": false, "password": password, "text": "database open fail"};
      }
      BlocProvider.of<WalletBloc>(Settings.appContext).add(DefaultWallet(wallet.address));
      ContactSchema? me = await contactCommon.getMe(selfAddress: pubKey, canAdd: true, fetchWalletAddress: true);
      contactCommon.meUpdateSink.add(me);
      onDatabaseOpen?.call();
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": false, "password": password, "text": "database error"};
    }
    // common
    try {
      bool reset = (_lastAddress == null) || (_lastAddress != wallet.publicKey);
      await chatCommon.reset(wallet.address, reset: reset);
      await chatInCommon.run(reset: reset);
      await chatOutCommon.run(reset: reset);
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": false, "password": password, "text": "reset error"};
    }
    // client
    Client? client;
    try {
      List<String> seedRpcList = await RPC.getRpcServers(wallet.address, measure: true);
      ClientConfig config = ClientConfig(seedRPCServerAddr: seedRpcList);
      while ((client?.address == null) || (client?.address.isEmpty == true)) {
        client = await Client.create(hexDecode(seed), numSubClients: 4, config: config); // network
      }
      _lastAddress = client?.address;
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": true, "password": password, "text": getErrorShow(e)};
    }
    // status no update (updated by ping/pang)
    return {"client": client, "canTry": true, "password": password};
  }

  Future signOut({bool lock = true, bool clearWallet = false, bool closeDB = true}) async {
    // status (just updated(disconnecting/disconnected) in this func)
    if (status == ClientConnectStatus.disconnecting || status == ClientConnectStatus.disconnected) return;
    await waitReconnect(); // before set status
    status = ClientConnectStatus.disconnecting;
    _statusSink.add(ClientConnectStatus.disconnecting);
    // client
    if (lock) {
      await _lock.synchronized(() async {
        int tryTimes = 0;
        while (true) {
          bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
          if (success) {
            logger.i("$TAG - signOut - try success - lock_on - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
            break;
          }
          logger.e("$TAG - signOut - try again - lock_on - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
          tryTimes++;
          _statusSink.add(ClientConnectStatus.disconnecting); // need flush
          await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
        }
      });
    } else {
      int tryTimes = 0;
      while (true) {
        bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
        if (success) {
          logger.i("$TAG - signOut - try success - lock_off - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
          break;
        }
        logger.e("$TAG - signOut - try again - lock_off - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
        tryTimes++;
        _statusSink.add(ClientConnectStatus.disconnecting); // need flush
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
      }
    }
    // status
    status = ClientConnectStatus.disconnected;
    _statusSink.add(ClientConnectStatus.disconnected);
    return;
  }

  Future<bool> _signOut({bool clearWallet = true, bool closeDB = true}) async {
    try {
      await chatOutCommon.pause(reset: closeDB);
      await client?.close();
      await _stopListen();
      await chatInCommon.pause(reset: closeDB);
      client = null;
      if (clearWallet) BlocProvider.of<WalletBloc>(Settings.appContext).add(DefaultWallet(null));
      if (closeDB) await dbCommon.close();
      return true;
    } catch (e, st) {
      handleError(e, st);
    }
    return false;
  }

  void _startListen(WalletSchema wallet) {
    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) async {
      logger.e("$TAG - onError -> event:${event.toString()}");
      handleError(event, null, text: "client error");
      await reconnect(force: true);
    });
    // client connect (just listen once)
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) async {
      logger.i("$TAG - onConnect -> node:${event.node} - rpcServers:${event.rpcServers}");
      if (!isClientStop) {
        status = ClientConnectStatus.connected;
        _statusSink.add(ClientConnectStatus.connected);
      }
      RPC.addRpcServers(wallet.address, event.rpcServers ?? []); // await
    });
    // client receive (looper)
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
      logger.d("$TAG - onMessage -> from:${event.src} - data:${((event.data is String) && (event.data as String).length <= 1000) ? event.data : "[data to long~~~]"}");
      MessageSchema? receive = MessageSchema.fromReceive(event);
      if (!isClientStop) {
        if (status != ClientConnectStatus.connected) {
          status = ClientConnectStatus.connected;
          _statusSink.add(ClientConnectStatus.connected);
        } else if ((receive?.isTargetSelf == true) && (receive?.contentType == MessageContentType.ping)) {
          int nowAt = DateTime.now().millisecondsSinceEpoch;
          if ((nowAt - (receive?.sendAt ?? 0)) < 1 * 60 * 1000) {
            _statusSink.add(ClientConnectStatus.connected);
          }
        }
      }
      chatInCommon.onMessageReceive(receive); // await
    });
  }

  Future _stopListen() async {
    try {
      await _onErrorStreamSubscription?.cancel();
      await _onConnectStreamSubscription?.cancel();
      await _onMessageStreamSubscription?.cancel();
    } catch (e, st) {
      handleError(e, st);
    }
  }

  /// **************************************************************************************** ///
  /// *********************************   Connect   ****************************************** ///
  /// **************************************************************************************** ///

  Future<bool> waitClientOk() async {
    if (clientCommon.isClientStop) {
      logger.e("$TAG - waitClientOk - closed - client:${clientCommon.client == null} - status:${clientCommon.status}");
      return false;
    }
    // interval
    int interval = 500;
    int gap = DateTime.now().millisecondsSinceEpoch - application.goForegroundAt;
    if (gap < interval) await Future.delayed(Duration(milliseconds: interval - gap));
    // reconnect
    await waitReconnect();
    // status
    int tryTimes = 0;
    while (!clientCommon.isClientOK) {
      if (clientCommon.isClientStop) break;
      logger.w("$TAG - waitClientOk - connecting - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
      tryTimes++;
      await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
    }
    if (!clientCommon.isClientOK) {
      logger.w("$TAG - waitClientOk - broken - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
      return false;
    } else if (tryTimes > 0) {
      logger.d("$TAG - waitClientOk - success - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
      return true;
    }
    return true;
  }

  Future waitReconnect() async {
    if ((reconnectCompleter != null) && !(reconnectCompleter?.isCompleted == true)) {
      logger.i("$TAG - waitReconnect - client:${clientCommon.client == null} - status:$status");
      await reconnectCompleter?.future;
    }
  }

  Future<bool> reconnect({bool force = false}) async {
    if (isClientStop) return false;
    // connecting wait
    if (isClientConnecting) {
      int tryTimes = 0;
      while (!clientCommon.isClientOK) {
        if (clientCommon.isClientStop) break;
        logger.w("$TAG - reconnect -  connecting wait - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
        tryTimes++;
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
      }
      logger.i("$TAG - reconnect - connecting complete - ok:${clientCommon.isClientOK} - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
      return clientCommon.isClientOK;
    }
    // complete check
    if ((reconnectCompleter != null) && !(reconnectCompleter?.isCompleted == true)) {
      if (force) {
        logger.i("$TAG - reconnect - force complete");
        await reconnectCompleter?.future;
        return await reconnect();
      } else {
        logger.i("$TAG - reconnect - last complete");
        return await reconnectCompleter?.future;
      }
    } else {
      logger.i("$TAG - reconnect - new complete");
      reconnectCompleter = Completer();
    }
    // network
    while (!isNetworkOk) {
      logger.w("$TAG - reconnect - wait network ok");
      await Future.delayed(Duration(milliseconds: 500));
    }
    // password
    WalletSchema? wallet = await walletCommon.getDefault();
    if ((wallet == null) || wallet.address.isEmpty) {
      logger.w("$TAG - reconnect - wallet is empty - address:$address");
      AppScreen.go(Settings.appContext);
      await signOut(clearWallet: true, closeDB: true);
      reconnectCompleter?.complete();
      reconnectCompleter = null;
      return false;
    }
    String? password = await walletCommon.getPassword(wallet.address);
    // client new
    Client? c;
    int tryTimes = 0;
    while (true) {
      Map<String, dynamic> result = await _signIn(wallet, password);
      c = result["client"];
      password = result["password"]?.toString();
      if (c != null) break;
      logger.w("$TAG - reconnect - signIn again - tryTimes:$tryTimes - wallet:$wallet - password:$password");
      if ((tryTimes > 1) && isNetworkOk) await RPC.setRpcServers(wallet.address, []);
      tryTimes++;
      await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
    }
    logger.i("$TAG - reconnect - signIn success - tryTimes:$tryTimes - address:${c.address}");
    // receive queues
    int interval = 500;
    int gap = DateTime.now().millisecondsSinceEpoch - application.goForegroundAt;
    if (gap < interval) await Future.delayed(Duration(milliseconds: interval - gap));
    await chatInCommon.waitReceiveQueues("reconnect");
    // client old
    tryTimes = 0;
    while (true) {
      if (await _signOut(clearWallet: false, closeDB: false)) break;
      logger.e("$TAG - reconnect - signOut again - tryTimes:$tryTimes");
      tryTimes++;
      await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
    }
    logger.i("$TAG - reconnect - signOut success - tryTimes:$tryTimes - address:$address");
    // client replace
    client = c;
    _startListen(wallet);
    logger.i("$TAG - reconnect - success - force:$force - address:$address");
    reconnectCompleter?.complete();
    await Future.delayed(Duration(milliseconds: 200));
    reconnectCompleter = null;
    ping(status: true); // await must after reconnectCompleter
    return true;
  }

  Future ping({bool status = false, int maxWaitTimes = Settings.tryTimesClientConnectWait}) async {
    if (isClientStop) return;
    if ((pingCompleter != null) && !(pingCompleter?.isCompleted == true)) {
      return await pingCompleter?.future;
    } else {
      pingCompleter = Completer();
    }
    int tryTimes = 0;
    while (true) {
      await waitReconnect();
      if (isClientStop) {
        logger.i("$TAG - ping - closed break - tryTimes:$tryTimes - status:$status");
        break;
      } else if (!isNetworkOk) {
        logger.w("$TAG - ping - wait network ok - tryTimes:$tryTimes - status:$status");
        if (status) _statusSink.add(ClientConnectStatus.connecting);
        await Future.delayed(Duration(milliseconds: 1000));
        continue;
      } else if (isClientOK) {
        logger.v("$TAG - ping - ping - tryTimes:$tryTimes - address:$address");
        if (status) _statusSink.add(ClientConnectStatus.connecting);
        await chatOutCommon.sendPing([address ?? ""], true);
        break;
      } else if (tryTimes < maxWaitTimes) {
        logger.i("$TAG - ping - wait connecting - tryTimes:$tryTimes - status:$status");
        ++tryTimes;
        if (status) _statusSink.add(ClientConnectStatus.connecting);
        await Future.delayed(Duration(milliseconds: maxWaitTimes <= 1 ? (2 * 1000) : 1000));
        continue;
      } else {
        logger.w("$TAG - ping - reconnect start - tryTimes:$tryTimes");
        if (await reconnect()) {
          tryTimes = 0;
          await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
          continue;
        }
        logger.e("$TAG - ping - reconnect fail - tryTimes:$tryTimes");
        break;
      }
    }
    pingCompleter?.complete();
    await Future.delayed(Duration(milliseconds: 200));
    pingCompleter = null;
  }
}
