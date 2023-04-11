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
import 'package:nmobile/common/client/sync_client.dart';
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
  static const int connecting = 1;
  static const int connected = 2;
  static const int disconnecting = 3;
  static const int disconnected = 4;
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

  String? _lastLoginClientAddress;

  String? get address => client?.address ?? _lastLoginClientAddress; // == chat_id / wallet.publicKey

  int status = ClientConnectStatus.disconnected;

  bool get isClientOK => (client != null) && ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected));

  bool get isClientConnecting => _isReConnecting || ((status == ClientConnectStatus.connecting) && (client == null));

  bool get isClientStop => !_isReConnecting && ((status == ClientConnectStatus.disconnecting) || (status == ClientConnectStatus.disconnected));

  int _timeClosedForce = 0;
  bool _isReConnecting = false;
  bool _isConnectChecking = false;

  bool isNetworkOk = true;

  ClientCommon() {
    // network
    Connectivity().onConnectivityChanged.listen((status) {
      if (status == ConnectivityResult.none) {
        logger.w("$TAG - ClientCommon - onConnectivityChanged - status:$status");
      } else {
        logger.i("$TAG - ClientCommon - onConnectivityChanged - status:$status");
      }
      isNetworkOk = status != ConnectivityResult.none;
      if (isClientOK) connectCheck(status: true);
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
  /// **********************************   Client   ****************************************** ///
  /// **************************************************************************************** ///

  Future<bool> signIn(WalletSchema? wallet, String? password, {bool force = false, bool toast = false, Function(bool, bool)? loading}) async {
    int timeSignIn = DateTime.now().millisecondsSinceEpoch;
    // status (just updated(connecting) in this func)
    if (status == ClientConnectStatus.connecting) return false;
    status = ClientConnectStatus.connecting;
    _statusSink.add(ClientConnectStatus.connecting);
    loading?.call(true, false);
    // client
    bool success = await _lock.synchronized(() async {
      bool success = false;
      int tryTimes = 0;
      while (true) {
        if (force) {
          if (timeSignIn <= _timeClosedForce) {
            logger.w("$TAG - signIn - try break by force before - tryTimes:$tryTimes - wallet:$wallet - password:$password");
            await signOut(clearWallet: true, closeDB: true, lock: false);
            break;
          }
        } else {
          if (_timeClosedForce > 0) {
            logger.w("$TAG - signIn - try again by no force - tryTimes:$tryTimes - wallet:$wallet - password:$password");
            await signOut(clearWallet: true, closeDB: true, lock: false);
            break;
          }
        }
        Map<String, dynamic> result = await _signIn(wallet, password, onDatabaseOpen: () => loading?.call(true, true));
        Client? c = result["client"];
        bool canTry = result["canTry"];
        password = result["password"]?.toString();
        String text = result["text"]?.toString() ?? "";
        if (toast && text.isNotEmpty) {
          if (tryTimes % 10 == 0) Toast.show(text);
        }
        if (c != null) {
          logger.i("$TAG - signIn - try success - tryTimes:$tryTimes - address:${c.address} - wallet:$wallet - password:$password");
          success = true;
          if ((timeSignIn > _timeClosedForce) && force) _timeClosedForce = 0;
          break;
        } else if (!canTry) {
          logger.e("$TAG - signIn - try break - tryTimes:$tryTimes - address:${c?.address} - wallet:$wallet - password:$password");
          await signOut(clearWallet: true, closeDB: true, lock: false);
          break;
        }
        logger.w("$TAG - signIn - try again - tryTimes:$tryTimes - wallet:$wallet - password:$password");
        tryTimes++;
        _statusSink.add(ClientConnectStatus.connecting); // need flush
        if ((tryTimes >= 3) && isNetworkOk) await RPC.setRpcServers(wallet?.address, []);
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 250 : 500));
      }
      return success;
    });
    // status (set when onMessageReceive)
    loading?.call(false, true);
    return success;
  }

  Future<Map<String, dynamic>> _signIn(WalletSchema? wallet, String? password, {Function? onDatabaseOpen}) async {
    if ((wallet == null) || wallet.address.isEmpty) {
      logger.e("$TAG - _signIn - wallet is null");
      return {"client": null, "canTry": false, "text": "wallet is no exists"};
    }
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
      ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true, needWallet: true);
      contactCommon.meUpdateSink.add(me);
      onDatabaseOpen?.call();
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": false, "password": password, "text": "database error"};
    }
    // common
    try {
      bool reset = (_lastLoginClientAddress == null) || (_lastLoginClientAddress != wallet.publicKey);
      await chatCommon.reset(wallet.address, reset: reset);
      await chatInCommon.start(reset: reset);
      await chatOutCommon.start(reset: reset);
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": false, "password": password, "text": "reset error"};
    }
    // client
    try {
      if (client == null) {
        List<String> seedRpcList = await RPC.getRpcServers(wallet.address, measure: true);
        ClientConfig config = ClientConfig(seedRPCServerAddr: seedRpcList);
        while ((client?.address == null) || (client?.address.isEmpty == true)) {
          client = await Client.create(hexDecode(seed), numSubClients: 4, config: config); // network
        }

        syncClientCommon.connect(wallet, password, seedRpcList);
        _startListen(wallet);
      } else {
        // reconnect will break in go-sdk, because connect closed when fail and no callback
        // maybe no go here, because closed too long, reconnect too long more
        await client?.reconnect(); // no onConnect callback
        await Future.delayed(Duration(milliseconds: 1000)); // reconnect need more time
      }
    } catch (e, st) {
      handleError(e, st, toast: false);
      return {"client": null, "canTry": true, "password": password, "text": getErrorShow(e)};
    }
    _lastLoginClientAddress = client?.address;
    // status no update (updated by ping/pang)
    connectCheck(); // await
    return {"client": client, "canTry": true, "password": password};
  }

  Future signOut({bool force = false, bool clearWallet = false, bool closeDB = true, bool lock = true}) async {
    if (force) _timeClosedForce = DateTime.now().millisecondsSinceEpoch;
    // status (just updated(disconnecting/disconnected) in this func)
    if (status == ClientConnectStatus.disconnecting || status == ClientConnectStatus.disconnected) return;
    status = ClientConnectStatus.disconnecting;
    _statusSink.add(ClientConnectStatus.disconnecting);
    // client
    if (lock) {
      await _lock.synchronized(() async {
        int tryTimes = 0;
        while (true) {
          bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
          if (success) {
            logger.i("$TAG - signOut - try success - tryTimes:$tryTimes - force:$force - lock:$lock");
            break;
          }
          logger.e("$TAG - signOut - try again - tryTimes:$tryTimes - force:$force - lock:$lock");
          tryTimes++;
          _statusSink.add(ClientConnectStatus.disconnecting); // need flush
          await Future.delayed(Duration(milliseconds: isNetworkOk ? 250 : 500));
        }
      });
    } else {
      int tryTimes = 0;
      while (true) {
        bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
        if (success) {
          logger.i("$TAG - signOut - try success - tryTimes:$tryTimes - force:$force - lock:$lock");
          break;
        }
        logger.e("$TAG - signOut - try again - tryTimes:$tryTimes - force:$force - lock:$lock");
        tryTimes++;
        _statusSink.add(ClientConnectStatus.disconnecting); // need flush
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 250 : 500));
      }
    }
    // status
    status = ClientConnectStatus.disconnected;
    _statusSink.add(ClientConnectStatus.disconnected);
    return;
  }

  Future<bool> _signOut({bool clearWallet = true, bool closeDB = true}) async {
    try {
      await chatOutCommon.stop(reset: closeDB);
      await client?.close();
      await _stopListen();
      await chatInCommon.stop(reset: closeDB);
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
      await reConnect();
    });
    // client connect (just listen once)
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) async {
      logger.i("$TAG - onConnect -> node:${event.node} - rpcServers:${event.rpcServers}");
      status = ClientConnectStatus.connected;
      _statusSink.add(ClientConnectStatus.connected);
      RPC.addRpcServers(wallet.address, event.rpcServers ?? []); // await
    });
    // client receive (looper)
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
      logger.v(
          "$TAG - onMessage -> src:${event.src} - type:${event.type} - encrypted:${event.encrypted} - messageId:${event.messageId} - data:${((event.data is String) && (event.data as String).length <= 1000) ? event.data : "[data to long~~~]"}");
      if (status != ClientConnectStatus.connected) {
        status = ClientConnectStatus.connected;
        _statusSink.add(ClientConnectStatus.connected);
      }
      syncClientCommon.onSyncMessage(event, address!);
      syncClientCommon.onMessageReceive(event);
      chatInCommon.onMessageReceive(MessageSchema.fromReceive(address ?? "", event)); // await
    });
  }

  Future _stopListen() async {
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
  }

  /// **************************************************************************************** ///
  /// *********************************   Connect   ****************************************** ///
  /// **************************************************************************************** ///

  Future<bool> reConnect({bool logout = true}) async {
    if (isClientStop) return false;
    if (_isReConnecting) return false;
    _isReConnecting = true;
    // signOut
    if (logout && ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected))) {
      logger.i("$TAG - reConnect - signOut");
      await signOut(clearWallet: false, closeDB: false);
    }
    // password
    WalletSchema? wallet = await walletCommon.getDefault();
    if ((wallet == null) || wallet.address.isEmpty) {
      AppScreen.go(Settings.appContext);
      await signOut(clearWallet: true, closeDB: true);
      _isReConnecting = false;
      return false;
    }
    String? password = await walletCommon.getPassword(wallet.address);
    // signIn
    logger.i("$TAG - reConnect - signIn");
    bool success = await signIn(wallet, password, toast: true);
    _isReConnecting = false;
    return success;
  }

  Future connectCheck({bool status = false, int waitTimes = Settings.tryTimesClientConnectWait}) async {
    // if (status) _statusSink.add(ClientConnectStatus.connecting);
    if (_isConnectChecking) return;
    _isConnectChecking = true;
    int tryTimes = 0;
    while (true) {
      if (isClientStop) {
        logger.i("$TAG - connectCheck - closed break - tryTimes:$tryTimes");
        break;
      } else if (isClientOK) {
        logger.v("$TAG - connectCheck - ping - tryTimes:$tryTimes - address:$address");
        await chatOutCommon.sendPing([address ?? ""], true);
        break;
      } else if (tryTimes <= waitTimes) {
        logger.i("$TAG - connectCheck - wait connecting - tryTimes:$tryTimes - _isClientReConnect:$_isReConnecting - status:$status");
        ++tryTimes;
        await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
        continue;
      } else {
        logger.w("$TAG - connectCheck - reConnect - tryTimes:$tryTimes");
        bool success = await reConnect();
        if (success) {
          tryTimes = 0;
          await Future.delayed(Duration(milliseconds: isNetworkOk ? 500 : 1000));
          continue;
        }
        logger.e("$TAG - connectCheck - reConnect fail - tryTimes:$tryTimes");
        break;
      }
    }
    _isConnectChecking = false;
  }
}
