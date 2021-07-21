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
    if (received.from.isEmpty || received.isTopic) return;
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
    if (clientCommon.address == null || clientCommon.address!.isEmpty || target == null || target.clientAddress.isEmpty) return;
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
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      MessageContentType.text,
      to: contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String data = MessageData.getText(schema);
    return _sendAndDisplay(schema, data);
  }

  Future<MessageSchema?> sendImage(File? content, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists())) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(contact?.id);
    String contentType = deviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      contentType,
      to: contact?.clientAddress,
      topic: topic?.topic,
      content: content,
      deleteAfterSeconds: contact?.options?.deleteAfterSeconds,
      burningUpdateAt: contact?.options?.updateBurnAfterAt,
    );
    String? data = await MessageData.getImage(schema);
    return _sendAndDisplay(schema, data, deviceInfo: deviceInfo);
  }

  Future<MessageSchema?> sendAudio(File? content, double? durationS, {ContactSchema? contact, TopicSchema? topic}) async {
    if ((contact?.clientAddress == null || contact?.clientAddress.isEmpty == true) && (topic?.topic == null || topic?.topic.isEmpty == true)) return null;
    if (content == null || (!await content.exists())) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    MessageSchema schema = MessageSchema.fromSend(
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
    String? data = await MessageData.getAudio(schema);
    return _sendAndDisplay(schema, data);
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(MessageSchema schema, {int tryCount = 1}) async {
    if (tryCount > 3) return null;
    try {
      DateTime timeNow = DateTime.now();
      await Future.delayed(Duration(milliseconds: (schema.sendTime ?? timeNow).millisecondsSinceEpoch - timeNow.millisecondsSinceEpoch));
      String data = MessageData.getPiece(schema);
      if (schema.isTopic) {
        OnMessage? onResult = await chatCommon.clientPublishData(genTopicHash(schema.topic!), data);
        schema.pid = onResult?.messageId;
      } else if (schema.to != null) {
        OnMessage? onResult = await chatCommon.clientSendData(schema.to, data);
        schema.pid = onResult?.messageId;
      }
      // logger.d("$TAG - sendPiece - success - index:${schema.index} - total:${schema.total} - time:${timeNow.millisecondsSinceEpoch} - schema:$schema - data:$data");
      double percent = (schema.index ?? 0) / (schema.total ?? 1);
      _onPieceOutSink.add({"msg_id": schema.msgId, "percent": percent});
      return schema;
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendPiece - fail - tryCount:$tryCount - schema:$schema");
      return await Future.delayed(Duration(seconds: 2), () {
        return sendPiece(schema, tryCount: ++tryCount);
      });
    }
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topicName) async {
    if (clientAddress == null || clientAddress.isEmpty || topicName == null || topicName.isEmpty) return null;
    if (clientCommon.status != ClientConnectStatus.connected || clientCommon.address == null || clientCommon.address!.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure); // TODO:GG locale
      return null;
    }
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
      clientCommon.address!,
      MessageContentType.topicInvitation,
      to: clientAddress,
      content: topicName,
    );
    String data = MessageData.getTopicInvitee(schema, topicName);
    return _sendAndDisplay(schema, data);
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic, {int tryCount = 1}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty || topic == null || topic.isEmpty) return;
    if (tryCount > 3) return;
    try {
      MessageSchema send = MessageSchema.fromSend(
        Uuid().v4(),
        clientCommon.address!,
        MessageContentType.topicSubscribe,
        topic: topic,
      );
      String data = MessageData.getTopicSubscribe(send);
      await _sendAndDisplay(send, data);
      // await chatCommon.clientPublishData(genTopicHash(send.topic!), data);
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
      MessageSchema send = MessageSchema.fromSend(
        Uuid().v4(),
        clientCommon.address!,
        MessageContentType.topicUnsubscribe,
        topic: topic,
      );
      String data = MessageData.getTopicUnSubscribe(send);
      await _sendAndDisplay(send, data);
      // await chatCommon.clientPublishData(genTopicHash(send.topic!), data);
      logger.d("$TAG - sendTopicUnSubscribe - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendTopicUnSubscribe - fail - tryCount:$tryCount - topic:$topic");
      await Future.delayed(Duration(seconds: 2), () {
        return sendTopicUnSubscribe(topic, tryCount: ++tryCount);
      });
    }
  }

  Future<MessageSchema?> resend(
    MessageSchema? schema, {
    ContactSchema? contact,
    DeviceInfoSchema? deviceInfo,
    TopicSchema? topic,
  }) async {
    if (schema == null) return null;
    schema = chatCommon.updateMessageStatus(schema, MessageStatus.Sending);
    switch (schema.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        return await _sendAndDisplay(
          schema,
          MessageData.getText(schema),
          contact: contact,
          topic: topic,
          deviceInfo: deviceInfo,
          resend: true,
        );
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.nknImage:
        return await _sendAndDisplay(
          schema,
          await MessageData.getImage(schema),
          contact: contact,
          topic: topic,
          deviceInfo: deviceInfo,
          resend: true,
        );
      case MessageContentType.audio:
        return await _sendAndDisplay(
          schema,
          await MessageData.getAudio(schema),
          contact: contact,
          topic: topic,
          deviceInfo: deviceInfo,
          resend: true,
        );
    }
    return schema;
  }

  Future<MessageSchema?> _sendAndDisplay(
    MessageSchema? schema,
    String? msgData, {
    ContactSchema? contact,
    DeviceInfoSchema? deviceInfo,
    TopicSchema? topic,
    bool resend = false,
  }) async {
    if (schema == null || msgData == null) return null;
    // DB
    if (!resend) {
      schema = await _messageStorage.insert(schema);
    } else {
      schema.sendTime = DateTime.now();
      _messageStorage.updateSendTime(schema.msgId, schema.sendTime); // await
    }
    if (schema == null) return null;
    // display
    _onSavedSink.add(schema); // resend already delete fail item in listview
    // contact
    ContactSchema? _contact = contact ?? await chatCommon.contactHandle(schema);
    DeviceInfoSchema? _deviceInfo = deviceInfo ?? await chatCommon.deviceInfoHandle(schema, _contact);
    // topic
    TopicSchema? _topic = topic ?? await chatCommon.topicHandle(schema);
    chatCommon.subscriberHandle(schema); // await
    // session
    chatCommon.sessionHandle(schema); // await
    // SDK
    Uint8List? pid;
    try {
      pid = await _sendByPiecesIfNeed(schema, _deviceInfo);
      if (pid == null || pid.isEmpty) {
        if (schema.isTopic) {
          OnMessage? onResult = await chatCommon.clientPublishData(genTopicHash(schema.topic!), msgData);
          pid = onResult?.messageId;
          logger.d("$TAG - _send - topic:${schema.topic} - pid:$pid");
        } else if (schema.to?.isNotEmpty == true) {
          OnMessage? onResult = await chatCommon.clientSendData(schema.to!, msgData);
          pid = onResult?.messageId;
          logger.d("$TAG - _send - user:${schema.to} - pid:$pid");
        } else {
          logger.e("$TAG - _send - null");
        }
      } else {
        logger.d("$TAG - _send - pieces:$_deviceInfo - pid:$pid");
      }
    } catch (e) {
      handleError(e);
    }
    // fail
    if (pid == null || pid.isEmpty) {
      schema = chatCommon.updateMessageStatus(schema, MessageStatus.SendFail, notify: true);
      return schema;
    }
    // pid
    schema.pid = pid;
    _messageStorage.updatePid(schema.msgId, schema.pid); // await
    // status
    schema = chatCommon.updateMessageStatus(schema, MessageStatus.SendSuccess, notify: true);
    // notification
    _sendPush(schema, _contact, _topic); // await
    return schema;
  }

  _sendPush(MessageSchema message, ContactSchema? contact, TopicSchema? topic) async {
    if (!message.canDisplayAndRead) return;
    if (topic != null) {
      // TODO:GG topic get all subscribe token and list.send
      return;
    }
    if (contact?.deviceToken == null || contact!.deviceToken!.isEmpty) return;

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
    //   case ContentType.topicInvitation:
    //   case ContentType.topicSubscribe:
    //   case ContentType.topicUnsubscribe:
    //     break;
    // }

    await SendPush.send(contact.deviceToken!, title, content);
  }

  // TODO:GG topic ???
  Future<Uint8List?> _sendByPiecesIfNeed(MessageSchema message, DeviceInfoSchema? deviceInfo) async {
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
        to: message.to,
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
}
