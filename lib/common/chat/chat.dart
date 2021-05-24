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

unleadingHashIt(String str) {
  return str.replaceFirst(RegExp(r'^#*'), '');
}

String genTopicHash(String topic) {
  if (topic == null || topic.isEmpty) {
    return null;
  }
  var t = unleadingHashIt(topic);
  return 'dchat' + hexEncode(sha1(t));
}

class Chat {
  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client client;

  // ignore: close_sinks
  StreamController<int> _statusController = StreamController<int>.broadcast();
  StreamSink<int> get _statusStreamSink => _statusController.sink;
  Stream<int> get statusStream => _statusController.stream;

  int status;

  String get id => client?.address;

  Uint8List get publicKey => client?.publicKey;

  // ignore: close_sinks
  StreamController<OnConnect> onConnectController = StreamController<OnConnect>.broadcast();
  StreamSink<OnConnect> get onConnectStreamSink => onConnectController.sink;
  Stream<OnConnect> get onConnect => onConnectController.stream;

  // ignore: close_sinks
  StreamController<OnMessage> onMessageController = StreamController<OnMessage>.broadcast();
  StreamSink<OnMessage> get onMessageStreamSink => onMessageController.sink;
  Stream<OnMessage> get onMessage => onMessageController.stream;

  // ignore: close_sinks
  StreamController<dynamic> onErrorController = StreamController<dynamic>.broadcast();
  StreamSink<dynamic> get onErrorStreamSink => onErrorController.sink;
  Stream<dynamic> get onError => onErrorController.stream;

  // ignore: close_sinks
  StreamController<MessageSchema> onReceivedMessageController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onReceivedMessageStreamSink => onReceivedMessageController.sink;
  Stream<MessageSchema> get onReceivedMessage => onReceivedMessageController.stream;

  // ignore: close_sinks
  StreamController<MessageSchema> onMessageSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onMessageSavedStreamSink => onMessageSavedController.sink;
  Stream<MessageSchema> get onMessageSaved => onMessageSavedController.stream;

  Chat() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((event) {
      status = event;
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
      await DB.open(pubKey, password);
      await contact.fetchCurrentUser(pubKey);
      await connect(restore);
    } catch (e) {
      handleError(e);
    }
  }

  Future connect(walletSDK.Wallet wallet) async {
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusStreamSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);
    Completer completer = Completer();
    client.onConnect.listen((event) {
      _statusStreamSink.add(ChatConnectStatus.connected);
      onConnectStreamSink.add(event);
      completer.complete();
    });
    client.onError.listen((event) {
      onErrorStreamSink.add(event);
    });
    client.onMessage.listen((event) {
      onMessageStreamSink.add(event);
    });
    receiveMessage.startReceiveMessage();
    await completer.future;
  }

  close() async {
    _statusStreamSink.add(ChatConnectStatus.disconnected);
    // await _statusController?.close();
    // await onConnectController?.close();
    // await onMessageController?.close();
    // await onReceivedMessageController?.close();
    // await onMessageSavedController?.close();
    // await onErrorController?.close();
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
