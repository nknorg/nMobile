import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';

import '../settings.dart';

class ChatCommon with Tag {
  String? currentTalkId;

  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  MessageStorage _messageStorage = MessageStorage();

  Map<String, Map<String, DateTime>> deletedCache = Map<String, Map<String, DateTime>>();

  ChatCommon();

  Future<OnMessage?> clientSendData(String? dest, String data) async {
    if (dest == null || dest.isEmpty) return null;
    return await clientCommon.client?.sendText([dest], data);
  }

  Future<OnMessage?> clientPublishData(String? topic, String data) async {
    if (topic == null || topic.isEmpty) return null;
    return await clientCommon.client?.publishText(topic, data);
  }

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    String? clientAddress = message.isOutbound ? message.to : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    if (exist == null) {
      logger.d("$TAG - contactHandle - new - clientAddress:$clientAddress");
      exist = await contactCommon.addByType(clientAddress, ContactType.stranger, checkDuplicated: false);
    } else {
      // profile
      if (exist.profileUpdateAt == null || DateTime.now().millisecondsSinceEpoch > (exist.profileUpdateAt! + Settings.profileExpireMs)) {
        logger.d("$TAG - contactHandle - sendRequestHeader - schema:$exist");
        chatOutCommon.sendContactRequest(exist, RequestType.header); // await
      } else {
        double between = ((exist.profileUpdateAt! + Settings.profileExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    // burning
    if (exist != null && message.canBurning && !message.isTopic && message.contentType != ContentType.contactOptions) {
      List<int?> burningOptions = MessageOptions.getContactBurning(message);
      int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
      int? updateBurnAfterAt = burningOptions.length >= 2 ? burningOptions[1] : null;
      if (burnAfterSeconds != null && burnAfterSeconds > 0 && exist.options?.deleteAfterSeconds != burnAfterSeconds) {
        if (exist.options?.updateBurnAfterAt == null || (updateBurnAfterAt ?? 0) > exist.options!.updateBurnAfterAt!) {
          // side update latest
          exist.options?.deleteAfterSeconds = burnAfterSeconds;
          exist.options?.updateBurnAfterAt = updateBurnAfterAt;
          contactCommon.setOptionsBurn(exist, burnAfterSeconds, updateBurnAfterAt, notify: true); // await
        } else if ((updateBurnAfterAt ?? 0) <= exist.options!.updateBurnAfterAt!) {
          // mine update latest
          DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(exist.id);
          if (deviceInfoCommon.isBurningUpdateAtEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
            chatOutCommon.sendContactOptionsBurn(
              exist.clientAddress,
              exist.options!.deleteAfterSeconds!,
              exist.options!.updateBurnAfterAt!,
            );
          }
        }
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> deviceInfoHandle(MessageSchema message, ContactSchema? contact) async {
    if (message.contentType == ContentType.deviceRequest || message.contentType == ContentType.deviceInfo) return null;
    if (contact == null || contact.id == null || contact.id == 0) return null;
    // duplicated
    DeviceInfoSchema? latest = await deviceInfoCommon.queryLatest(contact.id);
    if (latest == null) {
      logger.d("$TAG - deviceInfoHandle - new - request - contact:$contact");
      await chatOutCommon.sendDeviceRequest(contact.clientAddress);
    } else {
      if (latest.updateAt == null || DateTime.now().millisecondsSinceEpoch > (latest.updateAt! + Settings.deviceInfoExpireMs)) {
        logger.d("$TAG - deviceInfoHandle - exist - request - schema:$latest");
        await chatOutCommon.sendDeviceRequest(contact.clientAddress);
      } else {
        double between = ((latest.updateAt! + Settings.deviceInfoExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG deviceInfoHandle - expire - between:${between}s");
      }
    }
    return latest;
  }

  Future<TopicSchema?> topicHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    if (!message.isTopic) return null;
    TopicSchema? exist = await topicCommon.queryByTopic(message.topic);
    if (exist == null) {
      exist = await topicCommon.add(TopicSchema.create(message.topic));
    }
    // TODO:GG how to update profile
    return exist;
  }

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    if (message.targetId == null || message.targetId!.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(message.targetId);
    if (exist == null) {
      logger.d("$TAG - sessionHandle - new - targetId:${message.targetId}");
      return await sessionCommon.add(SessionSchema(
        targetId: message.targetId!,
        type: SessionSchema.getTypeByMessage(message),
        lastMessageTime: message.sendTime,
        lastMessageOptions: message.toMap(),
        isTop: false,
        unReadCount: message.isOutbound || !message.canDisplayAndRead ? 0 : 1,
      ));
    }
    if (message.isOutbound) {
      await sessionCommon.setLastMessage(message.targetId, message, notify: true);
    } else {
      int unreadCount = message.canDisplayAndRead ? exist.unReadCount + 1 : exist.unReadCount;
      await sessionCommon.setLastMessageAndUnReadCount(message.targetId, message, unreadCount, notify: true);
    }
    return exist;
  }

  Future<MessageSchema> burningHandle(MessageSchema message) async {
    if (!message.canBurning || message.isTopic) return message;
    List<int?> burningOptions = MessageOptions.getContactBurning(message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    if (burnAfterSeconds != null && burnAfterSeconds > 0) {
      message.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
      bool success = await _messageStorage.updateDeleteTime(message.msgId, message.deleteTime);
      if (success) onUpdateSink.add(message);
    }
    return message;
  }

  Future<List<MessageSchema>> queryListAndReadByTargetId(
    String? targetId, {
    int offset = 0,
    int limit = 20,
    int? unread,
    bool handleBurn = true,
  }) async {
    List<MessageSchema> list = await _messageStorage.queryListCanDisplayReadByTargetId(targetId, offset: offset, limit: limit);
    // unread
    if (offset == 0 && (unread == null || unread > 0)) {
      _messageStorage.queryListUnReadByTargetId(targetId).then((List<MessageSchema> unreadList) {
        int badgeDown = 0;
        unreadList.asMap().forEach((index, MessageSchema element) {
          if (index == 0) {
            sessionCommon.setUnReadCount(element.targetId, 0, notify: true); // await
          }
          updateMessageStatus(element, MessageStatus.ReceivedRead); // await
          // if (index >= unreadList.length - 1) {
          //   sessionCommon.setUnReadCount(element.targetId, 0, notify: true); // await
          // }
          if (element.canDisplayAndRead) badgeDown++;
        });
        Badge.onCountDown(badgeDown);
      });
      list = list.map((e) => e.isOutbound == false ? MessageStatus.set(e, MessageStatus.ReceivedRead) : e).toList(); // fake read
    }
    return list;
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> updateMessageStatus(MessageSchema schema, int status, {bool notify = false}) async {
    schema = MessageStatus.set(schema, status);
    await _messageStorage.updateMessageStatus(schema);
    if (notify) onUpdateSink.add(schema);
    return schema;
  }

  Future<int> unreadCount() {
    return _messageStorage.unReadCount();
  }

  Future<bool> msgDelete(String msgId, {bool notify = false}) async {
    bool success = await _messageStorage.delete(msgId);
    if (success) {
      String key = clientCommon.address ?? "";
      if (deletedCache[key] == null) deletedCache[key] = Map();
      deletedCache[key]![msgId] = DateTime.now();
    }
    if (success && notify) onDeleteSink.add(msgId);
    return success;
  }
}
