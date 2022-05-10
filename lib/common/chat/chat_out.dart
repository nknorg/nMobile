import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/send_push.dart';
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
import 'package:nmobile/utils/path.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPieceOutController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPieceOutSink => _onPieceOutController.sink;
  Stream<Map<String, dynamic>> get onPieceOutStream => _onPieceOutController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  // lock
  Lock sendLock = Lock(); // TODO:GG to queue
  Lock resendLock = Lock(); // TODO:GG to queue

  ChatOutCommon();

  void clear() {}

  Future<OnMessage?> sendData(String? selfAddress, List<String> destList, String data, {int tryTimes = 0, int maxTryTimes = 10}) async {
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.w("$TAG - sendData - destList is empty - destList:$destList - data:$data");
      return null;
    }
    // TODO:GG avatar pieces
    // if (data.length >= msgMaxSize) {
    //   logger.w("$TAG - sendData - size over - destList:$destList - data:$data");
    //   return null;
    // }
    if (tryTimes >= maxTryTimes) {
      logger.w("$TAG - sendData - try over - destList:$destList - data:$data");
      return null;
    }
    if (!clientCommon.isClientCreated || clientCommon.clientClosing || (selfAddress != clientCommon.address)) {
      logger.i("$TAG - sendData - client error - closing:${clientCommon.clientClosing} - tryTimes:$tryTimes - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 2));
      return sendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
    }
    return await sendLock.synchronized(() {
      return _clientSendData(selfAddress, destList, data);
    });
  }

  Future<OnMessage?> _clientSendData(String? selfAddress, List<String> destList, String data, {int tryTimes = 0, int maxTryTimes = 5}) async {
    if (tryTimes >= maxTryTimes) {
      logger.w("$TAG - _clientSendData - try over - destList:$destList - data:$data");
      return null;
    }
    if (!clientCommon.isClientCreated || clientCommon.clientClosing || (selfAddress != clientCommon.address)) {
      logger.i("$TAG - _clientSendData - client error - closing:${clientCommon.clientClosing} - tryTimes:$tryTimes - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
    }
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.d("$TAG - _clientSendData - send success - destList:$destList - data:$data");
        return onMessage;
      } else {
        logger.w("$TAG - _clientSendData - onMessage msgId is empty - tryTimes:$tryTimes - destList:$destList - data:$data");
        await Future.delayed(Duration(milliseconds: 100));
        return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
      }
    } catch (e) {
      if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
        if (clientCommon.clientResigning || (clientCommon.checkTimes > 0)) {
          await Future.delayed(Duration(milliseconds: 1000));
          return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
        } else {
          final client = (await clientCommon.reSignIn(false))[0];
          if ((client != null) && (client.address.isNotEmpty == true)) {
            logger.i("$TAG - _clientSendData - reSignIn success - tryTimes:$tryTimes - destList:$destList data:$data");
            await Future.delayed(Duration(milliseconds: 500));
            return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
          } else {
            // maybe always no here
            logger.w("$TAG - _clientSendData - reSignIn fail - wallet:${await walletCommon.getDefault()}");
            return null;
          }
        }
      } else if (e.toString().contains("invalid destination")) {
        logger.w("$TAG - _clientSendData - wrong clientAddress - destList:$destList");
        return null;
      } else {
        handleError(e);
        logger.w("$TAG - _clientSendData - try by error - tryTimes:$tryTimes - destList:$destList - data:$data");
        await Future.delayed(Duration(milliseconds: 100));
        return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
      }
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendPing(List<String> clientAddressList, bool isPing) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddressList.isEmpty) return;
    String data = MessageData.getPing(isPing);
    await _sendWithAddressSafe(clientAddressList, data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (received.from.isEmpty || received.isTopic) return; // topic no receipt, just send message to myself
    received = (await MessageStorage.instance.queryByNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
    String data = MessageData.getReceipt(received.msgId, received.receiveAt);
    await _sendWithAddressSafe([received.from], data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendRead(String? clientAddress, List<String> msgIds) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    String data = MessageData.getRead(msgIds);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendMsgStatus(String? clientAddress, bool ask, List<String> msgIds) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    String data = MessageData.getMsgStatus(ask, msgIds);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(String? clientAddress, String requestType, String? profileVersion) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    int updateAt = DateTime.now().millisecondsSinceEpoch;
    String data = MessageData.getContactRequest(requestType, profileVersion, updateAt);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(String? clientAddress, String requestType, {ContactSchema? me}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    ContactSchema? _me = me ?? await contactCommon.getMe();
    int updateAt = DateTime.now().millisecondsSinceEpoch;
    String data;
    if (requestType == RequestType.header) {
      data = MessageData.getContactResponseHeader(_me?.profileVersion, updateAt);
    } else {
      data = await MessageData.getContactResponseFull(_me?.firstName, _me?.lastName, _me?.avatar, _me?.profileVersion, updateAt);
    }
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO topic (1 to 1)
  Future sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.contactOptions,
      to: clientAddress,
      extra: {
        "deleteAfterSeconds": deleteSeconds,
        "burningUpdateAt": updateAt,
      },
    );
    send.content = MessageData.getContactOptionsBurn(send); // same with receive and old version
    await _saveAndSend(send, send.content);
  }

  // NO topic (1 to 1)
  Future sendContactOptionsToken(String? clientAddress, String deviceToken) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.contactOptions,
      to: clientAddress,
    );
    send.options = MessageOptions.setDeviceToken(send.options, deviceToken);
    send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
    await _saveAndSend(send, send.content);
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceRequest(String? clientAddress) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    String data = MessageData.getDeviceRequest();
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceInfo(String? clientAddress) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    String data = MessageData.getDeviceInfo();
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  Future<MessageSchema?> sendText(String? content, {dynamic target}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || content.trim().isEmpty) return null;
    // target
    String targetAddress = "";
    String targetTopic = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetTopic.isEmpty) {
      return null;
    }
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: ((deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text,
      to: targetAddress,
      topic: targetTopic,
      content: content,
      extra: {
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
      },
    );
    // data
    String data = MessageData.getText(message);
    return _saveAndSend(message, data);
  }

  Future<MessageSchema?> startIpfs(Map<String, dynamic> data, {dynamic target}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    // content
    String contentPath = data["path"]?.toString() ?? "";
    File? content = contentPath.isEmpty ? null : File(contentPath);
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) {
      return null;
    }
    // target
    String targetAddress = "";
    String targetTopic = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetTopic.isEmpty) {
      return null;
    }
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.ipfs,
      to: targetAddress,
      topic: targetTopic,
      content: content,
      extra: data
        ..addAll({
          "deleteAfterSeconds": deleteAfterSeconds,
          "burningUpdateAt": burningUpdateAt,
          "fileExt": data["fileExt"] ?? Path.getFileExt(content, "jpg"),
        }),
    );
    // insert
    message.options = MessageOptions.setIpfsState(message.options, false);
    MessageSchema? inserted = await _insertMessage(message);
    if (inserted == null) return null;
    // ipfs
    ipfsHelper.uploadFile(inserted.msgId, content.absolute.path, onProgress: (msgId, percent) {
      _onPieceOutSink.add({"msg_id": msgId, "percent": percent});
    }, onSuccess: (msgId, result) async {
      await sendIpfs(msgId, result);
    });
    return inserted;
  }

  Future<MessageSchema?> sendIpfs(String? msgId, Map<String, dynamic> result) async {
    if (msgId == null || msgId.isEmpty) return null;
    // schema
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    message.options = MessageOptions.setIpfsResult(message.options, result["Hash"], result["Size"], result["Name"]);
    message.options = MessageOptions.setIpfsState(message.options, true);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    // data
    String? data = await MessageData.getIpfs(message);
    return _saveAndSend(message, data, insert: false);
  }

  Future<MessageSchema?> sendImage(File? content, {dynamic target}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetAddress = "";
    String targetTopic = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetTopic.isEmpty) {
      return null;
    }
    // contentType
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(targetAddress);
    String contentType = DeviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: contentType,
      to: targetAddress,
      topic: targetTopic,
      content: content,
      extra: {
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileExt": Path.getFileExt(content, "jpg"),
      },
    );
    // data
    String? data = await MessageData.getImage(message);
    return _saveAndSend(message, data);
  }

  Future<MessageSchema?> sendAudio(File? content, double? durationS, {dynamic target}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetAddress = "";
    String targetTopic = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetTopic.isEmpty) {
      return null;
    }
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.audio,
      to: targetAddress,
      topic: targetTopic,
      content: content,
      extra: {
        "audioDurationS": durationS,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileExt": Path.getFileExt(content, "aac"),
      },
    );
    // data
    String? data = await MessageData.getAudio(message);
    return _saveAndSend(message, data);
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    int timeNowAt = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: (message.sendAt ?? timeNowAt) - timeNowAt));
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendData(clientCommon.address, clientAddressList, data);
    if ((onResult?.messageId == null) || onResult!.messageId.isEmpty) return null;
    message.pid = onResult.messageId;
    // progress
    if (percent > 0 && percent <= 1) {
      if (percent <= 1.05) {
        // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        _onPieceOutSink.add({"msg_id": message.msgId, "percent": percent});
      }
    } else {
      int? total = message.options?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE_INDEX];
      double percent = (index ?? 0) / (total ?? 1);
      if (percent <= 1.05) {
        // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        _onPieceOutSink.add({"msg_id": message.msgId, "percent": percent});
      }
    }
    return message;
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.topicSubscribe,
      topic: topic,
    );
    String data = MessageData.getTopicSubscribe(send);
    await _saveAndSend(send, data);
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.topicUnsubscribe,
      topic: topic,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicUnSubscribe(send);
    await _sendWithTopicSafe(_schema, send, data, notification: false);
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.topicInvitation,
      to: clientAddress,
      content: topic,
    );
    String data = MessageData.getTopicInvitee(message);
    return _saveAndSend(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      contentType: MessageContentType.topicKickOut,
      topic: topic,
      content: targetAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicKickOut(send);
    await _sendWithTopicSafe(_schema, send, data, notification: false);
  }

  Future<MessageSchema?> resend(MessageSchema? message) async {
    if (message == null) return null;
    message = await chatCommon.updateMessageStatus(message, MessageStatus.Sending, force: true, notify: true);
    await MessageStorage.instance.updateSendAt(message.msgId, message.sendAt);
    message.sendAt = DateTime.now().millisecondsSinceEpoch;
    // send
    return resendLock.synchronized(() async {
      if (message == null) return null;
      String? msgData;
      switch (message.contentType) {
        case MessageContentType.text:
        case MessageContentType.textExtension:
          msgData = MessageData.getText(message);
          break;
        case MessageContentType.ipfs:
          // TODO:GG type_ipfs 应该直接走startIpfs?
          msgData = await MessageData.getIpfs(message);
          break;
        case MessageContentType.media:
        case MessageContentType.image:
          msgData = await MessageData.getImage(message);
          break;
        case MessageContentType.audio:
          msgData = await MessageData.getAudio(message);
          break;
      }
      return await _saveAndSend(message, msgData, insert: false);
    });
  }

  Future<MessageSchema?> resendMute(MessageSchema? message, {bool? notification}) {
    return resendLock.synchronized(() {
      return resendMuteNoLock(message, notification: notification);
    });
  }

  Future<MessageSchema?> resendMuteNoLock(MessageSchema? message, {bool? notification}) async {
    if (message == null) return null;
    // msgData
    String? msgData;
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        msgData = MessageData.getText(message);
        logger.i("$TAG - resendMute - resend text - targetId:${message.targetId} - msgData:$msgData");
        break;
      case MessageContentType.ipfs:
        // TODO:GG type_ipfs 应该直接走startIpfs?
        msgData = await MessageData.getIpfs(message);
        logger.i("$TAG - resendMute - resend audio - targetId:${message.targetId} - msgData:$msgData");
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
      case MessageContentType.topicInvitation:
        msgData = MessageData.getTopicInvitee(message);
        logger.i("$TAG - resendMute - resend invitee - targetId:${message.targetId} - msgData:$msgData");
        break;
      default:
        logger.w("$TAG - resendMute - noReceipt not receipt/read - targetId:${message.targetId} - message:$message");
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
      } else if (message.to.isNotEmpty) {
        final contact = await chatCommon.contactHandle(message);
        pid = await _sendWithContactSafe(contact, message, msgData, notification: notification);
      }
    }
    // result
    if (pid?.isNotEmpty == true) {
      logger.i("$TAG - resendMute - resend result - pid:$pid - message:$message");
      message.pid = pid;
      MessageStorage.instance.updatePid(message.msgId, message.pid); // await
    } else {
      logger.w("$TAG - resendMute - resend fail - message:$message");
    }
    return message;
  }

  Future<MessageSchema?> _insertMessage(MessageSchema? message, {bool notify = true}) async {
    if (message == null) return null;
    message = await MessageStorage.instance.insert(message); // DB
    if (message == null) return null;
    if (notify) _onSavedSink.add(message); // display, resend just update sendTime
    return message;
  }

  Future<MessageSchema?> _saveAndSend(MessageSchema? message, String? msgData, {bool insert = true}) async {
    if (message == null || msgData == null) return null;
    if (insert) message = await _insertMessage(message);
    if (message == null) return null;
    // session
    await chatCommon.sessionHandle(message);
    // SDK
    Uint8List? pid;
    if (message.isTopic) {
      TopicSchema? topic = await chatCommon.topicHandle(message);
      pid = await _sendWithTopicSafe(topic, message, msgData, notification: message.canNotification);
      logger.d("$TAG - _sendAndDisplay - with_topic - to:${message.topic} - pid:$pid");
    } else if (message.to.isNotEmpty == true) {
      ContactSchema? contact = await chatCommon.contactHandle(message);
      pid = await _sendWithContactSafe(contact, message, msgData, notification: message.canNotification);
      logger.d("$TAG - _sendAndDisplay - with_contact - to:${message.to} - pid:$pid");
    }
    // pid
    if (pid?.isNotEmpty == true) {
      message.pid = pid;
      MessageStorage.instance.updatePid(message.msgId, message.pid); // await
      // no received receipt/read
      if (!message.canReceipt) {
        int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
        chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt); // await
      } else {
        chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, reQuery: true, notify: true); // await
      }
    } else {
      logger.w("$TAG - _sendAndDisplay - pid = null - message:$message");
      if (message.canResend) {
        message = await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
      } else {
        // noResend just delete
        int count = await MessageStorage.instance.deleteByContentType(message.msgId, message.contentType);
        if (count > 0) chatCommon.onDeleteSink.add(message.msgId);
        return null;
      }
    }
    return message;
  }

  Future<Uint8List?> _sendWithAddressSafe(List<String> clientAddressList, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithAddress(clientAddressList, msgData, notification: notification);
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  Future<Uint8List?> _sendWithContactSafe(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithContact(contact, message, msgData, notification: notification);
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  Future<Uint8List?> _sendWithTopicSafe(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithTopic(topic, message, msgData, notification: notification);
    } catch (e) {
      handleError(e);
      return null;
    }
  }

  Future<Uint8List?> _sendWithAddress(List<String> clientAddressList, String? msgData, {bool notification = false}) async {
    if (clientAddressList.isEmpty || msgData == null) return null;
    logger.d("$TAG - _sendWithAddress - clientAddressList:$clientAddressList - msgData:$msgData - msgData:$msgData");
    Uint8List? pid = (await sendData(clientCommon.address, clientAddressList, msgData))?.messageId;
    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        contactCommon.queryListByClientAddress(clientAddressList).then((List<ContactSchema> contactList) async {
          for (var i = 0; i < contactList.length; i++) {
            ContactSchema _contact = contactList[i];
            if (!_contact.isMe) _sendPush(_contact.deviceToken); // await
          }
        });
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (message == null || msgData == null) return null;
    logger.d("$TAG - _sendWithContact - contact:$contact - message:$message - msgData:$msgData");
    Uint8List? pid;
    if (message.isContentFile) {
      // deviceInfo
      DeviceInfoSchema? _deviceInfo = await chatCommon.deviceInfoHandle(message, contact);
      logger.d("$TAG - _sendWithContact - file - to:${message.to} - deviceInfo:$_deviceInfo");
      if (DeviceInfoCommon.isMsgPieceEnable(_deviceInfo?.platform, _deviceInfo?.appVersion)) {
        pid = await _sendByPieces([message.to], message);
        if ((pid == null) || pid.isEmpty) {
          pid = (await sendData(clientCommon.address, [message.to], msgData))?.messageId;
        }
      } else {
        MessageSchema copy = message.copy();
        copy.contentType = MessageContentType.text;
        copy.content = "The current version does not support viewing this message";
        String msgData = MessageData.getText(copy);
        pid = (await sendData(clientCommon.address, [message.to], msgData))?.messageId;
      }
    } else {
      logger.d("$TAG - _sendWithContact - text - to:${message.to} - msgData:$msgData");
      pid = (await sendData(clientCommon.address, [message.to], msgData))?.messageId;
    }
    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        if (contact != null && !contact.isMe) _sendPush(contact.deviceToken); // await
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (topic == null || message == null || msgData == null) return null;
    // me
    SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(message.topic, message.from); // chatOutCommon.handleSubscribe();
    bool checkStatus = message.contentType == MessageContentType.topicUnsubscribe;
    if (!checkStatus && (_me?.status != SubscriberStatus.Subscribed)) {
      logger.w("$TAG - _sendWithTopic - subscriber me is wrong - me:$_me - message:$message");
      return null;
    }
    // subscribers
    int limit = 20;
    List<SubscriberSchema> _subscribers = [];
    for (int offset = 0; true; offset += limit) {
      List<SubscriberSchema> result = await subscriberCommon.queryListByTopic(topic.topic, status: SubscriberStatus.Subscribed, offset: offset, limit: limit);
      _subscribers.addAll(result);
      if (result.length < limit) break;
    }
    if (message.contentType == MessageContentType.topicKickOut) {
      logger.i("$TAG - _sendWithTopic - add kick people - clientAddress:${message.content}");
      SubscriberSchema? kicked = SubscriberSchema.create(topic.topic, message.content?.toString(), SubscriberStatus.None, null);
      if (kicked != null) _subscribers.add(kicked);
    }
    if (_subscribers.isEmpty) return null;
    logger.d("$TAG - _sendWithTopic - topic:${topic.topic} - message:$message - msgData:$msgData");
    // destList
    bool selfIsReceiver = false;
    List<String> subscribersAddressList = [];
    for (var i = 0; i < _subscribers.length; i++) {
      String clientAddress = _subscribers[i].clientAddress;
      if (clientAddress == clientCommon.address) {
        selfIsReceiver = true;
      } else {
        subscribersAddressList.add(clientAddress);
      }
    }
    // others
    Uint8List? pid;
    if (subscribersAddressList.isNotEmpty) {
      if (message.isContentFile) {
        // targets
        List<DeviceInfoSchema> deviceInfoList = await deviceInfoCommon.queryListLatest(subscribersAddressList);
        List<String> targetIdsByPiece = [];
        List<String> targetIdsByTip = [];
        for (var i = 0; i < _subscribers.length; i++) {
          SubscriberSchema subscriber = _subscribers[i];
          int findIndex = deviceInfoList.indexWhere((element) => element.contactAddress == subscriber.clientAddress);
          DeviceInfoSchema? deviceInfo = findIndex >= 0 ? deviceInfoList[findIndex] : null;
          if (DeviceInfoCommon.isMsgPieceEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
            targetIdsByPiece.add(subscriber.clientAddress);
          } else {
            targetIdsByTip.add(subscriber.clientAddress);
          }
        }
        // send
        if (targetIdsByPiece.isNotEmpty) {
          pid = await _sendByPieces(targetIdsByPiece, message);
          if ((pid == null) || pid.isEmpty) {
            pid = (await sendData(clientCommon.address, subscribersAddressList, msgData))?.messageId;
          }
        }
        if (targetIdsByTip.isNotEmpty) {
          MessageSchema copy = message.copy();
          copy.contentType = MessageContentType.text;
          copy.content = "The current version does not support viewing this message";
          String copyData = MessageData.getText(copy);
          Uint8List? _pid = (await sendData(clientCommon.address, targetIdsByTip, copyData))?.messageId;
          if (targetIdsByPiece.isEmpty) pid = _pid;
        }
      } else {
        pid = (await sendData(clientCommon.address, subscribersAddressList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver && (clientCommon.address?.isNotEmpty == true)) {
      String data = MessageData.getReceipt(message.msgId, DateTime.now().millisecondsSinceEpoch);
      Uint8List? _pid = (await sendData(clientCommon.address, [clientCommon.address ?? ""], data))?.messageId;
      if (subscribersAddressList.isEmpty) pid = _pid;
    }

    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        contactCommon.queryListByClientAddress(subscribersAddressList).then((List<ContactSchema> contactList) async {
          for (var i = 0; i < contactList.length; i++) {
            ContactSchema _contact = contactList[i];
            if (!_contact.isMe) _sendPush(_contact.deviceToken); // await
          }
        });
      }
    }
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    return pid;
  }

  Future<Uint8List?> _sendByPieces(List<String> clientAddressList, MessageSchema message, {double totalPercent = -1}) async {
    Map<String, dynamic> results = await message.piecesInfo();
    if (results.isEmpty) return null;
    String dataBytesString = results["data"];
    int bytesLength = results["length"];
    int total = results["total"];
    int parity = results["parity"];

    // dataList.size = (total + parity) <= 255
    List<Object?> dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty) return null;

    logger.i("$TAG - _sendByPieces:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");

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
        extra: {
          "piece_parent_type": message.contentType,
          "piece_bytes_length": bytesLength,
          "piece_total": total,
          "piece_parity": parity,
          "piece_index": index,
        },
      );
      double percent = (totalPercent > 0 && totalPercent <= 1) ? (index / total * totalPercent) : -1;
      MessageSchema? result = await sendPiece(clientAddressList, piece, percent: percent);
      if ((result == null) || (result.pid == null)) {
        logger.w("$TAG - _sendByPieces:ERROR - msgId:${piece.msgId}");
      } else {
        resultList.add(result);
      }
      await Future.delayed(Duration(milliseconds: 1000 ~/ 100));
    }
    List<MessageSchema> finds = resultList.where((element) => element.pid != null).toList();
    finds.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    if (finds.length >= total) {
      logger.i("$TAG - _sendByPieces:SUCCESS - count:${resultList.length} - total:$total - message:$message");
      if (finds.isNotEmpty) return finds[0].pid;
    } else {
      logger.w("$TAG - _sendByPieces:FAIL - count:${resultList.length} - total:$total - message:$message");
    }
    return null;
  }

  Future _sendPush(String? deviceToken) async {
    if (deviceToken == null || deviceToken.isEmpty == true) return;

    String title = Global.locale((s) => s.new_message);
    // if (topic != null) {
    //   title = '[${topic.topicShort}] ${contact?.displayName}';
    // } else if (contact != null) {
    //   title = contact.displayName;
    // }

    String content = Global.locale((s) => s.you_have_new_message);
    // switch (message.contentType) {
    //   case MessageContentType.text:
    //   case MessageContentType.textExtension:
    //     content = message.content;
    //     break;
    //   case MessageContentType.ipfs:
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
}
