import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/time.dart';

class MessageCommon with Tag {
  MessageCommon();

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

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

  Future<int> unreadCount() {
    return MessageStorage.instance.unReadCount();
  }

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
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Read)) : true;
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

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {bool reQuery = false, int? receiveAt, bool force = false, bool notify = false}) async {
    if (reQuery) {
      MessageSchema? _latest = await MessageStorage.instance.query(message.msgId);
      if (_latest != null) message = _latest;
    }
    if ((status <= message.status) && !force) {
      if (status == message.status) return message;
      logger.w("$TAG - updateMessageStatus - status is wrong - new:$status - old:${message.status} - msgId:${message.msgId}");
      return message;
    }
    // update
    message.status = status;
    bool success = await MessageStorage.instance.updateStatus(message.msgId, status, receiveAt: receiveAt, noType: MessageContentType.piece);
    if (status == MessageStatus.SendSuccess) {
      message.options = MessageOptions.setOutAt(message.options, DateTime.now().millisecondsSinceEpoch);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
    }
    if (success && notify) onUpdateSink.add(message);
    // delete later
    if (message.isDelete && (message.content != null)) {
      bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Read)) : true;
      if (clearContent) {
        messageDelete(message, notify: false); // await
      } else {
        logger.i("$TAG - updateMessageStatus - delete later no - message:$message");
      }
    }
    return message;
  }

  Future readMessagesBySelf(String? targetId, String? topic, String? groupId, String? clientAddress) async {
    if (targetId == null || targetId.isEmpty) return;
    // update messages
    int limit = 20;

    List<MessageSchema> unreadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await MessageStorage.instance.queryListByTargetIdWithUnRead(targetId, topic, groupId, offset: offset, limit: limit);
      unreadList.addAll(result);
      if (result.length < limit) break;
    }

    List<String> msgIds = [];
    for (var i = 0; i < unreadList.length; i++) {
      MessageSchema element = unreadList[i];
      msgIds.add(element.msgId);
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false);
    }
    // send messages
    if ((clientAddress?.isNotEmpty == true) && msgIds.isNotEmpty) {
      await chatOutCommon.sendRead(clientAddress, msgIds);
    }
  }

  Future<int> readMessageBySide(String? targetId, String? topic, String? groupId, int? sendAt, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    // noReads
    List<MessageSchema> noReads = await MessageStorage.instance.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, topic: topic, groupId: groupId, offset: offset, limit: limit);
    List<MessageSchema> shouldReads = noReads.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
    // read
    for (var i = 0; i < shouldReads.length; i++) {
      MessageSchema element = shouldReads[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    // loop
    if (noReads.length >= limit) return readMessageBySide(targetId, topic, groupId, sendAt, offset: offset + limit, limit: limit);
    logger.i("$TAG - readMessageBySide - readCount:${offset + noReads.length} - reallySendAt:${Time.formatTime(DateTime.fromMillisecondsSinceEpoch(sendAt))}");
    return offset + noReads.length;
  }
}
