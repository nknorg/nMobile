import 'dart:async';
import 'dart:typed_data';

// import 'package:connectivity_plus/connectivity_plus.dart';
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
  static const int connecting = 1;
  static const int connected = 2;
  static const int disconnecting = 3;
  static const int disconnected = 4;
}

// TODO:GG 所有的chatId都要检查？
String? getPubKeyFromTopicOrChatId(String s) {
  final i = s.lastIndexOf('.');
  final pubKey = i >= 0 ? s.substring(i + 1) : s;
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

  // ignore: close_sinks
  StreamController<dynamic> _onErrorController = StreamController<dynamic>.broadcast();
  StreamSink<dynamic> get _onErrorSink => _onErrorController.sink;
  Stream<dynamic> get onErrorStream => _onErrorController.stream;

  StreamSubscription? _onErrorStreamSubscription;
  StreamSubscription? _onConnectStreamSubscription;
  StreamSubscription? _onMessageStreamSubscription;

  Lock _lock = new Lock();

  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  int status = ClientConnectStatus.disconnected;

  bool _isClientReSign = false;
  bool _isConnectCheck = false;

  bool get isConnecting => _isClientReSign || ((status == ClientConnectStatus.connecting) && (client == null));
  bool get isConnected => (status == ClientConnectStatus.connected) || ((status == ClientConnectStatus.connecting) && (client != null));
  bool get isDisConnecting => !_isClientReSign && (status == ClientConnectStatus.disconnecting);
  bool get isDisConnected => !_isClientReSign && (status == ClientConnectStatus.disconnected);

  bool get isClientOK => (client != null) && ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected));
  bool get isClientStop => (client == null) && !_isClientReSign && (status == ClientConnectStatus.disconnected);

  // bool isNetworkOk = true; // TODO:GG 应该有用吧

  String? _lastLoginWalletAddress;
  String? _lastLoginClientAddress;

  String? get address => client?.address ?? _lastLoginClientAddress; // == chat_id

  ClientCommon() {
    // client TODO:GG 要拆出来吗？ 有lock吗
    onErrorStream.listen((dynamic event) async {
      handleError(event, null);
      await reLogin(false); // TODO:GG 没问题吗？
    });
    // TODO:GG 后台切换网络呢？除了client，ipfs要考虑吗？检测none的时候，ipfs会不会中断(除非有断线重连)
    // TODO:GG chatOutCommon.stop()
    // network
    // Connectivity().onConnectivityChanged.listen((status) {
    //   if (status == ConnectivityResult.none) {
    //     logger.w("$TAG - onConnectivityChanged - status:$status");
    //     isNetworkOk = false;
    //     _statusSink.add(ClientConnectStatus.connecting);
    //     chatCommon.reset(reClient: true, netError: true);
    //     chatInCommon.reset(reClient: true, netError: true);
    //     chatOutCommon.reset(reClient: true, netError: true);
    //   } else {
    //     logger.i("$TAG - onConnectivityChanged - status:$status");
    //     isNetworkOk = true;
    //     if (isClientCreated) connectCheck(force: true, reconnect: true);
    //   }
    // });
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

  Future<Client?> signIn(WalletSchema? wallet, String? password, {bool toast = false, Function(bool, bool)? loading}) async {
    // status
    if (status == ClientConnectStatus.connecting) return null;
    status = ClientConnectStatus.connecting;
    _statusSink.add(ClientConnectStatus.connecting);
    loading?.call(true, false);
    // client
    Client? cc = await _lock.synchronized(() async {
      Client? c;
      int tryTimes = 0;
      while (true) {
        Map<String, dynamic> result = await _signIn(wallet, password, onDatabaseOpen: () => loading?.call(true, true));
        Client? client = result["client"];
        bool canTry = result["canTry"];
        String text = result["text"]?.toString() ?? "";
        if (toast && text.isNotEmpty) Toast.show(text);
        if (client != null) {
          logger.i("$TAG - signIn - try success - tryTimes:$tryTimes - address:${c?.address} - wallet:$wallet - password:$password");
          c = client;
          break;
        } else if (!canTry) {
          logger.e("$TAG - signIn - try fail - tryTimes:$tryTimes - address:${c?.address} - wallet:$wallet - password:$password");
          await signOut(clearWallet: true, closeDB: true, noLock: true);
          break;
        }
        logger.w("$TAG - signIn - try ing - tryTimes:$tryTimes - wallet:$wallet - password:$password");
        tryTimes++;
        if (tryTimes >= 3) await RPC.setRpcServers(wallet?.address, []);
        await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 1000 : (tryTimes * 250))); // TODO:GG 会delay吗
      }
      if (tryTimes <= 0) await Future.delayed(Duration(milliseconds: 500));
      return c;
    });
    // status (set in signOut)
    loading?.call(false, true);
    return cc;
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
      handleError(e, st, upload: false);
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
      handleError(e, st);
      return {"client": null, "canTry": false, "text": "wallet error"};
    }
    if ((pubKey == null) || pubKey.isEmpty || (seed == null) || seed.isEmpty) {
      logger.e("$TAG - _signIn - wallet restore error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
      return {"client": null, "canTry": false, "text": "wallet info empty"};
    }
    // database
    try {
      bool opened = dbCommon.isOpen();
      if (!opened) {
        opened = await dbCommon.open(pubKey, seed);
        BlocProvider.of<WalletBloc>(Settings.appContext).add(DefaultWallet(wallet.address));
        ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true, needWallet: true);
        contactCommon.meUpdateSink.add(me);
      }
      if (!opened) {
        logger.e("$TAG - _signIn - database opened fail - wallet:$wallet - pubKey:$pubKey - seed:$seed");
        return {"client": null, "canTry": false, "text": "database open fail"};
      }
      onDatabaseOpen?.call();
      chatCommon.reset(wallet.address, reClient: _lastLoginWalletAddress == wallet.address);
    } catch (e, st) {
      handleError(e, st);
      return {"client": null, "canTry": false, "text": "database error"};
    }
    // client
    try {
      if (client == null) {
        List<String> seedRpcList = await RPC.getRpcServers(wallet.address, measure: true);
        ClientConfig config = ClientConfig(seedRPCServerAddr: seedRpcList);
        while (client == null) {
          client = await Client.create(hexDecode(seed), numSubClients: 4, config: config); // network
        }
        // init
        chatInCommon.start(wallet.address, reClient: _lastLoginWalletAddress == wallet.address);
        chatOutCommon.start(wallet.address, reClient: _lastLoginClientAddress == client?.address);
        _lastLoginWalletAddress = wallet.address;
        _lastLoginClientAddress = client?.address;
        // TODO:GG 是不是这些listen失效了？test弱网下断掉再走下面的流程，看看reconnect会不会触发这些listen
        // client error
        _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
          logger.e("$TAG - _signIn - onError -> event:${event.toString()}");
          _onErrorSink.add(event);
        });
        // client connect (just listen once)
        _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
          logger.i("$TAG - _signIn - onConnect -> node:${event.node} - rpcServers:${event.rpcServers}");
          status = ClientConnectStatus.connected;
          _statusSink.add(ClientConnectStatus.connected);
          RPC.addRpcServers(wallet.address, event.rpcServers ?? []); // await
        });
        // client receive (looper)
        _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
          logger.i("$TAG - _signIn - onMessage -> src:${event.src} - type:${event.type} - encrypted:${event.encrypted} - messageId:${event.messageId} - data:${((event.data is String) && (event.data as String).length <= 1000) ? event.data : "[data to long~~~]"}");
          if (status != ClientConnectStatus.connected) {
            status = ClientConnectStatus.connected;
            _statusSink.add(ClientConnectStatus.connected);
          }
          chatInCommon.onMessageReceive(MessageSchema.fromReceive(address ?? "", event)); // await
        });
      } else {
        await client?.reconnect(); // no onConnect callback // TODO:GG await???
        // no status update (updated by ping/pang)
      }
      connectCheck(); // TODO:GG 测试会不会丢?
      return {"client": client, "canTry": true};
    } catch (e, st) {
      handleError(e, st);
      return {"client": null, "canTry": true};
    }
  }

  Future signOut({bool clearWallet = false, bool closeDB = true, bool noLock = false}) async {
    // status
    if (status == ClientConnectStatus.disconnecting) return;
    status = ClientConnectStatus.disconnecting;
    _statusSink.add(ClientConnectStatus.disconnecting);
    // client
    if (!noLock) {
      await _lock.synchronized(() async {
        int tryTimes = 0;
        while (true) {
          bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
          if (success) {
            logger.i("$TAG - signOut - try over - tryTimes:$tryTimes");
            break;
          }
          logger.e("$TAG - signOut - try ing - tryTimes:$tryTimes");
          tryTimes++;
          await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 1000 : (tryTimes * 250))); // TODO:GG 会delay吗
        }
      });
    } else {
      int tryTimes = 0;
      while (true) {
        bool success = await _signOut(clearWallet: clearWallet, closeDB: closeDB);
        if (success) {
          logger.i("$TAG - signOut - try over - tryTimes:$tryTimes");
          break;
        }
        logger.e("$TAG - signOut - try ing - tryTimes:$tryTimes");
        tryTimes++;
        await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 1000 : (tryTimes * 250))); // TODO:GG 会delay吗
      }
    }
    // status
    status = ClientConnectStatus.disconnected;
    _statusSink.add(ClientConnectStatus.disconnected);
    return;
  }

  Future<bool> _signOut({bool clearWallet = true, bool closeDB = true}) async {
    try {
      chatOutCommon.stop(clear: closeDB);
      chatInCommon.stop(clear: closeDB);
      await client?.close();
      await _onErrorStreamSubscription?.cancel();
      await _onConnectStreamSubscription?.cancel();
      await _onMessageStreamSubscription?.cancel();
      if (clearWallet) BlocProvider.of<WalletBloc>(Settings.appContext).add(DefaultWallet(null));
      if (closeDB) await dbCommon.close();
      client = null;
    } catch (e, st) {
      handleError(e, st);
      return false;
    }
    return true;
  }

  /// **************************************************************************************** ///
  /// *********************************   Connect   ****************************************** ///
  /// **************************************************************************************** ///

  Future<bool> reLogin(bool needPwd) async {
    if (_isClientReSign) return false;
    _isClientReSign = true;
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if ((wallet == null) || wallet.address.isEmpty) {
      AppScreen.go(Settings.appContext);
      await signOut(clearWallet: true, closeDB: true);
      return false;
    }
    // signOut
    if ((status == ClientConnectStatus.connecting) || (status == ClientConnectStatus.connected)) {
      logger.i("$TAG - reLogin - unsubscribe stream when client no created - wallet:$wallet");
      await signOut(clearWallet: false, closeDB: false);
    }
    // signIn
    String? walletPwd = needPwd ? (await authorization.getWalletPassword(wallet.address)) : (await walletCommon.getPassword(wallet.address));
    Client? c = await signIn(wallet, walletPwd);
    _isClientReSign = false;
    return c != null;
  }

  Future connectCheck({bool reconnect = false}) async {
    if (_isConnectCheck) return;
    _isConnectCheck = true;
    // client
    int tryTimes = 0;
    while (true) {
      if (isConnecting && (tryTimes <= Settings.tryTimesClientConnectWait)) {
        logger.i("$TAG - connectCheck - wait connecting - tryTimes:$tryTimes - _isClientReSign:$_isClientReSign - status:$status");
        ++tryTimes;
        await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 500 : (tryTimes * 100))); // TODO:GG 会delay吗
        continue;
      } else if (isConnected) {
        logger.i("$TAG - connectCheck - ping - tryTimes:$tryTimes - address:$address");
        await chatOutCommon.sendPing([address ?? ""], true);
        break;
      } else if (isDisConnecting) {
        logger.i("$TAG - connectCheck - wait disconnect - tryTimes:$tryTimes");
        ++tryTimes;
        await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 500 : (tryTimes * 100))); // TODO:GG 会delay吗
        continue;
      } else if (reconnect) {
        logger.w("$TAG - connectCheck - need reSign - tryTimes:$tryTimes");
        bool success = await reLogin(false);
        if (success) {
          tryTimes = 0;
          await Future.delayed(Duration(milliseconds: (tryTimes >= 5) ? 500 : (tryTimes * 100))); // TODO:GG 会delay吗
          continue;
        }
        logger.e("$TAG - connectCheck - reSign fail - tryTimes:$tryTimes");
        break;
      } else {
        logger.w("$TAG - connectCheck - connect check stop - tryTimes:$tryTimes - status:$status");
        break;
      }
    }
    _isConnectCheck = false;
  }
}
