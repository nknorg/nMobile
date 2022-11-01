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
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // queue
  ParallelQueue _sendQueue = ParallelQueue("chat_send", onLog: (log, error) => error ? logger.w(log) : null);
  ParallelQueue _resendQueue = ParallelQueue("chat_resend", onLog: (log, error) => error ? logger.w(log) : null);

  ChatOutCommon();

  void clear() {}

  Future<OnMessage?> sendData(String? selfAddress, List<String> destList, String data, {int tryTimes = 0, int maxTryTimes = 10}) async {
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.e("$TAG - sendData - destList is empty - destList:$destList - data:$data");
      return null;
    }
    if (data.length >= MessageSchema.msgMaxSize) {
      logger.w("$TAG - sendData - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
      // Sentry.captureMessage("$TAG - sendData - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
      // return null;
    }
    if (tryTimes >= maxTryTimes) {
      logger.w("$TAG - sendData - try over - destList:$destList - data:$data");
      return null;
    }
    if (!clientCommon.isClientCreated || clientCommon.clientClosing || (selfAddress != clientCommon.address)) {
      logger.w("$TAG - sendData - client error - closing:${clientCommon.clientClosing} - tryTimes:$tryTimes - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 2));
      return sendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
    }
    return await _sendQueue.add(() => _clientSendData(selfAddress, destList, data));
  }

  Future<OnMessage?> _clientSendData(String? selfAddress, List<String> destList, String data, {int tryTimes = 0, int maxTryTimes = 5}) async {
    if (tryTimes >= maxTryTimes) {
      logger.w("$TAG - _clientSendData - try over - destList:$destList - data:$data");
      return null;
    }
    if (!clientCommon.isClientCreated || clientCommon.clientClosing || (selfAddress != clientCommon.address)) {
      logger.w("$TAG - _clientSendData - client error - closing:${clientCommon.clientClosing} - tryTimes:$tryTimes - destList:$destList - data:$data");
      await Future.delayed(Duration(seconds: 1));
      return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
    }
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.d("$TAG - _clientSendData - send success - destList:$destList - data:$data");
        return onMessage;
      } else {
        logger.e("$TAG - _clientSendData - onMessage msgId is empty - tryTimes:$tryTimes - destList:$destList - data:$data");
        await Future.delayed(Duration(milliseconds: 100));
        return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
      }
    } catch (e, st) {
      String errStr = e.toString().toLowerCase();
      if (errStr.contains(NknError.invalidDestination)) {
        logger.e("$TAG - _clientSendData - wrong clientAddress - destList:$destList");
        return null;
      } else if (errStr.contains(NknError.messageOversize)) {
        logger.e("$TAG - _clientSendData - message over size - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
        Sentry.captureMessage("$TAG - _clientSendData - message over size - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
        return null;
      }
      if ((maxTryTimes - tryTimes) <= 1) handleError(e, st);
      bool isClientError = NknError.isClientError(e);
      bool isLastTryTime = (maxTryTimes - tryTimes) <= 2;
      if (isClientError || isLastTryTime) {
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
            logger.e("$TAG - _clientSendData - reSignIn fail - wallet:${await walletCommon.getDefault()}");
            return null;
          }
        }
      } else {
        logger.e("$TAG - _clientSendData - try by error - tryTimes:$tryTimes - destList:$destList - data:$data");
        await Future.delayed(Duration(milliseconds: 100));
        return _clientSendData(selfAddress, destList, data, tryTimes: ++tryTimes, maxTryTimes: maxTryTimes);
      }
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendPing(List<String> clientAddressList, bool isPing) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddressList.isEmpty) return;
    bool isSelf = (clientAddressList.length == 1) && (clientAddressList[0] == clientCommon.address);
    ContactSchema? _me = await contactCommon.getMe();
    String? profileVersion = isSelf ? null : _me?.profileVersion;
    String? deviceProfile = isSelf ? null : deviceInfoCommon.getDeviceProfile();
    String? deviceToken;
    if (!isSelf && (clientAddressList.length == 1)) {
      ContactSchema? _other = await contactCommon.queryByClientAddress(clientAddressList[0]);
      deviceToken = (_other?.options?.notificationOpen == true) ? _me?.deviceToken : null;
    }
    String data = MessageData.getPing(isPing, profileVersion, deviceProfile, deviceToken);
    await _sendWithAddressSafe(clientAddressList, data, notification: false);
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendReceipt(MessageSchema received) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (received.from.isEmpty || (received.isTopic || received.isPrivateGroup)) return; // topic/group no receipt, just send message to myself
    received = (await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
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
    String data = MessageData.getContactProfileRequest(requestType, profileVersion);
    await _sendWithAddressSafe([clientAddress], data, notification: false);
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(String? clientAddress, String requestType, {ContactSchema? me}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    ContactSchema? _me = me ?? await contactCommon.getMe();
    String data;
    if (requestType == RequestType.header) {
      data = MessageData.getContactProfileResponseHeader(_me?.profileVersion);
    } else {
      data = await MessageData.getContactProfileResponseFull(_me?.profileVersion, _me?.avatar, _me?.firstName, _me?.lastName);
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
      to: clientAddress,
      contentType: MessageContentType.contactOptions,
      extra: {
        "deleteAfterSeconds": deleteSeconds,
        "burningUpdateAt": updateAt,
      },
    );
    send.content = MessageData.getContactOptionsBurn(send); // same with receive and old version
    await _send(send, send.content);
  }

  // NO topic (1 to 1)
  Future sendContactOptionsToken(String? clientAddress, String? deviceToken) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: clientAddress,
      contentType: MessageContentType.contactOptions,
      extra: {
        "deviceToken": deviceToken,
      },
    );
    send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
    await _send(send, send.content);
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

  Future<MessageSchema?> sendText(dynamic target, String? content) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || content.trim().isEmpty) return null;
    ContactSchema? _me = await contactCommon.getMe();
    // target
    String targetAddress = "";
    String targetTopic = "";
    String groupId = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    bool notificationOpen = false;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
      notificationOpen = target.options?.notificationOpen ?? false;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && groupId.isEmpty && targetTopic.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: targetAddress,
      topic: targetTopic,
      groupId: groupId,
      contentType: ((deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text,
      content: content,
      extra: {
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "profileVersion": _me?.profileVersion,
        "deviceProfile": deviceInfoCommon.getDeviceProfile(),
        "deviceToken": notificationOpen ? _me?.deviceToken : null,
        "privateGroupVersion": privateGroupVersion,
      },
    );
    // data
    String data = MessageData.getText(message);
    return _send(message, data);
  }

  Future<MessageSchema?> saveIpfs(dynamic target, Map<String, dynamic> data) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    ContactSchema? _me = await contactCommon.getMe();
    // content
    String contentPath = data["path"]?.toString() ?? "";
    File? content = contentPath.isEmpty ? null : File(contentPath);
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) {
      return null;
    }
    // target
    String targetAddress = "";
    String targetTopic = "";
    String groupId = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    bool notificationOpen = false;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
      notificationOpen = target.options?.notificationOpen ?? false;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && groupId.isEmpty && targetTopic.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: targetAddress,
      topic: targetTopic,
      groupId: groupId,
      contentType: MessageContentType.ipfs,
      content: content,
      extra: data
        ..addAll({
          "deleteAfterSeconds": deleteAfterSeconds,
          "burningUpdateAt": burningUpdateAt,
          "profileVersion": _me?.profileVersion,
          "deviceProfile": deviceInfoCommon.getDeviceProfile(),
          "deviceToken": notificationOpen ? _me?.deviceToken : null,
          "privateGroupVersion": privateGroupVersion,
        }),
    );
    // insert
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
    }
    MessageSchema? inserted = await insertMessage(message);
    if (inserted == null) return null;
    // ipfs
    chatCommon.startIpfsUpload(inserted.msgId); // await
    return inserted;
  }

  Future<MessageSchema?> sendIpfs(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    // schema
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    // data
    String? data = MessageData.getIpfs(message);
    return _send(message, data, insert: false);
  }

  Future<MessageSchema?> sendImage(dynamic target, File? content) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    ContactSchema? _me = await contactCommon.getMe();
    // target
    String targetAddress = "";
    String targetTopic = "";
    String groupId = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    bool notificationOpen = false;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
      notificationOpen = target.options?.notificationOpen ?? false;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && groupId.isEmpty && targetTopic.isEmpty) return null;
    // contentType
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(targetAddress);
    String contentType = DeviceInfoCommon.isMsgImageEnable(deviceInfo?.platform, deviceInfo?.appVersion) ? MessageContentType.image : MessageContentType.media;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: targetAddress,
      topic: targetTopic,
      groupId: groupId,
      contentType: contentType,
      content: content,
      extra: {
        "fileType": MessageOptions.fileTypeImage,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_IMAGE_EXT),
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "profileVersion": _me?.profileVersion,
        "deviceProfile": deviceInfoCommon.getDeviceProfile(),
        "deviceToken": notificationOpen ? _me?.deviceToken : null,
        "privateGroupVersion": privateGroupVersion,
      },
    );
    // data
    String? data = await MessageData.getImage(message);
    return _send(message, data);
  }

  Future<MessageSchema?> sendAudio(dynamic target, File? content, double? durationS) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    ContactSchema? _me = await contactCommon.getMe();
    // target
    String targetAddress = "";
    String groupId = "";
    String targetTopic = "";
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    bool notificationOpen = false;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
      notificationOpen = target.options?.notificationOpen ?? false;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && groupId.isEmpty && targetTopic.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: targetAddress,
      topic: targetTopic,
      groupId: groupId,
      contentType: MessageContentType.audio,
      content: content,
      extra: {
        "fileType": MessageOptions.fileTypeAudio,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_AUDIO_EXT),
        "audioDurationS": durationS,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "profileVersion": _me?.profileVersion,
        "deviceProfile": deviceInfoCommon.getDeviceProfile(),
        "deviceToken": notificationOpen ? _me?.deviceToken : null,
        "privateGroupVersion": privateGroupVersion,
      },
    );
    // data
    String? data = await MessageData.getAudio(message);
    return _send(message, data);
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    int timeNowAt = DateTime.now().millisecondsSinceEpoch;
    await Future.delayed(Duration(milliseconds: (message.sendAt ?? timeNowAt) - timeNowAt));
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendData(clientCommon.address, clientAddressList, data);
    if ((onResult == null) || onResult.messageId.isEmpty) return null;
    message.pid = onResult.messageId;
    // progress
    if (percent > 0 && percent <= 1) {
      if (percent <= 1.05) {
        // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        chatCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    } else {
      int? total = message.options?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE_INDEX];
      double percent = (index ?? 0) / (total ?? 1);
      if (percent <= 1.05) {
        // logger.v("$TAG - sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        chatCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
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
      topic: topic,
      contentType: MessageContentType.topicSubscribe,
    );
    String data = MessageData.getTopicSubscribe(send);
    await _send(send, data);
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      topic: topic,
      contentType: MessageContentType.topicUnsubscribe,
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
      to: clientAddress,
      contentType: MessageContentType.topicInvitation,
      content: topic,
    );
    String data = MessageData.getTopicInvitee(message);
    return _send(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      topic: topic,
      contentType: MessageContentType.topicKickOut,
      content: targetAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicKickOut(send);
    await _sendWithTopicSafe(_schema, send, data, notification: false);
  }

  // NO group (1 to 1)
  Future<MessageSchema?> sendPrivateGroupInvitee(String? target, PrivateGroupSchema? privateGroup, PrivateGroupItemSchema? groupItem) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (privateGroup == null || groupItem == null) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: target,
      contentType: MessageContentType.privateGroupInvitation,
      content: {
        'groupId': privateGroup.groupId,
        'name': privateGroup.name,
        'type': privateGroup.type,
        'version': privateGroup.version,
        'item': {
          'groupId': privateGroup.groupId,
          'permission': groupItem.permission,
          'expiresAt': groupItem.expiresAt,
          'invitee': groupItem.invitee,
          'inviter': groupItem.inviter,
          'inviterRawData': groupItem.inviterRawData,
          'inviterSignature': groupItem.inviterSignature,
        },
      },
    );
    String data = MessageData.getPrivateGroupInvitation(message);
    return await _send(message, data);
  }

  // NO group (1 to 1)
  Future sendPrivateGroupAccept(String? target, PrivateGroupItemSchema? groupItem) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (groupItem == null) return null;
    String data = MessageData.getPrivateGroupAccept(groupItem);
    await _sendWithAddressSafe([target], data, notification: false);
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupOptionRequest(String? target, String? groupId) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    List<String> splits = group.version?.split(".") ?? [];
    int commits = splits.length >= 2 ? (int.tryParse(splits[0]) ?? 0) : 0;
    List<String> memberKeys = privateGroupCommon.getInviteesKey(await privateGroupCommon.getMembersAll(groupId));
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, memberKeys);
    String data = MessageData.getPrivateGroupOptionRequest(groupId, getVersion);
    await _sendWithAddressSafe([target], data, notification: false);
    return getVersion;
  }

  // NO group (1 to 1)
  Future sendPrivateGroupOptionResponse(String? target, PrivateGroupSchema? group) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (group == null) return null;
    String data = MessageData.getPrivateGroupOptionResponse(group);
    await _sendWithAddressSafe([target], data, notification: false);
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupMemberRequest(String? target, String? groupId) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    List<String> splits = group.version?.split(".") ?? [];
    int commits = splits.length >= 2 ? (int.tryParse(splits[0]) ?? 0) : 0;
    List<String> memberKeys = privateGroupCommon.getInviteesKey(await privateGroupCommon.getMembersAll(groupId));
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, memberKeys);
    String data = MessageData.getPrivateGroupMemberRequest(groupId, getVersion);
    await _sendWithAddressSafe([target], data, notification: false);
    return getVersion;
  }

  // NO group (1 to 1)
  Future sendPrivateGroupMemberResponse(String? target, PrivateGroupSchema? schema, List<PrivateGroupItemSchema> members) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (schema == null) return null;
    List<Map<String, dynamic>> membersData = privateGroupCommon.getMembersData(members);
    String data = MessageData.getPrivateGroupMemberResponse(schema, membersData);
    await _sendWithAddressSafe([target], data);
  }

  Future<MessageSchema?> resend(MessageSchema? message) async {
    if (message == null) return null;
    message = await chatCommon.updateMessageStatus(message, MessageStatus.Sending, force: true, notify: true);
    await MessageStorage.instance.updateSendAt(message.msgId, message.sendAt);
    message.sendAt = DateTime.now().millisecondsSinceEpoch;
    // send
    Function func = () async {
      if (message == null) return null;
      if (message.contentType == MessageContentType.ipfs) {
        if (MessageOptions.getIpfsState(message.options) == MessageOptions.ipfsStateYes) {
          return await chatOutCommon.sendIpfs(message.msgId);
        } else {
          return await chatCommon.startIpfsUpload(message.msgId);
        }
      }
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
      return await _send(message, msgData, insert: false);
    };
    return await _resendQueue.add(() async {
      try {
        return await func();
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    }, id: message.msgId);
  }

  Future<MessageSchema?> resendMute(MessageSchema? message, {bool? notification}) async {
    if (message == null) return null;
    Function func = () async {
      // msgData
      String? msgData;
      switch (message.contentType) {
        case MessageContentType.text:
        case MessageContentType.textExtension:
          msgData = MessageData.getText(message);
          logger.i("$TAG - resendMute - resend text - targetId:${message.targetId} - msgData:$msgData");
          break;
        case MessageContentType.ipfs:
          msgData = MessageData.getIpfs(message);
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
          logger.i("$TAG - resendMute - resend topic invitee - targetId:${message.targetId} - msgData:$msgData");
          break;
        case MessageContentType.privateGroupInvitation:
          msgData = MessageData.getPrivateGroupInvitation(message);
          logger.i("$TAG - resendMute - resend group invitee - targetId:${message.targetId} - msgData:$msgData");
          break;
        default:
          logger.i("$TAG - resendMute - noReceipt not receipt/read - targetId:${message.targetId} - message:$message");
          int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          return await chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
      }
      // send
      int msgSendAt = (message.sendAt ?? DateTime.now().millisecondsSinceEpoch);
      int between = DateTime.now().millisecondsSinceEpoch - msgSendAt;
      notification = (notification != null) ? notification : (between > (60 * 60 * 1000)); // 1h
      notification = false; // FIXED:GG notification duplicated
      return await _send(message, msgData, insert: false, sessionSync: false, statusSync: false, notification: notification);
    };
    return await _resendQueue.add(() async {
      try {
        return await func();
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    }, id: message.msgId);
  }

  Future<MessageSchema?> insertMessage(MessageSchema? message, {bool notify = true}) async {
    if (message == null) return null;
    message = await MessageStorage.instance.insert(message); // DB
    if (message == null) return null;
    if (notify) _onSavedSink.add(message); // display, resend just update sendTime
    return message;
  }

  Future<MessageSchema?> _send(
    MessageSchema? message,
    String? msgData, {
    bool insert = true,
    bool sessionSync = true,
    bool statusSync = true,
    bool? notification,
  }) async {
    if (message == null || msgData == null) return null;
    if (insert) message = await insertMessage(message);
    if (message == null) return null;
    // session
    if (sessionSync) await chatCommon.sessionHandle(message);
    // sdk
    Uint8List? pid;
    if (message.isTopic) {
      TopicSchema? topic = await chatCommon.topicHandle(message);
      pid = await _sendWithTopicSafe(topic, message, msgData, notification: notification ?? message.canNotification);
      logger.d("$TAG - _send - with_topic - to:${message.topic} - pid:$pid");
    } else if (message.isPrivateGroup) {
      PrivateGroupSchema? group = await chatCommon.privateGroupHandle(message);
      pid = await _sendWithPrivateGroupSafe(group, message, msgData, notification: notification ?? message.canNotification);
      logger.d("$TAG - _send - with_group - to:${message.topic} - pid:$pid");
    } else if (message.to.isNotEmpty == true) {
      ContactSchema? contact = await chatCommon.contactHandle(message);
      pid = await _sendWithContactSafe(contact, message, msgData, notification: notification ?? message.canNotification);
      logger.d("$TAG - _send - with_contact - to:${message.to} - pid:$pid");
    }
    // pid
    if (pid?.isNotEmpty == true) {
      message.pid = pid;
      MessageStorage.instance.updatePid(message.msgId, message.pid); // await
    } else {
      logger.w("$TAG - _send - pid is null - message:$message");
    }
    // status
    if (statusSync) {
      if (pid?.isNotEmpty == true) {
        if (!message.canReceipt) {
          // no received receipt/read
          int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt); // await
        } else {
          chatCommon.updateMessageStatus(message, MessageStatus.SendSuccess, reQuery: true, notify: true); // await
        }
      } else {
        logger.w("$TAG - _send - pid = null - message:$message");
        if (message.canResend) {
          message = await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
        } else {
          // noResend just delete
          int count = await MessageStorage.instance.deleteByIdContentType(message.msgId, message.contentType);
          if (count > 0) chatCommon.onDeleteSink.add(message.msgId);
          return null;
        }
      }
    }
    return message;
  }

  Future<Uint8List?> _sendWithAddressSafe(List<String> clientAddressList, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithAddress(clientAddressList, msgData, notification: notification);
    } catch (e, st) {
      handleError(e, st);
      return null;
    }
  }

  Future<Uint8List?> _sendWithContactSafe(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithContact(contact, message, msgData, notification: notification);
    } catch (e, st) {
      handleError(e, st);
      return null;
    }
  }

  Future<Uint8List?> _sendWithTopicSafe(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithTopic(topic, message, msgData, notification: notification);
    } catch (e, st) {
      handleError(e, st);
      return null;
    }
  }

  Future<Uint8List?> _sendWithPrivateGroupSafe(PrivateGroupSchema? group, MessageSchema? message, String? msgData, {bool notification = false}) async {
    try {
      return _sendWithPrivateGroup(group, message, msgData, notification: notification);
    } catch (e, st) {
      handleError(e, st);
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
            if (!_contact.isMe) _sendPush(_contact.deviceToken);
          }
        });
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (message == null || msgData == null) return null;
    logger.d("$TAG - _sendWithContact - contact:$contact - message:$message - msgData:$msgData");
    // send
    Uint8List? pid;
    if (message.canTryPiece) {
      pid = await _sendByPieces([message.to], message);
    }
    if ((pid == null) || pid.isEmpty) {
      pid = (await sendData(clientCommon.address, [message.to], msgData))?.messageId;
    }
    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        if (contact != null && !contact.isMe) {
          String uuid = _sendPush(contact.deviceToken);
          message.options = MessageOptions.setPushNotifyId(message.options, uuid);
          MessageStorage.instance.updateOptions(message.msgId, message.options); // await
        }
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (topic == null || message == null || msgData == null) return null;
    String? selfAddress = clientCommon.address;
    if (selfAddress == null || selfAddress.isEmpty) return null;
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
    List<String> destList = [];
    for (var i = 0; i < _subscribers.length; i++) {
      String clientAddress = _subscribers[i].clientAddress;
      if (clientAddress == selfAddress) {
        selfIsReceiver = true;
      } else {
        destList.add(clientAddress);
      }
    }
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      if (message.canTryPiece) {
        pid = await _sendByPieces(destList, message);
      }
      if ((pid == null) || pid.isEmpty) {
        pid = (await sendData(selfAddress, destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId, DateTime.now().millisecondsSinceEpoch);
      Uint8List? _pid = (await sendData(selfAddress, [selfAddress], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
          for (var i = 0; i < contactList.length; i++) {
            ContactSchema _contact = contactList[i];
            if (!_contact.isMe) _sendPush(_contact.deviceToken);
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

  Future<Uint8List?> _sendWithPrivateGroup(PrivateGroupSchema? group, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (group == null || message == null || msgData == null) return null;
    String? selfAddress = clientCommon.address;
    if (selfAddress == null || selfAddress.isEmpty) return null;
    // me
    PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(group.groupId, selfAddress);
    if ((_me == null) || ((_me.permission ?? 0) <= PrivateGroupItemPerm.none)) {
      logger.w("$TAG - _sendWithPrivateGroup - member me is null - me:$_me - group:$group - message:$message");
      return null;
    }
    // destList
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(message.groupId);
    bool selfIsReceiver = false;
    List<String> destList = [];
    for (var i = 0; i < members.length; i++) {
      String? clientAddress = members[i].invitee;
      if (clientAddress == null || clientAddress.isEmpty) continue;
      if (clientAddress == selfAddress) {
        selfIsReceiver = true;
      } else if ((members[i].permission ?? 0) > PrivateGroupItemPerm.none) {
        destList.add(clientAddress);
      }
    }
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      if (message.canTryPiece) {
        pid = await _sendByPieces(destList, message);
      }
      if ((pid == null) || pid.isEmpty) {
        pid = (await sendData(selfAddress, destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId, DateTime.now().millisecondsSinceEpoch);
      Uint8List? _pid = (await sendData(selfAddress, [selfAddress], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    // push
    if (pid?.isNotEmpty == true) {
      if (notification) {
        contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
          for (var i = 0; i < contactList.length; i++) {
            ContactSchema _contact = contactList[i];
            if (!_contact.isMe) _sendPush(_contact.deviceToken);
          }
        });
      }
    }
    return pid;
  }

  Future<Uint8List?> _sendByPieces(List<String> clientAddressList, MessageSchema message, {double totalPercent = -1}) async {
    Map<String, dynamic> results = await MessageSchema.piecesSplits(message);
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
        groupId: message.groupId, // need
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

  String _sendPush(String? deviceToken) {
    if (deviceToken == null || deviceToken.isEmpty == true) return "";

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

    String uuid = Uuid().v4();
    SendPush.send(uuid, deviceToken, title, content); // await
    return uuid;
  }
}
