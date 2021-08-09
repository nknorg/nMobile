import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';

import '../settings.dart';

class ChatCommon with Tag {
  String? currentChatTargetId;

  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get _onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  MessageStorage _messageStorage = MessageStorage();

  Map<String, Map<String, DateTime>> deletedCache = Map<String, Map<String, DateTime>>();

  ChatCommon();

  Future<OnMessage?> clientSendData(String? dest, String data) async {
    if (dest == null || dest.isEmpty) return null;
    return await clientCommon.client?.sendText([dest], data);
  }

  Future<OnMessage?> clientPublishData(String? topic, String data, {bool txPool = true}) async {
    if (topic == null || topic.isEmpty) return null;
    return await clientCommon.client?.publishText(topic, data, txPool: txPool);
  }

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    String? clientAddress = message.isOutbound ? (message.isTopic ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    if (exist == null) {
      logger.i("$TAG - contactHandle - new - clientAddress:$clientAddress");
      exist = await contactCommon.addByType(clientAddress, ContactType.stranger, notify: true, checkDuplicated: false);
    } else {
      // profile
      if (exist.profileUpdateAt == null || DateTime.now().millisecondsSinceEpoch > (exist.profileUpdateAt! + Settings.profileExpireMs)) {
        logger.d("$TAG - contactHandle - sendRequestHeader - contact:$exist");
        chatOutCommon.sendContactRequest(exist, RequestType.header); // await
      } else {
        double between = ((exist.profileUpdateAt! + Settings.profileExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    // burning
    if (exist != null && message.canBurning && !message.isTopic && message.contentType != MessageContentType.contactOptions) {
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
          deviceInfoCommon.queryLatest(exist.clientAddress).then((deviceInfo) {
            if (deviceInfoCommon.isBurningUpdateAtEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
              if (exist == null) return;
              chatOutCommon.sendContactOptionsBurn(
                exist.clientAddress,
                exist.options!.deleteAfterSeconds!,
                exist.options!.updateBurnAfterAt!,
              );
            }
          });
        }
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> deviceInfoHandle(MessageSchema message, ContactSchema? contact) async {
    if (contact == null || contact.id == null || contact.id == 0) return null;
    if (message.contentType == MessageContentType.deviceRequest || message.contentType == MessageContentType.deviceInfo) return null;
    // duplicated
    DeviceInfoSchema? latest = await deviceInfoCommon.queryLatest(contact.clientAddress);
    if (latest == null) {
      logger.i("$TAG - deviceInfoHandle - new - request - contact:$contact");
      chatOutCommon.sendDeviceRequest(contact.clientAddress); // await
    } else {
      if (latest.updateAt == null || DateTime.now().millisecondsSinceEpoch > (latest.updateAt! + Settings.deviceInfoExpireMs)) {
        logger.d("$TAG - deviceInfoHandle - exist - request - deviceInfo:$latest");
        chatOutCommon.sendDeviceRequest(contact.clientAddress); // await
      } else {
        double between = ((latest.updateAt! + Settings.deviceInfoExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG deviceInfoHandle - expire - between:${between}s");
      }
    }
    return latest;
  }

  Future<TopicSchema?> topicHandle(MessageSchema message) async {
    if (!message.isTopic) return null;
    if (!message.canDisplay && !message.isTopicAction) return null; // topic action need topic
    // duplicated
    TopicSchema? exists = await topicCommon.queryByTopic(message.topic);
    if (exists == null) {
      int expireHeight = await topicCommon.getExpireAtByNode(message.topic, clientCommon.address);
      exists = await topicCommon.add(TopicSchema.create(message.topic, expireHeight: expireHeight), notify: true, checkDuplicated: false);
      // expire + permission + subscribers
      if (exists != null) {
        logger.i("$TAG - topicHandle - new - expireHeight:$expireHeight - topic:$exists ");
        topicCommon.checkExpireAndSubscribe(exists.topic, refreshSubscribers: true); // await
      } else {
        logger.w("$TAG - topicHandle - topic is empty - topic:${message.topic} ");
      }
    }
    return exists;
  }

  Future<SubscriberSchema?> subscriberHandle(MessageSchema message, TopicSchema? topic, {DeviceInfoSchema? deviceInfo}) async {
    if (topic == null || topic.id == null || topic.id == 0) return null;
    if (!message.isTopic) return null;
    if (message.isTopicAction) return null; // action users will handle in later
    // duplicated
    SubscriberSchema? exist = await subscriberCommon.queryByTopicChatId(message.topic, message.from);
    if (exist == null) {
      if (topic.isPrivate != true) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - public: add Subscribed - subscriber:$exist");
      } else {
        // will go here when duration(TxPoolDelay) gone in new version
        List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic.topic, topic.isPrivate, message.from);
        int? permPage = permission[0];
        bool? acceptAll = permission[1];
        bool? isAccept = permission[2];
        bool? isReject = permission[3];
        if (acceptAll == true) {
          exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
          logger.i("$TAG - subscriberHandle - acceptAll: add Subscribed - subscriber:$exist");
        } else {
          if (isReject == true) {
            exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Unsubscribed, permPage));
            logger.w("$TAG - subscriberHandle - reject: add Unsubscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
          } else if (isAccept == true) {
            // SUPPORT:START
            if (!deviceInfoCommon.isTopicPermissionEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
              exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
              logger.w("$TAG - subscriberHandle - accept: add Subscribed(old version) - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            } else {
              // SUPPORT:END
              int expireHeight = await topicCommon.getExpireAtByNode(topic.topic, message.from);
              if (expireHeight <= 0) {
                exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.InvitedSend, permPage));
                logger.w("$TAG - subscriberHandle - accept: add invited - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
              } else {
                exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
                logger.w("$TAG - subscriberHandle - accept: add Subscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
              }
              // some subscriber status wrong in new version nee refresh
              subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
            }
          } else {
            // SUPPORT:START
            if (!deviceInfoCommon.isTopicPermissionEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
              exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
              logger.w("$TAG - subscriberHandle - none: add Subscribed(old version) - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            } else {
              // SUPPORT:END
              int expireHeight = await topicCommon.getExpireAtByNode(topic.topic, message.from);
              if (expireHeight <= 0) {
                exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Unsubscribed, permPage));
                logger.w("$TAG - subscriberHandle - none: add Unsubscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
              } else {
                exist = SubscriberSchema.create(message.topic, message.from, SubscriberStatus.None, permPage);
                logger.w("$TAG - subscriberHandle - none: just none - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
              }
              // some subscriber status wrong in new version nee refresh
              subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
            }
          }
        }
      }
    } else if (exist.status != SubscriberStatus.Subscribed) {
      // SUPPORT:START
      if (!deviceInfoCommon.isTopicPermissionEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
        logger.w("$TAG - subscriberHandle - replace by timer in old version - from:${message.from} - status:${exist.status} - topic:$topic");
      } else {
        // SUPPORT:END
        logger.w("$TAG - subscriberHandle - some subscriber status wrong in new version - from:${message.from} - status:${exist.status} - topic:$topic");
        // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
      }
    }
    return exist;
  }

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    if (message.targetId == null || message.targetId!.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(message.targetId);
    if (exist == null) {
      SessionSchema? added = await sessionCommon.add(
        SessionSchema(
          targetId: message.targetId!,
          type: SessionSchema.getTypeByMessage(message),
          lastMessageTime: message.sendTime,
          lastMessageOptions: message.toMap(),
          isTop: false,
          unReadCount: (message.isOutbound || !message.canDisplayAndRead) ? 0 : 1,
        ),
        notify: true,
      );
      logger.i("$TAG - sessionHandle - new - targetId:${message.targetId} - added:$added");
      return added;
    }
    if (message.isOutbound) {
      exist.lastMessageTime = message.sendTime;
      exist.lastMessageOptions = message.toMap();
      await sessionCommon.setLastMessage(exist.targetId, message, notify: true); // must await
    } else {
      int unreadCount = message.canDisplayAndRead ? exist.unReadCount + 1 : exist.unReadCount;
      exist.unReadCount = unreadCount;
      exist.lastMessageTime = message.sendTime;
      exist.lastMessageOptions = message.toMap();
      await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, message, unreadCount, notify: true); // must await
    }
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message) {
    if (!message.canBurning || message.isTopic) return message;
    List<int?> burningOptions = MessageOptions.getContactBurning(message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    if (burnAfterSeconds != null && burnAfterSeconds > 0) {
      logger.i("$TAG - burningHandle - start - message:$message");
      message.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
      _messageStorage.updateDeleteTime(message.msgId, message.deleteTime).then((success) {
        if (success) _onUpdateSink.add(message);
      });
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
          updateMessageStatus(element, MessageStatus.ReceivedRead);
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
  MessageSchema updateMessageStatus(MessageSchema message, int status, {bool notify = false}) {
    message = MessageStatus.set(message, status);
    _messageStorage.updateMessageStatus(message).then((success) {
      if (success && notify) _onUpdateSink.add(message);
    });
    return message;
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
    if (success && notify) _onDeleteSink.add(msgId);
    return success;
  }
}
