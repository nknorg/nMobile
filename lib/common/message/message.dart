import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/message_piece.dart';
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
  Map<String, String?> _syncMessageQueueParams = Map();

  String? currentChatTargetId;

  bool isTargetMessagePageVisible(String? targetId) {
    bool inSessionPage = currentChatTargetId == targetId;
    bool isAppForeground = application.appLifecycleState == AppLifecycleState.resumed;
    bool needAuth = (application.goForegroundAt - application.goBackgroundAt) >= Settings.gapClientReAuthMs;
    bool maybeAuthing = needAuth && ((DateTime.now().millisecondsSinceEpoch - application.goForegroundAt) < 200); // wait go app_screen
    return inSessionPage && isAppForeground && !maybeAuthing && !application.isAuthProgress;
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (schema == null) return null;
    if (schema.contentType == MessageContentType.piece) {
      return await MessagePieceStorage.instance.insert(schema);
    }
    return await MessageStorage.instance.insert(schema);
  }

  Future<int> delete(String? msgId, String? contentType) {
    if (contentType == MessageContentType.piece) {
      return MessagePieceStorage.instance.delete(msgId);
    }
    return MessageStorage.instance.delete(msgId);
  }

  Future<bool> deleteByTargetId(String? targetId, int targetType) async {
    await MessagePieceStorage.instance.deleteByTarget(targetId, targetType);
    return MessageStorage.instance.updateIsDeleteByTarget(targetId, targetType, true, clearContent: true);
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

  Future<bool> updateDeviceQueueId(String? msgId, String? deviceId, int queueId) {
    return MessageStorage.instance.updateDeviceQueueId(msgId, deviceId, queueId);
  }

  Future<MessageSchema?> query(String? msgId) {
    return MessageStorage.instance.query(msgId);
  }

  Future<List<MessageSchema>> queryPieceList(String? msgId, {int offset = 0, int limit = 20}) async {
    return await MessagePieceStorage.instance.queryList(msgId, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByIds(List<String>? msgIds) {
    return MessageStorage.instance.queryListByIds(msgIds);
  }

  Future<List<MessageSchema>> queryListByStatus(int? status, {String? targetId, int targetType = 0, bool? isDelete, int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByStatus(status, targetId: targetId, targetType: targetType, isDelete: isDelete, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByTargetUnRead(String? targetId, int targetType, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTarget(targetId, targetType, status: MessageStatus.Received, isDelete: false, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByTargetVisible(String? targetId, int targetType, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTarget(targetId, targetType, isDelete: false, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByTargetTypeVisible(String? targetId, int targetType, List<String> types, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetType(targetId, targetType, types, isDelete: false, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryListByTargetDeviceQueueId(String? targetId, int targetType, String? deviceId, int queueId, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetDeviceQueueId(targetId, targetType, deviceId, queueId, offset: offset, limit: limit);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.Receipt) || (message.status == MessageStatus.Read)) : true;
    bool success = await MessageStorage.instance.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (success && (message.contentType == MessageContentType.ipfs)) {
      message.options = MessageOptions.setIpfsResult(message.options, "", "", 0, "", [], 0);
      message.options = MessageOptions.setIpfsResultThumbnail(message.options, "", "", 0, "", [], 0);
      success = await updateMessageOptions(message, message.options, notify: false);
    }
    if (notify) onDeleteSink.add(message.msgId); // no need success
    // delete file
    if (clearContent && (message.isContentFile)) {
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
    bool success = await MessageStorage.instance.updateStatus(message.msgId, status, receiveAt: receiveAt);
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

  Future<int> readMessagesBySelf(String? targetId, int targetType) async {
    if (targetId == null || targetId.isEmpty) return 0;
    int limit = 20;
    // query
    List<MessageSchema> unreadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await queryListByTargetUnRead(targetId, targetType, offset: offset, limit: limit);
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
    if (msgIds.isNotEmpty && (targetType == MessageTargetType.Contact)) {
      chatOutCommon.sendRead(targetId, msgIds); // await
    }
    logger.d("$TAG - readMessagesBySelf - count:${msgIds.length} - targetId:$targetId");
    return msgIds.length;
  }

  Future<int> correctMessageRead(String? targetId, int targetType, int? lastSendAt) async {
    if (targetId == null || targetId.isEmpty || lastSendAt == null || lastSendAt == 0) return 0;
    int limit = 20;
    int readMinGap = 10 * 1000; // 10s
    // query
    List<MessageSchema> unReadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await queryListByStatus(MessageStatus.Receipt, targetId: targetId, targetType: targetType, offset: offset, limit: limit);
      List<MessageSchema> needReads = result.where((element) => element.isOutbound && ((element.sendAt ?? 0) <= (lastSendAt - readMinGap))).toList();
      unReadList.addAll(needReads);
      if (result.length < limit) break;
    }
    if (unReadList.isNotEmpty) {
      logger.i("$TAG - correctMessageRead - count:${unReadList.length} - targetId:$targetId - targetType:$targetType - lastSendAt:$lastSendAt");
    } else {
      logger.d("$TAG - correctMessageRead - count:${unReadList.length} - targetId:$targetId - targetType:$targetType - lastSendAt:$lastSendAt");
    }
    // update
    for (var i = 0; i < unReadList.length; i++) {
      MessageSchema element = unReadList[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      logger.d("$TAG - correctMessageRead - receiveAt:$receiveAt - element:${element.toStringNoContent()} - targetId:$targetId - targetType:$targetType - lastSendAt:$lastSendAt");
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    return unReadList.length;
  }

  Future<int> newContactMessageQueueId(String? targetAddress, String? targetDeviceId, String? messageId) async {
    if ((targetAddress == null) || targetAddress.isEmpty) return 0;
    if ((targetDeviceId == null) || targetDeviceId.isEmpty) return 0; // filter old_version
    if ((messageId == null) || messageId.isEmpty) return 0;
    Function func = () async {
      DeviceInfoSchema? targetDevice = await deviceInfoCommon.queryByDeviceId(targetAddress, targetDeviceId);
      if (targetDevice == null) return 0;
      String? queueIds = deviceInfoCommon.joinQueueIdsByDevice(targetDevice);
      logger.i("$TAG - newContactMessageQueueId - START - queueIds:$queueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId - messageId:$messageId");
      int nextQueueId = 0;
      // oldExists
      Map<int, String> sendingMessageQueueIds = targetDevice.sendingMessageQueueIds;
      if (sendingMessageQueueIds.isNotEmpty) {
        if (sendingMessageQueueIds.containsValue(messageId)) {
          sendingMessageQueueIds.forEach((key, value) {
            if (value == messageId) {
              logger.d("$TAG - newContactMessageQueueId - find in exists - nextQueueId:$key - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
              nextQueueId = key;
            }
          });
        } else {
          List<int> keys = sendingMessageQueueIds.keys.toList();
          for (var i = 0; i < keys.length; i++) {
            int queueId = keys[i];
            String msgId = sendingMessageQueueIds[queueId]?.toString() ?? "";
            MessageSchema? msg = await query(msgId);
            if ((msg == null) || !msg.canQueue || !msg.isOutbound) {
              logger.w("$TAG - newContactMessageQueueId - replace wrong msg (wrong here) - nextQueueId:$queueId - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId - msg:${msg?.toStringNoContent() ?? msgId}");
              nextQueueId = queueId;
              break;
            } else if (msg.status == MessageStatus.Error) {
              logger.d("$TAG - newContactMessageQueueId - replace status error - nextQueueId:$queueId - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId - msg:${msg.toStringNoContent()}");
              nextQueueId = queueId;
              break;
            } else if (msg.status >= MessageStatus.Success) {
              logger.w("$TAG - newContactMessageQueueId - replace wrong status(wrong here) - nextQueueId:$queueId - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId - msg:${msg.toStringNoContent()}");
              nextQueueId = queueId;
              break;
            } else {
              logger.i("$TAG - newContactMessageQueueId - replace refuse - msg:${msg.toStringNoContent()} - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
            }
          }
        }
      }
      // newCreate
      int latestSendMessageQueueId = targetDevice.latestSendMessageQueueId;
      if (nextQueueId <= 0) {
        nextQueueId = latestSendMessageQueueId + 1;
        logger.d("$TAG - newContactMessageQueueId - increase queue_id - nextQueueId:$nextQueueId - newMsgId:$messageId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      }
      // update
      await deviceInfoCommon.setSendingMessageQueueIds(targetAddress, targetDeviceId, {nextQueueId: messageId}, []);
      if (nextQueueId > latestSendMessageQueueId) {
        await deviceInfoCommon.setLatestSendMessageQueueId(targetAddress, targetDeviceId, nextQueueId);
      }
      logger.i("$TAG - newContactMessageQueueId - END - nextQueueId:$nextQueueId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId - messageId:$messageId");
      return nextQueueId;
    };
    // queue
    _messageQueueIdQueues[targetAddress] = _messageQueueIdQueues[targetAddress] ?? ParallelQueue("message_queue_id_$targetAddress", onLog: (log, error) => error ? logger.w(log) : null);
    int? queueId = await _messageQueueIdQueues[targetAddress]?.add(() => func());
    return queueId ?? 0;
  }

  Future<bool> onContactMessageQueueSendSuccess(String? targetAddress, String? targetDeviceId, int queueId) async {
    if ((targetAddress == null) || targetAddress.isEmpty) return false;
    if ((targetDeviceId == null) || targetDeviceId.isEmpty) return false;
    if (queueId <= 0) return false;
    Function func = () async {
      DeviceInfoSchema? targetDevice = await deviceInfoCommon.queryByDeviceId(targetAddress, targetDeviceId);
      if (targetDevice == null) return false;
      logger.i("$TAG - onContactMessageQueueSendSuccess - delete queueId from cache - queueId:$queueId - caches:${targetDevice.sendingMessageQueueIds} - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      return await deviceInfoCommon.setSendingMessageQueueIds(targetAddress, targetDeviceId, {}, [queueId]);
    };
    // queue
    _messageQueueIdQueues[targetAddress] = _messageQueueIdQueues[targetAddress] ?? ParallelQueue("message_queue_id_$targetAddress", onLog: (log, error) => error ? logger.w(log) : null);
    bool? success = await _messageQueueIdQueues[targetAddress]?.add(() => func());
    return success ?? false;
  }

  Future<bool> onContactMessageQueueReceive(MessageSchema message) async {
    if (!message.canQueue || (message.queueId <= 0)) return false;
    String targetAddress = message.sender;
    if (targetAddress.isEmpty) return false;
    Function func = () async {
      DeviceInfoSchema? targetDevice = await deviceInfoCommon.queryByDeviceId(targetAddress, message.deviceId);
      if (targetDevice == null) return false;
      String? nativeQueueIds = deviceInfoCommon.joinQueueIdsByDevice(targetDevice);
      String? sideQueueIds = MessageOptions.getMessageQueueIds(message.options);
      String? receiveDeviceId = deviceInfoCommon.splitQueueIds(sideQueueIds)[3];
      if (receiveDeviceId?.trim() != Settings.deviceId.trim()) {
        logger.w("$TAG - onContactMessageQueueReceive - no target device - receiveDeviceId:$receiveDeviceId - nativeDeviceId:${Settings.deviceId} - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        return false;
      }
      int receiveQueueId = message.queueId;
      int nativeQueueId = targetDevice.latestReceivedMessageQueueId;
      List<int> lostReceiveMessageQueueIds = targetDevice.lostReceiveMessageQueueIds;
      if (receiveQueueId > nativeQueueId) {
        logger.i("$TAG - onContactMessageQueueReceive - new higher - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        bool success = await deviceInfoCommon.setLatestReceivedMessageQueueId(targetAddress, targetDevice.deviceId, receiveQueueId);
        if (success && ((receiveQueueId - nativeQueueId) > 1)) {
          List<int> lostPairs = List.generate(receiveQueueId - nativeQueueId - 1, (index) => nativeQueueId + index + 1);
          logger.i("$TAG - onContactMessageQueueReceive - new higher and add lostIds - lostPairs:$lostPairs - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
          await deviceInfoCommon.setLostReceiveMessageQueueIds(targetAddress, targetDevice.deviceId, lostPairs, []);
        }
      } else if (receiveQueueId < nativeQueueId) {
        if (lostReceiveMessageQueueIds.contains(receiveQueueId)) {
          logger.i("$TAG - onContactMessageQueueReceive - new lower and delete lostIds - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
          await deviceInfoCommon.setLostReceiveMessageQueueIds(targetAddress, targetDevice.deviceId, [], [receiveQueueId]);
        } else {
          logger.d("$TAG - onContactMessageQueueReceive - new lower and duplicated received - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        }
      } else {
        logger.i("$TAG - onContactMessageQueueReceive - new == old - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
      }
      // clear too low queueId
      List<int> deleteQueueIds = lostReceiveMessageQueueIds.where((element) => element < (receiveQueueId - 100)).toList();
      if (deleteQueueIds.isNotEmpty) {
        logger.w("$TAG - onContactMessageQueueReceive - clear too low queueId - deleteIds:$deleteQueueIds - receiveQueueId:$receiveQueueId - nativeQueueId:$nativeQueueId - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds");
        await deviceInfoCommon.setLostReceiveMessageQueueIds(targetAddress, targetDevice.deviceId, [], deleteQueueIds);
      }
      return true;
    };
    // queue
    _messageQueueIdQueues[targetAddress] = _messageQueueIdQueues[targetAddress] ?? ParallelQueue("message_queue_id_$targetAddress", onLog: (log, error) => error ? logger.w(log) : null);
    bool? success = await _messageQueueIdQueues[targetAddress]?.add(() => func());
    return success ?? false;
  }

  Future syncContactMessages(String? targetAddress, String? targetDeviceId, int sideSendQueueId, int sideReceiveQueueId, List<int> sideLostQueueIds) async {
    if (targetAddress == null || targetAddress.isEmpty) return 0;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return 0;
    // use latest params
    bool replace = true;
    String? oldParams = _syncMessageQueueParams["${targetAddress}_$targetDeviceId"];
    if (oldParams != null) {
      List splits = deviceInfoCommon.splitQueueIds(oldParams);
      if ((sideSendQueueId <= splits[0]) && (sideReceiveQueueId <= splits[1])) {
        replace = false;
      }
    }
    if (replace) {
      String? queueIds = deviceInfoCommon.joinQueueIds(sideSendQueueId, sideReceiveQueueId, sideLostQueueIds, "???");
      logger.d("$TAG - syncContactMessages - receive_queue params replace - newQueueIds:$queueIds - oldQueueIds:$oldParams - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      _syncMessageQueueParams["${targetAddress}_$targetDeviceId"] = queueIds;
    }
    // wait receive queue complete
    var receiveQueue = chatInCommon.getReceiveQueue(targetAddress);
    if (receiveQueue != null) {
      int receiveCounts = receiveQueue.onCompleteCount("syncContactMessages_$targetDeviceId");
      if (receiveCounts > 0) {
        logger.d("$TAG - syncContactMessages - receive_queue progress - receiveCounts:$receiveCounts - params:$_syncMessageQueueParams - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
        return 0;
      }
      logger.d("$TAG - syncContactMessages - receive_queue waiting - params:$_syncMessageQueueParams - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      await receiveQueue.onComplete("syncContactMessages_$targetDeviceId");
    }
    logger.d("$TAG - syncContactMessages - receive_queue complete - params:$_syncMessageQueueParams - targetAddress:$targetAddress - sendQueueId:$sideSendQueueId");
    // use latest params
    String? queueIds = _syncMessageQueueParams["${targetAddress}_$targetDeviceId"];
    if (queueIds == null || queueIds.isEmpty) {
      logger.w("$TAG - syncContactMessages - params nil - queueIds:$queueIds - params:$_syncMessageQueueParams - targetAddress:$targetAddress - sendQueueId:$sideSendQueueId");
      return false;
    }
    // check start
    List splits = deviceInfoCommon.splitQueueIds(queueIds);
    await _syncContactMessages(targetAddress, targetDeviceId, splits[0], splits[1], splits[2]);
  }

  Future<int> _syncContactMessages(String? targetAddress, String? targetDeviceId, int sideSendQueueId, int sideReceiveQueueId, List<int> sideLostQueueIds) async {
    if (targetAddress == null || targetAddress.isEmpty) return 0;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return 0;
    // contact refresh
    DeviceInfoSchema? targetDevice = await deviceInfoCommon.queryByDeviceId(targetAddress, targetDeviceId);
    if (targetDevice == null) return 0;
    String? sideQueueIds = deviceInfoCommon.joinQueueIds(sideSendQueueId, sideReceiveQueueId, sideLostQueueIds, targetDeviceId);
    String? nativeQueueIds = deviceInfoCommon.joinQueueIdsByDevice(targetDevice);
    logger.i("$TAG - _syncContactMessages - START - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    // sync update
    int nativeSendQueueId = targetDevice.latestSendMessageQueueId;
    int nativeReceiveQueueId = targetDevice.latestReceivedMessageQueueId;
    List<int> lostReceiveMessageQueueIds = targetDevice.lostReceiveMessageQueueIds;
    if (sideReceiveQueueId > nativeSendQueueId) {
      logger.w("$TAG - _syncContactMessages - need self to sync queue (update native send/receive_queueId) - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      await chatOutCommon.sendQueue(targetAddress, targetDeviceId); // mast wait and before update
      await deviceInfoCommon.setLatestSendMessageQueueId(targetAddress, targetDeviceId, sideReceiveQueueId);
      if (sideSendQueueId > nativeReceiveQueueId) {
        await deviceInfoCommon.setLatestReceivedMessageQueueId(targetAddress, targetDeviceId, sideSendQueueId);
      }
      // sendingMessageQueueIds and lostReceiveMessageQueueIds will be correct auto
      return 0; // wait sendQueue reply
    }
    // sync request
    if ((sideSendQueueId > nativeReceiveQueueId) || lostReceiveMessageQueueIds.isNotEmpty) {
      logger.i("$TAG - _syncContactMessages - need side to resend lost - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - lostReceiveMessageQueueIds:$lostReceiveMessageQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      await chatOutCommon.sendQueue(targetAddress, targetDeviceId);
    } else if (sideSendQueueId < nativeReceiveQueueId) {
      logger.w("$TAG - _syncContactMessages - need side to sync queue - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - lostReceiveMessageQueueIds:$lostReceiveMessageQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      await chatOutCommon.sendQueue(targetAddress, targetDeviceId);
      return 0; // wait sendQueue reply
    } else {
      logger.d("$TAG - _syncContactMessages - queueIds equal (side==native) - sideSendQueueId:$sideSendQueueId - nativeReceiveQueueId:$nativeReceiveQueueId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    }
    // queueIds
    List<int> resendQueueIds = sideLostQueueIds;
    if (sideReceiveQueueId < nativeSendQueueId) {
      List<int> newLost = List.generate(nativeSendQueueId - sideReceiveQueueId, (index) => sideReceiveQueueId + index + 1);
      logger.i("$TAG - _syncContactMessages - resendQueueIds add latest msg - newLost:$newLost - sideReceiveQueueId:$sideReceiveQueueId - nativeSendQueueId:$nativeSendQueueId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      resendQueueIds.addAll(newLost);
    } else {
      logger.d("$TAG - _syncContactMessages - resendQueueIds skip latest msg - sideReceiveQueueId:$sideReceiveQueueId - nativeSendQueueId:$nativeSendQueueId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    }
    if (resendQueueIds.isEmpty) {
      logger.i("$TAG - _syncContactMessages - resendQueueIds is empty - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      return 0;
    }
    logger.d("$TAG - _syncContactMessages - resendQueueIds no empty - count:${resendQueueIds.length} - resendQueueIds:$resendQueueIds - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    // messages
    List<MessageSchema> resendMsgList = [];
    int limit = 5;
    for (var i = 0; i < resendQueueIds.length; i++) {
      int queueId = resendQueueIds[i];
      for (int offset = 0; true; offset += limit) {
        List<MessageSchema> result = await queryListByTargetDeviceQueueId(targetAddress, MessageTargetType.Contact, Settings.deviceId, queueId, offset: offset, limit: limit);
        MessageSchema? resendMsg;
        for (var j = 0; j < result.length; j++) {
          MessageSchema message = result[j];
          String? queueIds = MessageOptions.getMessageQueueIds(message.options);
          List splits = deviceInfoCommon.splitQueueIds(queueIds);
          bool isSameDevice = (queueIds != null) && (splits[3].toString().trim() == targetDeviceId.trim());
          if (message.canReceipt && message.isOutbound && isSameDevice && (message.status != MessageStatus.Error)) {
            logger.i("$TAG - _syncContactMessages - resend messages add - queueId:$queueId - message:$message - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
            resendMsg = message;
            break;
          }
        }
        if (resendMsg != null) {
          resendMsgList.add(resendMsg);
          break;
        }
        if (result.length < limit) {
          logger.w("$TAG - _syncContactMessages - resend message no find - queueId:$queueId - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
          break;
        }
      }
    }
    if (resendMsgList.isEmpty) {
      logger.i("$TAG - _syncContactMessages - resendMessages is empty - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
      return 0;
    }
    logger.d("$TAG - _syncContactMessages - resendMessages no empty - count:${resendMsgList.length}/${resendQueueIds.length} - sideQueueIds:$sideQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    // ack check (maybe other device queue)
    List<MessageSchema> noAckList = [];
    limit = 20;
    for (int offset = 0; true; offset += limit) {
      final result = await messageCommon.queryListByStatus(MessageStatus.Success, targetId: targetAddress, targetType: MessageTargetType.Contact, offset: offset, limit: limit);
      result.removeWhere((element) => !element.isOutbound || !element.canQueue);
      noAckList.addAll(result);
      if (result.length < limit) break;
    }
    bool noAckAdded = false;
    for (var i = 0; i < noAckList.length; i++) {
      MessageSchema noAck = noAckList[i];
      if (resendMsgList.indexWhere((element) => noAck.msgId == element.msgId) < 0) {
        logger.i("$TAG - _syncContactMessages - resend messages add - message:$noAck - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
        noAckAdded = true;
        resendMsgList.add(noAck);
      }
    }
    if (noAckAdded) {
      logger.d("$TAG - _syncContactMessages - resendMessages (with no ACK) no empty - count:${resendMsgList.length}/${resendQueueIds.length} - resendQueueIds:$resendQueueIds - sideQueueIds:$sideQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    }
    // resend
    int successCount = 0;
    for (var i = 0; i < resendMsgList.length; i++) {
      MessageSchema message = resendMsgList[i];
      int gap = Settings.gapMessageQueueResendMs * (message.isContentFile ? 2 : 1);
      var data = await chatOutCommon.resend(message, mute: true, muteGap: gap);
      if (data != null) successCount++;
    }
    logger.i("$TAG - _syncContactMessages - END - count:$successCount/${resendMsgList.length} - sideQueueIds:$sideQueueIds - nativeQueueIds:$nativeQueueIds - targetAddress:$targetAddress - targetDeviceId:$targetDeviceId");
    return successCount;
  }
}
