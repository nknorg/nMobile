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
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';

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
        logger.w("$TAG - sendMsg - try over - count:${destList.length} - destList:$destList");
      }
      return onMessage;
    });
  }

  Future<List<dynamic>> _sendData(List<String> destList, String data, {bool lastTime = false}) async {
    if (!(await _waitClientOk())) return [null, true, 100];
    // logger.v("$TAG - _sendData - send start - destList:$destList");
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId?.isNotEmpty == true) {
        logger.v("$TAG - _sendData - send success - count:${destList.length} - destList:$destList");
      } else {
        logger.e("$TAG - _sendData - pid is empty - count:${destList.length} - destList:$destList");
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
        if (clientCommon.isClientConnecting) return [null, true, 1000];
        logger.w("$TAG - _sendData - reConnect - count:${destList.length} - destList:$destList");
        bool success = await clientCommon.reConnect(reSignIn: lastTime);
        return [null, true, success ? 500 : 1000];
      }
      handleError(e, st);
      logger.e("$TAG - _sendData - try by unknown error - count:${destList.length} - destList:$destList");
    }
    return [null, true, 500];
  }

  Future<bool> _waitClientOk() async {
    int tryTimes = 0;
    // wait ios tcp pipe ok
    if (Platform.isIOS) {
      int gapForeground = DateTime.now().millisecondsSinceEpoch - application.goForegroundAt;
      if (gapForeground < 500) {
        await Future.delayed(Duration(milliseconds: 500 - gapForeground));
      }
    }
    // check client status
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
      ContactSchema? _other = await contactCommon.queryByClientAddress(destList[0]);
      bool notificationOpen = _other?.options?.notificationOpen == true;
      String? deviceToken = notificationOpen ? (await deviceInfoCommon.getMe(canAdd: true, fetchDeviceToken: true))?.deviceToken : null;
      DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(_other?.clientAddress); // just can latest
      String? queueIds = deviceInfoCommon.joinQueueIdsByDevice(device);
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
    if (received.isTargetTopic || received.isTargetGroup) return false; // topic/group no receipt, just send message to myself
    if (received.sender.isEmpty) return false;
    String data = MessageData.getReceipt(received.msgId);
    logger.i("$TAG - sendReceipt - dest:${received.sender} - msgId:${received.msgId}");
    Uint8List? pid = await _sendWithAddress([received.sender], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendRead(String? targetAddress, List<String> msgIds) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty || msgIds.isEmpty) return false; // topic/group no read, just like receipt
    String data = MessageData.getRead(msgIds);
    logger.i("$TAG - sendRead - dest:$targetAddress - count:${msgIds.length} - msgIds:$msgIds");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendQueue(String? targetAddress, String? targetDeviceId) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return false;
    String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetAddress, targetDeviceId);
    if (queueIds == null) return false;
    String data = MessageData.getQueue(queueIds);
    logger.i("$TAG - sendQueue - dest:$targetAddress - queueIds:$queueIds");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileRequest(String? targetAddress, String requestType, String? profileVersion) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    String data = MessageData.getContactProfileRequest(requestType, profileVersion);
    logger.i("$TAG - sendContactProfileRequest - dest:$targetAddress - requestType:${requestType == ContactRequestType.full ? "full" : "header"} - profileVersion:$profileVersion");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileResponse(String? targetAddress, ContactSchema? contactMe, String requestType, {DeviceInfoSchema? deviceInfo, int gap = 0}) async {
    if (!(await _waitClientOk())) return false;
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
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      MessageTargetType.Contact,
      MessageContentType.contactOptions,
      null,
      extra: {
        "deleteAfterSeconds": deleteSeconds,
        "burningUpdateAt": updateAt,
      },
    );
    message.content = MessageData.getContactOptionsBurn(message); // same with receive and old version
    message.data = message.content;
    logger.i("$TAG - sendContactOptionsBurn - dest:$targetAddress - deleteSeconds:$deleteSeconds - updateAt:$updateAt");
    var result = await _send(message);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsToken(String? targetAddress, String? deviceToken) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      MessageTargetType.Contact,
      MessageContentType.contactOptions,
      null,
      extra: {
        "deviceToken": deviceToken,
      },
    );
    message.content = MessageData.getContactOptionsToken(message); // same with receive and old version
    message.data = message.content;
    logger.i("$TAG - sendContactOptionsToken - dest:$targetAddress - deviceToken:$deviceToken");
    var result = await _send(message);
    return result != null;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceRequest(String? targetAddress) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    String data = MessageData.getDeviceRequest();
    logger.i("$TAG - sendDeviceRequest - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceInfo(String? targetAddress, DeviceInfoSchema selfDeviceInfo, bool withToken, {DeviceInfoSchema? targetDeviceInfo, int gap = 0}) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if ((targetDeviceInfo != null) && (gap > 0)) {
      int lastAt = targetDeviceInfo.deviceInfoResponseAt;
      int interval = DateTime.now().millisecondsSinceEpoch - lastAt;
      if (interval < gap) {
        logger.d('$TAG - sendDeviceInfo - gap small - gap:$interval<$gap - target:$targetAddress');
        return false;
      }
    }
    if (!withToken) selfDeviceInfo.deviceToken = null;
    String data = MessageData.getDeviceInfo(selfDeviceInfo);
    logger.i("$TAG - sendDeviceInfo - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> sendText(dynamic target, String? content) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || content.trim().isEmpty) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.clientAddress;
      targetType = MessageTargetType.Contact;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topic;
      targetType = MessageTargetType.Topic;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = MessageTargetType.Group;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    if (message.canQueue) {
      if (message.isTargetContact && !message.isTargetSelf) {
        DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(targetId); // just can latest
        if ((device != null) && DeviceInfoCommon.isMessageQueueEnable(device.platform, device.appVersion)) {
          message.queueId = await messageCommon.newContactMessageQueueId(targetId, device.deviceId, message.msgId);
          if (message.queueId > 0) {
            String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetId, device.deviceId);
            if (queueIds != null) message.options = MessageOptions.setMessageQueueIds(message.options, queueIds);
          }
        }
      } else {
        // nothing
      }
    }
    // data
    message.data = MessageData.getText(message);
    logger.i("$TAG - sendText - targetId:$targetId - content:$content - data:${message.data}");
    return await _send(message);
  }

  Future<MessageSchema?> saveIpfs(dynamic target, Map<String, dynamic> data) async {
    if (!(await _waitClientOk())) return null;
    // content
    String contentPath = data["path"]?.toString() ?? "";
    File? content = contentPath.isEmpty ? null : File(contentPath);
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) {
      logger.w("$TAG - saveIpfs - contact is null - data:$data");
      return null;
    }
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.clientAddress;
      targetType = MessageTargetType.Contact;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topic;
      targetType = MessageTargetType.Topic;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = MessageTargetType.Group;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    if (message.canQueue) {
      if (message.isTargetContact && !message.isTargetSelf) {
        DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(targetId); // just can latest
        if ((device != null) && DeviceInfoCommon.isMessageQueueEnable(device.platform, device.appVersion)) {
          message.queueId = await messageCommon.newContactMessageQueueId(targetId, device.deviceId, message.msgId);
          if (message.queueId > 0) {
            String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetId, device.deviceId);
            if (queueIds != null) message.options = MessageOptions.setMessageQueueIds(message.options, queueIds);
          }
        }
      } else {
        // nothing
      }
    }
    // insert
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
    }
    logger.i("$TAG - saveIpfs - targetId:$targetId - data:$data");
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
    MessageSchema? message = await messageCommon.query(msgId);
    if (message == null) return null;
    // data
    message.data = MessageData.getIpfs(message);
    logger.i("$TAG - sendIpfs - targetId:${message.targetId} - data:${message.data}");
    return await _send(message, insert: false);
  }

  Future<MessageSchema?> sendImage(dynamic target, File? content) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.clientAddress;
      targetType = MessageTargetType.Contact;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topic;
      targetType = MessageTargetType.Topic;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = MessageTargetType.Group;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    if (message.canQueue) {
      if (message.isTargetContact && !message.isTargetSelf) {
        DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(targetId); // just can latest
        if ((device != null) && DeviceInfoCommon.isMessageQueueEnable(device.platform, device.appVersion)) {
          message.queueId = await messageCommon.newContactMessageQueueId(targetId, device.deviceId, message.msgId);
          if (message.queueId > 0) {
            String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetId, device.deviceId);
            if (queueIds != null) message.options = MessageOptions.setMessageQueueIds(message.options, queueIds);
          }
        }
      } else {
        // nothing
      }
    }
    // data
    message.data = await MessageData.getImage(message);
    logger.i("$TAG - sendImage - targetId:$targetId - path:${content.absolute.path} - message:${message.toStringNoContent()}");
    return await _send(message);
  }

  Future<MessageSchema?> sendAudio(dynamic target, File? content, double? durationS) async {
    if (!(await _waitClientOk())) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetId = "";
    int targetType = 0;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    String? privateGroupVersion;
    if (target is ContactSchema) {
      targetId = target.clientAddress;
      targetType = MessageTargetType.Contact;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is TopicSchema) {
      targetId = target.topic;
      targetType = MessageTargetType.Topic;
    } else if (target is PrivateGroupSchema) {
      targetId = target.groupId;
      targetType = MessageTargetType.Group;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    if (message.canQueue) {
      if (message.isTargetContact && !message.isTargetSelf) {
        DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(targetId); // just can latest
        if ((device != null) && DeviceInfoCommon.isMessageQueueEnable(device.platform, device.appVersion)) {
          message.queueId = await messageCommon.newContactMessageQueueId(targetId, device.deviceId, message.msgId);
          if (message.queueId > 0) {
            String? queueIds = await deviceInfoCommon.joinQueueIdsByAddressDeviceId(targetId, device.deviceId);
            if (queueIds != null) message.options = MessageOptions.setMessageQueueIds(message.options, queueIds);
          }
        }
      } else {
        // nothing
      }
    }
    // data
    message.data = await MessageData.getAudio(message);
    logger.i("$TAG - sendAudio - targetId:$targetId - path:${content.absolute.path} - message:${message.toStringNoContent()}");
    return await _send(message);
  }

  // NO DB NO single
  Future<bool> sendTopicSubscribe(String? topic) async {
    if (!(await _waitClientOk())) return false;
    if (topic == null || topic.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topic,
      MessageTargetType.Topic,
      MessageContentType.topicSubscribe,
      null,
    );
    message.data = MessageData.getTopicSubscribe(message);
    logger.i("$TAG - sendTopicSubscribe - dest:$topic - data:${message.data}");
    var result = await _send(message);
    return result != null;
  }

  // NO DB NO single
  Future<bool> sendTopicUnSubscribe(String? topic) async {
    if (!(await _waitClientOk())) return false;
    if (topic == null || topic.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topic,
      MessageTargetType.Topic,
      MessageContentType.topicUnsubscribe,
      null,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(message);
    message.data = MessageData.getTopicUnSubscribe(message);
    logger.i("$TAG - sendTopicUnSubscribe - dest:$topic - data:${message.data}");
    var result = await _sendWithTopic(_schema, message, notification: false);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? targetAddress, String? topic) async {
    if (!(await _waitClientOk())) return null;
    if (targetAddress == null || targetAddress.isEmpty || topic == null || topic.isEmpty) return null;
    ContactSchema? me = await contactCommon.getMe();
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      MessageTargetType.Contact,
      MessageContentType.topicInvitation,
      topic,
      extra: {
        "profileVersion": me?.profileVersion,
      },
    );
    message.data = MessageData.getTopicInvitee(message);
    logger.i("$TAG - sendTopicInvitee - dest:$topic - invitee:$targetAddress - data:${message.data}");
    return await _send(message);
  }

  // NO DB NO single
  Future<bool> sendTopicKickOut(String? topic, String? kickAddress) async {
    if (!(await _waitClientOk())) return false;
    if (topic == null || topic.isEmpty || kickAddress == null || kickAddress.isEmpty) return false;
    MessageSchema message = MessageSchema.fromSend(
      topic,
      MessageTargetType.Topic,
      MessageContentType.topicKickOut,
      kickAddress,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(message);
    message.data = MessageData.getTopicKickOut(message);
    logger.i("$TAG - sendTopicKickOut - dest:$topic - kick:$kickAddress - data:${message.data}");
    var result = await _sendWithTopic(_schema, message, notification: false);
    return result != null;
  }

  // NO group (1 to 1)
  Future<MessageSchema?> sendPrivateGroupInvitee(String? targetAddress, PrivateGroupSchema? privateGroup, PrivateGroupItemSchema? groupItem) async {
    if (!(await _waitClientOk())) return null;
    if (targetAddress == null || targetAddress.isEmpty) return null;
    if (privateGroup == null || groupItem == null) return null;
    MessageSchema message = MessageSchema.fromSend(
      targetAddress,
      MessageTargetType.Contact,
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
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupAccept(groupItem);
    logger.i("$TAG - sendPrivateGroupAccept - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupQuit(String? targetAddress, PrivateGroupItemSchema? groupItem) async {
    if (!(await _waitClientOk())) return false;
    if (targetAddress == null || targetAddress.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupQuit(groupItem);
    logger.i("$TAG - sendPrivateGroupQuit - dest:$targetAddress - data:$data");
    Uint8List? pid = await _sendWithAddress([targetAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupOptionRequest(String? targetAddress, String? groupId, {int gap = 0}) async {
    if (!(await _waitClientOk())) return false;
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
    if (!(await _waitClientOk())) return false;
    if (targetAddressList.isEmpty || targetAddressList[0].isEmpty) return false;
    if (group == null) return false;
    String data = MessageData.getPrivateGroupOptionResponse(group);
    logger.i("$TAG - sendPrivateGroupOptionResponse - count:${targetAddressList.length} - dest:$targetAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(targetAddressList, data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupMemberRequest(String? targetAddress, String? groupId, {int gap = 0}) async {
    if (!(await _waitClientOk())) return false;
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
    if (!(await _waitClientOk())) return false;
    if (targetAddressList.isEmpty || targetAddressList[0].isEmpty) return false;
    if (schema == null) return false;
    List<Map<String, dynamic>> membersData = privateGroupCommon.getMembersData(members);
    String data = MessageData.getPrivateGroupMemberResponse(schema, membersData);
    logger.i("$TAG - sendPrivateGroupMemberResponse - dest:$targetAddressList - data:$data");
    Uint8List? pid = await _sendWithAddress(targetAddressList, data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> resend(MessageSchema? message, {bool mute = false, int muteGap = 0}) async {
    if (message == null) return null;
    // reSendAt
    if (mute && (muteGap > 0)) {
      int resendMuteAt = MessageOptions.getResendMuteAt(message.options) ?? 0;
      if (resendMuteAt <= 0) {
        logger.d("$TAG - resendMute - resend first no interval - targetId:${message.targetId} - message:${message.toStringNoContent()}");
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
    if (message.canQueue) {
      if (message.isTargetContact && !message.isTargetSelf) {
        DeviceInfoSchema? device = await deviceInfoCommon.queryLatest(message.targetId); // must be latest
        if ((device != null) && DeviceInfoCommon.isMessageQueueEnable(device.platform, device.appVersion)) {
          String? newQueueIds = deviceInfoCommon.joinQueueIdsByDevice(device);
          String? oldQueueIds = MessageOptions.getMessageQueueIds(message.options);
          if ((newQueueIds != null) && newQueueIds.isNotEmpty) {
            if (message.status == MessageStatus.Error) {
              message.deviceId = device.deviceId;
              message.queueId = await messageCommon.newContactMessageQueueId(message.targetId, message.deviceId, message.msgId);
              if (message.queueId > 0) {
                logger.i("$TAG - resendMute - queueIds new success - queueId:${message.queueId} - newQueueIds:$newQueueIds - oldQueueIds:$oldQueueIds - targetId:${message.targetId}");
                bool success = await messageCommon.updateDeviceQueueId(message.msgId, message.deviceId, message.queueId);
                if (!success) return null;
                message.options = MessageOptions.setMessageQueueIds(message.options, newQueueIds);
                await messageCommon.updateMessageOptions(message, message.options, notify: true);
              } else {
                logger.w("$TAG - resendMute - queueIds new fail - device:$device - targetId:${message.targetId}");
              }
            } else {
              logger.d("$TAG - resendMute - replace old queueIds - queueId:${message.queueId} - newQueueIds:$newQueueIds - oldQueueIds:$oldQueueIds - options:${message.options} - targetId:${message.targetId}");
              message.options = MessageOptions.setMessageQueueIds(message.options, newQueueIds);
              await messageCommon.updateMessageOptions(message, message.options, notify: true);
            }
          } else {
            logger.w("$TAG - resendMute - newQueueIds == null - oldQueueIds:$oldQueueIds - device:$device - targetId:${message.targetId}");
          }
        }
      }
    }
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
      }
    }
    // send
    switch (message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        logger.d("$TAG - resendMute - text - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        message.data = MessageData.getText(message);
        break;
      case MessageContentType.ipfs:
        logger.d("$TAG - resendMute - ipfs - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        message.data = MessageData.getIpfs(message);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        logger.d("$TAG - resendMute - image - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        message.data = await MessageData.getImage(message);
        break;
      case MessageContentType.audio:
        logger.d("$TAG - resendMute - audio - mute:$mute - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        message.data = await MessageData.getAudio(message);
        break;
      case MessageContentType.topicInvitation:
        logger.d("$TAG - resendMute - topic invitee - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        message.data = MessageData.getTopicInvitee(message);
        break;
      case MessageContentType.privateGroupInvitation:
        logger.d("$TAG - resendMute - group invitee - mute:$mute - targetId:${message.targetId} - data:${message.data}");
        message.data = MessageData.getPrivateGroupInvitation(message);
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
        logger.i("$TAG - resendMute - success mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringNoContent()}");
        result.options = MessageOptions.setResendMuteAt(result.options, DateTime.now().millisecondsSinceEpoch);
        await messageCommon.updateMessageOptions(result, result.options, notify: false);
      } else {
        logger.w("$TAG - resendMute - fail mute - type:${message.contentType} - targetId:${message.targetId} - message:${message.toStringNoContent()}");
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
      bool pushNotification = message.canNotification && (contact?.options?.notificationOpen == true) && (notification != false);
      pid = await _sendWithContact(contact, message, notification: pushNotification);
    } else {
      logger.e("$TAG - _send - with_error - type:${message.contentType} - message:${message.toStringNoContent()}");
      return null;
    }
    bool sendSuccess = pid?.isNotEmpty == true;
    // pid
    if (sendSuccess) {
      bool success = await messageCommon.updatePid(message.msgId, message.pid);
      if (success) message.pid = pid;
    } else {
      logger.w("$TAG - _send - pid is null - type:${message.contentType} - message:${message.toStringNoContent()}");
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
      logger.e("$TAG - _sendWithContact - data == null - message:${message?.toStringNoContent()}");
      return null;
    }
    logger.d("$TAG - _sendWithContact - type:${message.contentType} - target:${contact?.clientAddress} - message:${message.toStringNoContent()}");
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
      deviceInfoCommon.queryDeviceTokenList(contact.clientAddress).then((tokens) async {
        logger.d("$TAG - _sendWithContact - push notification - count:${tokens.length} - target:${contact.clientAddress} - tokens:$tokens");
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
      logger.e("$TAG - _sendWithTopic - topic/data == null - topic:${topic?.topic} - message:${message?.toStringNoContent()}");
      return null;
    }
    // me
    SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(message.targetId, message.sender); // chatOutCommon.handleSubscribe();
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
      if (clientAddress == message.sender) {
        selfIsReceiver = true;
      } else {
        destList.add(clientAddress);
      }
    }
    logger.d("$TAG - _sendWithTopic - type:${message.contentType} - topic:${topic.topic} - self:$selfIsReceiver - dest_count:${destList.length} - message:${message.toStringNoContent()}");
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
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg([message.sender], data))?.messageId;
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
      logger.e("$TAG - _sendWithPrivateGroup - group/data == null - group:${group?.groupId} - message:${message?.toStringNoContent()}");
      return null;
    }
    // me
    PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(group.groupId, message.sender);
    if ((_me == null) || ((_me.permission ?? 0) <= PrivateGroupItemPerm.none)) {
      logger.w("$TAG - _sendWithPrivateGroup - member me is null - type:${message.contentType} - me:$_me - group:$group - message:${message.toStringNoContent()}");
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
      } else if ((members[i].permission ?? 0) > PrivateGroupItemPerm.none) {
        destList.add(clientAddress);
      }
    }
    logger.d("$TAG - _sendWithPrivateGroup - type:${message.contentType} - groupId:${group.groupId} - self:$selfIsReceiver - dest_count:${destList.length} - message:${message.toStringNoContent()}");
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
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg([message.sender], data))?.messageId;
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
      logger.i("$TAG - _sendWithPieces:SUCCESS - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType} - message:${message.toStringNoContent()}");
      if (finds.isNotEmpty) return [finds.firstWhere((element) => element.pid != null).pid, true];
    }
    logger.w("$TAG - _sendWithPieces:FAIL - count:${resultList.length} - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - parentType:${message.contentType} - message:${message.toStringNoContent()}");
    return [null, false];
  }

  Future<MessageSchema?> _sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    if (!(await _waitClientOk())) return null;
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendMsg(clientAddressList, data);
    if ((onResult == null) || (onResult.messageId?.isEmpty == true)) {
      logger.w("$TAG - _sendPiece - fail - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_PARITY]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringNoContent()}");
      return null;
    }
    logger.d("$TAG - _sendPiece - success - progress:${message.options?[MessageOptions.KEY_PIECE_INDEX]}/${message.options?[MessageOptions.KEY_PIECE_PARITY]}/${message.options?[MessageOptions.KEY_PIECE_TOTAL]} - parentType:${message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]} - message:${message.toStringNoContent()}");
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
      double percent = (index ?? 0) / (total ?? 1);
      if (percent <= 1.05) {
        // logger.v("$TAG - _sendPiece - success - index:$index - total:$total - time:$timeNowAt - message:${message.toStringNoContent()}");
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      }
    }
    return message;
  }
}
