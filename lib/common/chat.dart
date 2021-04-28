import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/hash.dart';

class ChatConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

class ContentType {
  static const String system = 'system';
  static const String text = 'text';
  static const String receipt = 'receipt';
  static const String textExtension = 'textExtension';
  static const String media = 'media';
  static const String contact = 'contact';
  static const String eventContactOptions = 'event:contactOptions';
  static const String eventSubscribe = 'event:subscribe';
  static const String eventUnsubscribe = 'event:unsubscribe';
  static const String ChannelInvitation = 'event:channelInvitation';
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

  Stream<int> get _statusStream => _statusController.stream;

  int status;

  String get id => client?.address;

  Stream<OnConnect> onConnect;
  Stream<OnMessage> onMessage;
  Stream<dynamic> onError;

  Chat() {
    status = ChatConnectStatus.disconnected;
    _statusStream.listen((event) {
      status = event;
    });
  }

  Future connect(Wallet wallet) async {
    _statusStreamSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed);
    onConnect = client.onConnect;
    onMessage = client.onMessage;
    onError = client.onError;
    Completer completer = Completer();
    onConnect.listen((event) {
      _statusStreamSink.add(ChatConnectStatus.connected);
      completer.complete();
    });
    await completer.future;
  }

  close() {
    _statusStreamSink.add(ChatConnectStatus.disconnected);
  }

  Future sendText(MessageSchema messageSchema) async {
    await this.client.sendText([messageSchema.to], messageSchema.toSendTextData());
  }

  Future publishText(MessageSchema messageSchema) async {
    await this.client.publishText(messageSchema.topic, messageSchema.toSendTextData());
  }
}
