import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/device_info.dart';
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
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';

class ChatOutCommon with Tag {
  ChatOutCommon();

  ParallelQueue _sendQueue = ParallelQueue("chat_send", onLog: (log, error) => error ? logger.w(log) : null);

  Future run({bool reset = true}) async {
    logger.i("$TAG - run - reset:$reset");
    _sendQueue.run(clear: reset);
  }

  Future pause({bool reset = true}) async {
    logger.i("$TAG - pause - reset:$reset");
    _sendQueue.pause();
  }

  Future<OnMessage?> sendMsg(List<String> destList, String data) async {
    // logger.v("$TAG - sendMsg - send start - destList:$destList");
    // dest
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.e("$TAG - sendMsg - destList is empty");
      return null;
    }
    // size
    if (data.length >= Settings.sizeMsgMax) {
      logger.w("$TAG - sendMsg - size over - count:${destList.length} - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList");
      // Sentry.captureMessage("$TAG - sendData - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList");
      // return null;
    }
    // send
    return await _sendQueue.add(() async {
      OnMessage? onMessage;
      int tryTimes = 0;
      while (tryTimes < Settings.tryTimesMsgSend) {
        List<dynamic> result = await _sendData(destList, data, lastTime: tryTimes >= (Settings.tryTimesMsgSend - 1));
        onMessage = result[0];
        bool canTry = result[1];
        int delay = result[2];
        if (onMessage?.messageId?.isNotEmpty == true) break;
        if (!canTry) break;
        tryTimes++;
        await Future.delayed(Duration(milliseconds: delay));
      }
      if (tryTimes >= Settings.tryTimesMsgSend) {
        logger.e("$TAG - sendMsg - try max over - count:${destList.length} - destList:$destList");
      }
      return onMessage;
    });
  }

  Future<List<dynamic>> _sendData(List<String> destList, String data, {bool lastTime = false}) async {
    if (!(await clientCommon.waitClientOk())) return [null, false];
    // logger.v("$TAG - _sendData - send start - destList:$destList");
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId?.isNotEmpty == true) {
        logger.v("$TAG - _sendData - success - count:${destList.length} - destList:$destList");
      } else {
        logger.e("$TAG - _sendData - error - count:${destList.length} - destList:$destList");
      }
      return [onMessage, true, 100];
    } catch (e, st) {
      String errStr = e.toString().toLowerCase();
      if (errStr.contains(NknError.invalidDestination)) {
        logger.e("$TAG - _sendData - wrong clientAddress - count:${destList.length} - destList:$destList");
        return [null, false, 0];
      } else if (errStr.contains(NknError.messageOversize)) {
        logger.e("$TAG - _sendData - message over size - count:${destList.length} - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList");
        return [null, false, 0];
      }
      if (NknError.isClientError(e)) {
        handleError(e, st, toast: false);
        // if (clientCommon.isClientOK) return [null, true, 100];
        if (clientCommon.isClientConnecting || clientCommon.isClientReconnecting) return [null, true, 1000];
        logger.w("$TAG - _sendData - reconnect - count:${destList.length} - destList:$destList");
        bool success = await clientCommon.reconnect();
        return [null, true, success ? 500 : 1000];
      }
      handleError(e, st);
      logger.e("$TAG - _sendData - try by unknown error - count:${destList.length} - destList:$destList");
    }
    return [null, true, 500];
  }

  // NO DB NO display NO topic (1 to 1)
  Future<int> sendPing(List<String> clientAddressList, bool isPing, {int gap = 0}) async {
    if (!(await clientCommon.waitClientOk())) return 0;
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
            logger.d('$TAG - sendPing - ${isPing ? "ping" : "pong"} - gap small - gap:$interval<$gap - target:$address');
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
      ContactSchema? _target = await contactCommon.query(destList[0], fetchWalletAddress: false);
      bool notificationOpen = _target?.options.notificationOpen == true;
      String? deviceToken = notificationOpen ? (await deviceInfoCommon.getMe(canAdd: true, fetchDeviceToken: true))?.deviceToken : null;
      DeviceInfoSchema? targetDevice = await deviceInfoCommon.queryLatest(_target?.address); // just can latest
      String? queueIds;
      if ((targetDevice != null) && DeviceInfoCommon.isMessageQueueEnable(targetDevice.platform, targetDevice.appVersion)) {
        await Future.delayed(Duration(milliseconds: 1000));
        await chatInCommon.waitReceiveQueue(targetDevice.contactAddress, "sendPing");
        queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetDevice.contactAddress, targetDevice.deviceId);
      }
      data = MessageData.getPing(
        isPing,
        profileVersion: _me?.profileVersion,
        deviceToken: deviceToken,
        deviceProfile: deviceInfoCommon.getDeviceProfile(),
        queueIds: queueIds,
      );
      logger.d("$TAG - sendPing - contact - dest:${destList[0]} - data:$data");
    } else {
      // group
      ContactSchema? _me = await contactCommon.getMe();
      data = MessageData.getPing(
        isPing,
        profileVersion: _me?.profileVersion,
        // deviceToken(unknown notification_open)
        deviceProfile: deviceInfoCommon.getDeviceProfile(),
        // queueIds(no support)
      );
      logger.d("$TAG - sendPing - group - dest:$destList - data:$data");
    }
    // send
    Uint8List? pid = await _sendWithAddress(destList, data);
    // ping/pong at
    if ((pid?.isNotEmpty == true) && (gap > 0)) {
      int mowAt = DateTime.now().millisecondsSinceEpoch;
      deviceInfoCommon.queryListByContactAddress(destList).then((deviceInfoList) {
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
    if (!(await clientCommon.waitClientOk())) return false;
    if (received.isTargetTopic || received.isTargetGroup) {
      // handle in send topic/group with self receipt
      if (received.status < MessageStatus.Receipt) {
        await messageCommon.updateMessageStatus(received, MessageStatus.Receipt, notify: false);
      }
      return false; // topic/group no receipt, just send message to myself
    }
    if (received.sender.isEmpty) return false;
    String data = MessageData.getReceipt(received.msgId);
    logger.i("$TAG - sendReceipt - dest:${received.sender} - msgId:${received.msgId}");
    Uint8List? pid = await _sendWithAddress([received.sender], data);
    if ((pid?.isNotEmpty == true) && (messageCommon.chattingTargetId != received.targetId)) {
      await messageCommon.updateMessageStatus(received, MessageStatus.Receipt, notify: false);
    }
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendRead(String? targetAddress, List<String> msgIds) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty || msgIds.isEmpty) return false; // topic/group no read, just like receipt
    String data = MessageData.getRead(msgIds);
    logger.i("$TAG - sendRead - dest:$targetAddress - count:${msgIds.length} - msgIds:$msgIds");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendQueue(String? targetAddress, String? targetDeviceId) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return false;
    await Future.delayed(Duration(milliseconds: 500));
    await chatInCommon.waitReceiveQueue(targetAddress, "sendQueue");
    String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetAddress, targetDeviceId);
    if (queueIds == null) return false;
    String data = MessageData.getQueue(queueIds);
    logger.i("$TAG - sendQueue - dest:$targetAddress - queueIds:$queueIds");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileRequest(String? targetAddress, String requestType, String? profileVersion) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    String data = MessageData.getContactProfileRequest(requestType, profileVersion);
    logger.i("$TAG - sendContactProfileRequest - dest:$targetAddress - requestType:${requestType == ContactRequestType.full ? "full" : "header"} - profileVersion:$profileVersion");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileResponse(String? targetAddress, ContactSchema? contactMe, String requestType, {DeviceInfoSchema? deviceInfo, int gap = 0}) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty || contactMe == null) return false;
    if ((deviceInfo != null) && (gap > 0)) {
      int lastAt = deviceInfo.contactProfileResponseAt;
      int interval = DateTime.now().millisecondsSinceEpoch - lastAt;
      if (interval < gap) {
        logger.d('$TAG - sendContactProfileResponse - gap small - gap:$interval<$gap - target:$targetAddress');
        return false;
      }
    }
    String data;
    if (requestType == ContactRequestType.header) {
      data = MessageData.getContactProfileResponseHeader(contactMe.profileVersion);
    } else {
      data = await MessageData.getContactProfileResponseFull(contactMe.profileVersion, contactMe.avatar, contactMe.firstName, contactMe.lastName);
    }
    logger.i("$TAG - sendContactProfileResponse - dest:$targetAddress - requestType:$requestType");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsBurn(String? targetAddress, int deleteSeconds, int updateAt) async {
    // if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      SessionType.CONTACT,
      MessageContentType.contactOptions,
      null,
      extra: {
        "deleteAfterSeconds": deleteSeconds,
        "burningUpdateAt": updateAt,
      },
    );
    message.content = MessageData.getContactOptionsBurn(message.msgId, deleteSeconds, updateAt); // same with receive and old version
    message.data = message.content;
    logger.i("$TAG - sendContactOptionsBurn - dest:$targetAddress - deleteSeconds:$deleteSeconds - updateAt:$updateAt");
    var result = await _send(message);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsToken(String? targetAddress, String? deviceToken) async {
    // if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      SessionType.CONTACT,
      MessageContentType.contactOptions,
      null,
      extra: {
        "deviceToken": deviceToken,
      },
    );
    message.content = MessageData.getContactOptionsToken(message.msgId, deviceToken); // same with receive and old version
    message.data = message.content;
    logger.i("$TAG - sendContactOptionsToken - dest:$targetAddress - deviceToken:$deviceToken");
    var result = await _send(message);
    return result != null;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceRequest(String? targetAddress) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    String data = MessageData.getDeviceRequest();
    logger.i("$TAG - sendDeviceRequest - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceInfo(String? targetAddress, DeviceInfoSchema selfDeviceInfo, bool withToken, {DeviceInfoSchema? targetDeviceInfo, int gap = 0}) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if ((targetDeviceInfo != null) && (gap > 0)) {
      int lastAt = targetDeviceInfo.deviceInfoResponseAt;
      int interval = DateTime.now().millisecondsSinceEpoch - lastAt;
      if (interval < gap) {
        logger.d('$TAG - sendDeviceInfo - gap small - gap:$interval<$gap - target:$targetAddress');
        return false;
      }
    }
    if (!withToken) selfDeviceInfo.deviceToken = "";
    String data = MessageData.getDeviceInfo(selfDeviceInfo);
    logger.i("$TAG - sendDeviceInfo - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> sendText(dynamic target, String? content) async {
    //if (!(await clientCommon.waitClientOk())) return null;
    if (content == null || content.trim().isEmpty) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.address;
      targetType = SessionType.CONTACT;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topicId;
      targetType = SessionType.TOPIC;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = SessionType.PRIVATE_GROUP;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
      privateGroupVersion = target.version;
    }
    if (targetId.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      targetId,
      targetType,
      ((deleteAfterSeconds ?? 0) > 0) ? MessageContentType.textExtension : MessageContentType.text,
      content,
      extra: {
        "profileVersion": (await contactCommon.getMe())?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
      },
    );
    // queue
    message = await messageCommon.loadMessageSendQueue(message);
    // data
    message.data = MessageData.getText(message);
    logger.i("$TAG - sendText - targetId:$targetId - content:$content - data:${message.data}");
    return await _send(message);
  }

  Future<MessageSchema?> saveIpfs(dynamic target, Map<String, dynamic> data) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    // content
    String contentPath = data["path"]?.toString() ?? "";
    File? content = contentPath.isEmpty ? null : File(contentPath);
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) {
      logger.w("$TAG - saveIpfs - contact is null - mediaData:$data");
      return null;
    }
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.address;
      targetType = SessionType.CONTACT;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topicId;
      targetType = SessionType.TOPIC;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = SessionType.PRIVATE_GROUP;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
      privateGroupVersion = target.version;
    }
    if (targetId.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      targetId,
      targetType,
      MessageContentType.ipfs,
      content,
      extra: data
        ..addAll({
          "profileVersion": (await contactCommon.getMe())?.profileVersion,
          "privateGroupVersion": privateGroupVersion,
          "deleteAfterSeconds": deleteAfterSeconds,
          "burningUpdateAt": burningUpdateAt,
        }),
    );
    // queue
    message = await messageCommon.loadMessageSendQueue(message);
    // insert
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
    }
    logger.i("$TAG - saveIpfs - targetId:$targetId - message:$message");
    MessageSchema? inserted = await insertMessage(message);
    if (inserted == null) return null;
    // ipfs
    chatCommon.startIpfsUpload(inserted.msgId).then((msg) {
      if (msg != null) chatOutCommon.sendIpfs(msg.msgId); // await
    }); // await
    return inserted;
  }

  Future<MessageSchema?> sendIpfs(String? msgId) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    if (msgId == null || msgId.isEmpty) return null;
    // schema
    MessageSchema? message = await messageCommon.query(msgId);
    if (message == null) return null;
    // data
    message.data = MessageData.getIpfs(message);
    logger.i("$TAG - sendIpfs - targetId:${message.targetId} - data:${message.data}");
    return await _send(message, insert: false);
  }

  Future<MessageSchema?> sendImage(dynamic target, File? content) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.address;
      targetType = SessionType.CONTACT;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topicId;
      targetType = SessionType.TOPIC;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = SessionType.PRIVATE_GROUP;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
      privateGroupVersion = target.version;
    }
    if (targetId.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      targetId,
      targetType,
      MessageContentType.image,
      content,
      extra: {
        "profileVersion": (await contactCommon.getMe())?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileType": MessageOptions.fileTypeImage,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_IMAGE_EXT),
      },
    );
    // queue
    message = await messageCommon.loadMessageSendQueue(message);
    // data
    message.data = await MessageData.getImage(message);
    logger.i("$TAG - sendImage - targetId:$targetId - path:${content.absolute.path} - message:${message.toStringSimple()}");
    return await _send(message);
  }

  Future<MessageSchema?> sendAudio(dynamic target, File? content, double? durationS) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.address;
      targetType = SessionType.CONTACT;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topicId;
      targetType = SessionType.TOPIC;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = SessionType.PRIVATE_GROUP;
      deleteAfterSeconds = target.options.deleteAfterSeconds;
      burningUpdateAt = target.options.updateBurnAfterAt;
      privateGroupVersion = target.version;
    }
    if (targetId.isEmpty) return null;
    // schema
    MessageSchema message = MessageSchema.fromSend(
      targetId,
      targetType,
      MessageContentType.audio,
      content,
      extra: {
        "profileVersion": (await contactCommon.getMe())?.profileVersion,
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileType": MessageOptions.fileTypeAudio,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_AUDIO_EXT),
        "duration": durationS,
      },
    );
    // queue
    message = await messageCommon.loadMessageSendQueue(message);
    // data
    message.data = await MessageData.getAudio(message);
    logger.i("$TAG - sendAudio - targetId:$targetId - path:${content.absolute.path} - message:${message.toStringSimple()}");
    return await _send(message);
  }

  // NO DB NO single
  Future<bool> sendTopicSubscribe(String? topicId) async {
    // if (!(await clientCommon.waitClientOk())) return false;
    if (topicId == null || topicId.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topicId,
      SessionType.TOPIC,
      MessageContentType.topicSubscribe,
      null,
    );
    message.data = MessageData.getTopicSubscribe(message.msgId, message.targetId);
    logger.i("$TAG - sendTopicSubscribe - dest:$topicId - data:${message.data}");
    var result = await _send(message);
    return result != null;
  }

  // NO DB NO single
  Future<bool> sendTopicUnSubscribe(String? topicId) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (topicId == null || topicId.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topicId,
      SessionType.TOPIC,
      MessageContentType.topicUnsubscribe,
      "",
    );
    TopicSchema? _schema = await chatCommon.topicHandle(message);
    message.data = MessageData.getTopicUnSubscribe(message.targetId);
    logger.i("$TAG - sendTopicUnSubscribe - dest:$topicId - data:${message.data}");
    var result = await _sendWithTopic(_schema, message, notification: false);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? topicId, String? targetAddress) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    if (targetAddress == null || targetAddress.isEmpty || topicId == null || topicId.isEmpty) return null;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      SessionType.CONTACT,
      MessageContentType.topicInvitation,
      topicId,
      extra: {
        "profileVersion": (await contactCommon.getMe())?.profileVersion,
      },
    );
    message.data = MessageData.getTopicInvitee(message);
    logger.i("$TAG - sendTopicInvitee - dest:$topicId - invitee:$targetAddress - data:${message.data}");
    return await _send(message);
  }

  // NO DB NO single
  Future<bool> sendTopicKickOut(String? topicId, String? kickAddress) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (topicId == null || topicId.isEmpty || kickAddress == null || kickAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topicId,
      SessionType.TOPIC,
      MessageContentType.topicKickOut,
      kickAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(message);
    message.data = MessageData.getTopicKickOut(message.targetId, message.content);
    logger.i("$TAG - sendTopicKickOut - dest:$topicId - kick:$kickAddress - data:${message.data}");
    var result = await _sendWithTopic(_schema, message, notification: false);
    return result != null;
  }

  // NO group (1 to 1)
  Future<MessageSchema?> sendPrivateGroupInvitee(String? targetAddress, PrivateGroupSchema? privateGroup, PrivateGroupItemSchema? groupItem) async {
    // if (!(await clientCommon.waitClientOk())) return null;
    if (targetAddress == null || targetAddress.isEmpty) return null;
    if (privateGroup == null || groupItem == null) return null;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      SessionType.CONTACT,
      MessageContentType.privateGroupInvitation,
      {
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
        "profileVersion": (await contactCommon.getMe())?.profileVersion,
      },
    );
    message.data = MessageData.getPrivateGroupInvitation(message);
    logger.i("$TAG - sendPrivateGroupInvitee - dest:$targetAddress - data:${message.data}");
    return await _send(message);
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupAccept(String? targetAddress, PrivateGroupItemSchema? groupItem) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupAccept(groupItem);
    logger.i("$TAG - sendPrivateGroupAccept - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupQuit(String? targetAddress, PrivateGroupItemSchema? groupItem) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupQuit(groupItem);
    logger.i("$TAG - sendPrivateGroupQuit - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupOptionRequest(String? targetAddress, String? groupId, {int gap = 0}) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return false;
    if (gap > 0) {
      int interval = DateTime.now().millisecondsSinceEpoch - group.optionsRequestAt;
      if (interval < gap) {
        logger.d('$TAG - sendPrivateGroupOptionRequest - gap small - gap:$interval<$gap - targetAddress:$targetAddress');
        return false;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupOptionRequest(groupId, getVersion);
    logger.i("$TAG - sendPrivateGroupOptionRequest - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupOptionResponse(List<String> targetAddressList, PrivateGroupSchema? group) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddressList.isEmpty || targetAddressList[0].isEmpty) return false;
    if (group == null) return false;
    String data = MessageData.getPrivateGroupOptionResponse(group);
    logger.i("$TAG - sendPrivateGroupOptionResponse - count:${targetAddressList.length} - dest:$targetAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(targetAddressList, data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupMemberRequest(String? targetAddress, String? groupId, {int gap = 0}) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return false;
    if (gap > 0) {
      int interval = DateTime.now().millisecondsSinceEpoch - group.membersRequestAt;
      if (interval < gap) {
        logger.d('$TAG - sendPrivateGroupMemberRequest - gap small - gap:$interval<$gap - targetAddress:$targetAddress');
        return false;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupMemberRequest(groupId, getVersion);
    logger.i("$TAG - sendPrivateGroupMemberRequest - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupMemberResponse(List<String> targetAddressList, PrivateGroupSchema? schema, List<PrivateGroupItemSchema> members) async {
    if (!(await clientCommon.waitClientOk())) return false;
    if (targetAddressList.isEmpty || targetAddressList[0].isEmpty) return false;
    if (schema == null) return false;
    List<Map<String, dynamic>> membersData = privateGroupCommon.getMembersData(members);
    String data = MessageData.getPrivateGroupMemberResponse(schema, membersData);
    logger.i("$TAG - sendPrivateGroupMemberResponse - dest:$targetAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(targetAddressList, data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> resend(String? msgId, {bool mute = false, int muteGap = 0}) async {
    MessageSchema? message = await messageCommon.query(msgId);
    if (message == null) return null;
    // reSendAt
    if (mute && (muteGap > 0)) {
      int resendMuteAt = MessageOptions.getResendMuteAt(message.options) ?? 0;
      int sendSuccessAt = MessageOptions.getSendSuccessAt(message.options) ?? 0;
      resendMuteAt = (resendMuteAt > 0) ? resendMuteAt : sendSuccessAt;
      if (resendMuteAt <= 0) {
        logger.w("$TAG - resendMute - resend time set wrong - targetId:${message.targetId} - message:${message.toStringSimple()}");
      } else {
        int interval = DateTime.now().millisecondsSinceEpoch - resendMuteAt;
        if (interval < muteGap) {
          logger.i("$TAG - resendMute - resend gap small - gap:$interval<$muteGap - targetId:${message.targetId} - interval:$interval");
          return null;
        } else {
          logger.d("$TAG - resendMute - resend gap ok - gap:$interval>$muteGap - targetId:${message.targetId}");
        }
      }
    }
    // queue
    message = await messageCommon.loadMessageSendQueueAgain(message);
    // status
    if (!mute) {
      bool success = await messageCommon.updateSendAt(message.msgId, DateTime.now().millisecondsSinceEpoch);
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
      } else {
        logger.i("$TAG - resendMute - ipfs hash ok - mute:$mute - targetId:${message.targetId} - options:${message.options}");
      }
    }
    // send
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        message.data = MessageData.getText(message);
        logger.d("$TAG - resendMute - text - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        break;
      case MessageContentType.ipfs:
        message.data = MessageData.getIpfs(message);
        logger.d("$TAG - resendMute - ipfs - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        break;
      case MessageContentType.image:
        message.data = await MessageData.getImage(message);
        logger.d("$TAG - resendMute - image - mute:$mute - targetId:${message.targetId} - message:${message.toStringSimple()}");
        break;
      case MessageContentType.audio:
        message.data = await MessageData.getAudio(message);
        logger.d("$TAG - resendMute - audio - mute:$mute - targetId:${message.targetId} - message:${message.toStringSimple()}");
        break;
      case MessageContentType.topicInvitation:
        message.data = MessageData.getTopicInvitee(message);
        logger.d("$TAG - resendMute - topic invitee - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        break;
      case MessageContentType.privateGroupInvitation:
        message.data = MessageData.getPrivateGroupInvitation(message);
        logger.d("$TAG - resendMute - group invitee - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        break;
      default:
        logger.w("$TAG - resendMute - wrong type - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        // int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
        // return await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
        return null;
    }
    if (mute) {
      // notification
      bool notification;
      if (message.isTargetTopic || message.isTargetGroup) {
        notification = false;
      } else {
        bool noReceipt = message.status < MessageStatus.Receipt;
        String pushNotifyId = MessageOptions.getPushNotifyId(message.options) ?? "";
        notification = noReceipt && pushNotifyId.isEmpty;
      }
      // send_mute
      MessageSchema? result = await _send(message, insert: false, sessionSync: false, statusSync: false, notification: notification);
      if (result != null) {
        logger.i("$TAG - resendMute - success mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringSimple()}");
        result.options = MessageOptions.setResendMuteAt(result.options, DateTime.now().millisecondsSinceEpoch);
        await messageCommon.updateMessageOptions(result, result.options, notify: false);
      } else {
        logger.w("$TAG - resendMute - fail mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringSimple()}");
      }
      return result;
    }
    // send
    return await _send(message, insert: false);
  }

  Future<MessageSchema?> insertMessage(MessageSchema? message, {bool notify = true}) async {
    if (message == null) return null;
    message = await messageCommon.insert(message); // DB
    if (message == null) return null;
    if (notify) messageCommon.onSavedSink.add(message); // display, resend just update sendTime
    return message;
  }

  Future<MessageSchema?> _send(
    MessageSchema? message, {
    bool insert = true,
    bool sessionSync = true,
    bool statusSync = true,
    bool? notification,
  }) async {
    if (message == null || message.data == null) return null;
    if (insert) message = await insertMessage(message);
    if (message == null) return null;
    // session
    if (sessionSync) await chatCommon.sessionHandle(message);
    // sdk
    Uint8List? pid;
    if (message.isTargetTopic) {
      TopicSchema? topic = await chatCommon.topicHandle(message);
      bool pushNotification = message.canNotification && (notification != false);
      pid = await _sendWithTopic(topic, message, notification: pushNotification);
    } else if (message.isTargetGroup) {
      PrivateGroupSchema? group = await chatCommon.privateGroupHandle(message);
      // FUTURE:GG (group.options?.notificationOpen == true)
      bool pushNotification = message.canNotification && (notification != false);
      pid = await _sendWithPrivateGroup(group, message, notification: pushNotification);
    } else if (message.isTargetContact) {
      ContactSchema? contact = await chatCommon.contactHandle(message);
      bool pushNotification = message.canNotification && (contact?.options.notificationOpen == true) && (notification != false);
      pid = await _sendWithContact(contact, message, notification: pushNotification);
    } else {
      logger.e("$TAG - _send - with_error - type:${message.contentType} - message:${message.toStringSimple()}");
      return null;
    }
    bool sendSuccess = pid?.isNotEmpty == true;
    // pid
    if (sendSuccess) {
      bool success = await messageCommon.updatePid(message.msgId, message.pid);
      if (success) message.pid = pid;
    } else {
      logger.w("$TAG - _send - pid is null - type:${message.contentType} - message:${message.toStringSimple()}");
    }
    // queue_id (before set status success)
    if (message.canQueue && sendSuccess) {
      if (message.isTargetContact && !message.isTargetSelf) {
        String? queueIds = MessageOptions.getMessageQueueIds(message.options);
        String? deviceId = deviceInfoCommon.splitQueueIds(queueIds)[3];
        await messageCommon.onContactMessageQueueSendSuccess(message.targetId, deviceId, message.queueId);
      }
    }
    // status
    if (statusSync) {
      if (sendSuccess) {
        if (message.canReceipt) {
          message = await messageCommon.updateMessageStatus(message, MessageStatus.Success);
        } else {
          // no received receipt/read
          int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          message = await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
        }
      } else {
        if (message.canReceipt) {
          message = await messageCommon.updateMessageStatus(message, MessageStatus.Error, force: true);
        } else {
          // noResend just delete
          int count = await messageCommon.delete(message.msgId, message.contentType);
          if (count > 0) messageCommon.onDeleteSink.add(message.msgId);
        }
      }
    }
    return sendSuccess ? message : null;
  }

  Future<Uint8List?> _sendWithAddress(List<String> targetAddressList, String? data) async {
    if (targetAddressList.isEmpty || data == null) return null;
    logger.d("$TAG - _sendWithAddress - count:${targetAddressList.length} - addressList:$targetAddressList");
    return (await sendMsg(targetAddressList, data))?.messageId;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, {bool notification = false}) async {
    String? data = message?.data;
    if (message == null || data == null) {
      logger.e("$TAG - _sendWithContact - data == null - message:${message?.toStringSimple()}");
      return null;
    }
    logger.d("$TAG - _sendWithContact - type:${message.contentType} - target:${contact?.address} - message:${message.toStringSimple()}");
    // send
    Uint8List? pid;
    bool tryNoPiece = true;
    if (message.canTryPiece) {
      try {
        List result = await _sendWithPieces([message.targetId], message);
        pid = result[0];
        tryNoPiece = result[1];
      } catch (e, st) {
        handleError(e, st);
        return null;
      }
    }
    if (tryNoPiece && ((pid == null) || pid.isEmpty)) {
      pid = (await sendMsg([message.targetId], data))?.messageId;
    }
    if (pid == null || pid.isEmpty) return pid;
    // notification
    if (notification && (contact != null) && !contact.isMe) {
      deviceInfoCommon.queryDeviceTokenList(contact.address).then((tokens) async {
        logger.d("$TAG - _sendWithContact - push notification - count:${tokens.length} - target:${contact.address} - tokens:$tokens");
        List<String> results = await RemoteNotification.send(tokens);
        if (results.isNotEmpty) {
          message.options = MessageOptions.setPushNotifyId(message.options, results[0]);
          await messageCommon.updateMessageOptions(message, message.options, notify: false);
        }
      });
    }
    return pid;
  }

  Future<Uint8List?> _sendWithTopic(TopicSchema? topic, MessageSchema? message, {bool notification = false}) async {
    String? data = message?.data;
    if ((topic == null) || (message == null) || (data == null)) {
      logger.e("$TAG - _sendWithTopic - topic/data == null - topic:${topic?.topicId} - message:${message?.toStringSimple()}");
      return null;
    }
    // me
    SubscriberSchema? _me = await subscriberCommon.query(message.targetId, message.sender); // chatOutCommon.handleSubscribe();
    bool checkStatus = message.contentType == MessageContentType.topicUnsubscribe;
    if (!checkStatus && (_me?.status != SubscriberStatus.Subscribed)) {
      logger.w("$TAG - _sendWithTopic - subscriber me is wrong - type:${message.contentType} - me:$_me - message:${message.toStringSimple()}");
      return null;
    }
    // subscribers
    final limit = 20;
    List<SubscriberSchema> _subscribers = [];
    for (int offset = 0; true; offset += limit) {
      List<SubscriberSchema> result = await subscriberCommon.queryListByTopicId(topic.topicId, status: SubscriberStatus.Subscribed, offset: offset, limit: limit);
      _subscribers.addAll(result);
      if (result.length < limit) break;
    }
    if (message.contentType == MessageContentType.topicKickOut) {
      logger.i("$TAG - _sendWithTopic - add kick people - type:${message.contentType} - clientAddress:${message.content}");
      SubscriberSchema? kicked = SubscriberSchema.create(topic.topicId, message.content?.toString(), SubscriberStatus.None, null);
      if (kicked != null) _subscribers.add(kicked);
    }
    if (_subscribers.isEmpty) return null;
    // destList
    bool selfIsReceiver = false;
    List<String> destList = [];
    for (var i = 0; i < _subscribers.length; i++) {
      String clientAddress = _subscribers[i].contactAddress;
      if (clientAddress == message.sender) {
        selfIsReceiver = true;
      } else {
        destList.add(clientAddress);
      }
    }
    logger.d("$TAG - _sendWithTopic - type:${message.contentType} - topic:${topic.topicId} - self:$selfIsReceiver - dest_count:${destList.length} - message:${message.toStringSimple()}");
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      bool tryNoPiece = true;
      if (message.canTryPiece) {
        try {
          List result = await _sendWithPieces(destList, message);
          pid = result[0];
          tryNoPiece = result[1];
        } catch (e, st) {
          handleError(e, st);
          return null;
        }
      }
      if (tryNoPiece && ((pid == null) || pid.isEmpty)) {
        pid = (await sendMsg(destList, data))?.messageId;
      }
    }
    bool success = destList.isEmpty || (destList.isNotEmpty && !(pid == null || pid.isEmpty));
    // self
    if (success && selfIsReceiver) {
      String data = message.canReceipt ? MessageData.getReceipt(message.msgId) : MessageData.getPing(true);
      Uint8List? _pid = (await sendMsg([message.sender], data))?.messageId;
      if (destList.isEmpty && (_pid != null)) pid = _pid;
    }
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    if (!success) return null;
    // notification
    if (notification && destList.isNotEmpty) {
      contactCommon.queryListByAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.address).then((tokens) {
            logger.d("$TAG - _sendWithTopic - push notification - count:${tokens.length} - target:${_contact.address} - topic:${topic.topicId} - tokens:$tokens");
            RemoteNotification.send(tokens); // await // no need result
          });
        }
      });
    }
    return pid;
  }

  Future<Uint8List?> _sendWithPrivateGroup(PrivateGroupSchema? group, MessageSchema? message, {bool notification = false}) async {
    String? data = message?.data;
    if ((group == null) || (message == null) || (data == null)) {
      logger.e("$TAG - _sendWithPrivateGroup - group/data == null - group:${group?.groupId} - message:${message?.toStringSimple()}");
      return null;
    }
    // me
    PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(group.groupId, message.sender);
    if ((_me == null) || (_me.permission <= PrivateGroupItemPerm.none)) {
      logger.w("$TAG - _sendWithPrivateGroup - member me is null - type:${message.contentType} - me:$_me - group:$group - message:${message.toStringSimple()}");
      return null;
    }
    // destList
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(message.targetId);
    bool selfIsReceiver = false;
    List<String> destList = [];
    for (var i = 0; i < members.length; i++) {
      String? clientAddress = members[i].invitee;
      if (clientAddress == null || clientAddress.isEmpty) continue;
      if (clientAddress == message.sender) {
        selfIsReceiver = true;
      } else if (members[i].permission > PrivateGroupItemPerm.none) {
        destList.add(clientAddress);
      }
    }
    logger.d("$TAG - _sendWithPrivateGroup - type:${message.contentType} - groupId:${group.groupId} - self:$selfIsReceiver - dest_count:${destList.length} - message:${message.toStringSimple()}");
    // send
    Uint8List? pid;
    if (destList.isNotEmpty) {
      bool tryNoPiece = true;
      if (message.canTryPiece) {
        try {
          List result = await _sendWithPieces(destList, message);
          pid = result[0];
          tryNoPiece = result[1];
        } catch (e, st) {
          handleError(e, st);
          return null;
        }
      }
      if (tryNoPiece && ((pid == null) || pid.isEmpty)) {
        pid = (await sendMsg(destList, data))?.messageId;
      }
    }
    bool success = destList.isEmpty || (destList.isNotEmpty && !(pid == null || pid.isEmpty));
    // self
    if (success && selfIsReceiver) {
      String data = message.canReceipt ? MessageData.getReceipt(message.msgId) : MessageData.getPing(true);
      Uint8List? _pid = (await sendMsg([message.sender], data))?.messageId;
      if (destList.isEmpty && (_pid != null)) pid = _pid;
    }
    if (!success) return null;
    // notification
    if (notification && destList.isNotEmpty) {
      contactCommon.queryListByAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.address).then((tokens) {
            logger.d("$TAG - _sendWithPrivateGroup - push notification - count:${tokens.length} - target:${_contact.address} - groupId:${group.groupId} - tokens:$tokens");
            RemoteNotification.send(tokens); // await // no need result
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
      logger.e("$TAG - _sendWithPieces:ERROR - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType}");
      return [null, false];
    }
    logger.i("$TAG - _sendWithPieces:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType}");

    List<MessageSchema> resultList = [];
    for (var index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      Map<String, dynamic> options = Map();
      options.addAll(message.options ?? Map()); // new *
      MessageSchema piece = MessageSchema.fromSend(
        message.targetId,
        message.targetType,
        MessageContentType.piece,
        base64Encode(data),
        msgId: message.msgId,
        queueId: message.queueId,
        options: options,
        extra: {
          "piece_parent_type": MessageSchema.supportContentType(message.contentType),
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
      logger.i("$TAG - _sendWithPieces:SUCCESS - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType} - message:${message.toStringSimple()}");
      if (finds.isNotEmpty) return [finds.firstWhere((element) => element.pid != null).pid, true];
    }
    logger.w("$TAG - _sendWithPieces:FAIL - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType} - message:${message.toStringSimple()}");
    return [null, false];
  }

  Future<MessageSchema?> _sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    if (!(await clientCommon.waitClientOk())) return null;
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendMsg(clientAddressList, data);
    if ((onResult == null) || (onResult.messageId?.isEmpty == true)) {
      logger.w("$TAG - _sendPiece - fail - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]}+${message.options?[MessageOptions.KEY_PIECE_PARITY]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringSimple()}");
      return null;
    }
    logger.d("$TAG - _sendPiece - success - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]}+${message.options?[MessageOptions.KEY_PIECE_PARITY]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringSimple()}");
    message.pid = onResult.messageId;
    // progress
    if ((percent > 0) && (percent <= 1)) {
      if (percent <= 1.05) {
        // logger.v("$TAG - _sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:${message.toStringNoContent()}");
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    } else {
      int? total = message.options?[MessageOptions.KEY_PIECE_TOTAL];
      int? index = message.options?[MessageOptions.KEY_PIECE_INDEX];
      int? parity = message.options?[MessageOptions.KEY_PIECE_PARITY];
      double percent = ((index ?? 0) + 1) / ((total ?? 1) + (parity ?? 0));
      if (percent <= 1.05) {
        // logger.v("$TAG - _sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:${message.toStringNoContent()}");
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    }
    return message;
  }
}
