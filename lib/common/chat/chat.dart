import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';
import '../settings.dart';

class ChatConnectStatus {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int stopping = 3;
}

class ChatCommon with Tag {
  DB? db;

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

  /// ******************************************************   Client   ****************************************************** ///

  // need close
  Future<bool> signIn(WalletSchema? schema, {bool walletDefault = false}) async {
    if (schema == null) return false;
    // if (client != null) await close(); // async boom!!!
    try {
      String? pwd = await authorization.getWalletPassword(schema.address);
      if (pwd == null || pwd.isEmpty) return false;
      String keystore = await walletCommon.getKeystoreByAddress(schema.address);

      Wallet wallet = await Wallet.restore(keystore, config: WalletConfig(password: pwd));
      if (wallet.address.isEmpty || wallet.keystore.isEmpty) return false;

      if (walletDefault) BlocProvider.of<WalletBloc>(Global.appContext).add(DefaultWallet(schema.address));

      String pubKey = hexEncode(wallet.publicKey);
      String password = hexEncode(Uint8List.fromList(sha256(wallet.seed)));
      if (pubKey.isEmpty || password.isEmpty) return false;

      // open DB
      db = await DB.open(pubKey, password);
      // set currentUser
      await contactCommon.refreshCurrentUser(pubKey);
      // start client connect (no await)
      connect(wallet); // await
    } catch (e) {
      handleError(e);
    }
    return true;
  }

  Future connect(Wallet? wallet) async {
    if (wallet == null || wallet.seed.isEmpty) return;
    // client create
    ClientConfig config = ClientConfig(seedRPCServerAddr: await Global.getSeedRpcList());
    _statusSink.add(ChatConnectStatus.connecting);
    client = await Client.create(wallet.seed, config: config);

    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) {
      logger.e("$TAG - onError -> event:${event.toString()}");
      _onErrorSink.add(event);
    });

    // client connect
    Completer completer = Completer();
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) {
      logger.i("$TAG - onConnect -> node:${event.node}, rpcServers:${event.rpcServers}");
      _statusSink.add(ChatConnectStatus.connected);
      SettingsStorage().addSeedRpcServers(event.rpcServers!);
      completer.complete();
    });

    // TODO:GG client disconnect/reconnect listen (action statusSink.add)

    // client messages_receive
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async {
      logger.i("$TAG - onMessage -> src:${event.src} - type:${event.type} - messageId:${event.messageId} - data:${(event.data is String && (event.data as String).length <= 1000) ? event.data : "~~~~~"} - encrypted:${event.encrypted}");
      await receiveMessage.onClientMessage(MessageSchema.fromReceive(event));
    });
    await completer.future;
  }

  signOut() async {
    // status
    _statusSink.add(ChatConnectStatus.disconnected);
    // client
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
    await client?.close();
    client = null;
    // clear currentUser
    await contactCommon.refreshCurrentUser(null, notify: true);
    // close DB
    await db?.close();
  }

  /// ******************************************************   Handle   ****************************************************** ///

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    if (!message.canDisplayAndRead) return null;
    // duplicated
    String? clientAddress = message.isOutbound ? message.to : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    if (exist == null) {
      logger.d("$TAG - contactHandle - new - clientAddress:$clientAddress");
      return await contactCommon.addByType(clientAddress, ContactType.stranger, checkDuplicated: false);
    } else {
      if (exist.profileExpiresAt == null || DateTime.now().isAfter(exist.profileExpiresAt!.add(Settings.profileExpireDuration))) {
        logger.d("$TAG - contactHandle - sendMessageContactRequestHeader - schema:$exist");
        await sendMessage.sendContactRequest(exist, RequestType.header);
      } else {
        double between = ((exist.profileExpiresAt?.add(Settings.profileExpireDuration).millisecondsSinceEpoch ?? 0) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    return exist;
  }

  Future<TopicSchema?> topicHandle(MessageSchema message) async {
    if (!message.canDisplayAndRead) return null;
    // duplicated TODO:GG topic duplicated
    if (!message.isTopic) return null;
    TopicSchema? exist = await _topicStorage.queryTopicByTopicName(message.topic);
    if (exist == null) {
      return await _topicStorage.insertTopic(TopicSchema(
        // TODO: get topic info
        // expireAt:
        // joined:
        topic: message.topic!,
      ));
    }
    return exist;
  }

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplayAndRead) return null;
    // duplicated
    if (message.targetId == null || message.targetId!.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(message.targetId);
    if (exist == null) {
      logger.d("$TAG - sessionHandle - new - targetId:${message.targetId}");
      return await sessionCommon.add(SessionSchema(targetId: message.targetId!, type: SessionSchema.getTypeByMessage(message)));
    }
    if (message.isOutbound) {
      await sessionCommon.setLastMessage(message.targetId, message, notify: true);
    } else {
      await sessionCommon.setLastMessageAndUnReadCount(message.targetId, message, null, notify: true);
    }
    return exist;
  }

  Future<MessageSchema> burningHandle(MessageSchema message, {ContactSchema? contact, bool database = false}) async {
    if (!message.canDisplayAndRead || message.isTopic) return message;
    if (message.isOutbound) {
      // send
      ContactSchema? _contact = contact ?? await contactCommon.queryByClientAddress(message.targetId);
      int deleteAfterSeconds = _contact?.options?.deleteAfterSeconds ?? 0;
      if (deleteAfterSeconds > 0) {
        if (message.contentType == ContentType.text) {
          message.contentType = ContentType.textExtension;
        }
        message = MessageOptions.setDeleteAfterSeconds(message, deleteAfterSeconds);
      }
    } else {
      // receive
      int? seconds = MessageOptions.getDeleteAfterSeconds(message);
      if (seconds != null && seconds > 0) {
        message.deleteTime = DateTime.now().add(Duration(seconds: seconds));
        if (database) await _messageStorage.updateDeleteTime(message.msgId, message.deleteTime);
      }
      if (contact != null) {
        if (contact.options?.deleteAfterSeconds != seconds) {
          contact.options?.updateBurnAfterTime = DateTime.now().millisecondsSinceEpoch;
          contactCommon.setOptionsBurn(contact, seconds, notify: true); // await
        }
      }
    }
    return message;
  }

  /// ******************************************************   Messages   ****************************************************** ///

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
      unreadList.asMap().forEach((index, MessageSchema element) {
        read(element); // await
        if (index >= unreadList.length - 1) {
          sessionCommon.setUnReadCount(element.targetId, 0, notify: true); // await
        }
      });
      list = list.map((e) => e.isOutbound == false ? MessageStatus.set(e, MessageStatus.ReceivedRead) : e).toList(); // fake read
    }
    return list;
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> read(MessageSchema schema) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    return schema;
  }

  Future<OnMessage?> sendData(String dest, String data) async {
    return await this.client?.sendText([dest], data);
  }

  Future<OnMessage?> publishData(String topic, String data) async {
    return await this.client?.publishText(topic, data);
  }
}
