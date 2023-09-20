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
import 'package:nmobile/common/application.dart';
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
  static const int connectPing = 2;
  static const int connected = 3;
  static const int disconnecting = 4;
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

  // history
  ClientConfig? _lastConfig;
  String? _lastAddress;

  // status
  int status = ClientConnectStatus.disconnected;

  bool get isClientConnecting => (status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connectPing);
  bool get isClientReconnecting => (reconnectCompleter != null) && !(reconnectCompleter?.isCompleted == true);
  bool get isClientOK => (client != null) && (status == ClientConnectStatus.connected) && !isClientReconnecting;
  bool get isClientStop => (status == ClientConnectStatus.disconnecting) || (status == ClientConnectStatus.disconnected);

  // complete
  Completer? clientOkCompleter;
  Completer? reconnectCompleter;
  // Completer? pingCompleter;

  // tag
  bool isNetworkOk = true;

  void init() {
    // application
    application.appLifeStream.listen((bool inBackground) {
      if (isClientStop) return;
      if (inBackground) return;
      int gap = application.goForegroundAt - application.goBackgroundAt;
      if (gap < Settings.gapClientReAuthMs) {
        reconnect(force: true); // await
      } else {
        checkClientOk("appLifeStream_foreground", ping: true); // await
        // authing in app.dart
      }
    });
    // network
    Connectivity().onConnectivityChanged.listen((status) {
      if (status == ConnectivityResult.none) {
        logger.w("$TAG - onConnectivityChanged - none - status:$status");
      } else {
        logger.i("$TAG - onConnectivityChanged - okay - status:$status");
      }
      bool newNetworkOk = status != ConnectivityResult.none;
      bool isDiff = newNetworkOk != isNetworkOk;
      isNetworkOk = newNetworkOk;
      if (isClientStop) return;
      if (isNetworkOk) {
        if (isDiff) {
          reconnect(force: true); // await
        } else {
          if (!isClientOK) {
            reconnect(); // await
          } else {
            checkClientOk("onConnectivityChanged", ping: true); // await
          }
        }
      } else {
        _statusSink.add(ClientConnectStatus.connecting);
      }
    });
  }

  String? getPublicKey() {
    Uint8List? pkOriginal = client?.publicKey;
    if ((pkOriginal == null) || pkOriginal.isEmpty) return address;
    try {
      String pk = hexEncode(pkOriginal);
      return pk.isEmpty ? address : pk;
    } catch (e, st) {
      handleError(e, st);
    }
    return address;
  }

  Uint8List? getSeed() {
    return client?.seed;
  }

  /// **************************************************************************************** ///
  /// ***************************************   Sign   *************************************** ///
  /// **************************************************************************************** ///

  Future<bool> signIn(WalletSchema? wallet, {String? pwd, bool toast = false, Function(bool, bool, bool)? loading}) async {
    if ((wallet == null) || wallet.address.isEmpty) return false;
    bool success = await _lock.synchronized(() async {
      // password (before status update)
      String? password = pwd ??
          await authorization.getWalletPassword(
            wallet.address,
            onInput: (visible) => loading?.call(true, visible, false),
          );
      // status (just updated(connecting) in this func)
      if (status == ClientConnectStatus.connecting) return false;
      status = ClientConnectStatus.connecting;
      _statusSink.add(ClientConnectStatus.connecting);
      loading?.call(true, false, false);
      // client
      bool success = false;
      int tryTimes = 0;
      while (true) {
        Map<String, dynamic> result = await _signIn(
          wallet,
          password,
          onDatabaseOpen: () => loading?.call(true, false, true),
        );
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
      // status (set when onMessageReceive)
      loading?.call(false, false, true);
      return success;
    });
    if (success) checkClientOk("signIn", ping: true); // await
    return success;
  }

  Future<Map<String, dynamic>> _signIn(WalletSchema wallet, String? password, {Function? onDatabaseOpen}) async {
    while (!isNetworkOk) {
      logger.w("$TAG - _signIn - wait network ok");
      await Future.delayed(Duration(milliseconds: 500));
    }
    // password
    try {
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
    try {
      List<String> seedRpcList = await RPC.getRpcServers(wallet.address, measure: true);
      _lastConfig = ClientConfig(seedRPCServerAddr: seedRpcList);
      if (client == null) {
        while ((client?.address == null) || (client?.address.isEmpty == true)) {
          client = await Client.create(hexDecode(seed), numSubClients: 4, config: _lastConfig); // network
        }
        logger.i("$TAG - _signIn - client create OK - wallet:$wallet - pubKey:$pubKey - seed:$seed");
        _startListen(wallet);
      } else {
        await client?.recreate(hexDecode(seed), numSubClients: 4, config: _lastConfig); // network
        logger.i("$TAG - _signIn - client create(re) OK - wallet:$wallet - pubKey:$pubKey - seed:$seed");
      }
      _lastAddress = client?.address;
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": true, "password": password, "text": getErrorShow(e)};
    }
    // status no update (updated by ping/pang)
    return {"client": client, "canTry": true, "password": password};
  }

  Future signOut({bool clearWallet = false, bool closeDB = true, bool lock = true}) async {
    Func func = () async {
      // status (just updated(disconnecting/disconnected) in this func)
      if ((status == ClientConnectStatus.disconnecting) || (status == ClientConnectStatus.disconnected)) return;
      status = ClientConnectStatus.disconnecting;
      _statusSink.add(ClientConnectStatus.disconnecting);
      // msgReceives
      await chatInCommon.waitReceiveQueues("signOut");
      // client
      int tryTimes = 0;
      while (true) {
        bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
        if (success) {
          logger.i("$TAG - signOut - try success - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
          break;
        }
        logger.e("$TAG - signOut - try again - tryTimes:$tryTimes - clearWallet:$clearWallet - closeDB:$closeDB");
        tryTimes++;
        _statusSink.add(ClientConnectStatus.disconnecting); // need flush
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
      }
      // status
      status = ClientConnectStatus.disconnected;
      _statusSink.add(ClientConnectStatus.disconnected);
    };
    if (lock) {
      await _lock.synchronized(() async {
        await func();
      });
    } else {
      await func();
    }
    return;
  }

  Future<bool> _signOut({bool clearWallet = true, bool closeDB = true}) async {
    try {
      await chatOutCommon.pause(reset: closeDB);
      await Future.delayed(Duration(milliseconds: 500)); // wait message from client
      await client?.close();
      await Future.delayed(Duration(milliseconds: 500)); // wait message from listen
      await _stopListen();
      await chatInCommon.waitReceiveQueues("_signOut"); // wait db_insert from onMessage
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
      logger.e("$TAG - onError ->> event:${event.toString()}");
      handleError(event, null);
      if (isClientStop) return;
      WalletSchema? wallet = await walletCommon.getDefault();
      if ((wallet == null) || wallet.address.isEmpty) {
        logger.w("$TAG - onError - wallet is empty - address:$address");
        AppScreen.go(Settings.appContext);
        await signOut(clearWallet: true, closeDB: true);
        return;
      }
      logger.i("$TAG - onError - wallet is ok - address:$address");
      await signOut(clearWallet: false, closeDB: false);
      await Future.delayed(Duration(milliseconds: 500));
      String? password = await walletCommon.getPassword(wallet.address);
      await signIn(wallet, pwd: password);
    });
    // client connect (just listen once)
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) async {
      logger.i("$TAG - onConnect ->> node:${event.node} - rpcServers:${event.rpcServers}");
      RPC.addRpcServers(wallet.address, event.rpcServers ?? []); // await
      if (isClientStop) return;
      checkClientOk("onConnect", ping: true); // await
    });
    // client receive (looper)
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async {
      logger.d("$TAG - onMessage ->> from:${event.src} - data:${((event.data is String) && (event.data as String).length <= 1000) ? event.data : "[data to long~~~]"}");
      MessageSchema? receive = MessageSchema.fromReceive(event);
      chatInCommon.onMessageReceive(receive); // await
      // connect_status
      if (isClientStop) return;
      if ((receive?.isTargetSelf != true) || (receive?.contentType != MessageContentType.ping)) return;
      if ((DateTime.now().millisecondsSinceEpoch - (receive?.sendAt ?? 0)) > 1000) return;
      if (status != ClientConnectStatus.connected) {
        logger.i("$TAG - onMessage ->> ping self - gap:${(DateTime.now().millisecondsSinceEpoch - (receive?.sendAt ?? 0))}");
        _lock.synchronized(() async {
          status = ClientConnectStatus.connected;
          _statusSink.add(ClientConnectStatus.connected);
        }); // await
      } else {
        _statusSink.add(ClientConnectStatus.connected);
      }
      // completer
      try {
        if (clientOkCompleter?.isCompleted != true) clientOkCompleter?.complete(true);
      } catch (e, st) {
        handleError(e, st);
      }
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

  Future<bool> reconnect({bool force = false}) async {
    if (isClientStop) {
      logger.w("$TAG - reconnect - client closed - client:${client == null} - status:$status");
      return false;
    }
    // completer
    if (isClientReconnecting) {
      try {
        logger.i("$TAG - reconnect - wait last completer - isClientOK:$isClientOK");
        await reconnectCompleter?.future;
        if (!force) {
          logger.i("$TAG - reconnect - return last completer - isClientOK:$isClientOK");
          return await checkClientOk("reconnect_last", ping: true);
        } else {
          logger.i("$TAG - reconnect - after last completer - isClientOK:$isClientOK");
        }
      } catch (e, st) {
        handleError(e, st);
      }
    }
    // receive_queue
    await chatInCommon.waitReceiveQueues("reconnect");
    // complete check
    bool success = await _lock.synchronized(() async {
      // password
      WalletSchema? wallet = await walletCommon.getDefault();
      if ((wallet == null) || wallet.address.isEmpty) {
        logger.w("$TAG - reconnect - wallet is empty - address:$address");
        AppScreen.go(Settings.appContext);
        await signOut(clearWallet: true, closeDB: true, lock: false);
        return false;
      }
      String? password = await walletCommon.getPassword(wallet.address);
      // completer
      logger.i("$TAG - reconnect - START - new completer");
      reconnectCompleter = Completer();
      // status
      status = ClientConnectStatus.connecting;
      _statusSink.add(ClientConnectStatus.connecting);
      // recreate
      bool success = false;
      int tryTimes = 0;
      while (true) {
        Map<String, dynamic> result = await _signIn(wallet, password);
        Client? c = result["client"];
        bool canTry = result["canTry"];
        password = result["password"]?.toString();
        if (c != null) {
          logger.i("$TAG - reconnect - try success - tryTimes:$tryTimes - address:${c.address} - wallet:$wallet - password:$password");
          success = true;
          break;
        } else if (!canTry) {
          logger.e("$TAG - reconnect - try broken - tryTimes:$tryTimes - address:${c?.address} - wallet:$wallet - password:$password");
          await signOut(clearWallet: true, closeDB: true, lock: false);
          break;
        }
        logger.w("$TAG - reconnect - try again - tryTimes:$tryTimes - wallet:$wallet - password:$password");
        if ((tryTimes > 0) && isNetworkOk) await RPC.setRpcServers(wallet.address, []);
        tryTimes++;
        _statusSink.add(ClientConnectStatus.connecting); // need first flush
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
      }
      // complete
      try {
        reconnectCompleter?.complete();
      } catch (e, st) {
        handleError(e, st);
      }
      return success;
    });
    if (success) checkClientOk("reconnect", ping: true); // await
    return success;
  }

  Future<bool> checkClientOk(String tag, {bool ping = false}) async {
    if (isClientStop) {
      logger.w("$TAG - checkClientOk:$tag - client closed - client:${client == null} - status:$status");
      return false;
    }
    if (ping) {
      // status
      await _lock.synchronized(() async {
        if (status == ClientConnectStatus.connectPing) return;
        status = ClientConnectStatus.connectPing;
        _statusSink.add(ClientConnectStatus.connectPing);
      });
      // completer
      try {
        if ((clientOkCompleter != null) && !(clientOkCompleter?.isCompleted == true)) {
          logger.d("$TAG - checkClientOk:$tag - wait last completer - isClientOK:$isClientOK");
          bool success = await clientOkCompleter?.future;
          if (success) {
            logger.i("$TAG - checkClientOk:$tag - return last complete - isClientOK:$isClientOK");
          } else {
            logger.w("$TAG - checkClientOk:$tag - return last complete - isClientOK:$isClientOK - status:$status");
          }
          return success;
        }
      } catch (e, st) {
        handleError(e, st);
      }
      logger.i("$TAG - checkClientOk:$tag - START - new completer");
      clientOkCompleter = Completer();
    }
    // interval
    int interval = 500;
    int gap = DateTime.now().millisecondsSinceEpoch - application.goForegroundAt;
    if (gap < interval) await Future.delayed(Duration(milliseconds: interval - gap));
    // reConnecting
    while (isClientReconnecting) {
      logger.d("$TAG - checkClientOk:$tag - wait client reconnect");
      if (isClientStop) {
        logger.w("$TAG - checkClientOk:$tag - client closed - client:${client == null} - status:$status");
        if (ping) {
          try {
            if (clientOkCompleter?.isCompleted != true) clientOkCompleter?.complete(false);
          } catch (e, st) {
            handleError(e, st);
          }
        }
        return false;
      }
      await Future.delayed(Duration(milliseconds: 200));
    }
    bool success = isClientOK;
    // ping
    if (ping || isClientConnecting) {
      int tryTimes = 0;
      while (isClientConnecting) {
        if (isClientStop) {
          logger.w("$TAG - checkClientOk:$tag - client closed - client:${client == null} - status:$status");
          if (ping) {
            try {
              if (clientOkCompleter?.isCompleted != true) clientOkCompleter?.complete(false);
            } catch (e, st) {
              handleError(e, st);
            }
          }
          return false;
        }
        while (!isNetworkOk) {
          logger.w("$TAG - checkClientOk:$tag - wait network ok");
          await Future.delayed(Duration(milliseconds: 500));
        }
        logger.i("$TAG - checkClientOk:$tag - try ping - tryTimes:$tryTimes - client:${client == null} - status:$status");
        if (client != null) {
          try {
            String data = MessageData.getPing(true);
            await client?.sendText([address ?? ""], data);
          } catch (e) {
            // skip error handle
          }
        } else {
          logger.w("$TAG - checkClientOk:$tag - client null - tryTimes:$tryTimes - client:${client == null} - status:$status");
          break;
        }
        tryTimes++;
        await Future.delayed(Duration(milliseconds: 500));
      }
      success = status == ClientConnectStatus.connected;
      // complete
      try {
        logger.i("$TAG - checkClientOk:$tag - ping complete - status:$status");
        if (clientOkCompleter?.isCompleted != true) clientOkCompleter?.complete(success);
      } catch (e, st) {
        handleError(e, st);
      }
    }
    // return
    if (!success) logger.w("$TAG - checkClientOk:$tag - fail - client:${client != null} - status:$status");
    return success;
  }

// Future ping({int maxWaitTimes = Settings.tryTimesClientConnectWait}) async {
//   if (isClientStop) return;
//   try {
//     if ((pingCompleter != null) && !(pingCompleter?.isCompleted == true)) {
//       await pingCompleter?.future;
//       return;
//     } else {
//       pingCompleter = Completer();
//     }
//   } catch (_) {}
//   int tryTimes = 0;
//   while (true) {
//     await waitReconnect("ping");
//     if (isClientStop) {
//       logger.i("$TAG - ping - closed break - tryTimes:$tryTimes - status:$status");
//       break;
//     } else if (!isNetworkOk) {
//       logger.w("$TAG - ping - wait network ok - tryTimes:$tryTimes - status:$status");
//       await Future.delayed(Duration(milliseconds: 1000));
//       continue;
//     } else if (isClientOK) {
//       logger.v("$TAG - ping - ping - tryTimes:$tryTimes - address:$address");
//       await chatOutCommon.sendPing([address ?? ""], true);
//       break;
//     } else if (tryTimes < maxWaitTimes) {
//       logger.i("$TAG - ping - wait connecting - tryTimes:$tryTimes - status:$status");
//       ++tryTimes;
//       await Future.delayed(Duration(milliseconds: maxWaitTimes <= 1 ? (2 * 1000) : 1000));
//       continue;
//     } else {
//       logger.w("$TAG - ping - reconnect start - tryTimes:$tryTimes");
//       if (await reconnect()) {
//         tryTimes = 0;
//         await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
//         continue;
//       }
//       logger.e("$TAG - ping - reconnect fail - tryTimes:$tryTimes");
//       break;
//     }
//   }
//   try {
//     if (pingCompleter?.isCompleted != true) pingCompleter?.complete();
//   } catch (_) {}
//   await Future.delayed(Duration(milliseconds: 200));
// }
}
