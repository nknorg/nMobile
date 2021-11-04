import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/logger.dart';

class SessionCommon with Tag {
  SessionStorage _sessionStorage = SessionStorage();

  // ignore: close_sinks
  StreamController<SessionSchema> _addController = StreamController<SessionSchema>.broadcast();
  StreamSink<SessionSchema> get _addSink => _addController.sink;
  Stream<SessionSchema> get addStream => _addController.stream;

  // ignore: close_sinks
  StreamController<List<dynamic>> _deleteController = StreamController<List<dynamic>>.broadcast();
  StreamSink<List<dynamic>> get _deleteSink => _deleteController.sink;
  Stream<List<dynamic>> get deleteStream => _deleteController.stream;

  // ignore: close_sinks
  StreamController<SessionSchema> _updateController = StreamController<SessionSchema>.broadcast();
  StreamSink<SessionSchema> get _updateSink => _updateController.sink;
  Stream<SessionSchema> get updateStream => _updateController.stream;

  SessionCommon();

  Future<SessionSchema?> add(SessionSchema? schema, MessageSchema? lastMsg, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.targetId.isEmpty) return null;
    // duplicated
    if (checkDuplicated) {
      SessionSchema? exist = await query(schema.targetId, schema.type);
      if (exist != null) {
        logger.i("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    // lastMessage
    if (lastMsg == null) {
      List<MessageSchema> history = await chatCommon.queryMessagesByTargetIdVisible(schema.targetId, schema.type == SessionType.TOPIC ? schema.targetId : "", offset: 0, limit: 1);
      lastMsg = history.isNotEmpty ? history[0] : null;
    }
    if (schema.lastMessageAt == null || schema.lastMessageOptions == null) {
      schema.lastMessageAt = lastMsg?.sendAt ?? MessageOptions.getInAt(lastMsg);
      schema.lastMessageOptions = lastMsg?.toMap();
    }
    // unReadCount
    if (schema.unReadCount <= 0) {
      if (lastMsg != null) {
        schema.unReadCount = (lastMsg.isOutbound || !lastMsg.canNotification) ? 0 : 1;
      } else {
        schema.unReadCount = await chatCommon.unReadCountByTargetId(schema.targetId, schema.type == SessionType.TOPIC ? schema.targetId : "");
      }
    }
    // insert
    SessionSchema? added = await _sessionStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  Future<bool> delete(String? targetId, int? type, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await _sessionStorage.delete(targetId, type);
    if (success && notify) _deleteSink.add([targetId, type]);
    chatCommon.deleteByTargetId(targetId, type == SessionType.TOPIC ? targetId : ""); // await
    return success;
  }

  Future<SessionSchema?> query(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    return await _sessionStorage.query(targetId, type);
  }

  Future<List<SessionSchema>> queryListRecent({int? offset, int? limit}) {
    return _sessionStorage.queryListRecent(offset: offset, limit: limit);
  }

  Future<bool> setLastMessageAndUnReadCount(String? targetId, int? type, MessageSchema? lastMessage, int? unread, {int? sendAt, bool notify = false}) async {
    if (targetId == null || targetId.isEmpty) return false;
    SessionSchema session = SessionSchema(targetId: targetId, type: SessionSchema.getTypeByMessage(lastMessage));
    session.lastMessageAt = sendAt ?? lastMessage?.sendAt ?? MessageOptions.getInAt(lastMessage);
    session.lastMessageOptions = lastMessage?.toMap();
    session.unReadCount = unread ?? await chatCommon.unReadCountByTargetId(targetId, type == SessionType.TOPIC ? session.targetId : "");
    bool success = await _sessionStorage.updateLastMessageAndUnReadCount(session);
    if (success && notify) queryAndNotify(session.targetId, type);
    return success;
  }

  // Future<bool> setLastMessage(String? targetId, MessageSchema lastMessage, {bool notify = false}) async {
  //   if (targetId == null || targetId.isEmpty) return false;
  //   SessionSchema session = SessionSchema(targetId: targetId, type: SessionSchema.getTypeByMessage(lastMessage));
  //   session.lastMessageAt = lastMessage.sendAt ?? DateTime.now().millisecondsSinceEpoch;
  //   session.lastMessageOptions = lastMessage.toMap();
  //   bool success = await _sessionStorage.updateLastMessage(session);
  //   if (success && notify) queryAndNotify(session.targetId);
  //   return success;
  // }

  Future<bool> setTop(String? targetId, int? type, bool top, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await _sessionStorage.updateIsTop(targetId, type, top);
    if (success && notify) queryAndNotify(targetId, type);
    return success;
  }

  Future<bool> setUnReadCount(String? targetId, int? type, int unread, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await _sessionStorage.updateUnReadCount(targetId, type, unread);
    if (success && notify) queryAndNotify(targetId, type);
    return success;
  }

  Future queryAndNotify(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return;
    SessionSchema? updated = await query(targetId, type);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }

  // Future<MessageSchema?> findLastMessage(SessionSchema? session, {bool checkOptions = false}) async {
  //   if (session == null) return null;
  //   MessageSchema? message;
  //   if (checkOptions && session.lastMessageOptions != null && session.lastMessageOptions!.isNotEmpty) {
  //     message = MessageSchema.fromMap(session.lastMessageOptions!);
  //   } else {
  //     List<MessageSchema> history = await _messageStorage.queryListByTargetIdWithNotDeleteAndPiece(session.targetId, offset: 0, limit: 1);
  //     if (history.isNotEmpty) {
  //       message = history[0];
  //       // session.lastMessageOptions = message.toMap();
  //     }
  //   }
  //   // session.lastMessageTime = message?.sendTime;
  //   return message;
  // }
}
