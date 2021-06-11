import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nmobile/common/chat/send_message.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

import '../global.dart';
import '../locator.dart';

class ReceiveMessage with Tag {
  ReceiveMessage() {
    start();
  }

  // ignore: close_sinks
  StreamController<MessageSchema> _onReceiveController = StreamController<MessageSchema>(); //.broadcast();
  StreamSink<MessageSchema> get onReceiveSink => _onReceiveController.sink;
  Stream<MessageSchema> get onReceiveStream => _onReceiveController.stream.distinct((prev, next) => prev.pid == next.pid);

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  Future start() async {
    await for (MessageSchema received in onReceiveStream) {
      await _messageHandle(received);
    }
  }

  Future onClientMessage(MessageSchema? message, {bool sync = false}) async {
    if (message == null) return;
    // contact
    ContactSchema? contactSchema = await _contactHandle(message);
    // topic
    TopicSchema? topicSchema = await _topicHandle(message);
    // notification
    _notificationHandle(contactSchema, topicSchema, message);
    // session
    await _sessionHandle(message);
    // message
    if (!sync) {
      onReceiveSink.add(message);
    } else {
      await _messageHandle(message);
    }
  }

  Future<ContactSchema?> _contactHandle(MessageSchema received) async {
    if (!received.canRead) return null;
    // duplicated
    if (received.from.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(received.from);
    if (exist == null) {
      logger.d("$TAG - contactHandle - new - from:${received.from}");
      return await contactCommon.addByType(received.from, ContactType.stranger, checkDuplicated: false);
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

  Future<TopicSchema?> _topicHandle(MessageSchema received) async {
    if (!received.canRead) return null;
    // duplicated TODO:GG topic duplicated
    if (received.topic == null || received.topic!.isEmpty) return null;
    TopicSchema? exist = await _topicStorage.queryTopicByTopicName(received.topic);
    if (exist == null) {
      return await _topicStorage.insertTopic(TopicSchema(
        // TODO: get topic info
        // expireAt:
        // joined:
        topic: received.topic!,
      ));
    }
    return exist;
  }

  Future<void> _notificationHandle(ContactSchema? contact, TopicSchema? topic, MessageSchema message) async {
    if (!message.canRead) return null;
    late String title;
    late String content;
    if (contact != null && topic == null) {
      title = contact.displayName;
      content = message.content;
    } else if (topic != null) {
      notification.showDChatNotification('[${topic.topicShort}] ${contact?.displayName}', message.content);
      title = '[${topic.topicShort}] ${contact?.displayName}';
      content = message.content;
    }

    S localizations = S.of(Global.appContext);
    // TODO: notification
    switch (message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        notification.showDChatNotification(title, content);
        break;
      case ContentType.media:
      case ContentType.image:
      case ContentType.nknImage:
        notification.showDChatNotification(title, '[${localizations.image}]');
        break;
      case ContentType.audio:
        notification.showDChatNotification(title, '[${localizations.audio}]');
        break;
      // TODO:GG notification contentType
      case ContentType.system:
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
      case ContentType.eventChannelInvitation:
        // case ContentType.contact:
        // case ContentType.receipt:
        // case ContentType.piece:
        // case ContentType.eventContactOptions:
        break;
    }
  }

  Future<SessionSchema?> _sessionHandle(MessageSchema received) async {
    if (!received.canRead) return null;
    // duplicated
    if (received.targetId == null || received.targetId!.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(received.targetId);
    if (exist == null) {
      logger.d("$TAG - sessionHandle - new - targetId:${received.targetId}");
      return await sessionCommon.add(SessionSchema(targetId: received.targetId!, type: SessionSchema.getTypeByMessage(received)));
    }
    return exist;
  }

  Future _messageHandle(MessageSchema received) async {
    switch (received.contentType) {
      case ContentType.receipt:
        _receiveReceipt(received); // await
        break;
      case ContentType.contact:
        _receiveContact(received); // await
        break;
      case ContentType.piece:
        await _receivePiece(received);
        break;
      case ContentType.text:
        await _receiveText(received);
        break;
      case ContentType.media:
      case ContentType.image:
      case ContentType.nknImage:
        await _receiveImage(received);
        break;
      case ContentType.eventContactOptions:
        _receiveContactOptions(received); // await
        break;
      // TODO:GG receive contentType
      case ContentType.system:
      case ContentType.textExtension:
      case ContentType.audio:
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
      case ContentType.eventChannelInvitation:
        break;
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future _receiveReceipt(MessageSchema received) async {
    List<MessageSchema> _schemaList = await _messageStorage.queryList(received.content);
    _schemaList.forEach((MessageSchema element) async {
      element = MessageStatus.set(element, MessageStatus.SendWithReceipt);
      bool updated = await _messageStorage.updateMessageStatus(element);
      if (updated) {
        // update send by receipt
        sendMessage.onUpdateSink.add(element);
      }
      logger.d("$TAG - receiveReceipt - updated:$element");
    });
  }

  // NO DB NO display (1 to 1)
  Future _receiveContact(MessageSchema received) async {
    if (received.content == null) return;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? exist = await contactCommon.queryByClientAddress(received.from);
    if (exist == null) {
      logger.w("$TAG - receiveContact - empty - data:$data");
      return;
    }
    // D-Chat NO support piece
    String? supportPiece = data[MessageData.K_CONTACT_PIECE_SUPPORT]?.toString();
    if (supportPiece?.isNotEmpty == true) {
      contactCommon.setSupportPiece(received.from, value: supportPiece); // await
    }
    // D-Chat NO RequestType.header
    String? requestType = data['requestType']?.toString();
    String? responseType = data['responseType']?.toString();
    String? version = data['version']?.toString();
    Map<String, dynamic>? content = data['content'];
    if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
      // need reply
      if (requestType == RequestType.header) {
        await sendMessage.sendContactResponse(exist, RequestType.header);
      } else {
        await sendMessage.sendContactResponse(exist, RequestType.full);
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
        if (responseType != RequestType.full && content == null) {
          await sendMessage.sendContactRequest(exist, RequestType.full);
        } else {
          if (content == null) {
            logger.w("$TAG - receiveContact - content is empty - data:$data");
            return;
          }
          String firstName = content['first_name'] ?? content['name'] ?? "";
          String lastName = content['last_name'] ?? "";
          File? avatar;
          String? avatarType = content['avatar'] != null ? content['avatar']['type'] : null;
          if (avatarType?.isNotEmpty == true) {
            String? avatarData = content['avatar'] != null ? content['avatar']['data'] : null;
            if (avatarData?.isNotEmpty == true) {
              if (avatarData.toString().split(",").length != 1) {
                avatarData = avatarData.toString().split(",")[1];
              }
              avatar = await FileHelper.convertBase64toFile(avatarData, SubDirType.contact, extension: "jpg");
            }
          }
          await contactCommon.setOtherProfile(exist, firstName, lastName, avatar?.path ?? "", version, notify: true);
          logger.i("$TAG - receiveContact - setProfile - firstName:$firstName - avatar:${avatar?.path} - version:$version - data:$data");
        }
      } else {
        logger.d("$TAG - receiveContact - profileVersionSame - contact:$exist - data:$data");
      }
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future _receiveContactOptions(MessageSchema received) async {
    if (received.content == null) return;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? existContact = await contactCommon.queryByClientAddress(received.from);
    if (existContact == null) {
      logger.w("$TAG - _receiveContactOptions - empty - received:$received");
      return;
    }
    List<MessageSchema> existsMsg = await _messageStorage.queryList(received.msgId);
    if (existsMsg.isNotEmpty) {
      logger.d("$TAG - receiveText - duplicated - schema:$existsMsg");
      sendMessage.sendReceipt(existsMsg[0]); // await
      return;
    }
    // options type // TODO: remove optionsType
    String? optionsType = data[MessageData.K_CONTACT_OPTIONS_TYPE]?.toString();
    Map<String, dynamic> content = data['content'] ?? Map();
    if (optionsType == null || optionsType.isEmpty) return;
    if (optionsType == MessageData.V_CONTACT_OPTIONS_TYPE_BURN_TIME) {
      int seconds = (content['deleteAfterSeconds'] as int?) ?? 0;
      logger.i("$TAG - _receiveContactOptions - setBurn - seconds:$seconds - data:$data");
      contactCommon.setOptionsBurn(existContact, seconds, notify: true);
    } else if (optionsType == MessageData.V_CONTACT_OPTIONS_TYPE_DEVICE_TOKEN) {
      String deviceToken = (content['deviceToken']?.toString()) ?? "";
      logger.i("$TAG - _receiveContactOptions - setDeviceToken - deviceToken:$deviceToken - data:$data");
      contactCommon.setDeviceToken(existContact.id, deviceToken, notify: true);
    } else {
      logger.w("$TAG - _receiveContactOptions - setNothing - data:$data");
      return;
    }
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // receipt
    sendMessage.sendReceipt(schema); // await
    // display
    onSavedSink.add(schema);
  }

  // NO DB NO display
  Future _receivePiece(MessageSchema received) async {
    // duplicated
    List<MessageSchema> existsCombine = await _messageStorage.queryListByType(received.msgId, received.parentType);
    if (existsCombine.isNotEmpty) {
      logger.d("$TAG - receivePiece - duplicated - schema:$existsCombine");
      sendMessage.sendReceipt(existsCombine[0]); // await
      return;
    }
    // piece
    MessageSchema? piece = await _messageStorage.queryByPid(received.pid);
    if (piece == null) {
      received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.cache, extension: received.parentType);
      piece = await _messageStorage.insert(received);
    }
    if (piece == null) return;
    // pieces
    int total = piece.total ?? SendMessage.maxPiecesTotal;
    int parity = piece.parity ?? (total ~/ SendMessage.piecesParity);
    int bytesLength = piece.bytesLength ?? 0;
    int piecesCount = await _messageStorage.queryCountByType(piece.msgId, piece.contentType);
    logger.d("$TAG - receivePiece - progress:$piecesCount/${piece.total}/${total + parity}");
    if (piecesCount < total || bytesLength <= 0) return;
    logger.d("$TAG - receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema> pieces = await _messageStorage.queryListByType(piece.msgId, piece.contentType);
    pieces.sort((prev, next) => (prev.index ?? SendMessage.maxPiecesTotal).compareTo((next.index ?? SendMessage.maxPiecesTotal)));
    // recover
    List<Uint8List> recoverList = <Uint8List>[];
    for (int index = 0; index < total + parity; index++) {
      recoverList.add(Uint8List(0)); // fill
    }
    int recoverCount = 0;
    for (int index = 0; index < pieces.length; index++) {
      MessageSchema item = pieces[index];
      File? file = item.content as File?;
      if (file == null || !file.existsSync()) {
        logger.w("$TAG - receivePiece - COMBINE:ERROR - file no exists - item:$item - file:${file?.path}");
        continue;
      }
      Uint8List itemBytes = file.readAsBytesSync();
      if (item.index != null && item.index! >= 0 && item.index! < recoverList.length) {
        recoverList[item.index!] = itemBytes;
        recoverCount++;
      }
    }
    if (recoverCount < total) {
      logger.w("$TAG - receivePiece - COMBINE:FAIL - recover_lost:${pieces.length - recoverCount}");
      return;
    }
    // combine
    String? base64String = await Common.combinePieces(recoverList, total, parity, bytesLength);
    if (base64String == null || base64String.isEmpty) {
      logger.w("$TAG - receivePiece - COMBINE:FAIL - base64String is empty");
      return;
    }
    MessageSchema combine = MessageSchema.fromPieces(pieces, base64String);
    // combine.content - handle later
    logger.d("$TAG - receivePiece - COMBINE:SUCCESS - combine:$combine");
    await onClientMessage(combine, sync: true);
    // delete
    logger.d("$TAG - receivePiece - DELETE:START - pieces_count:${pieces.length}");
    bool deleted = await _messageStorage.deleteByType(piece.msgId, piece.contentType);
    if (deleted) {
      pieces.forEach((MessageSchema element) {
        if (element.content is File) {
          if ((element.content as File).existsSync()) {
            (element.content as File).delete(); // await
            logger.d("$TAG - receivePiece - DELETE:PROGRESS - path:${(element.content as File).path}");
          } else {
            logger.w("$TAG - receivePiece - DELETE:ERROR - NoExists - path:${(element.content as File).path}");
          }
        } else {
          logger.w("$TAG - receivePiece - DELETE:ERROR - empty:${element.content?.toString()}");
        }
      });
      logger.d("$TAG - receivePiece - DELETE:SUCCESS - count:${pieces.length}");
    } else {
      logger.w("$TAG - receivePiece - DELETE:FAIL - empty - pieces:$pieces");
    }
  }

  Future _receiveText(MessageSchema received) async {
    // duplicated
    List<MessageSchema> exists = await _messageStorage.queryList(received.msgId);
    if (exists.isNotEmpty) {
      logger.d("$TAG - receiveText - duplicated - schema:$exists");
      sendMessage.sendReceipt(exists[0]); // await
      return;
    }
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // receipt
    sendMessage.sendReceipt(schema); // await
    // display
    onSavedSink.add(schema);
    // session
    sessionCommon.setLastMessageAndUnReadCount(schema.targetId, schema, null, notify: true); // await
  }

  Future _receiveImage(MessageSchema received) async {
    bool isPieceCombine = received.options != null ? received.options![MessageOptions.KEY_PARENT_PIECE] : false;
    // duplicated
    List<MessageSchema> exists = [];
    if (isPieceCombine) {
      exists = await _messageStorage.queryListByType(received.msgId, received.contentType);
    } else {
      exists = await _messageStorage.queryList(received.msgId); // old version will send type nknImage/media/image
    }
    if (exists.isNotEmpty) {
      logger.d("$TAG - receiveImage - duplicated - schema:$exists");
      sendMessage.sendReceipt(exists[0]); // await
      return;
    }
    // File
    received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.chat, extension: isPieceCombine ? "jpg" : null);
    if (received.content == null) return;
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // receipt
    sendMessage.sendReceipt(schema); // await
    // display
    onSavedSink.add(schema);
    // session
    sessionCommon.setLastMessageAndUnReadCount(schema.targetId, schema, null, notify: true); // await
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> read(MessageSchema schema) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    return schema;
  }
}
