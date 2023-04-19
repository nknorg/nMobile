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

  Future<MessageSchema?> queryByTargetIdWithQueueId(String? targetId, String? topic, String? groupId, int queueId) {
    return MessageStorage.instance.queryByTargetIdWithQueueId(targetId, topic, groupId, queueId);
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
              logger.w("$TAG - newMessageQueueId - msg wrong (wrong here) - nextQueueId:$queueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId} - msg:${msg?.toStringNoContent() ?? msgId}");
              nextQueueId = queueId;
              break;
            } else if (msg.status != MessageStatus.Sending) {
              logger.d("$TAG - newMessageQueueId - replace no sending - nextQueueId:$queueId - newMsgId:$messageId - target:$targetClientAddress - deviceId:${device.deviceId} - msg:${msg.toStringNoContent()}");
              nextQueueId = queueId;
              break;
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
      String? remoteQueueIds = MessageOptions.getMessageQueueIds(message.options);
      String? targetDeviceId = deviceInfoCommon.splitQueueIds(remoteQueueIds)[3];
      if (targetDeviceId?.trim() != Settings.deviceId.trim()) {
        logger.w("$TAG - onMessageQueueReceive - no target device - targetDeviceId:$targetDeviceId - nativeDeviceId:${Settings.deviceId} - remoteQueueIds:$remoteQueueIds - nativeQueueIds:$nativeQueueIds");
        return false;
      }
      int receiveQueueId = message.queueId;
      int nativeQueueId = device.latestReceivedMessageQueueId;
      if (receiveQueueId > nativeQueueId) {
        logger.d("$TAG - onMessageQueueReceive - new higher - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - remoteQueueIds:$remoteQueueIds - nativeQueueIds:$nativeQueueIds");
        bool success = await deviceInfoCommon.setLatestReceivedMessageQueueId(targetClientAddress, device.deviceId, receiveQueueId);
        if (success && ((receiveQueueId - nativeQueueId) > 1)) {
          List<int> lostPairs = List.generate(receiveQueueId - nativeQueueId - 1, (index) => nativeQueueId + index + 1);
          logger.i("$TAG - onMessageQueueReceive - new higher and add lostIds - lostPairs:$lostPairs - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - remoteQueueIds:$remoteQueueIds - nativeQueueIds:$nativeQueueIds");
          await deviceInfoCommon.setLostReceiveMessageQueueIds(targetClientAddress, device.deviceId, lostPairs, []);
        }
      } else if (receiveQueueId < nativeQueueId) {
        logger.i("$TAG - onMessageQueueReceive - new lower and delete lostIds - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - remoteQueueIds:$remoteQueueIds - nativeQueueIds:$nativeQueueIds");
        await deviceInfoCommon.setLostReceiveMessageQueueIds(targetClientAddress, device.deviceId, [], [receiveQueueId]);
      } else {
        logger.d("$TAG - onMessageQueueReceive - new equal old - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - remoteQueueIds:$remoteQueueIds - nativeQueueIds:$nativeQueueIds");
        // nothing
      }
      return true;
    };
    // queue
    _messageQueueIdQueues[targetClientAddress] = _messageQueueIdQueues[targetClientAddress] ?? ParallelQueue("message_queue_id_$targetClientAddress", onLog: (log, error) => error ? logger.w(log) : null);
    bool? success = await _messageQueueIdQueues[targetClientAddress]?.add(() => func());
    return success ?? false;
  }
}
