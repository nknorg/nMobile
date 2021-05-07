import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/message.dart';
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

  Stream<OnConnect> onConnect;
  Stream<OnMessage> onMessage;
  Stream<dynamic> onError;

  Chat() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((event) {
      status = event;
    });
  }

  Future signin() async {
    // todo for test
    Wallet wallet = await Wallet.create(hexDecode('b62aed51da1d79fd0ccc8584592fe97636344239a34b7fcc49baa303fef3c038'), config: WalletConfig(password: '123'));

    String pubkey = hexEncode(wallet.publicKey);
    String password = hexEncode(sha256(wallet.seed));

    await DB.open(pubkey, password);
    connect(wallet);
  }

  Future connect(Wallet wallet) async {
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusStreamSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);
    onConnect = client.onConnect;
    onMessage = client.onMessage;
    onError = client.onError;
    Completer completer = Completer();
    onConnect.listen((event) {
      _statusStreamSink.add(ChatConnectStatus.connected);
      completer.complete();
    });
    await completer.future;

    receiveMessage.startReceiveMessage();
  }

  close() {
    _statusStreamSink.add(ChatConnectStatus.disconnected);
    _statusController.close();
  }

  Future sendText(MessageSchema messageSchema) async {
    await this.client.sendText([messageSchema.to], messageSchema.toSendTextData());
  }

  Future publishText(MessageSchema messageSchema) async {
    await this.client.publishText(messageSchema.topic, messageSchema.toSendTextData());
  }
}
