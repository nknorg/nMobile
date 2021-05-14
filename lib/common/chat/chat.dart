import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart' as walletSDK;
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/error.dart';
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

  StreamController<int> _statusController = StreamController<int>.broadcast();

  StreamSink<int> get _statusStreamSink => _statusController.sink;

  Stream<int> get statusStream => _statusController.stream;

  int status;

  String get id => client?.address;

  Uint8List get publicKey => client?.publicKey;

  StreamController<OnConnect> onConnectController = StreamController<OnConnect>.broadcast();
  StreamSink<OnConnect> get onConnectStreamSink => onConnectController.sink;
  Stream<OnConnect> get onConnect => onConnectController.stream;

  StreamController<OnMessage> onMessageController = StreamController<OnMessage>.broadcast();
  StreamSink<OnMessage> get onMessageStreamSink => onMessageController.sink;
  Stream<OnMessage> get onMessage => onMessageController.stream;

  StreamController<dynamic> onErrorController = StreamController<dynamic>.broadcast();
  StreamSink<dynamic> get onErrorStreamSink => onErrorController.sink;
  Stream<dynamic> get onError => onErrorController.stream;

  StreamController<MessageSchema> onReceivedMessageController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onReceivedMessageStreamSink => onReceivedMessageController.sink;
  Stream<MessageSchema> get onReceivedMessage => onReceivedMessageController.stream;

  StreamController<MessageSchema> onMessageSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onMessageSavedStreamSink => onMessageSavedController.sink;
  Stream<MessageSchema> get onMessageSaved => onMessageSavedController.stream;

  Chat() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((event) {
      status = event;
    });
  }

  Future signin(WalletSchema scheme) async {
    if (scheme == null || scheme.address == null) return null;
    try {
      String keystore = await wallet.getWalletKeystoreByAddress(scheme.address);
      String pwd = await wallet.getWalletPassword(Global.appContext, scheme.address);

      walletSDK.Wallet restore = await walletSDK.Wallet.restore(keystore, config: walletSDK.WalletConfig(password: pwd));

      String pubkey = hexEncode(restore.publicKey);
      String password = hexEncode(sha256(restore.seed));
      await DB.open(pubkey, password);
      await contact.fetchCurrentUser(pubkey);
      connect(restore);
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

  close() {
    _statusStreamSink.add(ChatConnectStatus.disconnected);
    _statusController?.close();
    onConnectController?.close();
    onMessageController?.close();
    onReceivedMessageController?.close();
    onMessageSavedController?.close();
    onErrorController?.close();
    client?.close();
  }

  Future sendText(String dest, String data) async {
    return this.client.sendText([dest], data);
  }

  Future publishText(String topic, String data) async {
    return this.client.publishText(topic, data);
  }
}
