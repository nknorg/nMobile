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
      SessionSchema? added = SessionSchema(targetId: message.targetId!, type: SessionSchema.getTypeByMessage(message));
      added = await sessionCommon.add(added, message, notify: true);
      logger.i("$TAG - sessionHandle - new - targetId:${message.targetId} - added:$added");
      return added;
    }
    // update
    var unreadCount = message.isOutbound ? exist.unReadCount : (message.canDisplayAndRead ? exist.unReadCount + 1 : exist.unReadCount);
    exist.unReadCount = (chatCommon.currentChatTargetId == exist.targetId) ? 0 : unreadCount;
    exist.lastMessageAt = message.sendAt;
    exist.lastMessageOptions = message.toMap();
    await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, message, exist.unReadCount, notify: true); // must await
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message) {
    if (!message.canBurning || message.isTopic) return message;
    List<int?> burningOptions = MessageOptions.getContactBurning(message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    if (burnAfterSeconds != null && burnAfterSeconds > 0) {
      // set delete time
      logger.i("$TAG - burningHandle - updateDeleteAt - message:$message");
      message.deleteAt = DateTime.now().add(Duration(seconds: burnAfterSeconds)).millisecondsSinceEpoch;
      _messageStorage.updateDeleteAt(message.msgId, message.deleteAt).then((success) {
        if (success) _onUpdateSink.add(message);
      });
    }
    return message;
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? (message.status == MessageStatus.SendReceipt) : true;
    bool success = await _messageStorage.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (success && notify) _onDeleteSink.add(message.msgId);
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {bool notify = false}) async {
    message.status = status;
    bool success = await _messageStorage.updateStatus(message.msgId, status);
    if (success && notify) _onUpdateSink.add(message);
    // delete later
    if (message.isDelete && message.content != null) {
      if (status == MessageStatus.SendReceipt) {
        logger.i("$TAG - updateMessageStatus - delete later - message:$message");
        _messageStorage.updateIsDelete(message.msgId, true, clearContent: true); // await
      }
    }
    return message;
  }

  Future<int> unreadCount() {
    return _messageStorage.unReadCount();
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, {int offset = 0, int limit = 20}) {
    return _messageStorage.queryListByTargetIdWithNotDeleteAndPiece(targetId, offset: offset, limit: limit);
  }

  Future<bool> readMessages(String? targetId, {bool badgeDown = false}) async {
    // TODO:GG read message
    // read
    int count = await _messageStorage.updateStatusReadByTargetIdWho(targetId, true);
    logger.i("$TAG - readMessages - count:$count");
    // badge
    if (badgeDown) {
      int badgeDown = await _messageStorage.unReadCountByTargetId(targetId);
      Badge.onCountDown(badgeDown); // await
    }
    return true;
  }
}
