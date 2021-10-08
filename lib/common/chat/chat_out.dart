import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/send_push.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  // piece
  static const int piecesPreLength = 4 * 1024; // 4 ~ 40k
  static const int piecesMinParity = 2; // parity >= 2
  static const int piecesMaxParity = (40 ~/ 4); // parity <= 10
  static const int piecesMinTotal = 5; // total >= 5
  static const int piecesMaxTotal = 40 - piecesMaxParity; // total <= 30

  static const int maxBodySize = piecesMaxTotal * (piecesPreLength * 10); // 1,228,800 less then 4,000,000(nkn-go-sdk)
  static const int shouldBodySize = maxBodySize ~/ 4; // 300k

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPieceOutController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPieceOutSink => _onPieceOutController.sink;
  Stream<Map<String, dynamic>> get onPieceOutStream => _onPieceOutController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  MessageStorage _messageStorage = MessageStorage();

  Map<String, Map<String, dynamic>> checkNoAckTimers = Map();

  ChatOutCommon();

  void setMsgStatusCheckTimer(String? targetId, bool isTopic, {bool refresh = false, int filterSec = 60}) {
    if (!clientCommon.isClientCreated) return;
    if (targetId == null || targetId.isEmpty) return;
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
    }
    // start
    checkNoAckTimers[targetId]?["timer"] = Timer(Duration(seconds: checkNoAckTimers[targetId]?["delay"] ?? initDelay), () async {
      logger.i("$TAG - setMsgStatusCheckTimer - start - delay${checkNoAckTimers[targetId]?["delay"]} - targetId:$targetId");
      int count = await chatOutCommon._checkMsgStatus(targetId, isTopic, filterSec: filterSec); // await
      if (count != 0) checkNoAckTimers[targetId]?["delay"] = 0;
      checkNoAckTimers[targetId]?["timer"]?.cancel();
    });
  }

  Future<int> _checkMsgStatus(String? targetId, bool isTopic, {bool forceResend = false, int filterSec = 60}) async {
    if (!clientCommon.isClientCreated) return 0;
    if (targetId == null || targetId.isEmpty) return 0;

    int limit = 20;
    List<MessageSchema> checkList = [];

    // noAck
    for (int offset = 0; true; offset += limit) {
      final result = await _messageStorage.queryListByStatus(MessageStatus.SendSuccess, targetId: targetId, offset: offset, limit: limit);
      checkList.addAll(result);
      logger.d("$TAG - _checkMsgStatus - noAck - offset:$offset - current_len:${result.length} - total_len:${checkList.length}");
      if (result.length < limit) break;
    }

    // noRead
    for (int offset = 0; true; offset += limit) {
      final result = await _messageStorage.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, offset: offset, limit: limit);
      checkList.addAll(result);
      logger.d("$TAG - _checkMsgStatus - noRead - offset:$offset - current_len:${result.length} - total_len:${checkList.length}");
      if (result.length < limit) break;
    }

    // filter
    checkList = checkList = checkList.where((element) => element.canReceipt).toList();
    checkList = checkList.where((element) {
      int msgSendAt = (element.sendAt ?? DateTime.now().millisecondsSinceEpoch);
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
        await resendMute(element);
      }
    } else {
      List<String> msgIds = [];
      checkList.forEach((element) {
        if (element.msgId.isNotEmpty) {
          msgIds.add(element.msgId);
        }
      });
      await sendMsgStatus(targetId, true, msgIds);
    }

    logger.i("$TAG - _checkMsgStatus - checkCount:${checkList.length} - targetId:$targetId - isTopic:$isTopic");
    return checkList.length;
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendPing(List<String> clientAddressList, bool isPing) async {
    if (!clientCommon.isClientCreated) return;
    String data = MessageData.getPing(isPing);
    await chatCommon.clientSendData(clientAddressList, data);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (received.from.isEmpty || received.isTopic) return; // topic no receipt, just send message to myself
    if (!clientCommon.isClientCreated) return;
    received = (await _messageStorage.queryByNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
    String data = MessageData.getReceipt(received.msgId, received.receiveAt);
    await chatCommon.clientSendData([received.from], data);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendRead(String? clientAddress, List<String> msgIds, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    if (!clientCommon.isClientCreated) return;
    String data = MessageData.getRead(msgIds);
    await chatCommon.clientSendData([clientAddress], data);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendMsgStatus(String? clientAddress, bool ask, List<String> msgIds, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    if (!clientCommon.isClientCreated) return;
    String data = MessageData.getMsgStatus(ask, msgIds);
    await chatCommon.clientSendData([clientAddress], data);
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    int updateAt = DateTime.now().millisecondsSinceEpoch;
    String data = MessageData.getContactRequest(requestType, target.profileVersion, updateAt);
    await chatCommon.clientSendData([target.clientAddress], data);
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(ContactSchema? target, String requestType, {ContactSchema? me, int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    ContactSchema? _me = me ?? await contactCommon.getMe();
    int updateAt = DateTime.now().millisecondsSinceEpoch;
    String data;
    if (requestType == RequestType.header) {
      data = MessageData.getContactResponseHeader(_me?.profileVersion, updateAt);
    } else {
      data = await MessageData.getContactResponseFull(_me?.firstName, _me?.lastName, _me?.avatar, _me?.profileVersion, updateAt);
    }
    await chatCommon.clientSendData([target.clientAddress], data);
  }

  // NO topic (1 to 1)
  Future sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.contactOptions,
      to: clientAddress,
      deleteAfterSeconds: deleteSeconds,
      burningUpdateAt: updateAt,
    );
    send.content = MessageData.getContactOptionsBurn(send); // same with receive and old version
    await _sendAndDB(send, send.content);
  }

  // NO topic (1 to 1)
  Future sendContactOptionsToken(String? clientAddress, String deviceToken, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.contactOptions,
      to: clientAddress,
    );
    send = MessageOptions.setDeviceToken(send, deviceToken);
    send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
    await _sendAndDB(send, send.content);
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceRequest(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    String data = MessageData.getDeviceRequest();
    await chatCommon.clientSendData([clientAddress], data);
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceInfo(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    String data = MessageData.getDeviceInfo();
    await chatCommon.clientSendData([clientAddress], data);
  }

  Future<MessageSchema?> sendText(String? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || content.isEmpty) return null;
    if (!clientCommon.isClientCreated) return null;
    String contentType = ((contact?.options?.deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: (topic?.topic.isNotEmpty == true) ? null : contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String data = MessageData.getText(message);
    return _sendAndDB(message, data);
  }

  Future<MessageSchema?> sendImage(File? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    if (!clientCommon.isClientCreated) return null;
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(contact?.clientAddress);
    String contentType = deviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: (topic?.topic.isNotEmpty == true) ? null : contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getImage(message);
    return _sendAndDB(message, data);
  }

  Future<MessageSchema?> sendAudio(File? content, double? durationS, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    if (!clientCommon.isClientCreated) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.audio,
      to: (topic?.topic.isNotEmpty == true) ? null : contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      audioDurationS: durationS,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getAudio(message);
    return _sendAndDB(message, data);
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(List<String> clientAddressList, MessageSchema message, {int tryCount = 1}) async {
    if (!clientCommon.isClientCreated) return null;
    int timeNowAt = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: (message.sendAt ?? timeNowAt) - timeNowAt));
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await chatCommon.clientSendData(clientAddressList, data);
    if ((onResult?.messageId == null) || onResult!.messageId.isEmpty) return null;
    message.pid = onResult.messageId;
    // progress
    int? total = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL];
    int? index = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX];
    double percent = (index ?? 0) / (total ?? 1);
    if (percent <= 1.05) {
      // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
      _onPieceOutSink.add({"msg_id": message.msgId, "percent": percent});
    }
    return message;
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicSubscribe,
      topic: topic,
    );
    String data = MessageData.getTopicSubscribe(send);
    await _sendAndDB(send, data);
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicUnsubscribe,
      topic: topic,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicUnSubscribe(send);
    await _sendWithTopicSafe(_schema, send, data);
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    if (!clientCommon.isClientCreated) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicInvitation,
      to: clientAddress,
      content: topic,
    );
    String data = MessageData.getTopicInvitee(message);
    return _sendAndDB(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicKickOut,
      topic: topic,
      content: targetAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicKickOut(send);
    await _sendWithTopicSafe(_schema, send, data);
  }

  Future<MessageSchema?> resend(MessageSchema? message, {ContactSchema? contact, DeviceInfoSchema? deviceInfo, TopicSchema? topic}) async {
    if (message == null) return null;
    message = await chatCommon.updateMessageStatus(message, MessageStatus.Sending, force: true, notify: true);
    String? msgData;
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        msgData = MessageData.getText(message);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        msgData = await MessageData.getImage(message);
        break;
      case MessageContentType.audio:
        msgData = await MessageData.getAudio(message);
        break;
    }
    return await _sendAndDB(message, msgData, contact: contact, topic: topic, resend: true);
  }

  Future<MessageSchema?> resendMute(MessageSchema? message, {bool? notification}) async {
    if (message == null) return null;
    // msgData
    String? msgData;
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        msgData = MessageData.getText(message);
        logger.i("$TAG - resendMute - resend text - targetId:${message.targetId} - msgData:$msgData");
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        msgData = await MessageData.getImage(message);
        logger.i("$TAG - resendMute - resend image - targetId:${message.targetId} - msgData:$msgData");
        break;
      case MessageContentType.audio:
        msgData = await MessageData.getAudio(message);
        logger.i("$TAG - resendMute - resend audio - targetId:${message.targetId} - msgData:$msgData");
        break;
      default:
        logger.w("$TAG - resendMute - noBurning no receipt/read - targetId:${message.targetId} - message:$message");
        int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
        message = await chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
        return message;
    }
    // send
    Uint8List? pid;
    if (msgData?.isNotEmpty == true) {
      int msgSendAt = (message.sendAt ?? DateTime.now().millisecondsSinceEpoch);
      int between = DateTime.now().millisecondsSinceEpoch - msgSendAt;
      notification = (notification != null) ? notification : (between > (60 * 60 * 1000)); // 1h
      if (message.isTopic) {
        final topic = await chatCommon.topicHandle(message);
        pid = await _sendWithTopicSafe(topic, message, msgData, notification: notification);
      } else if (message.to?.isNotEmpty == true) {
        final contact = await chatCommon.contactHandle(message);
        pid = await _sendWithContactSafe(contact, message, msgData, notification: notification);
      }
    }
    // result
    if (pid?.isNotEmpty == true) {
      logger.i("$TAG - resendMute - resend result - pid:$pid - message:$message");
      message.pid = pid;
      _messageStorage.updatePid(message.msgId, message.pid); // await
    } else {
      logger.w("$TAG - resendMute - resend fail - message:$message");
    }
    return message;
  }

  Future<MessageSchema?> _sendAndDB(
    MessageSchema? message,
    String? msgData, {
    ContactSchema? contact,
    TopicSchema? topic,
    bool resend = false,
    bool notification = true,
  }) async {
    if (message == null || msgData == null) return null;
    // DB
    if (!resend) {
      message = await _messageStorage.insert(message);
    } else if (resend) {
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      _messageStorage.updateSendAt(message.msgId, message.sendAt); // await
    }
    if (message == null) return null;
    // display
    if (!resend) _onSavedSink.add(message); // resend just update sendTime
    // contact
    contact = contact ?? await chatCommon.contactHandle(message);
    // topic
    topic = topic ?? await chatCommon.topicHandle(message);
    // session
    chatCommon.sessionHandle(message); // await
    // SDK
    Uint8List? pid;
    if (message.isTopic) {
      pid = await _sendWithTopicSafe(topic, message, msgData, notification: notification);
      logger.d("$TAG - _sendAndDisplay - with_topic - to:${message.topic} - pid:$pid");
    } else if (message.to?.isNotEmpty == true) {
      pid = await _sendWithContactSafe(contact, message, msgData, notification: notification);
      logger.d("$TAG - _sendAndDisplay - with_contact - to:${message.to} - pid:$pid");
    }
    // pid
    if (pid?.isNotEmpty == true) {
      message.pid = pid;
      _messageStorage.updatePid(message.msgId, message.pid); // await
      // no received receipt/read
      if (!message.canReceipt) {
        int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
        chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt); // await
      }
    } else {
      logger.w("$TAG - _sendAndDisplay - pid = null - message:$message");
      if (message.canResend) {
        message = await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
      } else {
        // noResend just delete
        int count = await _messageStorage.deleteByContentType(message.msgId, message.contentType);
        if (count > 0) chatCommon.onDeleteSink.add(message.msgId);
        return null;
      }
    }
    return message;
  }

  Future<Uint8List?> _sendWithContactSafe(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = true}) async {
    try {
      return _sendWithContact(contact, message, msgData, notification: notification);
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  Future<Uint8List?> _sendWithTopicSafe(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = true}) async {
    try {
      return _sendWithTopic(topic, message, msgData, notification: notification);
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = true}) async {
    if (message == null || msgData == null) return null;
    // deviceInfo
    DeviceInfoSchema? _deviceInfo = await chatCommon.deviceInfoHandle(message, contact);
    logger.d("$TAG - _sendWithContact - info - _deviceInfo:$_deviceInfo - contact:$contact - message:$message - msgData:$msgData");
    // send
    Uint8List? pid;
    if (deviceInfoCommon.isMsgPieceEnable(_deviceInfo?.platform, _deviceInfo?.appVersion)) {
      pid = await _sendByPieces([message.to ?? ""], message);
    }
    if (pid?.isNotEmpty == true) {
      logger.d("$TAG - _sendWithContact - to_contact_pieces - to:${message.to} - pid:$pid - deviceInfo:$_deviceInfo");
    } else {
      logger.d("$TAG - _sendWithContact - to_contact - to:${message.to} - msgData:$msgData");
      pid = (await chatCommon.clientSendData([message.to ?? ""], msgData))?.messageId;
    }
    // result
    if (pid?.isNotEmpty == true) {
      chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
    }
    // push
    if (notification && message.canNotification) {
      if (pid?.isNotEmpty == true) {
        _sendPush(message, contact?.deviceToken); // await
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = true}) async {
    if (topic == null || message == null || msgData == null) return null;
    // me
    SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(message.topic, message.from); // chatOutCommon.handleSubscribe();
    bool checkStatus = message.contentType == MessageContentType.topicUnsubscribe;
    if (!checkStatus && (_me?.status != SubscriberStatus.Subscribed)) {
      logger.w("$TAG - _sendWithTopic - subscriber me is wrong - me:$_me - message:$message");
      return null;
    }
    // subscribers
    List<SubscriberSchema> _subscribers = await subscriberCommon.queryListByTopic(topic.topic, status: SubscriberStatus.Subscribed);
    // SUPPORT:START
    List<SubscriberSchema> _oldSubscribers = await subscriberCommon.queryListByTopic(topic.topic, status: SubscriberStatus.None);
    for (var i = 0; i < _oldSubscribers.length; i++) {
      SubscriberSchema element = _oldSubscribers[i];
      DeviceInfoSchema? value = await deviceInfoCommon.queryLatest(element.clientAddress);
      if (!deviceInfoCommon.isTopicPermissionEnable(value?.platform, value?.appVersion)) {
        logger.i("$TAG - _sendWithTopic - add receiver to support old version - subscriber:$element");
        _subscribers.add(element);
      } else {
        logger.w("$TAG - _sendWithTopic - skip receiver because status is none - subscriber:$element");
      }
    }
    // SUPPORT:END
    // subscribers check
    if (message.contentType == MessageContentType.topicKickOut) {
      logger.i("$TAG - _sendWithTopic - add kick people - clientAddress:${message.content}");
      SubscriberSchema? kicked = SubscriberSchema.create(topic.topic, message.content, SubscriberStatus.None, null);
      if (kicked != null) _subscribers.add(kicked);
    }
    bool privateNormal = topic.isPrivate && !topic.isOwner(clientCommon.address);
    if (_subscribers.isEmpty || (_subscribers.length == 1 && (_subscribers.first.clientAddress == clientCommon.address) && privateNormal)) {
      logger.w("$TAG - _sendWithTopic - _subscribers is empty - topic:$topic - message:$message - msgData:$msgData");
      int total = await subscriberCommon.getSubscribersCount(message.topic!, false);
      List<OnMessage> onMessageList = await chatCommon.clientPublishData(message.topic, msgData, total: total); // permission checked in received
      if (onMessageList.isNotEmpty && (onMessageList[0].messageId.isNotEmpty == true)) {
        chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
        return onMessageList[0].messageId;
      }
      return null;
    }
    // targets
    List<String> targetIds = [];
    List<String> targetIdsByPiece = [];
    for (var i = 0; i < _subscribers.length; i++) {
      SubscriberSchema subscriber = _subscribers[i];
      DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(subscriber.clientAddress);
      if (!deviceInfoCommon.isMsgPieceEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
        targetIds.add(subscriber.clientAddress);
      } else {
        targetIdsByPiece.add(subscriber.clientAddress);
      }
    }
    // send
    Uint8List? piecePid;
    if (targetIdsByPiece.isNotEmpty) {
      piecePid = await _sendByPieces(targetIdsByPiece, message);
      if ((piecePid == null) || piecePid.isEmpty) {
        targetIds.addAll(targetIdsByPiece);
        targetIdsByPiece.clear();
      }
    }
    OnMessage? onMessage;
    if (targetIds.isNotEmpty) {
      onMessage = await chatCommon.clientSendData(targetIds, msgData); // long time to wait when targetIds too much
    }
    // result
    Uint8List? pid;
    if (targetIds.contains(clientCommon.address)) {
      pid = onMessage?.messageId;
    } else {
      pid = piecePid;
    }
    if (pid?.isNotEmpty == true) {
      chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
    }
    // push
    if (notification && message.canNotification) {
      if (piecePid?.isNotEmpty == true) {
        for (var i = 0; i < targetIdsByPiece.length; i++) {
          String targetId = targetIdsByPiece[i];
          ContactSchema? _contact = await contactCommon.queryByClientAddress(targetId);
          _sendPush(message, _contact?.deviceToken); // await
        }
      }
      if (onMessage?.messageId.isNotEmpty == true) {
        for (var i = 0; i < targetIds.length; i++) {
          String targetId = targetIds[i];
          ContactSchema? _contact = await contactCommon.queryByClientAddress(targetId);
          _sendPush(message, _contact?.deviceToken); // await
        }
      }
    }
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    return pid;
  }

  Future<Uint8List?> _sendByPieces(List<String> clientAddressList, MessageSchema message) async {
    List results = await _convert2Pieces(message);
    if (results.isEmpty) return null;
    String dataBytesString = results[0];
    int bytesLength = results[1];
    int total = results[2];
    int parity = results[3];

    // dataList.size = (total + parity) <= 255
    List<Object?> dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty) return null;

    logger.i("$TAG - _sendByPieces:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");

    List<MessageSchema> resultList = [];
    for (var index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      Map<String, dynamic> options = Map();
      options.addAll(message.options ?? Map()); // new *
      MessageSchema piece = MessageSchema.fromSend(
        msgId: message.msgId,
        from: message.from,
        to: "",
        topic: message.topic, // need
        contentType: MessageContentType.piece,
        content: base64Encode(data),
        options: options,
        parentType: message.contentType,
        bytesLength: bytesLength,
        total: total,
        parity: parity,
        index: index,
      );
      MessageSchema? result = await sendPiece(clientAddressList, piece);
      if ((result == null) || (result.pid == null)) {
        logger.w("$TAG - _sendByPieces:ERROR - piece:$piece");
      } else {
        resultList.add(result);
      }
      await Future.delayed(Duration(milliseconds: 25));
    }
    List<MessageSchema> finds = resultList.where((element) => element.pid != null).toList();
    finds.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    if (finds.length >= total) {
      logger.i("$TAG - _sendByPieces:SUCCESS - count:${resultList.length} - total:$total - message:$message");
      if (finds.isNotEmpty) return finds[0].pid;
    } else {
      logger.w("$TAG - _sendByPieces:FAIL - count:${resultList.length} - total:$total - message:$message");
    }
    return null;
  }

  Future<List<dynamic>> _convert2Pieces(MessageSchema message) async {
    if (!(message.content is File?)) return [];
    File? file = message.content as File?;
    if (file == null || !file.existsSync()) return [];
    int length = await file.length();
    if (length <= piecesPreLength) return [];
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    int bytesLength = base64Data.length;
    // total (2~192)
    int total;
    if (bytesLength < piecesPreLength * piecesMinTotal) {
      return [];
    } else if (bytesLength <= piecesPreLength * piecesMaxTotal) {
      total = bytesLength ~/ piecesPreLength;
      if (bytesLength % piecesPreLength > 0) {
        total += 1;
      }
    } else {
      total = piecesMaxTotal;
    }
    // parity(1~63)
    int parity = (total * (piecesMaxParity / (piecesMaxTotal + piecesMaxParity))).toInt();
    if (total % (piecesMaxParity / (piecesMaxTotal + piecesMaxParity)) > 0) {
      parity += 1;
    }
    if (parity > piecesMaxParity) {
      parity = piecesMaxParity;
    } else if (parity >= total) {
      parity = total - 1;
    } else if (parity < 1) {
      parity = 1;
    }

    // (total + parity) < 256
    logger.i("$TAG - _convert2Pieces - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    return [base64Data, bytesLength, total, parity];
  }

  Future _sendPush(MessageSchema message, String? deviceToken) async {
    if (deviceToken == null || deviceToken.isEmpty == true) return;
    S localizations = S.of(Global.appContext);

    String title = localizations.new_message;
    // if (topic != null) {
    //   title = '[${topic.topicShort}] ${contact?.displayName}';
    // } else if (contact != null) {
    //   title = contact.displayName;
    // }

    String content = localizations.you_have_new_message;
    // switch (message.contentType) {
    //   case MessageContentType.text:
    //   case MessageContentType.textExtension:
    //     content = message.content;
    //     break;
    //   case MessageContentType.media:
    //   case MessageContentType.image:
    //     content = '[${localizations.image}]';
    //     break;
    //   case MessageContentType.audio:
    //     content = '[${localizations.audio}]';
    //     break;
    //   case MessageContentType.topicSubscribe:
    //   case MessageContentType.topicUnsubscribe:
    //   case MessageContentType.topicInvitation:
    //   case MessageContentType.topicKickOut:
    //     break;
    // }

    await SendPush.send(deviceToken, title, content);
  }

  // Future<bool> _handleSendError(dynamic e, int tryCount, Function? callback) async {
  //   if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
  //     await Future.delayed(Duration(milliseconds: 100));
  //     final client = (await clientCommon.reSignIn(false))[0];
  //     if (client != null && (client.address.isNotEmpty == true)) {
  //       logger.i("$TAG - _handleSendError - callback - callback:${callback?.toString()}");
  //       try {
  //         await callback?.call();
  //         return true;
  //       } catch (e) {
  //         if (tryCount >= 3) {
  //           handleError(e);
  //           return true;
  //         }
  //         return false;
  //       }
  //     } else {
  //       final wallet = await walletCommon.getDefault();
  //       logger.w("$TAG - _handleSendError - reSignIn fail - wallet:$wallet");
  //       return false;
  //     }
  //   } else if (tryCount >= 3) {
  //     handleError(e);
  //     return true;
  //   }
  //   return false;
  // }
}
