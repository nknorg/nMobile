import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';

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

  Future<int> unReadCountByTargetId(String? targetId, String? topic, String? groupId) {
    return MessageStorage.instance.unReadCountByTargetId(targetId, topic, groupId);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, String? topic, String? groupId, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithNotDeleteAndPiece(targetId, topic, groupId, offset: offset, limit: limit);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisibleWithType(String? targetId, String? topic, String? groupId, List<String>? types, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithTypeNotDelete(targetId, topic, groupId, types, offset: offset, limit: limit);
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
          (message.content as File).delete(); // await
          logger.d("$TAG - messageDelete - content file delete success - path:${(message.content as File).path}");
        } else {
          logger.w("$TAG - messageDelete - content file no Exists - path:${(message.content as File).path}");
        }
      });
    }
    // delete thumbnail
    String? mediaThumbnail = MessageOptions.getMediaThumbnailPath(message.options);
    if (clearContent && (mediaThumbnail != null) && mediaThumbnail.isNotEmpty) {
      File(mediaThumbnail).exists().then((exist) {
        if (exist) {
          File(mediaThumbnail).delete(); // await
          logger.d("$TAG - messageDelete - video_thumbnail delete success - path:$mediaThumbnail");
        } else {
          logger.w("$TAG - messageDelete - video_thumbnail no Exists - path:$mediaThumbnail");
        }
      });
    }
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {bool force = false, int? receiveAt, bool notify = true}) async {
    // re_query
    MessageSchema? _latest = await MessageStorage.instance.query(message.msgId);
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

  /*Future<int> readMessageBySide(String? targetId, String? topic, String? groupId, int? sendAt) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    int limit = 20;
    // query
    List<MessageSchema> unReadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await MessageStorage.instance.queryListByStatus(MessageStatus.Receipt, targetId: targetId, topic: topic, groupId: groupId, offset: offset, limit: limit);
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
}
