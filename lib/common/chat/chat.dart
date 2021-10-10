import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
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
import 'package:nmobile/utils/utils.dart';

class ChatCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // concurrent
  int nowConcurrent = 0;
  int maxConcurrent = 10;

  bool inBackGround = false;
  String? currentChatTargetId;

  MessageStorage _messageStorage = MessageStorage();

  ChatCommon();

  void init() {
    application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
      Timer? timer;
      if (application.isFromBackground(states)) {
        timer?.cancel();
        timer = null;
        timer = Timer(Duration(seconds: 1), () {
          inBackGround = false;
        });
      } else if (application.isGoBackground(states)) {
        inBackGround = true;
        timer?.cancel();
        timer = null;
      }
    });
  }

  Future<OnMessage?> clientSendData(List<String> destList, String data, {int tryCount = 0, int maxTryCount = 10}) async {
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.w("$TAG - clientSendData - destList is empty - destList:$destList - data:$data");
      return null;
    }
    if (tryCount >= maxTryCount) {
      logger.w("$TAG - clientSendData - try over - destList:$destList - data:$data");
      return null;
    }
    if (!clientCommon.isClientCreated) {
      logger.i("$TAG - clientPublishData - client is null - tryCount:$tryCount - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 2));
      return clientSendData(destList, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
    }
    if (inBackGround && Platform.isIOS) {
      logger.i("$TAG - clientSendData - in background - tryCount:$tryCount - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return clientSendData(destList, data, tryCount: tryCount, maxTryCount: maxTryCount);
    }
    if (nowConcurrent >= maxConcurrent) {
      logger.i("$TAG - clientSendData - concurrent max - tryCount:$tryCount - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return clientSendData(destList, data, tryCount: tryCount, maxTryCount: maxTryCount);
    }
    nowConcurrent++;
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.d("$TAG - clientSendData - send success - destList:$destList - data:$data");
        nowConcurrent--;
        return onMessage;
      } else {
        logger.w("$TAG - clientSendData - onMessage msgId is empty - tryCount:$tryCount - destList:$destList - data:$data");
        nowConcurrent--;
        await Future.delayed(Duration(seconds: 2));
        return clientSendData(destList, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
      }
    } catch (e) {
      if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
        final client = (await clientCommon.reSignIn(false, delayMs: 100))[0];
        if ((client != null) && (client.address.isNotEmpty == true)) {
          logger.i("$TAG - clientSendData - reSignIn success - tryCount:$tryCount - destList:$destList data:$data");
          nowConcurrent--;
          await Future.delayed(Duration(seconds: 1));
          return clientSendData(destList, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
        } else {
          // maybe always no here
          logger.w("$TAG - clientSendData - reSignIn fail - wallet:${await walletCommon.getDefault()}");
          nowConcurrent--;
          return null;
        }
      } else if (e.toString().contains("invalid destination")) {
        logger.w("$TAG - clientSendData - wrong clientAddress - destList:$destList");
        nowConcurrent--;
        return null;
      } else {
        handleError(e);
        logger.w("$TAG - clientSendData - try by error - tryCount:$tryCount - destList:$destList - data:$data");
        nowConcurrent--;
        await Future.delayed(Duration(seconds: 2));
        return clientSendData(destList, data, tryCount: ++tryCount, maxTryCount: maxTryCount);
      }
    }
  }

  Future<List<OnMessage>> clientPublishData(String? topic, String data, {bool txPool = true, int? total, int tryCount = 0, int maxTryCount = 10}) async {
    if (topic == null || topic.isEmpty) return [];
    if (tryCount >= maxTryCount) {
      logger.w("$TAG - clientPublishData - try over - dest:$topic - data:$data");
      return [];
    }
    if (!clientCommon.isClientCreated) {
      logger.i("$TAG - clientPublishData - client is null - tryCount:$tryCount - dest:$topic - data:$data");
      await Future.delayed(Duration(seconds: 2));
      return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: ++tryCount, maxTryCount: maxTryCount);
    }
    if (inBackGround && Platform.isIOS) {
      logger.i("$TAG - clientPublishData - ios background - tryCount:$tryCount - dest:$topic - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: tryCount, maxTryCount: maxTryCount);
    }
    if (nowConcurrent >= maxConcurrent) {
      logger.i("$TAG - clientPublishData - concurrent max - tryCount:$tryCount - dest:$topic - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: tryCount, maxTryCount: maxTryCount);
    }
    nowConcurrent++;
    try {
      // once
      if (total == null || total <= 1000) {
        OnMessage result = await clientCommon.client!.publishText(genTopicHash(topic), data, txPool: txPool, offset: 0, limit: 1000);
        nowConcurrent--;
        return [result];
      }
      // split
      List<Future<OnMessage>> futures = [];
      for (int i = 0; i < total; i += 1000) {
        futures.add(clientCommon.client!.publishText(genTopicHash(topic), data, txPool: txPool, offset: i, limit: i + 1000));
      }
      List<OnMessage> onMessageList = await Future.wait(futures);
      logger.i("$TAG - clientPublishData - topic:$topic - total:$total - data$data - onMessageList:$onMessageList");
      nowConcurrent--;
      return onMessageList;
    } catch (e) {
      if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
        final client = (await clientCommon.reSignIn(false, delayMs: 100))[0];
        if ((client != null) && (client.address.isNotEmpty == true)) {
          logger.i("$TAG - clientPublishData - reSignIn success - tryCount:$tryCount - topic:$topic data:$data");
          nowConcurrent--;
          await Future.delayed(Duration(seconds: 1));
          return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: ++tryCount, maxTryCount: maxTryCount);
        } else {
          // maybe always no here
          logger.w("$TAG - clientPublishData - reSignIn fail - wallet:${await walletCommon.getDefault()}");
          nowConcurrent--;
          return [];
        }
      } else {
        handleError(e);
        logger.w("$TAG - clientPublishData - try by error - tryCount:$tryCount - topic:$topic - data:$data");
        nowConcurrent--;
        await Future.delayed(Duration(seconds: 2));
        return clientPublishData(topic, data, txPool: txPool, total: total, tryCount: ++tryCount, maxTryCount: maxTryCount);
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
        bool success = await contactCommon.setType(exist.id, ContactType.stranger, notify: true);
        if (success) exist.type = ContactType.stranger;
      }
      // profile
      if ((exist.profileUpdateAt == null) || (DateTime.now().millisecondsSinceEpoch > (exist.profileUpdateAt! + Global.profileExpireMs))) {
        logger.i("$TAG - contactHandle - sendRequestHeader - contact:$exist");
        chatOutCommon.sendContactRequest(exist, RequestType.header); // await
        // skip all messages need send contact request
        await contactCommon.setProfileOnly(exist, exist.profileVersion, notify: true);
      } else {
        double between = ((exist.profileUpdateAt! + Global.profileExpireMs) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    // burning
    if ((exist != null) && message.canBurning) {
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
      await deviceInfoCommon.set(DeviceInfoSchema(contactAddress: contact.clientAddress));
    } else {
      if ((latest.updateAt == null) || (DateTime.now().millisecondsSinceEpoch > (latest.updateAt! + Global.deviceInfoExpireMs))) {
        logger.i("$TAG - deviceInfoHandle - exist - request - deviceInfo:$latest");
        chatOutCommon.sendDeviceRequest(contact.clientAddress); // await
        // skip all messages need send contact request
        latest.updateAt = DateTime.now().millisecondsSinceEpoch;
        await deviceInfoCommon.set(latest);
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
    exist.lastMessageAt = MessageOptions.getSendAt(message) ?? message.sendAt;
    exist.lastMessageOptions = message.toMap();
    await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, message, exist.unReadCount, notify: true); // must await
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

  Future<bool> deleteByTargetId(String? targetId) async {
    await _messageStorage.deleteByTargetIdContentType(targetId, MessageContentType.piece);
    return _messageStorage.updateIsDeleteByTargetId(targetId, true, clearContent: true);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Received) || (message.status == MessageStatus.Read)) : true;
    bool success = await _messageStorage.updateIsDelete(message.msgId, true, clearContent: clearContent);
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
    if ((message.status == MessageStatus.Sending) && (status != MessageStatus.SendSuccess)) {
      if (!force && (message.content is File) && (tryCount <= 5)) {
        logger.i("$TAG - updateMessageStatus - piece to fast - new:$status - old:${message.status} - msgId:${message.msgId}");
        await Future.delayed(Duration(seconds: 1));
        MessageSchema? _message = await _messageStorage.queryByNoContentType(message.msgId, MessageContentType.piece);
        if (_message != null) return updateMessageStatus(_message, status, receiveAt: receiveAt, force: force, notify: notify, tryCount: ++tryCount);
      }
    }
    // update
    message.status = status;
    bool success = await _messageStorage.updateStatus(message.msgId, status, receiveAt: receiveAt, noType: MessageContentType.piece);
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

  Future readMessagesBySelf(String? targetId, String? clientAddress) async {
    if (!clientCommon.isClientCreated) return;
    if (targetId == null || targetId.isEmpty) return;
    // update messages
    List<String> msgIds = [];
    List<MessageSchema> unreadList = await _messageStorage.queryListByTargetIdWithUnRead(targetId);
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

  Future<int> readMessageBySide(String? targetId, int? sendAt, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    // noReads
    List<MessageSchema> noReads = await _messageStorage.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, offset: offset, limit: limit);
    List<MessageSchema> shouldReads = noReads.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
    // read
    for (var i = 0; i < shouldReads.length; i++) {
      MessageSchema element = shouldReads[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    // loop
    if (noReads.length >= limit) return readMessageBySide(targetId, sendAt, offset: offset + limit, limit: limit);
    logger.i("$TAG - readMessageBySide - readCount:${offset + noReads.length} - reallySendAt:${timeFormat(DateTime.fromMillisecondsSinceEpoch(sendAt))}");
    return offset + noReads.length;
  }

  Future<int> checkSending({int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    int waitSec = 3 * 60; // 1m
    List<MessageSchema> sendingList = await _messageStorage.queryListByStatus(MessageStatus.Sending);

    for (var i = 0; i < sendingList.length; i++) {
      MessageSchema message = sendingList[i];
      int msgSendAt = message.sendAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (waitSec * 1000)) {
        logger.d("$TAG - checkSending - sendAt justNow - targetId:${message.targetId} - message:$message");
      } else {
        logger.i("$TAG - checkSending - sendFail add - targetId:${message.targetId} - message:$message");
        if (message.canResend) {
          await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, notify: true);
        } else {
          int count = await _messageStorage.deleteByContentType(message.msgId, message.contentType);
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

    int max = 100;
    int limit = 20;
    List<String> targetIds = [];

    // sessions
    int filterDay = 10; // 10 days filter
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
