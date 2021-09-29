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

  bool get isClientCreated => (client != null) && (client!.address.isNotEmpty == true);

  int connectedAt = 0;

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
        connectedAt = DateTime.now().millisecondsSinceEpoch;
      }
    });
    onErrorStream.listen((dynamic event) {
      handleError(event);
      connectCheck();
    });
  }

  /// ******************************************************   Client   ****************************************************** ///

  // need signOut
  // return [client, pwdError]
  Future<List> signIn(
    WalletSchema? wallet, {
    bool fetchRemote = true,
    Function(bool, int)? dialogVisible,
    String? password,
    int tryCount = 1,
  }) async {
    if (wallet == null || wallet.address.isEmpty) return [null, false];
    // if (client != null) await close(); // async boom!!!
    try {
      // password
      password = (password?.isNotEmpty == true) ? password : (await authorization.getWalletPassword(wallet.address));
      if (password == null || password.isEmpty) return [null, true];
      dialogVisible?.call(true, tryCount);

      // pubKey/seed
      List<String>? seedRpcList;
      String? pubKey;
      String? seed;
      if (fetchRemote) {
        String keystore = await walletCommon.getKeystore(wallet.address);
        seedRpcList = await Global.getSeedRpcList(wallet.address, measure: true);
        Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
        pubKey = nknWallet.publicKey.isEmpty ? null : hexEncode(nknWallet.publicKey);
        seed = nknWallet.seed.isEmpty ? null : hexEncode(nknWallet.seed);
      } else {
        if (!(await walletCommon.isPasswordRight(wallet.address, password, seedRpcList: seedRpcList))) {
          logger.w("$TAG - signIn - password error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          throw Exception("wrong password");
        }
        pubKey = wallet.publicKey;
        seed = await walletCommon.getSeed(wallet.address);
      }
      if (pubKey == null || pubKey.isEmpty || seed == null || seed.isEmpty) {
        dialogVisible?.call(false, tryCount);
        if (!fetchRemote) {
          logger.w("$TAG - signIn - pubKey/seed error, reSignIn by check - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return signIn(wallet, fetchRemote: true, dialogVisible: dialogVisible, password: password);
        } else {
          logger.e("$TAG - signIn - pubKey/seed error - wallet:$wallet - pubKey:$pubKey - seed:$seed");
          return [null, false];
        }
      }

      // database
      if (!(dbCommon.isOpen() == true)) {
        await dbCommon.open(pubKey, seed);
        // wallet
        BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(wallet.address));
        // contact
        ContactSchema? me = await contactCommon.getMe(clientAddress: pubKey, canAdd: true);
        contactCommon.meUpdateSink.add(me);
      }

      // client create
      if (client == null) {
        _statusSink.add(ClientConnectStatus.connecting);
        seedRpcList = seedRpcList ?? (await Global.getSeedRpcList(wallet.address, measure: true));
        client = await Client.create(hexDecode(seed), config: ClientConfig(seedRPCServerAddr: seedRpcList));

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
          pingSelfSuccess(force: true); // await
          if (!completer.isCompleted) completer.complete();
        });

        // client receive (looper)
        _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) {
          logger.i("$TAG - signIn - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
          chatInCommon.onClientMessage(MessageSchema.fromReceive(event));
          if (status != ClientConnectStatus.connected) {
            pingSelfSuccess(force: true); // await
          }
        });
      } else {
        dialogVisible?.call(false, tryCount);
        client?.reconnect(); // await no onConnect callback
      }
      // await completer.future;
      return [client, false];
    } catch (e) {
      dialogVisible?.call(false, tryCount);
      // password/keystore
      if ((e.toString().contains("password") == true) || (e.toString().contains("keystore") == true)) {
        if (!fetchRemote) {
          logger.w("$TAG - signIn - password/keystore error, reSignIn by check - wallet:$wallet");
          return signIn(wallet, fetchRemote: true, dialogVisible: dialogVisible, password: password);
        }
        handleError(e);
        return [null, true];
      }
      // toast
      if ((tryCount != 0) && (tryCount % 10 == 0)) handleError(e);
      // loop login
      await SettingsStorage.setSeedRpcServers([], prefix: wallet.address);
      await Future.delayed(Duration(seconds: tryCount >= 5 ? 5 : tryCount));
      return signIn(wallet, fetchRemote: fetchRemote, dialogVisible: dialogVisible, password: password, tryCount: ++tryCount);
    }
  }

  Future signOut({bool closeDB = true}) async {
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
      return signOut(closeDB: closeDB);
    }
    client = null;
    // close DB
    if (closeDB) {
      BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(null)); // should first
      await dbCommon.close();
    }
  }

  Future<List> reSignIn(bool needPwd, {int delayMs = 200}) async {
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.address.isEmpty) {
      AppScreen.go(Global.appContext);
      await signOut(closeDB: true);
      return [null, false];
    }

    // await signOut(closeDB: false);
    await Future.delayed(Duration(milliseconds: delayMs));
    if (status != ClientConnectStatus.connecting) {
      _statusSink.add(ClientConnectStatus.connecting);
    }

    // client
    String? walletPwd = needPwd ? (await authorization.getWalletPassword(wallet.address)) : (await walletCommon.getPassword(wallet.address));
    return await signIn(wallet, fetchRemote: false, password: walletPwd);
  }

  Future connectCheck() async {
    if (client == null) return;
    _statusSink.add(ClientConnectStatus.connecting);
    reSignIn(false, delayMs: 0).then((value) {
      chatOutCommon.sendPing(address, true);
    });
    // loop
    Future.delayed(Duration(milliseconds: 1000), () {
      if (status == ClientConnectStatus.connecting) {
        _connectingVisibleSink.add(true);
        connectCheck();
      }
    });
  }

  Future pingSelfSuccess({bool force = false}) async {
    if (client == null) return;
    if (!force && (status != ClientConnectStatus.connecting)) return;
    _statusSink.add(ClientConnectStatus.connected);
    // visible
    Future.delayed(Duration(milliseconds: 1000), () {
      _connectingVisibleSink.add(false);
    });
  }
}
