import 'dart:async';
import 'dart:io';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';

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

  Future<OnMessage?> clientSendData(String? dest, String data, {int tryCount = 0, int maxTryCount = 5}) async {
    if (dest == null || dest.isEmpty) return null;
    if (tryCount >= maxTryCount) {
      logger.w("$TAG - clientSendData - try over - dest:$dest - data:$data");
      return null;
    }
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText([dest], data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.d("$TAG - clientSendData - send success - dest:$dest - data:$data");
        return onMessage;
      } else {
        await Future.delayed(Duration(seconds: 2));
        logger.w("$TAG - clientSendData - result is empty - dest:$dest - data:$data");
        return clientSendData(dest, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
      }
    } catch (e) {
      if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
        await Future.delayed(Duration(milliseconds: 100));
        final client = (await clientCommon.reSignIn(false))[0];
        if (client != null && (client.address.isNotEmpty == true)) {
          logger.i("$TAG - clientSendData - reSignIn success - dest:$dest data:$data");
          return clientSendData(dest, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
        } else {
          final wallet = await walletCommon.getDefault();
          logger.w("$TAG - clientSendData - reSignIn fail - wallet:$wallet");
          return null;
        }
      } else if (e.toString().contains("invalid destination")) {
        logger.w("$TAG - clientSendData - wrong clientAddress - dest:$dest");
        return null;
      } else {
        handleError(e);
        await Future.delayed(Duration(seconds: 2));
        logger.w("$TAG - clientSendData - try be error - dest:$dest - data:$data");
        return clientSendData(dest, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
      }
    }
  }

  Future<List<OnMessage>> clientPublishData(String? topic, String data, {bool txPool = true, int? total, int tryCount = 0, int maxTryCount = 5}) async {
    if (topic == null || topic.isEmpty || clientCommon.client == null) return [];
    if (tryCount >= maxTryCount) {
      logger.w("$TAG - clientPublishData - try over - dest:$topic - data:$data");
      return [];
    }
    try {
      // once
      if (total == null || total <= 1000) {
        OnMessage result = await clientCommon.client!.publishText(topic, data, txPool: txPool, offset: 0, limit: 1000);
        return [result];
      }
      // split
      List<Future<OnMessage>> futures = [];
      for (int i = 0; i < total; i += 1000) {
        futures.add(clientCommon.client!.publishText(topic, data, txPool: txPool, offset: i, limit: i + 1000));
      }
      List<OnMessage> onMessageList = await Future.wait(futures);
      logger.i("$TAG - clientPublishData - topic:$topic - total:$total - data$data - onMessageList:$onMessageList");
      return onMessageList;
    } catch (e) {
      if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
        await Future.delayed(Duration(milliseconds: 100));
        final client = (await clientCommon.reSignIn(false))[0];
        if (client != null && (client.address.isNotEmpty == true)) {
          logger.i("$TAG - clientPublishData - reSignIn success - topic:$topic data:$data");
          return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: tryCount, maxTryCount: maxTryCount);
        } else {
          final wallet = await walletCommon.getDefault();
          logger.w("$TAG - clientPublishData - reSignIn fail - wallet:$wallet");
          return [];
        }
      } else {
        handleError(e);
        await Future.delayed(Duration(seconds: 2));
        logger.w("$TAG - clientPublishData - try be error - topic:$topic - data:$data");
        return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: tryCount, maxTryCount: maxTryCount);
      }
    }
  }

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    String? clientAddress = message.isOutbound ? (message.isTopic ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    if (exist == null) {
      logger.i("$TAG - contactHandle - new - clientAddress:$clientAddress");
      int type = message.isTopic ? ContactType.none : ContactType.stranger;
      exist = await contactCommon.addByType(clientAddress, type, notify: true, checkDuplicated: false);
    } else {
      if ((exist.type == ContactType.none) && !message.isTopic) {
        exist.type = ContactType.stranger;
        await contactCommon.setType(exist.id, exist.type, notify: true);
      }
      // profile
      if (exist.profileUpdateAt == null || DateTime.now().millisecondsSinceEpoch > (exist.profileUpdateAt! + Global.profileExpireMs)) {
        logger.i("$TAG - contactHandle - sendRequestHeader - contact:$exist");
        chatOutCommon.sendContactRequest(exist, RequestType.header); // await
      } else {
        double between = ((exist.profileUpdateAt! + Global.profileExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    // burning
    if (exist != null && message.canBurning && message.contentType != MessageContentType.contactOptions) {
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
              ); // await
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
      if (latest.updateAt == null || DateTime.now().millisecondsSinceEpoch > (latest.updateAt! + Global.deviceInfoExpireMs)) {
        logger.i("$TAG - deviceInfoHandle - exist - request - deviceInfo:$latest");
        chatOutCommon.sendDeviceRequest(contact.clientAddress); // await
      } else {
        double between = ((latest.updateAt! + Global.deviceInfoExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
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
              // some subscriber status wrong in new version need refresh
              // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
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
              // some subscriber status wrong in new version need refresh
              // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
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
    var unreadCount = message.isOutbound ? exist.unReadCount : (message.canNotification ? exist.unReadCount + 1 : exist.unReadCount);
    exist.unReadCount = (chatCommon.currentChatTargetId == exist.targetId) ? 0 : unreadCount;
    exist.lastMessageAt = message.sendAt;
    exist.lastMessageOptions = message.toMap();
    await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, message, exist.unReadCount, notify: true); // must await
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message) {
    if (!message.canBurning) return message;
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

  Future<int> unreadCount() {
    return _messageStorage.unReadCount();
  }

  Future<int> unReadCountByTargetId(String? targetId) {
    return _messageStorage.unReadCountByTargetId(targetId);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, {int offset = 0, int limit = 20}) {
    return _messageStorage.queryListByTargetIdWithNotDeleteAndPiece(targetId, offset: offset, limit: limit);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? (message.status == MessageStatus.SendReceipt || message.status == MessageStatus.Read) : true;
    bool success = await _messageStorage.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (success && notify) _onDeleteSink.add(message.msgId);
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {int? receiveAt, bool force = false, bool notify = false, int tryCount = 0}) async {
    if (status <= message.status && !force) return message;
    // pieces will set sendReceipt fast, set sendSuccess lowly
    if (message.status == MessageStatus.Sending && status != MessageStatus.SendSuccess) {
      if (!force && (message.content is File) && (tryCount <= 5)) {
        logger.i("$TAG - updateMessageStatus - piece to fast - new:$status - old:${message.status} - msgId:${message.msgId}");
        await Future.delayed(Duration(seconds: 1));
        MessageSchema? _message = await _messageStorage.query(message.msgId);
        if (_message != null) return updateMessageStatus(_message, status, receiveAt: receiveAt, force: force, notify: notify, tryCount: ++tryCount);
      }
    }
    // update
    message.status = status;
    bool success = await _messageStorage.updateStatus(message.msgId, status, receiveAt: receiveAt);
    if (success && notify) _onUpdateSink.add(message);
    // delete later
    if (message.isDelete && message.content != null) {
      if (status == MessageStatus.SendReceipt || status == MessageStatus.Read) {
        logger.i("$TAG - updateMessageStatus - delete later yes - message:$message");
        _messageStorage.updateIsDelete(message.msgId, true, clearContent: true); // await
      } else {
        logger.i("$TAG - updateMessageStatus - delete later no - message:$message");
      }
    }
    return message;
  }

  Future readMessagesBySelf(String? targetId, String? clientAddress) async {
    if (targetId == null || targetId.isEmpty) return;
    // update messages
    List<String> msgIds = [];
    List<Future> futures = [];
    List<MessageSchema> unreadList = await _messageStorage.queryListByTargetIdWithUnRead(targetId);
    unreadList.forEach((element) {
      msgIds.add(element.msgId);
      futures.add(updateMessageStatus(element, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false));
    });
    await Future.wait(futures);
    // send messages
    if ((clientAddress?.isNotEmpty == true) && msgIds.isNotEmpty) {
      await chatOutCommon.sendRead(clientAddress, msgIds);
    }
  }

  Future<int> readMessageBySide(String? targetId, int? sendAt, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    // noReads
    List<MessageSchema> noReads = await _messageStorage.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, offset: offset, limit: limit);
    List<MessageSchema> shouldReads = noReads.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
    // read
    List<Future> futures = [];
    shouldReads.forEach((element) {
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : null;
      futures.add(updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true));
    });
    await Future.wait(futures);
    // loop
    if (noReads.length >= limit) return readMessageBySide(targetId, sendAt, offset: offset + limit, limit: limit);
    logger.i("$TAG - readMessageBySide - readCount:${offset + noReads.length} - reallySendAt:${timeFormat(DateTime.fromMillisecondsSinceEpoch(sendAt))}");
    return offset + noReads.length;
  }

  Future<int> checkSending({int? delayMs}) async {
    if (!dbCommon.isOpen()) return 0;
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    List<MessageSchema> sendingList = await _messageStorage.queryListByStatus(MessageStatus.Sending);
    List<Future> futures = [];
    sendingList.forEach((message) {
      int msgSendAt = (message.sendAt ?? DateTime.now().millisecondsSinceEpoch);
      if (DateTime.now().millisecondsSinceEpoch - msgSendAt < (60 * 1000)) {
        logger.d("$TAG - checkSending - sendAt justNow - targetId:${message.targetId} - message:$message");
      } else {
        logger.i("$TAG - checkSending - sendFail add - targetId:${message.targetId} - message:$message");
        futures.add(chatCommon.updateMessageStatus(message, MessageStatus.SendFail, notify: true));
      }
    });
    await Future.wait(futures);
    logger.i("$TAG - checkSending - checkCount:${sendingList.length}");
    return sendingList.length;
  }

  Future sendPang2SessionsContact({int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    int max = 100;
    int limit = 20;
    List<SessionSchema> sessions = [];

    // sessions
    for (int offset = 0; true; offset += limit) {
      List<SessionSchema> result = await sessionCommon.queryListRecent(offset: offset, limit: limit);
      result.forEach((element) {
        if (element.isContact) sessions.add(element);
      });
      logger.d("$TAG - sendPang2SessionsContact - offset:$offset - current_len:${result.length} - total_len:${sessions.length}");
      if ((result.length < limit) || (sessions.length >= max)) break;
    }

    List<Future> futures = [];
    sessions.forEach((session) {
      logger.d("$TAG - sendPang2SessionsContact - send pang - session:$session");
      futures.add(chatOutCommon.sendPing(session.targetId, false));
    });
    await Future.wait(futures);
  }
}
