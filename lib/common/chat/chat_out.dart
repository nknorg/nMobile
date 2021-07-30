import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/push/send_push.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
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
import 'package:uuid/uuid.dart';

import '../locator.dart';

class ChatOutCommon with Tag {
  // piece
  static const int piecesParity = 3;
  static const int prePieceLength = 1024 * 6;
  static const int minPiecesTotal = 2 * piecesParity; // parity >= 2
  static const int maxPiecesTotal = 10 * piecesParity; // parity <= 10

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

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (received.from.isEmpty || received.isTopic) return; // topic no receipt, just send message to myself
    if (tryCount > 3) return;
    try {
      String data = MessageData.getReceipt(received.msgId);
      await chatCommon.clientSendData(received.from, data);
      logger.d("$TAG - sendReceipt - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendReceipt - fail - tryCount:$tryCount - received:$received");
      await Future.delayed(Duration(seconds: 2), () {
        return sendReceipt(received, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      int updateAt = DateTime.now().millisecondsSinceEpoch;
      String data = MessageData.getContactRequest(requestType, target.profileVersion, updateAt);
      await chatCommon.clientSendData(target.clientAddress, data);
      logger.d("$TAG - sendContactRequest - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendContactRequest - fail - tryCount:$tryCount - requestType:$requestType - target:$target");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactRequest(target, requestType, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(ContactSchema? target, String requestType, {ContactSchema? me, int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (tryCount > 3) return;
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
      handleError(e);
      logger.w("$TAG - sendContactResponse - fail - tryCount:$tryCount - requestType:$requestType");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactResponse(target, requestType, me: _me, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt, {int tryCount = 1}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty || clientAddress == null || clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      MessageSchema send = MessageSchema.fromSend(
        Uuid().v4(),
        clientCommon.address!,
        MessageContentType.contactOptions,
        to: clientAddress,
        deleteAfterSeconds: deleteSeconds,
        burningUpdateAt: updateAt,
      );
      send.content = MessageData.getContactOptionsBurn(send); // same with receive and old version
      await _sendAndDisplay(send, send.content);
      logger.d("$TAG - sendContactOptionsBurn - success - data:${send.content}");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendContactOptionsBurn - fail - tryCount:$tryCount - clientAddress:$clientAddress - deleteSeconds:$deleteSeconds");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactOptionsBurn(clientAddress, deleteSeconds, updateAt, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future sendContactOptionsToken(String? clientAddress, String deviceToken, {int tryCount = 1}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty || clientAddress == null || clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      MessageSchema send = MessageSchema.fromSend(
        Uuid().v4(),
        clientCommon.address!,
        MessageContentType.contactOptions,
        to: clientAddress,
      );
      send = MessageOptions.setDeviceToken(send, deviceToken);
      send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
      await _sendAndDisplay(send, send.content);
      logger.d("$TAG - sendContactOptionsToken - success - data:${send.content}");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendContactOptionsToken - fail - tryCount:$tryCount - clientAddress:$clientAddress - deviceToken:$deviceToken");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactOptionsToken(clientAddress, deviceToken, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceRequest(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      String data = MessageData.getDeviceRequest();
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendDeviceRequest - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendDeviceRequest - fail - tryCount:$tryCount - clientAddress:$clientAddress");
      await Future.delayed(Duration(seconds: 2), () {
        return sendDeviceRequest(clientAddress, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendDeviceInfo(String? clientAddress, {int tryCount = 1}) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      String data = MessageData.getDeviceInfo();
      await chatCommon.clientSendData(clientAddress, data);
      logger.d("$TAG - sendDeviceInfo - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendDeviceInfo - fail - tryCount:$tryCount - clientAddress:$clientAddress");
      await Future.delayed(Duration(seconds: 2), () {
        return sendDeviceInfo(clientAddress, tryCount: ++tryCount);
      });
    }
  }

  Future<MessageSchema?> sendText(String? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || content.isEmpty) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    MessageSchema message = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      MessageContentType.text,
      to: contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String data = MessageData.getText(message);
    return _sendAndDisplay(message, data);
  }

  Future<MessageSchema?> sendImage(File? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists())) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(contact?.clientAddress);
    String contentType = deviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    MessageSchema message = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      contentType,
      to: contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getImage(message);
    return _sendAndDisplay(message, data);
  }

  Future<MessageSchema?> sendAudio(File? content, double? durationS, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists())) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    MessageSchema message = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      MessageContentType.audio,
      to: contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      audioDurationS: durationS,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getAudio(message);
    return _sendAndDisplay(message, data);
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(MessageSchema message, {int tryCount = 1}) async {
    if (tryCount > 3) return null;
    try {
      DateTime timeNow = DateTime.now();
      await Future.delayed(Duration(milliseconds: (message.sendTime ?? timeNow).millisecondsSinceEpoch - timeNow.millisecondsSinceEpoch));
      String data = MessageData.getPiece(message);
      if (message.to?.isNotEmpty == true) {
        OnMessage? onResult = await chatCommon.clientSendData(message.to, data);
        message.pid = onResult?.messageId;
      } else {
        logger.w("$TAG - sendPiece - message target is empty - message:$message");
        return null;
      }
      // logger.d("$TAG - sendPiece - success - index:${schema.index} - total:${schema.total} - time:${timeNow.millisecondsSinceEpoch} - message:$message - data:$data");
      if (!message.isTopic) {
        double percent = (message.index ?? 0) / (message.total ?? 1);
        _onPieceOutSink.add({"msg_id": message.msgId, "percent": percent});
      }
      return message;
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendPiece - fail - tryCount:$tryCount - message:$message");
      return await Future.delayed(Duration(seconds: 2), () {
        return sendPiece(message, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic, {int tryCount = 1}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty || topic == null || topic.isEmpty) return;
    if (tryCount > 3) return;
    SessionSchema? _session = await sessionCommon.query(topic);
    SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(topic, clientCommon.address);
    bool msgDisplaySelf = (_session == null) || (_me?.status != SubscriberStatus.Subscribed);
    try {
      MessageSchema send = MessageSchema.fromSend(
        Uuid().v4(),
        clientCommon.address!,
        MessageContentType.topicSubscribe,
        topic: topic,
      );
      String data = MessageData.getTopicSubscribe(send);
      await _sendAndDisplay(send, data, displaySelf: msgDisplaySelf);
      logger.d("$TAG - sendTopicSubscribe - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendTopicSubscribe - fail - tryCount:$tryCount - topic:$topic");
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicSubscribe(topic, tryCount: ++tryCount);
      });
    }
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic, {int tryCount = 1}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty || topic == null || topic.isEmpty) return;
    if (tryCount > 3) return;
    try {
      String data = MessageData.getTopicUnSubscribe(topic);
      await chatCommon.clientPublishData(genTopicHash(topic), data); // its ok
      logger.d("$TAG - sendTopicUnSubscribe - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendTopicUnSubscribe - fail - tryCount:$tryCount - topic:$topic");
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicUnSubscribe(topic, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    MessageSchema message = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      MessageContentType.topicInvitation,
      to: clientAddress,
      content: topic,
    );
    String data = MessageData.getTopicInvitee(message);
    return _sendAndDisplay(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress, {int tryCount = 1}) async {
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    if (tryCount > 3) return;
    try {
      String data = MessageData.getTopicKickOut(topic, targetAddress);
      await chatCommon.clientPublishData(genTopicHash(topic), data); // its ok
      logger.d("$TAG - sendTopicKickOut - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendTopicKickOut - fail - tryCount:$tryCount - topic:$topic");
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
    message = chatCommon.updateMessageStatus(message, MessageStatus.Sending);
    String? msgData;
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        msgData = MessageData.getText(message);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.nknImage:
        msgData = await MessageData.getImage(message);
        break;
      case MessageContentType.audio:
        msgData = await MessageData.getAudio(message);
        break;
    }
    return await _sendAndDisplay(message, msgData, contact: contact, topic: topic, resend: true);
  }

  Future<MessageSchema?> _sendAndDisplay(
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
      message.sendTime = DateTime.now();
      _messageStorage.updateSendTime(message.msgId, message.sendTime); // await
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
      handleError(e);
    }
    // fail
    if (pid == null || pid.isEmpty) {
      logger.w("$TAG - _sendAndDisplay - pid = null - message:$message");
      message = chatCommon.updateMessageStatus(message, MessageStatus.SendFail, notify: true);
      return message;
    }
    // pid
    message.pid = pid;
    _messageStorage.updatePid(message.msgId, message.pid); // await
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
      logger.d("$TAG - _sendWithContact - to_contact - to:${message.to} - deviceInfo:$_deviceInfo");
      pid = (await chatCommon.clientSendData(message.to!, msgData))?.messageId;
    }
    // success
    if (pid?.isNotEmpty == true) {
      chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true);
      _sendPush(message, contact?.deviceToken); // await
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData) async {
    if (topic == null || message == null || msgData == null) return null;
    // me
    SubscriberSchema? _me = await chatCommon.subscriberHandle(message, topic);
    if (_me == null || (topic.isPrivate == true && (_me.status != SubscriberStatus.Subscribed))) {
      logger.w("$TAG - _sendWithTopic - subscriber me is wrong - me:$_me - message:$message");
      return null;
    }
    // subscribers
    List<SubscriberSchema> _subscribers = await subscriberCommon.queryListByTopic(topic.topic, status: SubscriberStatus.Subscribed);
    if (_subscribers.isEmpty) {
      logger.w("$TAG - _sendWithTopic - _subscribers is empty - topic:$topic - message:$message - msgData:$msgData");
      OnMessage? onResult = await chatCommon.clientPublishData(genTopicHash(message.topic!), msgData); // permission checked in received
      if (onResult?.messageId.isNotEmpty == true) {
        chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true);
      }
      return onResult?.messageId;
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
            chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true);
          }
          return Future.value(OnMessage(messageId: _pid!, data: null, src: null, type: null, encrypted: null));
        } else {
          logger.d("$TAG - _sendWithTopic - to_subscriber - to:${subscriber.clientAddress} - subscriber:$subscriber");
          int createBetween = DateTime.now().millisecondsSinceEpoch - (topic.createAt ?? DateTime.now().millisecondsSinceEpoch);
          if (message.contentType == MessageContentType.topicSubscribe && createBetween > 10 * 1000) {
            return deviceInfoCommon.queryLatest(subscriber.clientAddress).then((value) {
              bool enable = deviceInfoCommon.isMsgSubscribeFrequent(value?.platform, value?.appVersion);
              if (enable) {
                logger.i("$TAG - _sendWithTopic - send subscribe is enable - to:${subscriber.clientAddress} - subscriber:$subscriber");
                return chatCommon.clientSendData(subscriber.clientAddress, msgData).then((value) {
                  if ((value?.messageId.isNotEmpty == true) && (subscriber.clientAddress == clientCommon.address)) {
                    chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true);
                  }
                  return value;
                });
              } else {
                logger.i("$TAG - _sendWithTopic - send subscribe not enable - to:${subscriber.clientAddress} - subscriber:$subscriber");
                return Future.value(null);
              }
            });
          } else {
            return chatCommon.clientSendData(subscriber.clientAddress, msgData).then((value) {
              if ((value?.messageId.isNotEmpty == true) && (subscriber.clientAddress == clientCommon.address)) {
                chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, notify: true);
              }
              return value;
            });
          }
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

    // dataList.size = (total + parity)
    List<Object?> dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty) return null;

    List<Future<MessageSchema?>> futures = <Future<MessageSchema?>>[];
    DateTime dataNow = DateTime.now();
    for (int index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      MessageSchema send = MessageSchema.fromSend(
        message.msgId,
        message.from,
        MessageContentType.piece,
        to: to ?? message.to,
        topic: message.topic,
        content: base64Encode(data),
        options: message.options,
        parentType: message.contentType,
        bytesLength: bytesLength,
        total: total,
        parity: parity,
        index: index,
      );
      send.sendTime = dataNow.add(Duration(milliseconds: index * 50)); // wait 50ms
      futures.add(sendPiece(send));
    }
    logger.d("$TAG - _sendByPiecesIfNeed:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema?> returnList = await Future.wait(futures);
    returnList.sort((prev, next) => (prev?.index ?? maxPiecesTotal).compareTo((next?.index ?? maxPiecesTotal)));

    List<MessageSchema?> successList = returnList.where((element) => element != null).toList();
    if (successList.length < total) {
      logger.w("$TAG - _sendByPiecesIfNeed:FAIL - count:${successList.length}");
      return null;
    }
    logger.d("$TAG - _sendByPiecesIfNeed:SUCCESS - count:${successList.length}");

    MessageSchema? firstSuccess = returnList.firstWhere((element) => element?.pid != null);
    return firstSuccess?.pid;
  }

  Future<List<dynamic>> _convert2Pieces(MessageSchema message) async {
    if (!(message.content is File?)) return [];
    File? file = message.content as File?;
    if (file == null || !file.existsSync()) return [];
    int length = await file.length();
    if (length <= prePieceLength) return [];
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    // bytesLength
    int bytesLength = base64Data.length;
    if (bytesLength < prePieceLength * minPiecesTotal) return [];
    // total (5~257)
    int total;
    if (bytesLength < prePieceLength * maxPiecesTotal) {
      total = bytesLength ~/ prePieceLength;
      if (bytesLength % prePieceLength > 0) {
        total += 1;
      }
    } else {
      total = maxPiecesTotal;
    }
    // parity(>=2)
    int parity = total ~/ piecesParity;
    if (parity <= minPiecesTotal ~/ piecesParity) {
      parity = minPiecesTotal ~/ piecesParity;
    }
    return [base64Data, bytesLength, total, parity];
  }

  _sendPush(MessageSchema message, String? deviceToken) async {
    if (!message.canDisplayAndRead) return;
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
    //   case ContentType.text:
    //   case ContentType.textExtension:
    //     content = message.content;
    //     break;
    //   case ContentType.media:
    //   case ContentType.image:
    //   case ContentType.nknImage:
    //     content = '[${localizations.image}]';
    //     break;
    //   case ContentType.audio:
    //     content = '[${localizations.audio}]';
    //     break;
    //   case ContentType.topicSubscribe:
    //   case ContentType.topicUnsubscribe:
    //   case ContentType.topicInvitation:
    //     break;
    // }

    await SendPush.send(deviceToken, title, content);
  }
}
