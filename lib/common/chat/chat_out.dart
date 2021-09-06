import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/send_push.dart';
import 'package:nmobile/components/tip/toast.dart';
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
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  // piece
  static const int piecesPreLength = 4 * 1024; // 4 ~ 8k
  static const int piecesMinParity = 2; // parity >= 2
  static const int piecesMaxParity = (255 ~/ 4); // parity <= 63
  static const int piecesMinTotal = 5; // total >= 5
  static const int piecesMaxTotal = 255 - piecesMaxParity; // total <= 192

  static const int maxBodySize = piecesMaxTotal * piecesPreLength * 2; // 1,572,864 less then 4,000,000(nkn-go-sdk)

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPieceOutController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPieceOutSink => _onPieceOutController.sink;
  Stream<Map<String, dynamic>> get onPieceOutStream => _onPieceOutController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  MessageStorage _messageStorage = MessageStorage();

  ChatOutCommon();

  Future sendPing(String? clientAddress, bool isPing, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendPing(clientAddress, isPing), null);
    }
    try {
      String data = MessageData.getPing(isPing);
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendPing - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendPing - fail - tryCount:$tryCount - clientAddress:$clientAddress - isPing:$isPing");
      if (await _handleSendError(e, tryCount, () => sendPing(clientAddress, isPing, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendPing(clientAddress, isPing, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (received.from.isEmpty || received.isTopic) return; // topic no receipt, just send message to myself
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendReceipt(received), null);
    }
    try {
      received = (await _messageStorage.query(received.msgId)) ?? received; // get receiveAt
      String data = MessageData.getReceipt(received.msgId, received.receiveAt);
      await chatCommon.clientSendData(received.from, data);
      logger.d("$TAG - sendReceipt - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendReceipt - fail - tryCount:$tryCount - received:$received");
      if (await _handleSendError(e, tryCount, () => sendReceipt(received, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendReceipt(received, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendRead(String? clientAddress, List<String> msgIds, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendRead(clientAddress, msgIds), null);
    }
    try {
      String data = MessageData.getRead(msgIds);
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendRead - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendRead - fail - tryCount:$tryCount - clientAddress:$clientAddress - msgIds:$msgIds");
      if (await _handleSendError(e, tryCount, () => sendRead(clientAddress, msgIds, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendRead(clientAddress, msgIds, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendContactRequest(target, requestType), null);
    }
    try {
      int updateAt = DateTime.now().millisecondsSinceEpoch;
      String data = MessageData.getContactRequest(requestType, target.profileVersion, updateAt);
      await chatCommon.clientSendData(target.clientAddress, data);
      logger.d("$TAG - sendContactRequest - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendContactRequest - fail - tryCount:$tryCount - requestType:$requestType - target:$target");
      if (await _handleSendError(e, tryCount, () => sendContactRequest(target, requestType, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactRequest(target, requestType, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(ContactSchema? target, String requestType, {ContactSchema? me, int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendContactResponse(target, requestType, me: me), null);
    }
    ContactSchema? _me = me ?? await contactCommon.getMe();
    try {
      int updateAt = DateTime.now().millisecondsSinceEpoch;
      String data;
      if (requestType == RequestType.header) {
        data = MessageData.getContactResponseHeader(_me?.profileVersion, updateAt);
      } else {
        data = await MessageData.getContactResponseFull(_me?.firstName, _me?.lastName, _me?.avatar, _me?.profileVersion, updateAt);
      }
      await chatCommon.clientSendData(target.clientAddress, data);
      logger.d("$TAG - sendContactResponse - success - requestType:$requestType - data:$data");
    } catch (e) {
      logger.w("$TAG - sendContactResponse - fail - tryCount:$tryCount - requestType:$requestType");
      if (await _handleSendError(e, tryCount, () => sendContactResponse(target, requestType, me: _me, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactResponse(target, requestType, me: _me, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendContactOptionsBurn(clientAddress, deleteSeconds, updateAt), null);
    }
    try {
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
      logger.d("$TAG - sendContactOptionsBurn - success - data:${send.content}");
    } catch (e) {
      logger.w("$TAG - sendContactOptionsBurn - fail - tryCount:$tryCount - clientAddress:$clientAddress - deleteSeconds:$deleteSeconds");
      if (await _handleSendError(e, tryCount, () => sendContactOptionsBurn(clientAddress, deleteSeconds, updateAt, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactOptionsBurn(clientAddress, deleteSeconds, updateAt, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future sendContactOptionsToken(String? clientAddress, String deviceToken, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendContactOptionsToken(clientAddress, deviceToken), null);
    }
    try {
      MessageSchema send = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: clientCommon.address!,
        contentType: MessageContentType.contactOptions,
        to: clientAddress,
      );
      send = MessageOptions.setDeviceToken(send, deviceToken);
      send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
      await _sendAndDB(send, send.content);
      logger.d("$TAG - sendContactOptionsToken - success - data:${send.content}");
    } catch (e) {
      logger.w("$TAG - sendContactOptionsToken - fail - tryCount:$tryCount - clientAddress:$clientAddress - deviceToken:$deviceToken");
      if (await _handleSendError(e, tryCount, () => sendContactOptionsToken(clientAddress, deviceToken, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactOptionsToken(clientAddress, deviceToken, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceRequest(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendDeviceRequest(clientAddress), null);
    }
    try {
      String data = MessageData.getDeviceRequest();
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendDeviceRequest - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendDeviceRequest - fail - tryCount:$tryCount - clientAddress:$clientAddress");
      if (await _handleSendError(e, tryCount, () => sendDeviceRequest(clientAddress, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendDeviceRequest(clientAddress, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceInfo(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendDeviceInfo(clientAddress), null);
    }
    try {
      String data = MessageData.getDeviceInfo();
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendDeviceInfo - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendDeviceInfo - fail - tryCount:$tryCount - clientAddress:$clientAddress");
      if (await _handleSendError(e, tryCount, () => sendDeviceInfo(clientAddress, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendDeviceInfo(clientAddress, tryCount: ++tryCount);
      });
    }
  }

  Future<MessageSchema?> sendText(String? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || content.isEmpty) return null;
    if (!clientCommon.isClientCreated) {
      return (await _checkClient(() => sendText(content, contact: contact, topic: topic), null)) as MessageSchema?;
    }
    String contentType = ((contact?.options?.deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: contact?.clientAddress,
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
    if (!clientCommon.isClientCreated) {
      return (await _checkClient(() => sendImage(content, contact: contact, topic: topic), null)) as MessageSchema?;
    }
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(contact?.clientAddress);
    String contentType = deviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: contact?.clientAddress,
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
    if (!clientCommon.isClientCreated) {
      return (await _checkClient(() => sendAudio(content, durationS, contact: contact, topic: topic), null)) as MessageSchema?;
    }
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.audio,
      to: contact?.clientAddress,
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
  Future<MessageSchema?> sendPiece(MessageSchema message, {int tryCount = 1}) async {
    if (!clientCommon.isClientCreated) {
      return (await _checkClient(() => sendPiece(message), null)) as MessageSchema?;
    }
    try {
      int timeNowAt = DateTime.now().millisecondsSinceEpoch;
      await Future.delayed(Duration(milliseconds: (message.sendAt ?? timeNowAt) - timeNowAt));
      String data = MessageData.getPiece(message);
      if (message.to?.isNotEmpty == true) {
        OnMessage? onResult = await chatCommon.clientSendData(message.to, data);
        message.pid = onResult?.messageId;
      } else {
        logger.w("$TAG - sendPiece - message target is empty - message:$message");
        return null;
      }
      int? total = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX];
      // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
      // callback
      if (!message.isTopic) {
        double percent = (index ?? 0) / (total ?? 1);
        _onPieceOutSink.add({"msg_id": message.msgId, "percent": percent});
      }
      return message;
    } catch (e) {
      logger.w("$TAG - sendPiece - fail - tryCount:$tryCount - message:$message");
      if (await _handleSendError(e, tryCount, () => sendPiece(message, tryCount: ++tryCount))) return null;
      return await Future.delayed(Duration(seconds: 2), () {
        return sendPiece(message, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendTopicSubscribe(topic), null);
    }
    try {
      MessageSchema send = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: clientCommon.address!,
        contentType: MessageContentType.topicSubscribe,
        topic: topic,
      );
      String data = MessageData.getTopicSubscribe(send);
      await _sendAndDB(send, data);
      logger.d("$TAG - sendTopicSubscribe - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendTopicSubscribe - fail - tryCount:$tryCount - topic:$topic");
      if (await _handleSendError(e, tryCount, () => sendTopicSubscribe(topic, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicSubscribe(topic, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendTopicUnSubscribe(topic), null);
    }
    try {
      MessageSchema send = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: clientCommon.address!,
        contentType: MessageContentType.topicUnsubscribe,
        topic: topic,
      );
      String data = MessageData.getTopicUnSubscribe(send);
      await _sendAndDB(send, data, displaySelf: false);
      logger.d("$TAG - sendTopicUnSubscribe - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendTopicUnSubscribe - fail - tryCount:$tryCount - topic:$topic");
      if (await _handleSendError(e, tryCount, () => sendTopicUnSubscribe(topic, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicUnSubscribe(topic, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendTopicInvitee(clientAddress, topic), null) as MessageSchema?;
    }
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
    if (!clientCommon.isClientCreated) {
      return _checkClient(() => sendTopicKickOut(topic, targetAddress), null);
    }
    try {
      MessageSchema send = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: clientCommon.address!,
        contentType: MessageContentType.topicKickOut,
        topic: topic,
        content: targetAddress,
      );
      String data = MessageData.getTopicKickOut(send);
      await _sendAndDB(send, data, displaySelf: false);
      logger.d("$TAG - sendTopicKickOut - success - data:$data");
    } catch (e) {
      logger.w("$TAG - sendTopicKickOut - fail - tryCount:$tryCount - topic:$topic");
      if (await _handleSendError(e, tryCount, () => sendTopicKickOut(topic, targetAddress, tryCount: ++tryCount))) return;
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicKickOut(topic, targetAddress, tryCount: ++tryCount);
      });
    }
  }

  Future<MessageSchema?> resend(
    MessageSchema? message, {
    ContactSchema? contact,
    DeviceInfoSchema? deviceInfo,
    TopicSchema? topic,
  }) async {
    if (message == null) return null;
    message = await chatCommon.updateMessageStatus(message, MessageStatus.Sending, force: true, notify: false);
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

  Future<MessageSchema?> _sendAndDB(
    MessageSchema? message,
    String? msgData, {
    ContactSchema? contact,
    TopicSchema? topic,
    bool resend = false,
    bool displaySelf = true,
  }) async {
    if (message == null || msgData == null) return null;
    // DB
    if (!resend && displaySelf) {
      message = await _messageStorage.insert(message);
    } else if (resend) {
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      _messageStorage.updateSendAt(message.msgId, message.sendAt); // await
    }
    if (message == null) return null;
    // display
    if (!resend && displaySelf) _onSavedSink.add(message); // resend just update sendTime
    // contact
    contact = contact ?? await chatCommon.contactHandle(message);
    // topic
    topic = topic ?? await chatCommon.topicHandle(message);
    // session
    if (displaySelf) chatCommon.sessionHandle(message); // await
    // SDK
    Uint8List? pid;
    try {
      if (message.isTopic) {
        pid = await _sendWithTopic(topic, message, msgData);
        logger.d("$TAG - _sendAndDisplay - with_topic - to:${message.topic} - pid:$pid");
      } else if (message.to?.isNotEmpty == true) {
        pid = await _sendWithContact(contact, message, msgData);
        logger.d("$TAG - _sendAndDisplay - with_contact - to:${message.to} - pid:$pid");
      } else {
        logger.e("$TAG - _sendAndDisplay - with_null - message:$message");
      }
    } catch (e) {
      _handleSendError(e, 3, null);
    }
    // pid
    if (pid == null || pid.isEmpty) {
      logger.w("$TAG - _sendAndDisplay - pid = null - message:$message");
      message = await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
    } else {
      message.pid = pid;
      _messageStorage.updatePid(message.msgId, message.pid); // await
    }
    return message;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData) async {
    if (message == null || msgData == null) return null;
    // deviceInfo
    DeviceInfoSchema? _deviceInfo = await chatCommon.deviceInfoHandle(message, contact);
    logger.d("$TAG - _sendWithContact - info - _deviceInfo:$_deviceInfo - contact:$contact - message:$message - msgData:$msgData");
    // send message
    Uint8List? pid = await _sendByPiecesIfNeed(message, _deviceInfo);
    if (pid?.isNotEmpty == true) {
      logger.d("$TAG - _sendWithContact - to_contact_pieces - to:${message.to} - pid:$pid - deviceInfo:$_deviceInfo");
    } else {
      logger.d("$TAG - _sendWithContact - to_contact - to:${message.to} - msgData:$msgData");
      pid = (await chatCommon.clientSendData(message.to!, msgData))?.messageId;
    }
    // success
    if (pid?.isNotEmpty == true) {
      chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
      _sendPush(message, contact?.deviceToken); // await
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData) async {
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
    List<SubscriberSchema> _oldSubscribers = await subscriberCommon.queryListByTopic(topic.topic, status: SubscriberStatus.None);
    if (_oldSubscribers.isNotEmpty) {
      // SUPPORT:START
      List<Future> futures = [];
      _oldSubscribers.forEach((element) {
        futures.add(deviceInfoCommon.queryLatest(element.clientAddress).then((value) {
          if (!deviceInfoCommon.isTopicPermissionEnable(value?.platform, value?.appVersion)) {
            logger.i("$TAG - _sendWithTopic - add receiver to support old version - subscriber:$element");
            _subscribers.add(element);
          } else {
            logger.w("$TAG - _sendWithTopic - skip receiver because status is none - subscriber:$element");
          }
          return;
        }));
      });
      await Future.wait(futures);
      // SUPPORT:END
    }
    // subscribers check
    if (message.contentType == MessageContentType.topicKickOut) {
      logger.i("$TAG - _sendWithTopic - add kick people - clientAddress:${message.content}");
      SubscriberSchema? kicked = SubscriberSchema.create(topic.topic, message.content, SubscriberStatus.None, null);
      if (kicked != null) _subscribers.add(kicked);
    }
    bool privateNormal = topic.isPrivate && !topic.isOwner(clientCommon.address);
    if (_subscribers.isEmpty || (_subscribers.length == 1 && _subscribers.first.clientAddress == clientCommon.address && privateNormal)) {
      logger.w("$TAG - _sendWithTopic - _subscribers is empty - topic:$topic - message:$message - msgData:$msgData");
      List<OnMessage> onMessageList = await chatCommon.clientPublishData(genTopicHash(message.topic!), msgData, total: 2001); // permission checked in received
      if (onMessageList.isNotEmpty && onMessageList[0].messageId.isNotEmpty == true) {
        chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
        return onMessageList[0].messageId;
      }
      return null;
    }
    // sendData
    Uint8List? pid;
    List<Future> futures = [];
    _subscribers.forEach((SubscriberSchema subscriber) {
      futures.add(deviceInfoCommon.queryLatest(subscriber.clientAddress).then((DeviceInfoSchema? deviceInfo) {
        // deviceInfo
        return _sendByPiecesIfNeed(message, deviceInfo, to: subscriber.clientAddress);
      }).then((Uint8List? _pid) {
        // send data (no pieces)
        if (_pid?.isNotEmpty == true) {
          logger.d("$TAG - _sendWithTopic - to_subscriber_pieces - to:${subscriber.clientAddress} - subscriber:$subscriber - pid:$_pid");
          if (subscriber.clientAddress == clientCommon.address) {
            chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
          }
          return Future.value(OnMessage(messageId: _pid!, data: null, src: null, type: null, encrypted: null));
        } else {
          logger.d("$TAG - _sendWithTopic - to_subscriber - to:${subscriber.clientAddress} - subscriber:$subscriber");
          return chatCommon.clientSendData(subscriber.clientAddress, msgData).then((value) {
            if ((value?.messageId.isNotEmpty == true) && (subscriber.clientAddress == clientCommon.address)) {
              chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true); // await
            }
            return value;
          });
        }
      }).then((OnMessage? onResult) {
        // pid
        var _pid = onResult?.messageId;
        if ((_pid != null) && (pid == null)) {
          logger.d("$TAG - _sendWithTopic - find_pid_first - pid:$_pid - subscriber:$subscriber");
          pid = _pid;
        }
        if ((_pid != null) && (subscriber.clientAddress == clientCommon.address)) {
          logger.d("$TAG - _sendWithTopic - find_pid_last - pid:$_pid - subscriber:$subscriber");
          pid = _pid;
        }
        if (_pid?.isNotEmpty == true) {
          return subscriber.getContact(emptyAdd: false);
        }
        return Future.value(null);
      }).then((ContactSchema? contact) {
        // notification
        return _sendPush(message, contact?.deviceToken);
      }));
    });
    await Future.wait(futures);
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    return pid;
  }

  Future<Uint8List?> _sendByPiecesIfNeed(MessageSchema message, DeviceInfoSchema? deviceInfo, {String? to}) async {
    if (!deviceInfoCommon.isMsgPieceEnable(deviceInfo?.platform, deviceInfo?.appVersion)) return null;
    List results = await _convert2Pieces(message);
    if (results.isEmpty) return null;
    String dataBytesString = results[0];
    int bytesLength = results[1];
    int total = results[2];
    int parity = results[3];

    // dataList.size = (total + parity) <= 255
    List<Object?> dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty) return null;

    List<Future<MessageSchema?>> futures = <Future<MessageSchema?>>[];
    DateTime dataNow = DateTime.now();
    for (int index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      Map<String, dynamic> options = Map();
      options.addAll(message.options ?? Map());
      MessageSchema send = MessageSchema.fromSend(
        msgId: message.msgId,
        from: message.from,
        contentType: MessageContentType.piece,
        to: to ?? message.to,
        topic: message.topic,
        content: base64Encode(data),
        options: options,
        parentType: message.contentType,
        bytesLength: bytesLength,
        total: total,
        parity: parity,
        index: index,
      );
      send.sendAt = dataNow.add(Duration(milliseconds: index * 50)).millisecondsSinceEpoch; // wait 50ms
      futures.add(sendPiece(send));
    }
    logger.i("$TAG - _sendByPiecesIfNeed:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema?> returnList = await Future.wait(futures);
    returnList.sort((prev, next) => (prev?.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next?.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));

    List<MessageSchema?> successList = returnList.where((element) => element != null).toList();
    if (successList.length < total) {
      logger.w("$TAG - _sendByPiecesIfNeed:FAIL - count:${successList.length}");
      return null;
    }
    logger.i("$TAG - _sendByPiecesIfNeed:SUCCESS - count:${successList.length}");

    List<MessageSchema?> finds = returnList.where((element) => element?.pid != null).toList();
    if (finds.isNotEmpty) return finds[0]?.pid;
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

  _sendPush(MessageSchema message, String? deviceToken) async {
    if (!message.canRead) return;
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
    //     break;
    // }

    await SendPush.send(deviceToken, title, content);
  }

  Future _checkClient(Function? callback, dynamic defaultReturn) async {
    // TODO:GG 按理说应该等创建好了再发送，这里要不要把这些消息挂起来
    Toast.show("client为null，后续会处理");
    // WalletSchema? wallet = await walletCommon.getDefault();
    // if (wallet == null || wallet.address.isEmpty) {
    //   AppScreen.go(Global.appContext);
    //   return defaultReturn;
    // }
    // if (clientCommon.status != ClientConnectStatus.disconnected) {
    //   // for no duplicated
    //   return defaultReturn;
    // }
    // final client = (await clientCommon.signIn(
    //   wallet,
    //   fetchRemote: false,
    //   dialogVisible: (show) => show ? Loading.show() : Loading.dismiss(),
    // ))[0];
    // if (client != null && (client.address.isNotEmpty == true)) {
    //   logger.i("$TAG - _tryLogin - callback - callback:${callback.toString()}");
    //   return callback?.call();
    // }
    logger.w("$TAG - _tryLogin - fail");
    return defaultReturn;
  }

  Future<bool> _handleSendError(dynamic e, int tryCount, Function? callback) async {
    if (e.toString().contains("write: broken pipe")) {
      await Future.delayed(Duration(milliseconds: 100));
      final client = (await clientCommon.reSignIn(false))[0];
      if (client != null && (client.address.isNotEmpty == true)) {
        logger.i("$TAG - _handleSendError - callback - callback:${callback?.toString()}");
        try {
          await callback?.call();
          return true;
        } catch (e) {
          if (tryCount >= 3) {
            handleError(e);
            return true;
          }
          return false;
        }
      } else {
        final wallet = await walletCommon.getDefault();
        logger.w("$TAG - _handleSendError - reSignIn fail - wallet:$wallet");
        return false;
      }
    } else if (tryCount >= 3) {
      handleError(e);
      return true;
    }
    return false;
  }
}
