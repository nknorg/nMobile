import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class MessageCommon with Tag {
  MessageCommon();

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onProgressController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get onProgressSink => _onProgressController.sink;
  Stream<Map<String, dynamic>> get onProgressStream => _onProgressController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  Map<String, ParallelQueue> _messageQueueIdQueues = Map();

  /*Future<int> unReadCountByTargetId(String? targetId, String? topic, String? groupId) {
    return MessageStorage.instance.unReadCountByTargetId(targetId, topic, groupId);
  }*/

  Future<MessageSchema?> insert(MessageSchema? schema) {
    return MessageStorage.instance.insert(schema);
  }

  Future<bool> updateDeleteAt(String? msgId, int? deleteAt) {
    return MessageStorage.instance.updateDeleteAt(msgId, deleteAt);
  }

  Future<bool> updateSendAt(String? msgId, int? sendAt) {
    return MessageStorage.instance.updateSendAt(msgId, sendAt);
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) {
    return MessageStorage.instance.updatePid(msgId, pid);
  }

  Future<bool> updateQueueId(String? msgId, int queueId) {
    return MessageStorage.instance.updateQueueId(msgId, queueId);
  }

  Future<MessageSchema?> query(String? msgId) {
    return MessageStorage.instance.query(msgId);
  }

  Future<MessageSchema?> queryByIdNoContentType(String? msgId, String? contentType) {
    return MessageStorage.instance.queryByIdNoContentType(msgId, contentType);
  }

  Future<List<MessageSchema>> queryListByIds(List<String>? msgIds) {
    return MessageStorage.instance.queryListByIds(msgIds);
  }

  Future<List<MessageSchema>> queryListByStatus(int? status, {String? targetId, String? topic, String? groupId, int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByStatus(status, targetId: targetId, topic: topic, groupId: groupId, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByIdContentType(String? msgId, String? contentType, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByIdContentType(msgId, contentType, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByIdsNoContentType(List<String>? msgIds, String? contentType) {
    return MessageStorage.instance.queryListByIdsNoContentType(msgIds, contentType);
  }

  Future<List<MessageSchema>> queryListByTargetIdWithQueueId(String? targetId, String? topic, String? groupId, int queueId, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithQueueId(targetId, topic, groupId, queueId, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, String? topic, String? groupId, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithNotDeleteAndPiece(targetId, topic, groupId, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisibleWithType(String? targetId, String? topic, String? groupId, List<String>? types, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithTypeNotDelete(targetId, topic, groupId, types, offset: offset, limit: limit);
  }

  Future<int> deleteByIdContentType(String? msgId, String? contentType) {
    return MessageStorage.instance.deleteByIdContentType(msgId, contentType);
  }

  Future<bool> deleteByTargetId(String? targetId, String? topic, String? groupId) async {
    await MessageStorage.instance.deleteByTargetIdContentType(targetId, topic, groupId, MessageContentType.piece);
    return MessageStorage.instance.updateIsDeleteByTargetId(targetId, topic, groupId, true, clearContent: true);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.Receipt) || (message.status == MessageStatus.Read)) : true;
    bool success = await MessageStorage.instance.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (notify) onDeleteSink.add(message.msgId); // no need success
    // delete file
    if (clearContent && (message.content is File)) {
      (message.content as File).exists().then((exist) {
        if (exist) {
          try {
            (message.content as File).delete(); // await
          } catch (e) {}
          logger.d("$TAG - messageDelete - content file delete success - path:${(message.content as File).path}");
        } else {
          logger.d("$TAG - messageDelete - content file no Exists - path:${(message.content as File).path}");
        }
      });
    }
    // delete thumbnail
    String? mediaThumbnail = MessageOptions.getMediaThumbnailPath(message.options);
    if (clearContent && (mediaThumbnail != null) && mediaThumbnail.isNotEmpty) {
      File(mediaThumbnail).exists().then((exist) {
        if (exist) {
          try {
            File(mediaThumbnail).delete(); // await
          } catch (e) {}
          logger.d("$TAG - messageDelete - video_thumbnail delete success - path:$mediaThumbnail");
        } else {
          logger.d("$TAG - messageDelete - video_thumbnail no Exists - path:$mediaThumbnail");
        }
      });
    }
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {bool force = false, int? receiveAt, bool notify = true}) async {
    // re_query
    MessageSchema? _latest = await query(message.msgId);
    if (_latest != null) message = _latest;
    // check
    if ((status <= message.status) && !force) {
      if (status == message.status) {
        logger.w("$TAG - updateMessageStatus - status is same - new:$status - old:${message.status} - msgId:${message.msgId}");
      } else {
        logger.w("$TAG - updateMessageStatus - status is wrong - new:$status - old:${message.status} - msgId:${message.msgId}");
      }
      return message;
    }
    // update
    logger.d("$TAG - updateMessageStatus - new:$status - old:${message.status} - msgId:${message.msgId}");
    bool success = await MessageStorage.instance.updateStatus(message.msgId, status, receiveAt: receiveAt, noType: MessageContentType.piece);
    if (success) {
      message.status = status;
      if (message.status == MessageStatus.Success) {
        message.options = MessageOptions.setSendSuccessAt(message.options, DateTime.now().millisecondsSinceEpoch);
        await updateMessageOptions(message, message.options, notify: false);
      }
      if (notify) onUpdateSink.add(message);
    }
    // delete later
    if (message.isDelete && (message.content != null)) {
      bool clearContent = message.isOutbound ? ((message.status == MessageStatus.Receipt) || (message.status == MessageStatus.Read)) : true;
      if (clearContent) {
        messageDelete(message, notify: false); // await
      } else {
        logger.i("$TAG - updateMessageStatus - delete later no - message:${message.toStringNoContent()}");
      }
    }
    return message;
  }

  Future<bool> updateMessageOptions(MessageSchema? message, Map<String, dynamic>? added, {bool notify = true}) async {
    if (message == null || message.msgId.isEmpty) return false;
    logger.d("$TAG - updateMessageOptions - start - add:$added - old:${message.options} - msgId:${message.msgId}");
    Map<String, dynamic>? options = await MessageStorage.instance.updateOptions(message.msgId, added);
    if (options != null) {
      logger.d("$TAG - updateMessageOptions - end success - new:$options - msgId:${message.msgId}");
      message.options = options;
      if (notify) onUpdateSink.add(message);
    } else {
      logger.w("$TAG - updateMessageOptions - end fail - add:$added - old:${message.options} - msgId:${message.msgId}");
    }
    return options != null;
  }

  Future<int> readMessagesBySelf(String? targetId, String? topic, String? groupId, String? clientAddress) async {
    if (targetId == null || targetId.isEmpty) return 0;
    int limit = 20;
    // query
    List<MessageSchema> unreadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await MessageStorage.instance.queryListByTargetIdWithUnRead(targetId, topic, groupId, offset: offset, limit: limit);
      // result.removeWhere((element) => element.isOutbound);
      unreadList.addAll(result);
      if (result.length < limit) break;
    }
    // update
    List<String> msgIds = [];
    for (var i = 0; i < unreadList.length; i++) {
      MessageSchema element = unreadList[i];
      element = await updateMessageStatus(element, MessageStatus.Read);
      if (element.status == MessageStatus.Read) {
        msgIds.add(element.msgId);
      }
    }
    // send
    if ((clientAddress?.isNotEmpty == true) && msgIds.isNotEmpty) {
      chatOutCommon.sendRead(clientAddress, msgIds); // await
    }
    logger.d("$TAG - readMessagesBySelf - count:${msgIds.length} - targetId:$targetId");
    return msgIds.length;
  }

  // TODO:GG read 最新read之后，凡是已经ack的，并且时间线早的，都可以setRead
  /*Future<int> readMessageBySide(String? targetId, String? topic, String? groupId, int? sendAt) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    int limit = 20;
    // query
    List<MessageSchema> unReadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await queryListByStatus(MessageStatus.Receipt, targetId: targetId, topic: topic, groupId: groupId, offset: offset, limit: limit);
      List<MessageSchema> needReads = result.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
      unReadList.addAll(needReads);
      if (result.length < limit) break;
    }
    // update
    for (var i = 0; i < unReadList.length; i++) {
      MessageSchema element = unReadList[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    return unReadList.length;
  }*/

  Future<int> newMessageQueueId(String? targetClientAddress, String? deviceId, String? messageId) async {
    if ((targetClientAddress == null) || targetClientAddress.isEmpty) return 0;
    if (deviceId == null || deviceId.isEmpty) return 0; // filter old_version
    if ((messageId == null) || messageId.isEmpty) return 0;
    Function func = () async {
      DeviceInfoSchema? device = await deviceInfoCommon.queryByDeviceId(targetClientAddress, deviceId);
      if (device == null) return 0;
      String? queueIds = deviceInfoCommon.joinQueueIdsByDevice(device);
      logger.i("$TAG - newMessageQueueId - START - queueIds:$queueIds - target:$targetClientAddress - deviceId:${device.deviceId} - messageId:$messageId");
      int nextQueueId = 0;
      // oldExists
      Map<int, String> sendingMessageQueueIds = device.sendingMessageQueueIds;
      if (sendingMessageQueueIds.isNotEmpty) {
        if (sendingMessageQueueIds.containsValue(messageId)) {
          sendingMessageQueueIds.forEach((key, value) {
            if (value == messageId) {
              logger.d("$TAG - newMessageQueueId - find in exists - nextQueueId:$key - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId}");
              nextQueueId = key;
            }
          });
        } else {
          List<int> keys = sendingMessageQueueIds.keys.toList();
          for (var i = 0; i < keys.length; i++) {
            int queueId = keys[i];
            String msgId = sendingMessageQueueIds[queueId]?.toString() ?? "";
            MessageSchema? msg = await queryByIdNoContentType(msgId, MessageContentType.piece);
            if ((msg == null) || !msg.canQueue || !msg.isOutbound) {
              logger.w("$TAG - newMessageQueueId - replace wrong msg (wrong here) - nextQueueId:$queueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId} - msg:${msg?.toStringNoContent() ?? msgId}");
              nextQueueId = queueId;
              break;
            } else if (msg.status == MessageStatus.Error) {
              logger.d("$TAG - newMessageQueueId - replace status error - nextQueueId:$queueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId} - msg:${msg.toStringNoContent()}");
              nextQueueId = queueId;
              break;
            } else if (msg.status >= MessageStatus.Success) {
              logger.w("$TAG - newMessageQueueId - replace wrong status(wrong here) - nextQueueId:$queueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId} - msg:${msg.toStringNoContent()}");
              nextQueueId = queueId;
              break;
            } else {
              logger.i("$TAG - newMessageQueueId - replace refuse - msg:${msg.toStringNoContent()} - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId}");
            }
          }
        }
      }
      // newCreate
      int latestSendMessageQueueId = device.latestSendMessageQueueId;
      if (nextQueueId <= 0) {
        nextQueueId = latestSendMessageQueueId + 1;
        logger.d("$TAG - newMessageQueueId - increase queue_id - nextQueueId:$nextQueueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId}");
      }
      // update
      await deviceInfoCommon.setSendingMessageQueueIds(targetClientAddress, device.deviceId, {nextQueueId: messageId}, []);
      if (nextQueueId > latestSendMessageQueueId) {
        await deviceInfoCommon.setLatestSendMessageQueueId(targetClientAddress, device.deviceId, nextQueueId);
      }
      logger.i("$TAG - newMessageQueueId - END - nextQueueId:$nextQueueId - target:$targetClientAddress - deviceId:${device.deviceId} - messageId:$messageId");
      return nextQueueId;
    };
    // queue
    _messageQueueIdQueues[targetClientAddress] = _messageQueueIdQueues[targetClientAddress] ?? ParallelQueue("message_queue_id_$targetClientAddress", onLog: (log, error) => error ? logger.w(log) : null);
    int? queueId = await _messageQueueIdQueues[targetClientAddress]?.add(() => func());
    return queueId ?? 0;
  }

  Future<bool> onMessageQueueSendSuccess(String? targetClientAddress, String? deviceId, int queueId) async {
    if ((targetClientAddress == null) || targetClientAddress.isEmpty) return false;
    if (deviceId == null || deviceId.isEmpty) return false;
    if (queueId <= 0) return false;
    Function func = () async {
      DeviceInfoSchema? device = await deviceInfoCommon.queryByDeviceId(targetClientAddress, deviceId);
      if (device == null) return false;
      logger.i("$TAG - onMessageQueueSendSuccess - delete queueId from cache - queueId:$queueId - caches:${device.sendingMessageQueueIds} - target:$targetClientAddress - deviceId:${device.deviceId}");
      return await deviceInfoCommon.setSendingMessageQueueIds(targetClientAddress, device.deviceId, {}, [queueId]);
    };
    // queue
    _messageQueueIdQueues[targetClientAddress] = _messageQueueIdQueues[targetClientAddress] ?? ParallelQueue("message_queue_id_$targetClientAddress", onLog: (log, error) => error ? logger.w(log) : null);
    bool? success = await _messageQueueIdQueues[targetClientAddress]?.add(() => func());
    return success ?? false;
  }

  Future<bool> onMessageQueueReceive(MessageSchema message) async {
    if (!message.canQueue || (message.queueId <= 0)) return false;
    String targetClientAddress = message.from;
    if (targetClientAddress.isEmpty) return false;
    Function func = () async {
      String? deviceId = MessageOptions.getDeviceId(message.options);
      DeviceInfoSchema? device = await deviceInfoCommon.queryByDeviceId(targetClientAddress, deviceId);
      if (device == null) return false;
      String? nativeQueueIds = deviceInfoCommon.joinQueueIdsByDevice(device);
      String? sideQueueIds = MessageOptions.getMessageQueueIds(message.options);
      String? selfDeviceId = deviceInfoCommon.splitQueueIds(sideQueueIds)[3];
      if (selfDeviceId?.trim() != Settings.deviceId.trim()) {
        logger.w("$TAG - onMessageQueueReceive - no target device - selfDeviceId:$selfDeviceId - nativeDeviceId:${Settings.deviceId} - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        return false;
      }
      int receiveQueueId = message.queueId;
      int nativeQueueId = device.latestReceivedMessageQueueId;
      if (receiveQueueId > nativeQueueId) {
        logger.i("$TAG - onMessageQueueReceive - new higher - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        bool success = await deviceInfoCommon.setLatestReceivedMessageQueueId(targetClientAddress, device.deviceId, receiveQueueId);
        if (success && ((receiveQueueId - nativeQueueId) > 1)) {
          List<int> lostPairs = List.generate(receiveQueueId - nativeQueueId - 1, (index) => nativeQueueId + index + 1);
          logger.i("$TAG - onMessageQueueReceive - new higher and add lostIds - lostPairs:$lostPairs - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
          await deviceInfoCommon.setLostReceiveMessageQueueIds(targetClientAddress, device.deviceId, lostPairs, []);
        }
      } else if (receiveQueueId < nativeQueueId) {
        logger.i("$TAG - onMessageQueueReceive - new lower and delete lostIds - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        await deviceInfoCommon.setLostReceiveMessageQueueIds(targetClientAddress, device.deviceId, [], [receiveQueueId]);
      } else {
        logger.i("$TAG - onMessageQueueReceive - new == old - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
      }
      return true;
    };
    // queue
    _messageQueueIdQueues[targetClientAddress] = _messageQueueIdQueues[targetClientAddress] ?? ParallelQueue("message_queue_id_$targetClientAddress", onLog: (log, error) => error ? logger.w(log) : null);
    bool? success = await _messageQueueIdQueues[targetClientAddress]?.add(() => func());
    return success ?? false;
  }

  // TODO:GG 后面触发的，才是最新的！
  Future<int> syncContactMessages(String? clientAddress, String? targetDeviceId, int sideSendQueueId, int sideReceiveQueueId, List<int> sideLostQueueIds) async {
    if (clientAddress == null || clientAddress.isEmpty) return 0;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return 0;
    // wait receive queue complete
    var receiveQueue = chatInCommon.getReceiveQueue(clientAddress);
    if (receiveQueue != null) {
      int receiveCounts = receiveQueue.onCompleteCount("syncContactMessages_$targetDeviceId");
      if (receiveCounts > 0) {
        logger.d("$TAG - syncContactMessages - receive_queue progress - receiveCounts:$receiveCounts - from:$clientAddress - targetDeviceId:$targetDeviceId - sendQueueId:$sideSendQueueId - receivedQueueId:$sideReceiveQueueId - lostQueueIds:$sideLostQueueIds");
        return 0;
      }
      logger.d("$TAG - syncContactMessages - receive_queue waiting - from:$clientAddress - targetDeviceId:$targetDeviceId - sendQueueId:$sideSendQueueId - receivedQueueId:$sideReceiveQueueId - lostQueueIds:$sideLostQueueIds");
      await receiveQueue.onComplete("syncContactMessages_$targetDeviceId");
    } else {
      logger.w("$TAG - syncContactMessages - receive queue nil - from:$clientAddress - sendQueueId:$sideSendQueueId - receivedQueueId:$sideReceiveQueueId - lostQueueIds:$sideLostQueueIds - targetDeviceId:$targetDeviceId");
    }
    // contact refresh
    DeviceInfoSchema? device = await deviceInfoCommon.queryByDeviceId(clientAddress, targetDeviceId);
    if (device == null) return 0;
    String? sideQueueIds = deviceInfoCommon.joinQueueIds(sideSendQueueId, sideReceiveQueueId, sideLostQueueIds, targetDeviceId);
    String? nativeQueueIds = deviceInfoCommon.joinQueueIdsByDevice(device);
    logger.i("$TAG - syncContactMessages - START - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
    // sync update
    int nativeSendQueueId = device.latestSendMessageQueueId;
    if (sideReceiveQueueId > nativeSendQueueId) {
      logger.w("$TAG - syncContactMessages - need self sync queueIds - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
      await deviceInfoCommon.setLatestSendMessageQueueId(clientAddress, targetDeviceId, sideReceiveQueueId);
      await deviceInfoCommon.setLatestReceivedMessageQueueId(clientAddress, targetDeviceId, sideSendQueueId);
      chatOutCommon.sendQueue(clientAddress, targetDeviceId); // await
      return 0; // wait sendQueue reply
    }
    // sync request
    int nativeReceiveQueueId = device.latestReceivedMessageQueueId;
    if (sideSendQueueId > nativeReceiveQueueId) {
      logger.i("$TAG - syncContactMessages - need side to resend lost - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
      chatOutCommon.sendQueue(clientAddress, targetDeviceId); // await
    } else if (sideSendQueueId < nativeReceiveQueueId) {
      logger.w("$TAG - syncContactMessages - need side to sync queue - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
      chatOutCommon.sendQueue(clientAddress, targetDeviceId); // await
      return 0; // wait sendQueue reply
    } else {
      logger.d("$TAG - syncContactMessages - queueIds equal (side==native) - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
    }
    // queueIds
    List<int> resendQueueIds = sideLostQueueIds;
    if (sideReceiveQueueId < nativeSendQueueId) {
      logger.i("$TAG - syncContactMessages - need resend latest msg - sideReceiveQueueId:$sideReceiveQueueId - nativeSendQueueId:$nativeSendQueueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
      List<int> newLost = List.generate(nativeSendQueueId - sideReceiveQueueId, (index) => sideReceiveQueueId + index + 1);
      resendQueueIds.addAll(newLost);
    } else {
      logger.d("$TAG - syncContactMessages - no resend latest msg - sideReceiveQueueId:$sideReceiveQueueId - nativeSendQueueId:$nativeSendQueueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
    }
    if (resendQueueIds.isEmpty) {
      logger.i("$TAG - syncContactMessages - resendQueueIds is empty - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
      return 0;
    }
    logger.d("$TAG - syncContactMessages - resendQueueIds no empty - count:${resendQueueIds.length} - resendQueueIds:$resendQueueIds - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
    // messages
    List<MessageSchema> resendMsgList = [];
    int limit = 10;
    for (var i = 0; i < resendQueueIds.length; i++) {
      int queueId = resendQueueIds[i];
      for (int offset = 0; true; offset += limit) {
        List<MessageSchema> result = await queryListByTargetIdWithQueueId(clientAddress, "", "", queueId);
        MessageSchema? resendMsg;
        for (var j = 0; j < result.length; j++) {
          MessageSchema message = result[j];
          String? queueIds = MessageOptions.getMessageQueueIds(message.options);
          if ((queueIds == null) || (queueIds[3].toString().trim() != targetDeviceId.trim())) {
            logger.d("$TAG - syncContactMessages - resend message device diff - queueId:$queueId - message:$message - from:$clientAddress - targetDeviceId:$targetDeviceId");
            continue;
          } else if (!message.canReceipt || !message.isOutbound) {
            logger.w("$TAG - syncContactMessages - resend message type wrong - queueId:$queueId - message:$message - from:$clientAddress - targetDeviceId:$targetDeviceId");
            continue;
          } else if (message.status == MessageStatus.Error) {
            logger.d("$TAG - syncContactMessages - resend message status error - queueId:$queueId - message:$message - from:$clientAddress - targetDeviceId:$targetDeviceId");
            continue;
          }
          logger.i("$TAG - syncContactMessages - resend messages add - queueId:$queueId - message:$message - from:$clientAddress - targetDeviceId:$targetDeviceId");
          resendMsg = message;
          break;
        }
        if (resendMsg != null) {
          resendMsgList.add(resendMsg);
          break;
        }
        if (result.length < limit) {
          logger.w("$TAG - syncContactMessages - resend message no find wrong - queueId:$queueId - from:$clientAddress - targetDeviceId:$targetDeviceId");
          break;
        }
      }
    }
    if (resendMsgList.isEmpty) {
      logger.i("$TAG - syncContactMessages - resendMessages is empty - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
      return 0;
    }
    logger.d("$TAG - syncContactMessages - resendMessages no empty - count:${resendMsgList.length} - resendQueueIds:$resendQueueIds - sideQueueIds:$sideQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
    // ack check (maybe other device queue)
    List<MessageSchema> noAckList = [];
    for (int offset = 0; true; offset += limit) {
      final result = await messageCommon.queryListByStatus(MessageStatus.Success, offset: offset, limit: limit);
      result.removeWhere((element) => !element.isOutbound);
      noAckList.addAll(result);
      if (result.length < limit) break;
    }
    bool noAckAdded = false;
    for (var i = 0; i < noAckList.length; i++) {
      MessageSchema noAck = noAckList[i];
      if (resendMsgList.indexWhere((element) => noAck.msgId == element.msgId) < 0) {
        logger.i("$TAG - syncContactMessages - resend messages add - message:$noAck - from:$clientAddress - targetDeviceId:$targetDeviceId");
        noAckAdded = true;
        resendMsgList.add(noAck);
      }
    }
    if (noAckAdded) logger.d("$TAG - syncContactMessages - resendMessages (with no ACK) no empty - count:${resendMsgList.length} - resendQueueIds:$resendQueueIds - sideQueueIds:$sideQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
    // resend
    int successCount = 0;
    for (var i = 0; i < resendMsgList.length; i++) {
      MessageSchema message = resendMsgList[i];
      int gap = Settings.gapMessageQueueResendMs * ((message.content is File) ? 2 : 1);
      var data = await chatOutCommon.resend(message, mute: true, muteGap: gap);
      if (data != null) successCount++;
    }
    logger.i("$TAG - syncContactMessages - END - count:$successCount/${resendMsgList.length} - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - from:$clientAddress - targetDeviceId:$targetDeviceId");
    return successCount;
  }
}
