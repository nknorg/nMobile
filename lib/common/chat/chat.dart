import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';

class ChatConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

unLeadingHashIt(String str) {
  return str.replaceFirst(RegExp(r'^#*'), '');
}

String? genTopicHash(String? topic) {
  if (topic == null || topic.isEmpty) {
    return null;
  }
  var t = unLeadingHashIt(topic);
  return 'dchat' + hexEncode(Uint8List.fromList(sha1(t)));
}

class ChatCommon {
  /// nkn-sdk-flutter
  /// doc: https://github.com/nknorg/nkn-sdk-flutter
  Client? client;

  String? get id => client?.address;
  Uint8List? get publicKey => client?.publicKey;

  late int status;

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

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  ChatCommon() {
    status = ChatConnectStatus.disconnected;
    statusStream.listen((int event) {
      status = event;
    });
    onErrorStream.listen((dynamic event) {
      // TODO:GG client error
    });
  }

  Future signIn(WalletSchema? scheme) async {
    if (scheme == null) return null;
    try {
      String? pwd = await walletCommon.getPassword(Global.appContext, scheme.address);
      if (pwd == null || pwd.isEmpty) return;
      String keystore = await walletCommon.getKeystoreByAddress(scheme.address);

      Wallet wallet = await Wallet.restore(keystore, config: WalletConfig(password: pwd));
      if (wallet.address.isEmpty || wallet.keystore.isEmpty) return;

      String pubKey = hexEncode(wallet.publicKey);
      String password = hexEncode(Uint8List.fromList(sha256(wallet.seed)));

      // toggle DB
      await DB.open(pubKey, password);
      // refresh currentUser
      await contactCommon.refreshCurrentUser(pubKey);
      // start client connect (no await)
      connect(wallet);
    } catch (e) {
      handleError(e);
    }
  }

  Future connect(Wallet? wallet) async {
    if (wallet == null || wallet.seed.isEmpty) return;
    if (client != null) await close();
    // client create
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);

    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
      logger.e("onErrorStream -> event:$event");
      _onErrorSink.add(event);
    });

    // client connect
    Completer completer = Completer();
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
      logger.i("onConnectStream -> event:$event");
      _statusSink.add(ChatConnectStatus.connected);
      SettingsStorage().addSeedRpcServers(event.rpcServers!);
      completer.complete();
    });

    // TODO:GG client disconnect/reconnect listen (action statusSink.add)

    // client messages_receive
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async {
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

  Future<List<MessageSchema>> queryListAndReadByTargetId(
    String? targetId, {
    int offset = 0,
    int limit = 20,
    int? unread,
    bool handleBurn = true,
  }) async {
    List<MessageSchema> list = await _messageStorage.queryListCanReadByTargetId(targetId, offset: offset, limit: limit);
    // unread
    if (offset == 0 && (unread == null || unread > 0)) {
      List<MessageSchema> unreadList = await _messageStorage.queryListUnReadByTargetId(targetId);
      unreadList.forEach((MessageSchema element) {
        receiveMessage.read(element); // await
      });
      list = list.map((e) => e.isOutbound == false ? MessageStatus.set(e, MessageStatus.ReceivedRead) : e).toList(); // fake read
    }
    // burn
    if (list.isNotEmpty && handleBurn) {
      for (var i = 0; i < list.length; i++) {
        MessageSchema messageItem = list[i];
        int? burnAfterSeconds = MessageOptions.getDeleteAfterSeconds(messageItem);
        if (messageItem.deleteTime == null && burnAfterSeconds != null) {
          messageItem.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
          _messageStorage.updateDeleteTime(messageItem.msgId, messageItem.deleteTime); // await
        }
      }
    }
    return list;
  }

  Future<OnMessage?> sendText(String dest, String data) async {
    return await this.client?.sendText([dest], data);
  }

  Future<OnMessage?> publishText(String topic, String data) async {
    return await this.client?.publishText(topic, data);
  }
}
