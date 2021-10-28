import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

class ChatCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // current page
  String? currentChatTargetId;

  // check timers
  Map<String, Map<String, dynamic>> checkNoAckTimers = Map();

  ChatCommon();

  void clear() {
    currentChatTargetId = null;
    checkNoAckTimers.clear();
    checkSendingWithFail(force: true); // await
  }

  void setMsgStatusCheckTimer(String? targetId, bool isTopic, {bool refresh = false, int filterSec = 60}) {
    if (!clientCommon.isClientCreated) return;
    if (targetId == null || targetId.isEmpty) return;
    if (application.inBackGroundLater) return;

    if (checkNoAckTimers[targetId] == null) checkNoAckTimers[targetId] = Map();
    Timer? timer = checkNoAckTimers[targetId]?["timer"];
    // delay
    int initDelay = 3; // 3s
    int maxDelay = 5 * 60; // 5m
    int? delay = checkNoAckTimers[targetId]?["delay"];
    if (refresh || (timer == null) || (delay == null) || (delay == 0)) {
      checkNoAckTimers[targetId]?["delay"] = initDelay;
      logger.i("$TAG - setMsgStatusCheckTimer - delay init - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
    } else if (timer.isActive != true) {
      checkNoAckTimers[targetId]?["delay"] = ((delay * 2) >= maxDelay) ? maxDelay : (delay * 2);
      logger.i("$TAG - setMsgStatusCheckTimer - delay * 3 - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
    } else {
      logger.i("$TAG - setMsgStatusCheckTimer - delay same - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
    }
    // timer
    if (timer?.isActive == true) {
      logger.i("$TAG - setMsgStatusCheckTimer - cancel old - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
      timer?.cancel();
      timer = null;
    }
    // start
    checkNoAckTimers[targetId]?["timer"] = Timer(Duration(seconds: checkNoAckTimers[targetId]?["delay"] ?? initDelay), () async {
      logger.i("$TAG - setMsgStatusCheckTimer - start - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
      int count = await _checkMsgStatus(targetId, isTopic, filterSec: filterSec); // await
      if (count != 0) checkNoAckTimers[targetId]?["delay"] = 0;
      checkNoAckTimers[targetId]?["timer"]?.cancel();
    });
  }

  Future<int> _checkMsgStatus(String? targetId, bool isTopic, {bool forceResend = false, int filterSec = 60}) async {
    if (!clientCommon.isClientCreated) return 0;
    if (targetId == null || targetId.isEmpty) return 0;
    if (application.inBackGroundLater) return 0;

    int limit = 20;
    int maxCount = 10;
    List<MessageSchema> checkList = [];

    // noAck
    for (int offset = 0; true; offset += limit) {
      final result = await MessageStorage.instance.queryListByStatus(MessageStatus.SendSuccess, targetId: targetId, topic: isTopic ? targetId : "", offset: offset, limit: limit);
      final canReceipts = result.where((element) => element.canReceipt).toList();
      checkList.addAll(canReceipts);
      logger.d("$TAG - _checkMsgStatus - noAck - offset:$offset - current_len:${canReceipts.length} - total_len:${checkList.length}");
      if (result.length < limit) break;
      if ((offset + limit) >= maxCount) break;
    }

    // noRead
    // for (int offset = 0; true; offset += limit) {
    //   final result = await MessageStorage.instance.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, topic: isTopic ? targetId : "", offset: offset, limit: limit);
    //   final canReceipts = result.where((element) => element.canReceipt).toList();
    //   checkList.addAll(canReceipts);
    //   logger.d("$TAG - _checkMsgStatus - noRead - offset:$offset - current_len:${canReceipts.length} - total_len:${checkList.length}");
    //   if (result.length < limit) break;
    //   if ((offset + limit) >= maxCount) break;
    // }

    // filter
    checkList = checkList.where((element) {
      int msgSendAt = (element.sendAt ?? 0);
      int between = DateTime.now().millisecondsSinceEpoch - msgSendAt;
      if (between < (filterSec * 1000)) {
        logger.d("$TAG - _checkMsgStatus - sendAt justNow - targetId:$targetId - message:$element");
        return false;
      }
      return true;
    }).toList();

    if (checkList.isEmpty) {
      logger.d("$TAG - _checkMsgStatus - OK OK OK - targetId:$targetId - isTopic:$isTopic");
      return 0;
    }

    // resend
    if (isTopic || forceResend) {
      for (var i = 0; i < checkList.length; i++) {
        MessageSchema element = checkList[i];
        chatOutCommon.resendMute(element);
        await Future.delayed(Duration(milliseconds: forceResend ? 200 : 500));
      }
    } else {
      List<String> msgIds = [];
      checkList.forEach((element) {
        if (element.msgId.isNotEmpty) {
          msgIds.add(element.msgId);
        }
      });
      chatOutCommon.sendMsgStatus(targetId, true, msgIds); // await
    }

    logger.i("$TAG - _checkMsgStatus - checkCount:${checkList.length} - targetId:$targetId - isTopic:$isTopic");
    return checkList.length;
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
        bool success = await contactCommon.setType(exist.id, ContactType.stranger, notify: true);
        if (success) exist.type = ContactType.stranger;
      }
    }
    if (exist == null) return null;
    // profile
    if (!message.isTopic) {
      if ((exist.profileUpdateAt == null) || (DateTime.now().millisecondsSinceEpoch > (exist.profileUpdateAt! + Global.profileExpireMs))) {
        logger.i("$TAG - contactHandle - sendRequestHeader - contact:$exist");
        chatOutCommon.sendContactRequest(exist, RequestType.header); // await
        // skip all messages need send contact request
        exist.updateAt = DateTime.now().millisecondsSinceEpoch;
        exist.profileVersion = exist.profileVersion ?? Uuid().v4();
        exist.profileUpdateAt = DateTime.now().millisecondsSinceEpoch;
        await contactCommon.setProfileOnly(exist, exist.profileVersion, notify: true);
      } else {
        double between = ((exist.profileUpdateAt! + Global.profileExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    // burning
    if (message.canBurning) {
      List<int?> burningOptions = MessageOptions.getContactBurning(message);
      int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
      int? updateBurnAfterAt = burningOptions.length >= 2 ? burningOptions[1] : null;
      if (burnAfterSeconds != null && (burnAfterSeconds > 0) && (exist.options?.deleteAfterSeconds != burnAfterSeconds)) {
        if ((exist.options?.updateBurnAfterAt == null) || ((updateBurnAfterAt ?? 0) >= exist.options!.updateBurnAfterAt!)) {
          // side update latest
          exist.options?.deleteAfterSeconds = burnAfterSeconds;
          exist.options?.updateBurnAfterAt = updateBurnAfterAt;
          contactCommon.setOptionsBurn(exist, burnAfterSeconds, updateBurnAfterAt, notify: true); // await
        } else {
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
      // skip all messages need send contact request
      latest = await deviceInfoCommon.set(DeviceInfoSchema(contactAddress: contact.clientAddress));
    }
    if (latest == null) return null;
    // profile
    if (!message.isTopic) {
      if ((latest.updateAt == null) || (DateTime.now().millisecondsSinceEpoch > (latest.updateAt! + Global.deviceInfoExpireMs))) {
        logger.i("$TAG - deviceInfoHandle - exist - request - deviceInfo:$latest");
        chatOutCommon.sendDeviceRequest(contact.clientAddress); // await
        // skip all messages need send contact request
        latest.updateAt = DateTime.now().millisecondsSinceEpoch;
        latest = await deviceInfoCommon.set(latest);
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
      if (!topic.isPrivate) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - public: add Subscribed - subscriber:$exist");
      } else if (topic.isOwner(message.from)) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - private: add Owner - subscriber:$exist");
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
    if (message.targetId.isEmpty) return null;
    SessionSchema? exist = await sessionCommon.query(message.targetId, message.isTopic ? SessionType.TOPIC : SessionType.CONTACT);
    if (exist == null) {
      SessionSchema? added = SessionSchema(targetId: message.targetId, type: SessionSchema.getTypeByMessage(message));
      added = await sessionCommon.add(added, message, notify: true);
      logger.i("$TAG - sessionHandle - new - targetId:${message.targetId} - added:$added");
      return added;
    }
    // update
    var unreadCount = message.isOutbound ? exist.unReadCount : (message.canNotification ? (exist.unReadCount + 1) : exist.unReadCount);
    exist.unReadCount = (chatCommon.currentChatTargetId == exist.targetId) ? 0 : unreadCount;
    exist.lastMessageAt = message.sendAt ?? MessageOptions.getGetAt(message);
    exist.lastMessageOptions = message.toMap();
    await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, exist.type, message, exist.unReadCount, notify: true); // must await
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message) {
    if (!message.canBurning) return message;
    List<int?> burningOptions = MessageOptions.getContactBurning(message);
    int? burnAfterSeconds = (burningOptions.length >= 1) ? burningOptions[0] : null;
    if ((burnAfterSeconds != null) && (burnAfterSeconds > 0)) {
      // set delete time
      logger.i("$TAG - burningHandle - updateDeleteAt - message:$message");
      message.deleteAt = DateTime.now().add(Duration(seconds: burnAfterSeconds)).millisecondsSinceEpoch;
      MessageStorage.instance.updateDeleteAt(message.msgId, message.deleteAt).then((success) {
        if (success) _onUpdateSink.add(message);
      });
    }
    return message;
  }

  Future<int> unreadCount() {
    return MessageStorage.instance.unReadCount();
  }

  Future<int> unReadCountByTargetId(String? targetId, String? topic) {
    return MessageStorage.instance.unReadCountByTargetId(targetId, topic);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, String? topic, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithNotDeleteAndPiece(targetId, topic, offset: offset, limit: limit);
  }

  Future<bool> deleteByTargetId(String? targetId, String? topic) async {
    await MessageStorage.instance.deleteByTargetIdContentType(targetId, topic, MessageContentType.piece);
    return MessageStorage.instance.updateIsDeleteByTargetId(targetId, topic, true, clearContent: true);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Received) || (message.status == MessageStatus.Read)) : true;
    bool success = await MessageStorage.instance.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (success && notify) onDeleteSink.add(message.msgId);
    // delete file
    if (clearContent && (message.content is File)) {
      (message.content as File).exists().then((value) {
        if (value) {
          (message.content as File).delete(); // await
          logger.v("$TAG - receivePiece - content file delete success - path:${(message.content as File).path}");
        } else {
          logger.w("$TAG - messageDelete - content file no Exists - path:${(message.content as File).path}");
        }
      });
    }
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {int? receiveAt, bool force = false, bool notify = false, int tryCount = 0}) async {
    if (status <= message.status && !force) return message;
    // pieces will set sendReceipt fast, set sendSuccess lowly
    // if ((message.status == MessageStatus.Sending) && (status != MessageStatus.SendSuccess)) {
    //   if (!force && (message.content is File) && (tryCount <= 5)) {
    //     logger.i("$TAG - updateMessageStatus - piece to fast - new:$status - old:${message.status} - msgId:${message.msgId}");
    //     await Future.delayed(Duration(seconds: 1));
    //     MessageSchema? _message = await MessageStorage.instance.queryByNoContentType(message.msgId, MessageContentType.piece);
    //     if (_message != null) return updateMessageStatus(_message, status, receiveAt: receiveAt, force: force, notify: notify, tryCount: ++tryCount);
    //   }
    // }
    // update
    message.status = status;
    bool success = await MessageStorage.instance.updateStatus(message.msgId, status, receiveAt: receiveAt, noType: MessageContentType.piece);
    if (success && notify) _onUpdateSink.add(message);
    // delete later
    if (message.isDelete && (message.content != null)) {
      if ((status == MessageStatus.SendReceipt) || (status == MessageStatus.Received) || (status == MessageStatus.Read)) {
        messageDelete(message, notify: false); // await
      } else {
        logger.i("$TAG - updateMessageStatus - delete later no - message:$message");
      }
    }
    return message;
  }

  Future readMessagesBySelf(String? targetId, String? topic, String? clientAddress) async {
    if (!clientCommon.isClientCreated) return;
    if (targetId == null || targetId.isEmpty) return;
    // update messages
    List<String> msgIds = [];
    List<MessageSchema> unreadList = await MessageStorage.instance.queryListByTargetIdWithUnRead(targetId, topic);
    for (var i = 0; i < unreadList.length; i++) {
      MessageSchema element = unreadList[i];
      msgIds.add(element.msgId);
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false);
    }
    // send messages
    if ((clientAddress?.isNotEmpty == true) && msgIds.isNotEmpty) {
      await chatOutCommon.sendRead(clientAddress, msgIds);
    }
  }

  Future<int> readMessageBySide(String? targetId, String? topic, int? sendAt, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    // noReads
    List<MessageSchema> noReads = await MessageStorage.instance.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, topic: topic, offset: offset, limit: limit);
    List<MessageSchema> shouldReads = noReads.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
    // read
    for (var i = 0; i < shouldReads.length; i++) {
      MessageSchema element = shouldReads[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    // loop
    if (noReads.length >= limit) return readMessageBySide(targetId, topic, sendAt, offset: offset + limit, limit: limit);
    logger.i("$TAG - readMessageBySide - readCount:${offset + noReads.length} - reallySendAt:${timeFormat(DateTime.fromMillisecondsSinceEpoch(sendAt))}");
    return offset + noReads.length;
  }

  Future<int> checkSendingWithFail({bool force = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    List<MessageSchema> sendingList = await MessageStorage.instance.queryListByStatus(MessageStatus.Sending, offset: 0, limit: 100);

    for (var i = 0; i < sendingList.length; i++) {
      MessageSchema message = sendingList[i];
      bool isFail = false;
      if (force) {
        isFail = true;
      } else {
        int singleWaitSec = 3 * 60; // 3m
        int topicWaitSec = singleWaitSec * 2; // 6m
        int topicMediaWaitSec = topicWaitSec * 2; // 12m
        int msgSendAt = message.sendAt ?? DateTime.now().millisecondsSinceEpoch;
        if (!message.isTopic && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (singleWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by single - targetId:${message.targetId} - message:$message");
        } else if (message.isTopic && !(message.content is File) && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (topicWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by topic - targetId:${message.targetId} - message:$message");
        } else if (message.isTopic && (message.content is File) && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (topicMediaWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by topic media - targetId:${message.targetId} - message:$message");
        } else {
          isFail = true;
        }
      }
      if (isFail) {
        logger.i("$TAG - checkSending - sendFail add - targetId:${message.targetId} - message:$message");
        if (message.canResend) {
          await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
        } else {
          int count = await MessageStorage.instance.deleteByContentType(message.msgId, message.contentType);
          if (count > 0) chatCommon.onDeleteSink.add(message.msgId);
        }
      }
    }

    logger.i("$TAG - checkSending - checkCount:${sendingList.length}");
    return sendingList.length;
  }

  Future sendPang2SessionsContact({int? delayMs}) async {
    if (!clientCommon.isClientCreated) return;
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    int max = 20;
    int limit = 20;
    int filterDay = 10; // 10 days filter
    List<String> targetIds = [];

    // sessions
    for (int offset = 0; true; offset += limit) {
      List<SessionSchema> result = await sessionCommon.queryListRecent(offset: offset, limit: limit);
      result.forEach((element) {
        int between = DateTime.now().millisecondsSinceEpoch - (element.lastMessageAt ?? 0);
        if (element.isContact && (between < (filterDay * 24 * 60 * 60 * 1000))) {
          targetIds.add(element.targetId);
        }
      });
      logger.d("$TAG - sendPang2SessionsContact - offset:$offset - current_len:${result.length} - total_len:${targetIds.length}");
      if ((result.length < limit) || (targetIds.length >= max)) break;
    }

    // send
    await chatOutCommon.sendPing(targetIds, false);
  }
}
