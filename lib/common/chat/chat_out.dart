import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/remote_notification.dart';
import 'package:nmobile/common/settings.dart';
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
import 'package:uuid/uuid.dart';

class ChatOutCommon with Tag {
  ChatOutCommon();

  ParallelQueue _sendQueue = ParallelQueue("chat_send", onLog: (log, error) => error ? logger.w(log) : null);

  Future start({bool reset = true}) async {
    logger.i("$TAG - start - reset:$reset");
    _sendQueue.restart(clear: reset);
  }

  Future stop({bool reset = true}) async {
    logger.i("$TAG - stop - reset:$reset");
    _sendQueue.stop();
  }

  Future<OnMessage?> sendMsg(List<String> destList, String data) async {
    // logger.v("$TAG - sendMsg - send start - destList:$destList - data:$data");
    // dest
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.e("$TAG - sendMsg - destList is empty - data:$data");
      return null;
    }
    // size
    if (data.length >= Settings.sizeMsgMax) {
      logger.w("$TAG - sendMsg - size over - count:${destList.length} - size:${Format.flowSize(data.length.toDouble(), unitArr: [
            'B',
            'KB',
            'MB',
            'GB'
          ])} - destList:$destList - data:$data");
      // Sentry.captureMessage("$TAG - sendData - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
      // return null;
    }
    // send
    return await _sendQueue.add(() async {
      OnMessage? onMessage;
      int tryTimes = 0;
      while (tryTimes < Settings.tryTimesMsgSend) {
        List<dynamic> result = await _sendData(destList, data);
        onMessage = result[0];
        bool canTry = result[1];
        int delay = result[2];
        if (onMessage?.messageId.isNotEmpty == true) break;
        if (!canTry) break;
        tryTimes++;
        await Future.delayed(Duration(milliseconds: delay));
      }
      if (tryTimes >= Settings.tryTimesMsgSend) {
        logger.w("$TAG - sendMsg - try over - count:${destList.length} - destList:$destList - data:$data");
      }
      return onMessage;
    });
  }

  Future<List<dynamic>> _sendData(List<String> destList, String data) async {
    if (!(await _waitClientOk())) return [null, true, 100];
    // logger.v("$TAG - _sendData - send start - destList:$destList - data:$data");
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.v("$TAG - _sendData - send success - count:${destList.length} - destList:$destList - data:$data");
      } else {
        logger.e("$TAG - _sendData - pid is empty - count:${destList.length} - destList:$destList - data:$data");
      }
      return [onMessage, true, 100];
    } catch (e, st) {
      String errStr = e.toString().toLowerCase();
      if (errStr.contains(NknError.invalidDestination)) {
        logger.e("$TAG - _sendData - wrong clientAddress - count:${destList.length} - destList:$destList");
        return [null, false, 0];
      } else if (errStr.contains(NknError.messageOversize)) {
        logger.e("$TAG - _sendData - message over size - count:${destList.length} - size:${Format.flowSize(data.length.toDouble(), unitArr: [
              'B',
              'KB',
              'MB',
              'GB'
            ])} - destList:$destList - data:$data");
        return [null, false, 0];
      }
      if (NknError.isClientError(e)) {
        handleError(e, st, toast: false);
        // if (clientCommon.isClientOK) return [null, true, 100];
        if (clientCommon.isClientConnecting) return [null, true, 500];
        logger.w("$TAG - _sendData - reConnect - count:${destList.length} - destList:$destList - data:$data");
        bool success = await clientCommon.reConnect();
        return [null, true, success ? 500 : 1000];
      }
      handleError(e, st);
      logger.e("$TAG - _sendData - try by unknown error - count:${destList.length} - destList:$destList - data:$data");
    }
    return [null, true, 250];
  }

  Future<bool> _waitClientOk() async {
    int tryTimes = 0;
    while (!clientCommon.isClientOK) {
      if (clientCommon.isClientStop) {
        logger.e("$TAG - _waitClientOk - client closed - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
        break;
      }
      logger.w("$TAG - _waitClientOk - client waiting - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 500));
    }
    if (!clientCommon.isClientOK) logger.w("$TAG - _waitClientOk - client wrong - tryTimes:$tryTimes - client:${clientCommon.client == null} - status:${clientCommon.status}");
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<int> sendPing(List<String> clientAddressList, bool isPing, {int gap = 0}) async {
    if (!(await _waitClientOk())) return 0;
    if (clientAddressList.isEmpty) return 0;
    String? selfAddress = clientCommon.address;
    // destList
    List<String> destList = [];
    for (int i = 0; i < clientAddressList.length; i++) {
      String address = clientAddressList[i];
      if (address.isEmpty) continue;
      if ((address == selfAddress) || (gap <= 0)) {
        destList.add(address);
      } else {
        DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(address);
        if (deviceInfo != null) {
          int lastAt = isPing ? deviceInfo.pingAt : deviceInfo.pongAt;
          int interval = DateTime.now().millisecondsSinceEpoch - lastAt;
          if (interval < gap) {
            logger.d('$TAG - sendPing - interval < gap - interval:${interval - gap} - target:$address');
            continue;
          }
        }
        destList.add(address);
      }
    }
    if (destList.isEmpty) return 0;
    // data
    String? data;
    if ((destList.length == 1) && (destList[0] == selfAddress)) {
      // self
      data = MessageData.getPing(isPing);
      logger.v("$TAG - sendPing - self - data:$data");
    } else if ((destList.length == 1) && (destList[0] != selfAddress)) {
      // contact
      ContactSchema? _me = await contactCommon.getMe();
      ContactSchema? _other = await contactCommon.queryByClientAddress(destList[0]);
      bool notificationOpen = _other?.options?.notificationOpen == true;
      String? deviceToken = notificationOpen ? (await deviceInfoCommon.getMe(canAdd: true, fetchDeviceToken: true))?.deviceToken : null;
      data = MessageData.getPing(
        isPing,
        profileVersion: _me?.profileVersion,
        deviceToken: deviceToken,
        deviceProfile: deviceInfoCommon.getDeviceProfile(),
      );
      logger.d("$TAG - sendPing - contact - dest:$destList - data:$data");
    } else {
      // group
      ContactSchema? _me = await contactCommon.getMe();
      data = MessageData.getPing(
        isPing,
        profileVersion: _me?.profileVersion,
        // deviceToken(unknown notification_open)
        deviceProfile: deviceInfoCommon.getDeviceProfile(),
      );
      logger.d("$TAG - sendPing - group - dest:$destList - data:$data");
    }
    // send
    Uint8List? pid = await _sendWithAddress(destList, data);
    // ping/pong at
    if ((pid?.isNotEmpty == true) && (gap > 0)) {
      int mowAt = DateTime.now().millisecondsSinceEpoch;
      deviceInfoCommon.queryListLatest(destList).then((deviceInfoList) {
        for (int i = 0; i < deviceInfoList.length; i++) {
          DeviceInfoSchema deviceInfo = deviceInfoList[i];
          if (deviceInfo.contactAddress == selfAddress) continue;
          if (isPing) {
            deviceInfoCommon.setPingAt(deviceInfo.contactAddress, deviceInfo.deviceId, pingAt: mowAt);
          } else {
            deviceInfoCommon.setPongAt(deviceInfo.contactAddress, deviceInfo.deviceId, pongAt: mowAt);
          }
        }
      });
    }
    return destList.length;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendReceipt(MessageSchema received) async {
    if (!(await _waitClientOk())) return false;
    if (received.from.isEmpty || (received.isTopic || received.isPrivateGroup)) return false; // topic/group no receipt, just send message to myself
    // received = (await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
    String data = MessageData.getReceipt(received.msgId);
    logger.i("$TAG - sendReceipt - dest:${received.from} - msgId:${received.msgId}");
    Uint8List? pid = await _sendWithAddress([received.from], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendRead(String? clientAddress, List<String> msgIds) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return false; // topic no read, just like receipt
    String data = MessageData.getRead(msgIds);
    logger.i("$TAG - sendRead - dest:$clientAddress - msgIds:$msgIds");
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  /*Future<bool> sendMsgStatus(String? clientAddress, bool ask, List<String> msgIds) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return false; // topic no read, just like receipt
    String data = MessageData.getMsgStatus(ask, msgIds);
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }*/

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileRequest(String? clientAddress, String requestType, String? profileVersion) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String data = MessageData.getContactProfileRequest(requestType, profileVersion);
    logger.i("$TAG - sendContactProfileRequest - dest:$clientAddress - requestType:${requestType == ContactRequestType.full ? "full" : "header"} - profileVersion:$profileVersion");
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileResponse(String? clientAddress, String requestType, {DeviceInfoSchema? deviceInfo, int gap = 0}) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    if (gap > 0) {
      deviceInfo = deviceInfo ?? (await deviceInfoCommon.queryLatest(clientAddress));
      if (deviceInfo != null) {
        int lastAt = deviceInfo.contactProfileResponseAt;
        int interval = DateTime.now().millisecondsSinceEpoch - lastAt;
        if (interval < gap) {
          logger.d('$TAG - sendContactProfileResponse - interval < gap - interval:${interval - gap} - target:$clientAddress');
          return false;
        }
      }
    }
    ContactSchema? me = await contactCommon.getMe();
    String data;
    if (requestType == ContactRequestType.header) {
      data = MessageData.getContactProfileResponseHeader(me?.profileVersion);
    } else {
      data = await MessageData.getContactProfileResponseFull(me?.profileVersion, me?.avatar, me?.firstName, me?.lastName);
    }
    logger.i("$TAG - sendContactProfileResponse - dest:$clientAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String selfAddress = clientCommon.address ?? "";
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: clientAddress,
      contentType: MessageContentType.contactOptions,
      extra: {
        "deleteAfterSeconds": deleteSeconds,
        "burningUpdateAt": updateAt,
      },
    );
    send.content = MessageData.getContactOptionsBurn(send); // same with receive and old version
    logger.i("$TAG - sendContactOptionsBurn - dest:$clientAddress - message:$send");
    var result = await _send(send, send.content);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsToken(String? clientAddress, String? deviceToken) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String selfAddress = clientCommon.address ?? "";
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: clientAddress,
      contentType: MessageContentType.contactOptions,
      extra: {
        "deviceToken": deviceToken,
      },
    );
    send.content = MessageData.getContactOptionsToken(send); // same with receive and old version
    logger.i("$TAG - sendContactOptionsToken - dest:$clientAddress - message:$send");
    var result = await _send(send, send.content);
    return result != null;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceRequest(String? clientAddress) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String data = MessageData.getDeviceRequest();
    logger.i("$TAG - sendDeviceRequest - dest:$clientAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceInfo(String? clientAddress, DeviceInfoSchema deviceInfo, bool withToken) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    if (!withToken) deviceInfo.deviceToken = null;
    String data = MessageData.getDeviceInfo(deviceInfo);
    logger.i("$TAG - sendDeviceInfo - dest:$clientAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> sendText(dynamic target, String? content) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || content.trim().isEmpty) return null;
    String selfAddress = clientCommon.address ?? "";
    // target
    String targetAddress = "";
    String targetTopic = "";
    String targetGroupId = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      targetGroupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetGroupId.isEmpty && targetTopic.isEmpty) return null;
    ContactSchema? me = await contactCommon.getMe();
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: targetAddress,
      topic: targetTopic,
      groupId: targetGroupId,
      contentType: ((deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text,
      content: content,
      extra: {
        "profileVersion": me?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
      },
    );
    // data
    String data = MessageData.getText(message);
    logger.i("$TAG - sendText - contact:$targetAddress - group:$targetGroupId - topic:$targetTopic - message:${message.toStringNoContent()}");
    return await _send(message, data);
  }

  Future<MessageSchema?> saveIpfs(dynamic target, Map<String, dynamic> data) async {
    if (!(await _waitClientOk())) return null;
    String selfAddress = clientCommon.address ?? "";
    // content
    String contentPath = data["path"]?.toString() ?? "";
    File? content = contentPath.isEmpty ? null : File(contentPath);
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) {
      logger.w("$TAG - saveIpfs - contact is null - data:$data");
      return null;
    }
    // target
    String targetAddress = "";
    String targetTopic = "";
    String targetGroupId = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      targetGroupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetGroupId.isEmpty && targetTopic.isEmpty) return null;
    ContactSchema? me = await contactCommon.getMe();
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: targetAddress,
      topic: targetTopic,
      groupId: targetGroupId,
      contentType: MessageContentType.ipfs,
      content: content,
      extra: data
        ..addAll({
          "profileVersion": me?.profileVersion,
          "privateGroupVersion": privateGroupVersion,
          "deleteAfterSeconds": deleteAfterSeconds,
          "burningUpdateAt": burningUpdateAt,
        }),
    );
    // insert
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
    }
    logger.i("$TAG - saveIpfs - contact:$targetAddress - group:$targetGroupId - topic:$targetTopic - message:${message.toStringNoContent()}");
    MessageSchema? inserted = await insertMessage(message);
    if (inserted == null) return null;
    // ipfs
    chatCommon.startIpfsUpload(inserted.msgId).then((msg) {
      if (msg != null) chatOutCommon.sendIpfs(msg.msgId); // await
    }); // await
    return inserted;
  }

  Future<MessageSchema?> sendIpfs(String? msgId) async {
    if (!(await _waitClientOk())) return null;
    if (msgId == null || msgId.isEmpty) return null;
    // schema
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    // data
    String? data = MessageData.getIpfs(message);
    logger.i("$TAG - sendIpfs - contact:${message.to} - group:${message.groupId} - topic:${message.topic} - message:${message.toStringNoContent()}");
    return await _send(message, data, insert: false);
  }

  Future<MessageSchema?> sendImage(dynamic target, File? content) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    String selfAddress = clientCommon.address ?? "";
    // target
    String targetAddress = "";
    String targetTopic = "";
    String targetGroupId = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      targetGroupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetGroupId.isEmpty && targetTopic.isEmpty) return null;
    ContactSchema? me = await contactCommon.getMe();
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: targetAddress,
      topic: targetTopic,
      groupId: targetGroupId,
      contentType: MessageContentType.image,
      content: content,
      extra: {
        "profileVersion": me?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileType": MessageOptions.fileTypeImage,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_IMAGE_EXT),
      },
    );
    // data
    String? data = await MessageData.getImage(message);
    logger.i("$TAG - sendImage - contact:$targetAddress - group:$targetGroupId - topic:$targetTopic - message:${message.toStringNoContent()}");
    return await _send(message, data);
  }

  Future<MessageSchema?> sendAudio(dynamic target, File? content, double? durationS) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    String selfAddress = clientCommon.address ?? "";
    // target
    String targetAddress = "";
    String targetGroupId = "";
    String targetTopic = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      targetGroupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetTopic = target.topic;
    }
    if (targetAddress.isEmpty && targetGroupId.isEmpty && targetTopic.isEmpty) return null;
    ContactSchema? me = await contactCommon.getMe();
    // schema
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: targetAddress,
      topic: targetTopic,
      groupId: targetGroupId,
      contentType: MessageContentType.audio,
      content: content,
      extra: {
        "profileVersion": me?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileType": MessageOptions.fileTypeAudio,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_AUDIO_EXT),
        "duration": durationS,
      },
    );
    // data
    String? data = await MessageData.getAudio(message);
    logger.i("$TAG - sendAudio - contact:$targetAddress - group:$targetGroupId - topic:$targetTopic - message:${message.toStringNoContent()}");
    return await _send(message, data);
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic) async {
    if (!(await _waitClientOk())) return;
    if (topic == null || topic.isEmpty) return;
    String selfAddress = clientCommon.address ?? "";
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      topic: topic,
      contentType: MessageContentType.topicSubscribe,
    );
    String data = MessageData.getTopicSubscribe(send);
    logger.i("$TAG - sendTopicSubscribe - dest:$topic - data:$data");
    await _send(send, data);
  }

  // NO DB NO single
  Future sendTopicUnSubscribe(String? topic) async {
    if (!(await _waitClientOk())) return;
    if (topic == null || topic.isEmpty) return;
    String selfAddress = clientCommon.address ?? "";
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      topic: topic,
      contentType: MessageContentType.topicUnsubscribe,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicUnSubscribe(send);
    logger.i("$TAG - sendTopicUnSubscribe - dest:$topic - data:$data");
    await _sendWithTopic(_schema, send, data, notification: false);
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    if (!(await _waitClientOk())) return null;
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    String selfAddress = clientCommon.address ?? "";
    ContactSchema? me = await contactCommon.getMe();
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      to: clientAddress,
      contentType: MessageContentType.topicInvitation,
      content: topic,
      extra: {
        "profileVersion": me?.profileVersion,
      },
    );
    String data = MessageData.getTopicInvitee(message);
    logger.i("$TAG - sendTopicInvitee - dest:$topic - data:$data");
    return await _send(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress) async {
    if (!(await _waitClientOk())) return;
    if (topic == null || topic.isEmpty || targetAddress == null || targetAddress.isEmpty) return;
    String selfAddress = clientCommon.address ?? "";
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
      topic: topic,
      contentType: MessageContentType.topicKickOut,
      content: targetAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicKickOut(send);
    logger.i("$TAG - sendTopicKickOut - dest:$topic - data:$data");
    await _sendWithTopic(_schema, send, data, notification: false);
  }

  // NO group (1 to 1)
  Future<MessageSchema?> sendPrivateGroupInvitee(String? target, PrivateGroupSchema? privateGroup, PrivateGroupItemSchema? groupItem) async {
    if (!(await _waitClientOk())) return null;
    if (target == null || target.isEmpty) return null;
    if (privateGroup == null || groupItem == null) return null;
    String selfAddress = clientCommon.address ?? "";
    ContactSchema? me = await contactCommon.getMe();
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: selfAddress,
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
      extra: {
        "profileVersion": me?.profileVersion,
      },
    );
    String data = MessageData.getPrivateGroupInvitation(message);
    logger.i("$TAG - sendPrivateGroupInvitee - dest:$target - data:$data");
    return await _send(message, data);
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupAccept(String? target, PrivateGroupItemSchema? groupItem) async {
    if (!(await _waitClientOk())) return false;
    if (target == null || target.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupAccept(groupItem);
    logger.i("$TAG - sendPrivateGroupAccept - dest:$target - data:$data");
    Uint8List? pid = await _sendWithAddress([target], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupQuit(String? target, PrivateGroupItemSchema? groupItem) async {
    if (!(await _waitClientOk())) return false;
    if (target == null || target.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupQuit(groupItem);
    logger.i("$TAG - sendPrivateGroupQuit - dest:$target - data:$data");
    Uint8List? pid = await _sendWithAddress([target], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupOptionRequest(String? target, String? groupId, {int gap = 0}) async {
    if (!(await _waitClientOk())) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    if (gap > 0) {
      int interval = DateTime.now().millisecondsSinceEpoch - group.optionsRequestAt;
      if (interval < gap) {
        logger.d('$TAG - sendPrivateGroupOptionRequest - interval < gap - interval:${interval - gap} - target:$target');
        return null;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupOptionRequest(groupId, getVersion);
    logger.i("$TAG - sendPrivateGroupOptionRequest - dest:$target - data:$data");
    Uint8List? pid = await _sendWithAddress([target], data);
    return (pid?.isNotEmpty == true) ? getVersion : null;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupOptionResponse(List<String> clientAddressList, PrivateGroupSchema? group) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddressList.isEmpty || clientAddressList[0].isEmpty) return false;
    if (group == null) return false;
    String data = MessageData.getPrivateGroupOptionResponse(group);
    logger.i("$TAG - sendPrivateGroupOptionResponse - count:${clientAddressList.length} - dest:$clientAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(clientAddressList, data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupMemberRequest(String? target, String? groupId, {int gap = 0}) async {
    if (!(await _waitClientOk())) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    if (gap > 0) {
      int interval = DateTime.now().millisecondsSinceEpoch - group.membersRequestAt;
      if (interval < gap) {
        logger.d('$TAG - sendPrivateGroupMemberRequest - interval < gap - interval:${interval - gap} - target:$target');
        return null;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupMemberRequest(groupId, getVersion);
    logger.i("$TAG - sendPrivateGroupMemberRequest - dest:$target - data:$data");
    Uint8List? pid = await _sendWithAddress([target], data);
    return (pid?.isNotEmpty == true) ? getVersion : null;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupMemberResponse(List<String> clientAddressList, PrivateGroupSchema? schema, List<PrivateGroupItemSchema> members) async {
    if (!(await _waitClientOk())) return false;
    if (clientAddressList.isEmpty || clientAddressList[0].isEmpty) return false;
    if (schema == null) return false;
    List<Map<String, dynamic>> membersData = privateGroupCommon.getMembersData(members);
    String data = MessageData.getPrivateGroupMemberResponse(schema, membersData);
    logger.i("$TAG - sendPrivateGroupMemberResponse - dest:$clientAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(clientAddressList, data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> resend(MessageSchema? message, {bool mute = false, int muteGap = 0}) async {
    if (message == null) return null;
    // sendAt
    if (mute) {
      int resendMuteAt = MessageOptions.getResendMuteAt(message.options) ?? 0;
      if ((muteGap > 0) && (resendMuteAt > 0)) {
        int interval = DateTime.now().millisecondsSinceEpoch - resendMuteAt;
        if (interval < muteGap) {
          logger.i("$TAG - resendMute - resend gap small - targetId:${message.targetId} - interval:$interval");
          return null;
        }
      }
    } else {
      bool success = await MessageStorage.instance.updateSendAt(message.msgId, DateTime.now().millisecondsSinceEpoch);
      if (success) message.sendAt = DateTime.now().millisecondsSinceEpoch;
      message = await messageCommon.updateMessageStatus(message, MessageStatus.Sending, force: true);
    }
    // ipfs
    if (message.contentType == MessageContentType.ipfs) {
      String? fileHash = MessageOptions.getIpfsHash(message.options);
      if (fileHash == null || fileHash.isEmpty) {
        logger.i("$TAG - resendMute - ipfs start - mute:$mute - targetId:${message.targetId} - options:${message.options}");
        message = await chatCommon.startIpfsUpload(message.msgId);
        if (message == null) return null;
      }
    }
    // send
    String? msgData;
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        logger.i("$TAG - resendMute - text - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        msgData = MessageData.getText(message);
        break;
      case MessageContentType.ipfs:
        logger.i("$TAG - resendMute - ipfs - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        msgData = MessageData.getIpfs(message);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        logger.i("$TAG - resendMute - image - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        msgData = await MessageData.getImage(message);
        break;
      case MessageContentType.audio:
        logger.i("$TAG - resendMute - audio - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        msgData = await MessageData.getAudio(message);
        break;
      case MessageContentType.topicInvitation:
        logger.i("$TAG - resendMute - topic invitee - mute:$mute - targetId:${message.targetId} - message:$message");
        msgData = MessageData.getTopicInvitee(message);
        break;
      case MessageContentType.privateGroupInvitation:
        logger.i("$TAG - resendMute - group invitee - mute:$mute - targetId:${message.targetId} - message:$message");
        msgData = MessageData.getPrivateGroupInvitation(message);
        break;
      default:
        logger.w("$TAG - resendMute - wrong type - mute:$mute - targetId:${message.targetId} - message:$message");
        // int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
        // return await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
        return null;
    }
    if (mute) {
      // notification
      bool notification;
      if (message.isTopic || message.isPrivateGroup) {
        notification = false;
      } else {
        bool noReceipt = message.status < MessageStatus.Receipt;
        String pushNotifyId = MessageOptions.getPushNotifyId(message.options) ?? "";
        notification = noReceipt && pushNotifyId.isEmpty;
      }
      // send_mute
      MessageSchema? result = await _send(message, msgData, insert: false, sessionSync: false, statusSync: false, notification: notification);
      if (result != null) {
        logger.i("$TAG - resendMute - success mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        result.options = MessageOptions.setResendMuteAt(result.options, DateTime.now().millisecondsSinceEpoch);
        await messageCommon.updateMessageOptions(result, result.options, notify: false);
      } else {
        logger.w("$TAG - resendMute - fail mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringNoContent()}");
      }
      return result;
    }
    // send
    return await _send(message, msgData, insert: false);
  }

  Future<MessageSchema?> insertMessage(MessageSchema? message, {bool notify = true}) async {
    if (message == null) return null;
    message = await MessageStorage.instance.insert(message); // DB
    if (message == null) return null;
    if (notify) messageCommon.onSavedSink.add(message); // display, resend just update sendTime
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
    if (message.canDisplay) {
      syncClientCommon.syncAllDevicesMessage(message.from, message.to, jsonDecode(msgData));
    }
    // session
    if (sessionSync) await chatCommon.sessionHandle(message);
    // sdk
    Uint8List? pid;
    if (message.isTopic) {
      TopicSchema? topic = await chatCommon.topicHandle(message);
      bool pushNotification = message.canNotification && (notification != false);
      pid = await _sendWithTopic(topic, message, msgData, notification: pushNotification);
    } else if (message.isPrivateGroup) {
      PrivateGroupSchema? group = await chatCommon.privateGroupHandle(message);
      // FUTURE:GG (group.options?.notificationOpen == true)
      bool pushNotification = message.canNotification && (notification != false);
      pid = await _sendWithPrivateGroup(group, message, msgData, notification: pushNotification);
    } else if (message.to.isNotEmpty == true) {
      ContactSchema? contact = await chatCommon.contactHandle(message);
      bool pushNotification = message.canNotification && (contact?.options?.notificationOpen == true) && (notification != false);
      pid = await _sendWithContact(contact, message, msgData, notification: pushNotification);
    } else {
      logger.e("$TAG - _send - with_error - type:${message.contentType} - message:${message.toStringNoContent()}");
      return null;
    }
    // pid
    if (pid?.isNotEmpty == true) {
      message.pid = pid;
      MessageStorage.instance.updatePid(message.msgId, message.pid); // await
    } else {
      logger.w("$TAG - _send - pid is null - type:${message.contentType} - message:${message.toStringNoContent()}");
    }
    // status
    if (statusSync) {
      if (pid?.isNotEmpty == true) {
        if (message.canReceipt) {
          messageCommon.updateMessageStatus(message, MessageStatus.Success); // await
        } else {
          // no received receipt/read
          int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt); // await
        }
      } else {
        if (message.canResend) {
          message = await messageCommon.updateMessageStatus(message, MessageStatus.Error, force: true);
        } else {
          // noResend just delete
          int count = await MessageStorage.instance.deleteByIdContentType(message.msgId, message.contentType);
          if (count > 0) messageCommon.onDeleteSink.add(message.msgId);
          return null;
        }
      }
    }
    return message;
  }

  Future<Uint8List?> _sendWithAddress(List<String> clientAddressList, String? msgData) async {
    if (clientAddressList.isEmpty || msgData == null) return null;
    logger.d("$TAG - _sendWithAddress - count:${clientAddressList.length} - addressList:$clientAddressList - msgData:$msgData");
    return (await sendMsg(clientAddressList, msgData))?.messageId;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (message == null || msgData == null) return null;
    logger.d("$TAG - _sendWithContact - type:${message.contentType} - target:${contact?.clientAddress} - message:${message.toStringNoContent()} - data:$msgData");
    // send
    Uint8List? pid;
    bool canTry = true;
    if (message.canTryPiece) {
      try {
        List result = await _sendWithPieces([message.to], message);
        pid = result[0];
        canTry = result[1];
      } catch (e, st) {
        handleError(e, st);
        return null;
      }
    }
    if (canTry && ((pid == null) || pid.isEmpty)) {
      pid = (await sendMsg([message.to], msgData))?.messageId;
    }
    if (pid == null || pid.isEmpty) return pid;
    // notification
    if (notification && (contact != null) && !contact.isMe) {
      deviceInfoCommon.queryDeviceTokenList(contact.clientAddress).then((tokens) async {
        logger.d("$TAG - _sendWithContact - push notification - count:${tokens.length} - target:${contact.clientAddress} - tokens:$tokens");
        bool pushOk = false;
        for (int i = 0; i < tokens.length; i++) {
          String? uuid = await RemoteNotification.send(tokens[i]); // need result
          if (!pushOk && (uuid != null) && uuid.isNotEmpty) {
            message.options = MessageOptions.setPushNotifyId(message.options, uuid);
            bool optionsOK = await messageCommon.updateMessageOptions(message, message.options, notify: false);
            if (optionsOK) pushOk = true;
          }
        }
      });
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (topic == null || message == null || msgData == null) return null;
    // me
    SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(message.topic, message.from); // chatOutCommon.handleSubscribe();
    bool checkStatus = message.contentType == MessageContentType.topicUnsubscribe;
    if (!checkStatus && (_me?.status != SubscriberStatus.Subscribed)) {
      logger.w("$TAG - _sendWithTopic - subscriber me is wrong - type:${message.contentType} - me:$_me - message:${message.toStringNoContent()}");
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
      logger.i("$TAG - _sendWithTopic - add kick people - type:${message.contentType} - clientAddress:${message.content}");
      SubscriberSchema? kicked = SubscriberSchema.create(topic.topic, message.content?.toString(), SubscriberStatus.None, null);
      if (kicked != null) _subscribers.add(kicked);
    }
    if (_subscribers.isEmpty) return null;
    // destList
    bool selfIsReceiver = false;
    List<String> destList = [];
    for (var i = 0; i < _subscribers.length; i++) {
      String clientAddress = _subscribers[i].clientAddress;
      if (clientAddress == message.from) {
        selfIsReceiver = true;
      } else {
        destList.add(clientAddress);
      }
    }
    logger.d(
        "$TAG - _sendWithTopic - type:${message.contentType} - topic:${topic.topic} - self:$selfIsReceiver - dest_count:${destList.length} - topic:$topic - message:${message.toStringNoContent()} - data:$msgData");
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      bool canTry = true;
      if (message.canTryPiece) {
        try {
          List result = await _sendWithPieces(destList, message);
          pid = result[0];
          canTry = result[1];
        } catch (e, st) {
          handleError(e, st);
          return null;
        }
      }
      if (canTry && ((pid == null) || pid.isEmpty)) {
        pid = (await sendMsg(destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg([message.from], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    if (pid == null || pid.isEmpty) return null;
    // notification
    if (notification && destList.isNotEmpty) {
      contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.clientAddress).then((tokens) {
            logger.d("$TAG - _sendWithTopic - push notification - count:${tokens.length} - target:${_contact.clientAddress} - topic:${topic.topic} - tokens:$tokens");
            tokens.forEach((token) {
              RemoteNotification.send(token); // await // no need result
            });
          });
        }
      });
    }
    return pid;
  }

  Future<Uint8List?> _sendWithPrivateGroup(PrivateGroupSchema? group, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (group == null || message == null || msgData == null) return null;
    // me
    PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(group.groupId, message.from);
    if ((_me == null) || ((_me.permission ?? 0) <= PrivateGroupItemPerm.none)) {
      logger.w("$TAG - _sendWithPrivateGroup - member me is null - type:${message.contentType} - me:$_me - group:$group - message:${message.toStringNoContent()}");
      return null;
    }
    // destList
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(message.groupId);
    bool selfIsReceiver = false;
    List<String> destList = [];
    for (var i = 0; i < members.length; i++) {
      String? clientAddress = members[i].invitee;
      if (clientAddress == null || clientAddress.isEmpty) continue;
      if (clientAddress == message.from) {
        selfIsReceiver = true;
      } else if ((members[i].permission ?? 0) > PrivateGroupItemPerm.none) {
        destList.add(clientAddress);
      }
    }
    logger.d(
        "$TAG - _sendWithPrivateGroup - type:${message.contentType} - groupId:${group.groupId} - self:$selfIsReceiver - dest_count:${destList.length} - group:$group - message:${message.toStringNoContent()} - data:$msgData");
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      bool canTry = true;
      if (message.canTryPiece) {
        try {
          List result = await _sendWithPieces(destList, message);
          pid = result[0];
          canTry = result[1];
        } catch (e, st) {
          handleError(e, st);
          return null;
        }
      }
      if (canTry && ((pid == null) || pid.isEmpty)) {
        pid = (await sendMsg(destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg([message.from], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    if (pid == null || pid.isEmpty) return null;
    // notification
    if (notification && destList.isNotEmpty) {
      contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.clientAddress).then((tokens) {
            logger.d("$TAG - _sendWithPrivateGroup - push notification - count:${tokens.length} - target:${_contact.clientAddress} - groupId:${group.groupId} - tokens:$tokens");
            tokens.forEach((token) {
              RemoteNotification.send(token); // await // no need result
            });
          });
        }
      });
    }
    return pid;
  }

  Future<List<dynamic>> _sendWithPieces(List<String> clientAddressList, MessageSchema message, {double totalPercent = -1}) async {
    Map<String, dynamic> results = await MessageSchema.piecesSplits(message);
    if (results.isEmpty) return [null, true];
    String dataBytesString = results["data"];
    int bytesLength = results["length"];
    int total = results["total"];
    int parity = results["parity"];

    // dataList.size = (total + parity) <= 255
    List<Object?> dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty) {
      logger.e("$TAG - _sendWithPieces:ERROR - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: [
            'B',
            'KB',
            'MB',
            'GB'
          ])} - parentType:${message.contentType}");
      return [null, false];
    }
    logger.i("$TAG - _sendWithPieces:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: [
          'B',
          'KB',
          'MB',
          'GB'
        ])} - parentType:${message.contentType}");

    List<MessageSchema> resultList = [];
    for (var index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      Map<String, dynamic> options = Map();
      options.addAll(message.options ?? Map()); // new *
      MessageSchema piece = MessageSchema.fromSend(
        msgId: message.msgId,
        from: message.from,
        to: message.to,
        topic: message.topic,
        groupId: message.groupId,
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
      MessageSchema? result = await _sendPiece(clientAddressList, piece, percent: percent);
      if ((result != null) && (result.pid != null)) resultList.add(result);
      await Future.delayed(Duration(milliseconds: 10)); // send with interval
    }
    List<MessageSchema> finds = resultList.where((element) => element.pid != null).toList();
    finds.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    if (finds.length >= total) {
      logger.i("$TAG - _sendWithPieces:SUCCESS - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: [
            'B',
            'KB',
            'MB',
            'GB'
          ])} - parentType:${message.contentType} - message:${message.toStringNoContent()}");
      if (finds.isNotEmpty) return [finds.firstWhere((element) => element.pid != null).pid, true];
    }
    logger.w("$TAG - _sendWithPieces:FAIL - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: [
          'B',
          'KB',
          'MB',
          'GB'
        ])} - parentType:${message.contentType} - message:${message.toStringNoContent()}");
    return [null, false];
  }

  Future<MessageSchema?> _sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    if (!(await _waitClientOk())) return null;
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendMsg(clientAddressList, data);
    if ((onResult == null) || onResult.messageId.isEmpty) {
      logger.w(
          "$TAG - _sendPiece - fail - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_PARITY]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringNoContent()}");
      return null;
    }
    logger.d(
        "$TAG - _sendPiece - success - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_PARITY]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringNoContent()}");
    message.pid = onResult.messageId;
    // progress
    if ((percent > 0) && (percent <= 1)) {
      if (percent <= 1.05) {
        // logger.v("$TAG - _sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    } else {
      int? total = message.options?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE_INDEX];
      double percent = (index ?? 0) / (total ?? 1);
      if (percent <= 1.05) {
        // logger.v("$TAG - _sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:$message - data:$data");
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    }
    return message;
  }
}
