import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';
import '../settings.dart';

class ChatCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  Map<String, DateTime> deletedCache = Map<String, DateTime>();

  Future<OnMessage?> sendData(String dest, String data) async {
    return await clientCommon.client?.sendText([dest], data);
  }

  Future<OnMessage?> publishData(String topic, String data) async {
    return await clientCommon.client?.publishText(topic, data);
  }

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
        logger.d("$TAG - contactHandle - sendRequestHeader - schema:$exist");
        await chatOutCommon.sendContactRequest(exist, RequestType.header);
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

  Future<void> notificationHandle(ContactSchema? contact, TopicSchema? topic, MessageSchema message) async {
    if (!message.canDisplayAndRead) return null;
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

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplayAndRead) return null;
    // duplicated
    if (message.targetId == null || message.targetId!.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(message.targetId);
    if (exist == null) {
      logger.d("$TAG - sessionHandle - new - targetId:${message.targetId}");
      return await sessionCommon.add(SessionSchema(targetId: message.targetId!, type: SessionSchema.getTypeByMessage(message)), lastMsg: message);
    }
    if (message.isOutbound) {
      await sessionCommon.setLastMessage(message.targetId, message, notify: true);
    } else {
      int unreadCount = exist.unReadCount + 1;
      await sessionCommon.setLastMessageAndUnReadCount(message.targetId, message, unreadCount, notify: true);
    }
    return exist;
  }

  Future<MessageSchema> burningHandle(MessageSchema message, {ContactSchema? contact}) async {
    if (!message.canDisplayAndRead || message.isTopic) return message;
    int? seconds = MessageOptions.getDeleteAfterSeconds(message);
    if (seconds != null && seconds > 0) {
      message.deleteTime = DateTime.now().add(Duration(seconds: seconds));
      bool success = await _messageStorage.updateDeleteTime(message.msgId, message.deleteTime);
      if (success) onUpdateSink.add(message);
    }
    // if (contact != null) {
    //   if (contact.options?.deleteAfterSeconds != seconds) {
    //     contact.options?.updateBurnAfterTime = DateTime.now().millisecondsSinceEpoch;
    //     contactCommon.setOptionsBurn(contact, seconds, notify: true); // await
    //   }
    // }
    return message;
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
      _messageStorage.queryListUnReadByTargetId(targetId).then((List<MessageSchema> unreadList) {
        unreadList.asMap().forEach((index, MessageSchema element) {
          if (index == 0) {
            sessionCommon.setUnReadCount(element.targetId, 0, notify: true); // await
          }
          msgRead(element); // await
          // if (index >= unreadList.length - 1) {
          //   sessionCommon.setUnReadCount(element.targetId, 0, notify: true); // await
          // }
        });
      });
      list = list.map((e) => e.isOutbound == false ? MessageStatus.set(e, MessageStatus.ReceivedRead) : e).toList(); // fake read
    }
    return list;
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> msgRead(MessageSchema schema, {bool notify = false}) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    if (notify) onUpdateSink.add(schema);
    return schema;
  }

  Future<bool> msgDelete(String msgId, {bool notify = false}) async {
    bool success = await _messageStorage.delete(msgId);
    if (success) deletedCache[msgId] = DateTime.now();
    if (success && notify) onDeleteSink.add(msgId);
    return success;
  }
}
