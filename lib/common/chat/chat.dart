import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart' as walletSDK;
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';

class ChatConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

class ContentType {
  static const String system = 'system';
  static const String text = 'text';
  static const String textExtension = 'textExtension';
  static const String receipt = 'receipt';
  static const String media = 'media';

  static const String nknImage = 'nknImage'; // todo, remove this, or rename image
  static const String audio = 'audio';

  static const String contact = 'contact';
  static const String nknOnePiece = 'nknOnePiece';
  static const String eventContactOptions = 'event:contactOptions';
  static const String eventSubscribe = 'event:subscribe';
  static const String eventUnsubscribe = 'event:unsubscribe';
  static const String channelInvitation = 'event:channelInvitation';
}

unLeadingHashIt(String str) {
  return str.replaceFirst(RegExp(r'^#*'), '');
}

String genTopicHash(String topic) {
  if (topic == null || topic.isEmpty) {
    return null;
  }
  var t = unLeadingHashIt(topic);
  return 'dchat' + hexEncode(sha1(t));
}

class Chat {
  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client client;

  String get id => client?.address;
  Uint8List get publicKey => client?.publicKey;

  int status;

  // ignore: close_sinks
  StreamController<int> _statusController = StreamController<int>.broadcast();
  StreamSink<int> get _statusSink => _statusController.sink;
  Stream<int> get statusStream => _statusController.stream;

  // ignore: close_sinks
  StreamController<dynamic> _onErrorController = StreamController<dynamic>.broadcast();
  StreamSink<dynamic> get _onErrorSink => _onErrorController.sink;
  Stream<dynamic> get onErrorStream => _onErrorController.stream;

  StreamSubscription _onErrorStreamSubscription;
  StreamSubscription _onConnectStreamSubscription;
  StreamSubscription _onMessageStreamSubscription;

  Chat() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      // TODO:GG client error
    });
  }

  Future signIn(WalletSchema scheme) async {
    if (scheme == null || scheme.address == null) return null;
    try {
      String pwd = await wallet.getWalletPassword(Global.appContext, scheme.address);
      if (pwd == null || pwd.isEmpty) return;
      String keystore = await wallet.getWalletKeystoreByAddress(scheme.address);

      walletSDK.Wallet restore = await walletSDK.Wallet.restore(keystore, config: walletSDK.WalletConfig(password: pwd));
      String pubKey = hexEncode(restore.publicKey);
      String password = hexEncode(sha256(restore.seed));

      // toggle DB
      await DB.open(pubKey, password);
      // refresh currentUser
      await contact.refreshCurrentUser(pubKey);
      // start client connect (no await)
      connect(restore);
    } catch (e) {
      handleError(e);
    }
  }

  Future connect(walletSDK.Wallet wallet) async {
    if (client != null) await close();
    // client create
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);

    // client error
    _onErrorStreamSubscription = client.onError?.listen((dynamic event) {
      logger.e("onErrorStream -> event:$event");
      _onErrorSink.add(event);
    });

    // client connect
    Completer completer = Completer();
    _onConnectStreamSubscription = client.onConnect?.listen((OnConnect event) {
      logger.i("onConnectStream -> event:$event");
      _statusSink.add(ChatConnectStatus.connected);
      completer.complete();
    });

    // TODO:GG client disconnect/reconnect listen (action statusSink.add)

    // client messages_receive
    _onMessageStreamSubscription = client.onMessage?.listen((OnMessage event) async {
      logger.i("onMessageStream -> messageId:${event.messageId} - src:${event.src} - data:${event.data} - type:${event.type} - encrypted:${event.encrypted}");
      await receiveMessage.onClientMessage(MessageSchema.fromReceive(event));
    });
    receiveMessage.startReceiveMessage();
    await completer.future;
  }

  close() async {
    // status
    _statusSink.add(ChatConnectStatus.disconnected);
    // message
    await receiveMessage.stopReceiveMessage();
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    await client?.close();
    client = null;
  }

  Future sendText(String dest, String data) async {
    return this.client.sendText([dest], data);
  }

  Future publishText(String topic, String data) async {
    return this.client.publishText(topic, data);
  }
}
