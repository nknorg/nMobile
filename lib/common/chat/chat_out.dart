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

  void reset({bool reClient = false, bool netError = false}) {
    if (!reClient) {
      _sendQueue.cancel();
      _sendQueue = ParallelQueue("chat_send", onLog: (log, error) => error ? logger.w(log) : null);
      _resendQueue.cancel();
      _resendQueue = ParallelQueue("chat_resend", onLog: (log, error) => error ? logger.w(log) : null);
    }
  }

  // queue
  ParallelQueue _sendQueue = ParallelQueue("chat_send", onLog: (log, error) => error ? logger.w(log) : null);
  ParallelQueue _resendQueue = ParallelQueue("chat_resend", onLog: (log, error) => error ? logger.w(log) : null);

  Future<OnMessage?> sendMsg(String? selfAddress, List<String> destList, String data) async {
    // dest
    destList = destList.where((element) => element.isNotEmpty).toList();
    if (destList.isEmpty) {
      logger.e("$TAG - sendMsg - destList is empty - destList:$destList - data:$data");
      return null;
    }
    // size
    if (data.length >= Settings.sizeMsgMax) {
      logger.w("$TAG - sendMsg - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
      // Sentry.captureMessage("$TAG - sendData - size over - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
      // return null;
    }
    // client
    int tryTimes = 0;
    while (tryTimes < Settings.tryTimesSendMsgUntilClientOk) {
      if (clientCommon.isClientOK && (selfAddress == clientCommon.address)) break;
      logger.w("$TAG - sendMsg - client no ok - tryTimes:${tryTimes + 1} - destList:$destList - data:$data");
      tryTimes++;
      int waitMs = (10 * 1000) ~/ Settings.tryTimesSendMsgUntilClientOk; // 500ms
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    if (tryTimes >= Settings.tryTimesSendMsgUntilClientOk) return null;
    // send
    return await _sendQueue.add(() async {
      OnMessage? onMessage;
      int tryTimes = 0;
      while (tryTimes < Settings.tryTimesSendMsg) {
        List<dynamic> result = await _sendData(selfAddress, destList, data);
        bool canTry = result[0];
        onMessage = result[1];
        int delay = result[2];
        if (!canTry) break;
        if (onMessage?.messageId.isNotEmpty == true) break;
        tryTimes++;
        await Future.delayed(Duration(milliseconds: delay)); // TODO:GG 会delay吗?
      }
      if (tryTimes >= Settings.tryTimesSendMsg) {
        logger.w("$TAG - sendMsg - try over - destList:$destList - data:$data");
      }
      return onMessage;
    });
  }

  Future<List<dynamic>> _sendData(String? selfAddress, List<String> destList, String data) async {
    try {
      OnMessage? onMessage = await clientCommon.client?.sendText(destList, data);
      if (onMessage?.messageId.isNotEmpty == true) {
        logger.d("$TAG - _sendData - send success - destList:$destList - data:$data");
      } else {
        logger.e("$TAG - _sendData - onMessage msgId is empty - - destList:$destList - data:$data");
      }
      return [true, onMessage, 100];
    } catch (e, st) {
      String errStr = e.toString().toLowerCase();
      if (errStr.contains(NknError.invalidDestination)) {
        logger.e("$TAG - _sendData - wrong clientAddress - destList:$destList");
        return [false, null, 0];
      } else if (errStr.contains(NknError.messageOversize)) {
        logger.e("$TAG - _sendData - message over size - size:${Format.flowSize(data.length.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - destList:$destList - data:$data");
        return [false, null, 0];
      }
      handleError(e, st);
      if (NknError.isClientError(e)) {
        // if (clientCommon.isConnected) return [true, null, 100];
        if (clientCommon.isConnecting) return [true, null, 500];
        logger.i("$TAG - _sendData - reSignIn - destList:$destList data:$data");
        bool success = await clientCommon.reLogin(false);
        return [true, null, success ? 500 : 1000];
      }
      logger.e("$TAG - _sendData - try by error - destList:$destList - data:$data");
    }
    return [true, null, 250];
  }

  // NO DB NO display NO topic (1 to 1)
  Future sendPing(List<String> clientAddressList, bool isPing, {DeviceInfoSchema? deviceInfo, int gap = 0}) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddressList.isEmpty) return;
    // destList
    List<String> destList = [];
    for (int i = 0; i < clientAddressList.length; i++) {
      String address = clientAddressList[i];
      if (address.isEmpty) continue;
      if (gap <= 0) {
        destList.add(address);
      } else {
        if (address == clientCommon.address) {
          destList.add(address);
        } else {
          DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(address);
          if (deviceInfo != null) {
            int timeAt = isPing ? (deviceInfo.pingAt ?? 0) : (deviceInfo.pongAt ?? 0);
            int interval = DateTime.now().millisecondsSinceEpoch - timeAt;
            if (interval < gap) continue;
          }
          destList.add(address);
        }
      }
    }
    // data
    String? data;
    if ((destList.length == 1) && (destList[0] != clientCommon.address)) {
      // just on other
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
    } else {
      // self or group
      data = MessageData.getPing(isPing);
    }
    // send
    Uint8List? pid = await _sendWithAddress(destList, data);
    // ping/pong at
    if ((pid?.isNotEmpty == true) && (gap > 0)) {
      int mowAt = DateTime.now().millisecondsSinceEpoch;
      deviceInfoCommon.queryListLatest(destList).then((deviceInfoList) {
        for (int i = 0; i < deviceInfoList.length; i++) {
          DeviceInfoSchema deviceInfo = deviceInfoList[i];
          if (deviceInfo.contactAddress == clientCommon.address) continue;
          if (isPing) {
            deviceInfoCommon.setPingAt(deviceInfo.contactAddress, deviceInfo.deviceId, pingAt: mowAt);
          } else {
            deviceInfoCommon.setPongAt(deviceInfo.contactAddress, deviceInfo.deviceId, pongAt: mowAt);
          }
        }
      });
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendReceipt(MessageSchema received) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (received.from.isEmpty || (received.isTopic || received.isPrivateGroup)) return false; // topic/group no receipt, just send message to myself
    received = (await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece)) ?? received; // get receiveAt
    String data = MessageData.getReceipt(received.msgId);
    Uint8List? pid = await _sendWithAddress([received.from], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> sendRead(String? clientAddress, List<String> msgIds) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return false; // topic no read, just like receipt
    String data = MessageData.getRead(msgIds);
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display NO topic (1 to 1)
  /*Future<bool> sendMsgStatus(String? clientAddress, bool ask, List<String> msgIds) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty || msgIds.isEmpty) return false; // topic no read, just like receipt
    String data = MessageData.getMsgStatus(ask, msgIds);
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }*/

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileRequest(String? clientAddress, String requestType, String? profileVersion) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String data = MessageData.getContactProfileRequest(requestType, profileVersion);
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendContactProfileResponse(String? clientAddress, String requestType, {ContactSchema? me}) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    ContactSchema? _me = me ?? await contactCommon.getMe();
    String data;
    if (requestType == ContactRequestType.header) {
      data = MessageData.getContactProfileResponseHeader(_me?.profileVersion);
    } else {
      data = await MessageData.getContactProfileResponseFull(_me?.profileVersion, _me?.avatar, _me?.firstName, _me?.lastName);
    }
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsBurn(String? clientAddress, int deleteSeconds, int updateAt) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
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
    var result = await _send(send, send.content);
    return result != null;
  }

  // NO topic (1 to 1)
  Future<bool> sendContactOptionsToken(String? clientAddress, String? deviceToken) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (clientAddress == null || clientAddress.isEmpty) return false;
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
    var result = await _send(send, send.content);
    return result != null;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceRequest(String? clientAddress) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    String data = MessageData.getDeviceRequest();
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> sendDeviceInfo(String? clientAddress, DeviceInfoSchema deviceInfo, bool withToken) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    if (!withToken) deviceInfo.deviceToken = null;
    String data = MessageData.getDeviceInfo(deviceInfo);
    Uint8List? pid = await _sendWithAddress([clientAddress], data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> sendText(dynamic target, String? content) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || content.trim().isEmpty) return null;
    // target
    String targetAddress = "";
    String targetTopic = "";
    String groupId = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
      },
    );
    // data
    String data = MessageData.getText(message);
    return await _send(message, data);
  }

  Future<MessageSchema?> saveIpfs(dynamic target, Map<String, dynamic> data) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
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
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    MessageSchema? inserted = await insertMessage(message);
    if (inserted == null) return null;
    // ipfs
    chatCommon.startIpfsUpload(inserted.msgId).then((msg) {
      if (msg != null) chatOutCommon.sendIpfs(msg.msgId);
    }); // await
    return inserted;
  }

  Future<MessageSchema?> sendIpfs(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    // schema
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    // data
    String? data = MessageData.getIpfs(message);
    return await _send(message, data, insert: false);
  }

  Future<MessageSchema?> sendImage(dynamic target, File? content) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetAddress = "";
    String targetTopic = "";
    String groupId = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
      contentType: MessageContentType.image,
      content: content,
      extra: {
        "privateGroupVersion": privateGroupVersion,
        "deleteAfterSeconds": deleteAfterSeconds,
        "burningUpdateAt": burningUpdateAt,
        "fileType": MessageOptions.fileTypeImage,
        "fileExt": Path.getFileExt(content, FileHelper.DEFAULT_IMAGE_EXT),
      },
    );
    // data
    String? data = await MessageData.getImage(message);
    return await _send(message, data);
  }

  Future<MessageSchema?> sendAudio(dynamic target, File? content, double? durationS) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (content == null || (!await content.exists()) || ((await content.length()) <= 0)) return null;
    // target
    String targetAddress = "";
    String groupId = "";
    String targetTopic = "";
    String? privateGroupVersion;
    int? deleteAfterSeconds;
    int? burningUpdateAt;
    if (target is ContactSchema) {
      targetAddress = target.clientAddress;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
    } else if (target is PrivateGroupSchema) {
      groupId = target.groupId;
      privateGroupVersion = target.version;
      deleteAfterSeconds = target.options?.deleteAfterSeconds;
      burningUpdateAt = target.options?.updateBurnAfterAt;
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
    return await _send(message, data);
  }

  // NO DB NO single
  Future sendTopicSubscribe(String? topic) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    if (topic == null || topic.isEmpty) return;
    MessageSchema send = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      topic: topic,
      contentType: MessageContentType.topicUnsubscribe,
    );
    TopicSchema? _schema = await chatCommon.topicHandle(send);
    String data = MessageData.getTopicUnSubscribe(send);
    await _sendWithTopic(_schema, send, data, notification: false);
  }

  // NO topic (1 to 1)
  Future<MessageSchema?> sendTopicInvitee(String? clientAddress, String? topic) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (clientAddress == null || clientAddress.isEmpty || topic == null || topic.isEmpty) return null;
    MessageSchema message = MessageSchema.fromSend(
      msgId: Uuid().v4(),
      from: clientCommon.address ?? "",
      to: clientAddress,
      contentType: MessageContentType.topicInvitation,
      content: topic,
    );
    String data = MessageData.getTopicInvitee(message);
    return await _send(message, data);
  }

  // NO DB NO single
  Future sendTopicKickOut(String? topic, String? targetAddress) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
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
    await _sendWithTopic(_schema, send, data, notification: false);
  }

  // NO group (1 to 1)
  Future<MessageSchema?> sendPrivateGroupInvitee(String? target, PrivateGroupSchema? privateGroup, PrivateGroupItemSchema? groupItem) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
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
  Future<bool> sendPrivateGroupAccept(String? target, PrivateGroupItemSchema? groupItem) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (target == null || target.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupAccept(groupItem);
    Uint8List? pid = await _sendWithAddress([target], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupQuit(String? target, PrivateGroupItemSchema? groupItem) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (target == null || target.isEmpty) return false;
    if (groupItem == null) return false;
    String data = MessageData.getPrivateGroupQuit(groupItem);
    Uint8List? pid = await _sendWithAddress([target], data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupOptionRequest(String? target, String? groupId, {int? gap}) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    if (gap != null) {
      int timePast = DateTime.now().millisecondsSinceEpoch - group.optionsRequestAt;
      if (timePast < gap) {
        logger.d('$TAG - sendPrivateGroupOptionRequest - time gap small - past:$timePast');
        return null;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupOptionRequest(groupId, getVersion);
    Uint8List? pid = await _sendWithAddress([target], data);
    return (pid?.isNotEmpty == true) ? getVersion : null;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupOptionResponse(List<String> clientAddressList, PrivateGroupSchema? group) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddressList.isEmpty || clientAddressList[0].isEmpty) return false;
    if (group == null) return false;
    String data = MessageData.getPrivateGroupOptionResponse(group);
    Uint8List? pid = await _sendWithAddress(clientAddressList, data);
    return pid?.isNotEmpty == true;
  }

  // NO group (1 to 1)
  Future<String?> sendPrivateGroupMemberRequest(String? target, String? groupId, {int? gap}) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    if (target == null || target.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    PrivateGroupSchema? group = await privateGroupCommon.queryGroup(groupId);
    if (group == null) return null;
    if (gap != null) {
      int timePast = DateTime.now().millisecondsSinceEpoch - group.membersRequestAt;
      if (timePast < gap) {
        logger.d('$TAG - sendPrivateGroupMemberRequest - time gap small - past:$timePast');
        return null;
      }
    }
    int commits = privateGroupCommon.getPrivateGroupVersionCommits(group.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String getVersion = privateGroupCommon.genPrivateGroupVersion(commits, group.signature, members);
    String data = MessageData.getPrivateGroupMemberRequest(groupId, getVersion);
    Uint8List? pid = await _sendWithAddress([target], data);
    return (pid?.isNotEmpty == true) ? getVersion : null;
  }

  // NO group (1 to 1)
  Future<bool> sendPrivateGroupMemberResponse(List<String> clientAddressList, PrivateGroupSchema? schema, List<PrivateGroupItemSchema> members) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return false;
    if (clientAddressList.isEmpty || clientAddressList[0].isEmpty) return false;
    if (schema == null) return false;
    List<Map<String, dynamic>> membersData = privateGroupCommon.getMembersData(members);
    String data = MessageData.getPrivateGroupMemberResponse(schema, membersData);
    Uint8List? pid = await _sendWithAddress(clientAddressList, data);
    return pid?.isNotEmpty == true;
  }

  Future<MessageSchema?> resend(MessageSchema? message, {bool mute = false, int gapMute = 0}) async {
    if (message == null) return null;
    // sendAt
    if (mute) {
      int resendMuteAt = MessageOptions.getResendMuteAt(message.options) ?? 0;
      if ((gapMute > 0) && (resendMuteAt > 0)) {
        int interval = DateTime.now().millisecondsSinceEpoch - resendMuteAt;
        if (interval < gapMute) {
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
        message = await chatCommon.startIpfsUpload(message.msgId);
        if (message == null) return null;
      }
    }
    // send
    Function func = () async {
      if (message == null) return null;
      String? msgData;
      switch (message.contentType) {
        case MessageContentType.text:
        case MessageContentType.textExtension:
          msgData = MessageData.getText(message);
          logger.i("$TAG - resendMute - resend text - targetId:${message.targetId} - msgData:$msgData");
          break;
        case MessageContentType.ipfs:
          msgData = MessageData.getIpfs(message);
          logger.i("$TAG - resendMute - resend ipfs - targetId:${message.targetId} - msgData:$msgData");
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
          //   logger.i("$TAG - resendMute - noReceipt not receipt/read - targetId:${message.targetId} - message:$message");
          //   int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          //   return await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
          return null;
      }
      if (mute) {
        // notification
        bool notification;
        if (message.isTopic || message.isPrivateGroup) {
          notification = false;
        } else {
          bool sendNoReply = message.status < MessageStatus.Receipt;
          String pushNotifyId = MessageOptions.getPushNotifyId(message.options) ?? "";
          notification = sendNoReply && pushNotifyId.isEmpty;
        }
        // send_mute
        MessageSchema? result = await _send(message, msgData, insert: false, sessionSync: false, statusSync: false, notification: notification);
        if (result != null) {
          var options = MessageOptions.setResendMuteAt(result.options, DateTime.now().millisecondsSinceEpoch);
          bool optionsOK = await messageCommon.updateMessageOptions(result, options, reQuery: true, notify: false);
          if (optionsOK) result.options = options;
        }
        return result;
      }
      // send
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
    // session
    if (sessionSync) await chatCommon.sessionHandle(message);
    // sdk
    Uint8List? pid;
    if (message.isTopic) {
      TopicSchema? topic = await chatCommon.topicHandle(message);
      pid = await _sendWithTopic(topic, message, msgData, notification: notification ?? message.canNotification);
      logger.d("$TAG - _send - with_topic - to:${message.topic} - pid:$pid");
    } else if (message.isPrivateGroup) {
      PrivateGroupSchema? group = await chatCommon.privateGroupHandle(message);
      pid = await _sendWithPrivateGroup(group, message, msgData, notification: notification ?? message.canNotification);
      logger.d("$TAG - _send - with_group - to:${message.topic} - pid:$pid");
    } else if (message.to.isNotEmpty == true) {
      ContactSchema? contact = await chatCommon.contactHandle(message);
      pid = await _sendWithContact(contact, message, msgData, notification: notification ?? message.canNotification);
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
        if (message.canReceipt) {
          messageCommon.updateMessageStatus(message, MessageStatus.Success, reQuery: true); // await
        } else {
          // no received receipt/read
          int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt); // await
        }
      } else {
        logger.w("$TAG - _send - pid = null - message:$message");
        if (message.canResend) {
          message = await messageCommon.updateMessageStatus(message, MessageStatus.Error, force: true);
        } else if (message.canDisplay) {
          // noResend just delete
          int count = await MessageStorage.instance.deleteByIdContentType(message.msgId, message.contentType);
          if (count > 0) messageCommon.onDeleteSink.add(message.msgId);
          return null;
        } else {
          // nothing
          return null;
        }
      }
    }
    return message;
  }

  Future<Uint8List?> _sendWithAddress(List<String> clientAddressList, String? msgData) async {
    if (clientAddressList.isEmpty || msgData == null) return null;
    logger.d("$TAG - _sendWithAddress - clientAddressList:$clientAddressList - msgData:$msgData - msgData:$msgData");
    return (await sendMsg(clientCommon.address, clientAddressList, msgData))?.messageId;
  }

  Future<Uint8List?> _sendWithContact(ContactSchema? contact, MessageSchema? message, String? msgData, {bool notification = false}) async {
    if (message == null || msgData == null) return null;
    logger.d("$TAG - _sendWithContact - contact:$contact - message:$message - msgData:$msgData");
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
      pid = (await sendMsg(clientCommon.address, [message.to], msgData))?.messageId;
    }
    if (pid == null || pid.isEmpty) return pid;
    // notification
    if (notification) {
      if ((contact != null) && !contact.isMe) {
        deviceInfoCommon.queryDeviceTokenList(contact.clientAddress, max: Settings.maxCountDevicesPush, days: Settings.timeoutDeviceTokensDay).then((tokens) async {
          bool pushOk = false;
          for (int i = 0; i < tokens.length; i++) {
            String? uuid = await RemoteNotification.send(tokens[i]); // need result
            if (!pushOk && (uuid != null) && uuid.isNotEmpty) {
              var options = MessageOptions.setPushNotifyId(message.options, uuid);
              bool optionsOK = await messageCommon.updateMessageOptions(message, options, reQuery: true, notify: false);
              if (optionsOK) pushOk = true;
            }
          }
        });
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
        pid = (await sendMsg(selfAddress, destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg(selfAddress, [selfAddress], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    // do not forget delete (replace by setJoined)
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   await topicCommon.delete(topic.id, notify: true);
    // }
    if (pid == null || pid.isEmpty) return pid;
    // notification
    if (notification) {
      contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.clientAddress, max: Settings.maxCountDevicesPush, days: Settings.timeoutDeviceTokensDay).then((tokens) {
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
        pid = (await sendMsg(selfAddress, destList, msgData))?.messageId;
      }
    }
    // self
    if (selfIsReceiver) {
      String data = MessageData.getReceipt(message.msgId);
      Uint8List? _pid = (await sendMsg(selfAddress, [selfAddress], data))?.messageId;
      if (destList.isEmpty) pid = _pid;
    }
    if (pid == null || pid.isEmpty) return pid;
    // notification
    if (notification) {
      contactCommon.queryListByClientAddress(destList).then((List<ContactSchema> contactList) async {
        for (var i = 0; i < contactList.length; i++) {
          ContactSchema _contact = contactList[i];
          if (_contact.isMe) continue;
          deviceInfoCommon.queryDeviceTokenList(_contact.clientAddress, max: Settings.maxCountDevicesPush, days: Settings.timeoutDeviceTokensDay).then((tokens) {
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
    if (dataList.isEmpty) return [null, false];

    logger.i("$TAG - _sendWithPieces:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");

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
      if ((result == null) || (result.pid == null)) {
        logger.w("$TAG - _sendWithPieces:ERROR - msgId:${piece.msgId}");
      } else {
        resultList.add(result);
      }
      await Future.delayed(Duration(milliseconds: 10)); // send with interval
    }
    List<MessageSchema> finds = resultList.where((element) => element.pid != null).toList();
    finds.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    if (finds.length >= total) {
      logger.i("$TAG - _sendWithPieces:SUCCESS - count:${resultList.length} - total:$total - message:$message");
      if (finds.isNotEmpty) return [finds[0].pid, true];
    }
    logger.w("$TAG - _sendWithPieces:FAIL - count:${resultList.length} - total:$total - message:$message");
    return [null, false];
  }

  Future<MessageSchema?> _sendPiece(List<String> clientAddressList, MessageSchema message, {double percent = -1}) async {
    // if (!clientCommon.isClientCreated || clientCommon.clientClosing) return null;
    String data = MessageData.getPiece(message);
    OnMessage? onResult = await sendMsg(clientCommon.address, clientAddressList, data);
    if ((onResult == null) || onResult.messageId.isEmpty) return null;
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
