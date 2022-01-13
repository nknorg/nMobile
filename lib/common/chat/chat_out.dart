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
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  // piece
  static const int piecesPreMinLen = 4 * 1000; // >= 4K
  static const int piecesPreMaxLen = 20 * 1000; // <= 20K < 32K
  static const int piecesMinParity = (5 ~/ 5); // >= 1
  static const int piecesMinTotal = 5 - piecesMinParity; // >= 4 (* piecesPreMinLen < piecesPreMaxLen)
  static const int piecesMaxParity = (100 ~/ 5); // <= 20
  static const int piecesMaxTotal = 100 - piecesMaxParity; // <= 80

  // size
  static const int imgBestSize = 400 * 1000; // 400k
  static const int imgMaxSize = piecesMaxTotal * piecesPreMaxLen; // 1.6M = 80 * 20K
  static const int avatarBestSize = 100 * 1000; // 400k
  static const int avatarMaxSize = 500 * 1000; // 1.6M = 80 * 20K
  static const int msgMaxSize = 32 * 1000; // < 32K
  // static const int maxBodySize = piecesMaxTotal * (piecesPreLength * 10); // 1,843,200 < 4,000,000(nkn-go-sdk)

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPieceOutController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPieceOutSink => _onPieceOutController.sink;
  Stream<Map<String, dynamic>> get onPieceOutStream => _onPieceOutController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  // lock
  Lock sendLock = Lock();
  Lock resendLock = Lock();

  ChatOutCommon();

  void clear() {}

  Future<OnMessage?> sendData(String? selfAddress, List<String> destList, String data, {int tryTimes = 0, int maxTryTimes = 10}) async {
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.w("$TAG - sendData - destList is empty - destList:$destList - data:$data");
      return null;
    }
    if (data.length >= msgMaxSize) {
      logger.w("$TAG - sendData - size over - destList:$destList - data:$data");
      return null;
    }
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

  // Future<List<OnMessage>> _clientPublishData(String? selfAddress, String? topic, String data, {bool txPool = true, int? total, int tryTimes = 0, int maxTryTimes = 10}) async {
  //   if (topic == null || topic.isEmpty) {
  //     logger.w("$TAG - _clientPublishData - topic is empty - dest:$topic - data:$data");
  //     return [];
  //   }
  //   if (tryTimes >= maxTryTimes) {
  //     logger.w("$TAG - _clientPublishData - try over - dest:$topic - data:$data");
  //     return [];
  //   }
  //   if (!clientCommon.isClientCreated || clientCommon.clientClosing || (selfAddress != clientCommon.address)) {
  //     logger.i("$TAG - _clientPublishData - client error - closing:${clientCommon.clientClosing} - tryTimes:$tryTimes - dest:$topic - data:$data");
  //     await Future.delayed(Duration(seconds: 2));
  //     return _clientPublishData(selfAddress, topic, data, txPool: txPool, total: total, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
  //   }
  //   if (application.inBackGroundLater && Platform.isIOS) {
  //     logger.i("$TAG - _clientPublishData - ios background - tryTimes:$tryTimes - dest:$topic - data:$data");
  //     await Future.delayed(Duration(seconds: 1));
  //     return _clientPublishData(selfAddress, topic, data, txPool: txPool, total: total, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
  //   }
  //   if (DateTime.now().millisecondsSinceEpoch < (lastSendTimeStamp + minSendIntervalMs)) {
  //     int interval = DateTime.now().millisecondsSinceEpoch - lastSendTimeStamp;
  //     logger.i("$TAG - _clientPublishData - interval small - interval:$interval - tryTimes:$tryTimes - dest:$topic - data:$data");
  //     await Future.delayed(Duration(milliseconds: minSendIntervalMs * 2));
  //     return _clientPublishData(selfAddress, topic, data, txPool: txPool, total: total, tryTimes: tryTimes, maxTryTimes: maxTryTimes);
  //   }
  //   lastSendTimeStamp = DateTime.now().millisecondsSinceEpoch;
  //   try {
  //     // once
  //     if (total == null || total <= 1000) {
  //       OnMessage result = await clientCommon.client!.publishText(genTopicHash(topic), data, txPool: txPool, offset: 0, limit: 1000);
  //       return [result];
  //     }
  //     // split
  //     List<Future<OnMessage>> futures = [];
  //     for (int i = 0; i < total; i += 1000) {
  //       futures.add(clientCommon.client!.publishText(genTopicHash(topic), data, txPool: txPool, offset: i, limit: i + 1000));
  //     }
  //     List<OnMessage> onMessageList = await Future.wait(futures);
  //     logger.i("$TAG - clientPublishData - topic:$topic - total:$total - data$data - onMessageList:$onMessageList");
  //     return onMessageList;
  //   } catch (e) {
  //     if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
  //       final client = (await clientCommon.reSignIn(false, delayMs: 500))[0];
  //       if ((client != null) && (client.address.isNotEmpty == true)) {
  //         logger.i("$TAG - clientPublishData - reSignIn success - tryTimes:$tryTimes - topic:$topic data:$data");
  //         await Future.delayed(Duration(seconds: 1));
  //         return _clientPublishData(selfAddress, topic, data, txPool: txPool, total: total, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
  //       } else {
  //         // maybe always no here
  //         logger.w("$TAG - clientPublishData - reSignIn fail - wallet:${await walletCommon.getDefault()}");
  //         return [];
  //       }
  //     } else {
  //       handleError(e);
  //       logger.w("$TAG - clientPublishData - try by error - tryTimes:$tryTimes - topic:$topic - data:$data");
  //       await Future.delayed(Duration(seconds: 2));
  //       return _clientPublishData(selfAddress, topic, data, txPool: txPool, total: total, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
  //     }
  //   }
  // }

  // NO DB NO display NO topic (1 to 1)
  Future sendPing(List<String> clientAddressList, bool isPing) async {
    if (clientAddressList.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    String data = MessageData.getPing(isPing);
    await _sendWithAddressSafe(clientAddressList, data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received) async {
    if (received.from.isEmpty || received.isTopic) return; // topic no receipt, just send message to myself
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    received = (await MessageStorage.instance.queryByNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
    String data = MessageData.getReceipt(received.msgId, received.receiveAt);
    await _sendWithAddressSafe([received.from], data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendRead(String? clientAddress, List<String> msgIds) async {
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    String data = MessageData.getRead(msgIds);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendMsgStatus(String? clientAddress, bool ask, List<String> msgIds) async {
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return; // topic no read, just like receipt
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    String data = MessageData.getMsgStatus(ask, msgIds);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(String? clientAddress, String requestType, String? profileVersion) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    int updateAt = DateTime.now().millisecondsSinceEpoch;
    String data = MessageData.getContactRequest(requestType, profileVersion, updateAt);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(String? clientAddress, String requestType, {ContactSchema? me}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
  Future sendContactOptionsToken(String? clientAddress, String deviceToken) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
  Future sendDeviceRequest(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    String data = MessageData.getDeviceRequest();
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceInfo(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    String data = MessageData.getDeviceInfo();
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  Future<MessageSchema?> sendText(String? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || content.trim().isEmpty) return null;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    String contentType = ((contact?.options?.deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: (topic?.topic.isNotEmpty == true) ? "" : (contact?.clientAddress ?? ""),
      topic: topic?.topic ?? "",
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String data = MessageData.getText(message);
    return _sendAndDB(message, data, contact: contact, topic: topic);
  }

  Future<MessageSchema?> sendImage(File? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(contact?.clientAddress);
    String contentType = DeviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: contentType,
      to: (topic?.topic.isNotEmpty == true) ? "" : (contact?.clientAddress ?? ""),
      topic: topic?.topic ?? "",
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getImage(message);
    return _sendAndDB(message, data, contact: contact, topic: topic);
  }

  Future<MessageSchema?> sendAudio(File? content, double? durationS, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.audio,
      to: (topic?.topic.isNotEmpty == true) ? "" : (contact?.clientAddress ?? ""),
      topic: topic?.topic ?? "",
      content: content,
      audioDurationS: durationS,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getAudio(message);
    return _sendAndDB(message, data, contact: contact, topic: topic);
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
      int? total = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX];
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
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
  Future sendTopicUnSubscribe(String? topic) async {
    if (topic == null || topic.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicUnsubscribe,
      topic: topic,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicUnSubscribe(send);
    await _sendWithTopicSafe(_schema, send, data, notification: false);
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
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
  Future sendTopicKickOut(String? topic, String? targetAddress) async {
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty) return;
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address!,
      contentType: MessageContentType.topicKickOut,
      topic: topic,
      content: targetAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicKickOut(send);
    await _sendWithTopicSafe(_schema, send, data, notification: false);
  }

  Future<MessageSchema?> resend(MessageSchema? message, {ContactSchema? contact, DeviceInfoSchema? deviceInfo, TopicSchema? topic}) async {
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
        case MessageContentType.media:
        case MessageContentType.image:
          msgData = await MessageData.getImage(message);
          break;
        case MessageContentType.audio:
          msgData = await MessageData.getAudio(message);
          break;
      }
      return await _sendAndDB(message, msgData, contact: contact, topic: topic, resend: true);
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

  Future<MessageSchema?> _sendAndDB(
    MessageSchema? message,
    String? msgData, {
    ContactSchema? contact,
    TopicSchema? topic,
    bool resend = false,
  }) async {
    if (message == null || msgData == null) return null;
    // DB
    if (!resend) {
      message = await MessageStorage.instance.insert(message);
    }
    if (message == null) return null;
    // display
    if (!resend) _onSavedSink.add(message); // resend just update sendTime
    // contact
    contact = contact ?? await chatCommon.contactHandle(message);
    // topic
    topic = topic ?? await chatCommon.topicHandle(message);
    // session
    await chatCommon.sessionHandle(message);
    // SDK
    Uint8List? pid;
    if (message.isTopic) {
      pid = await _sendWithTopicSafe(topic, message, msgData, notification: message.canNotification);
      logger.d("$TAG - _sendAndDisplay - with_topic - to:${message.topic} - pid:$pid");
    } else if (message.to.isNotEmpty == true) {
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
        copy.content = "当前版本不支持该消息类型"; // TODO:GG locale 英文
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
        copy.content = "当前版本不支持该消息类型"; // TODO:GG locale 英文
        String copyData = MessageData.getText(copy);
        Uint8List? _pid = (await sendData(clientCommon.address, targetIdsByTip, copyData))?.messageId;
        if (targetIdsByPiece.isEmpty) pid = _pid;
      }
    } else {
      pid = (await sendData(clientCommon.address, subscribersAddressList, msgData))?.messageId;
    }
    // self
    if (selfIsReceiver && (clientCommon.address?.isNotEmpty == true)) {
      String data = MessageData.getReceipt(message.msgId, DateTime.now().millisecondsSinceEpoch);
      await sendData(clientCommon.address, [clientCommon.address ?? ""], data);
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
    if (length <= piecesPreMinLen) return [];
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    int bytesLength = base64Data.length;
    // total (2~192)
    int total;
    if (bytesLength < piecesPreMinLen * piecesMinTotal) {
      return [];
    } else if (bytesLength <= piecesPreMinLen * piecesMaxTotal) {
      total = bytesLength ~/ piecesPreMinLen;
      if (bytesLength % piecesPreMinLen > 0) {
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

  // Future<bool> _handleSendError(dynamic e, int tryTimes, Function? callback) async {
  //   if (e.toString().contains("write: broken pipe") || e.toString().contains("use of closed network connection")) {
  //     await Future.delayed(Duration(milliseconds: 100));
  //     final client = (await clientCommon.reSignIn(false))[0];
  //     if (client != null && (client.address.isNotEmpty == true)) {
  //       logger.i("$TAG - _handleSendError - callback - callback:${callback?.toString()}");
  //       try {
  //         await callback?.call();
  //         return true;
  //       } catch (e) {
  //         if (tryTimes >= 3) {
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
  //   } else if (tryTimes >= 3) {
  //     handleError(e);
  //     return true;
  //   }
  //   return false;
  // }
}
