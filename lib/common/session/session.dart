import 'dart:async';

import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/logger.dart';

class SessionCommon with Tag {
  SessionStorage _sessionStorage = SessionStorage();
  MessageStorage _messageStorage = MessageStorage();

  StreamController<SessionSchema> _addController = StreamController<SessionSchema>.broadcast();
  StreamSink<SessionSchema> get addSink => _addController.sink;
  Stream<SessionSchema> get addStream => _addController.stream;

  StreamController<String> _deleteController = StreamController<String>.broadcast();
  StreamSink<String> get deleteSink => _deleteController.sink;
  Stream<String> get deleteStream => _deleteController.stream;

  StreamController<SessionSchema> _updateController = StreamController<SessionSchema>.broadcast();
  StreamSink<SessionSchema> get _updateSink => _updateController.sink;
  Stream<SessionSchema> get updateStream => _updateController.stream;

  close() {
    _addController.close();
    _deleteController.close();
    _updateController.close();
  }

  Future<SessionSchema?> add(SessionSchema? schema, {bool checkDuplicated = true}) async {
    if (schema == null || schema.targetId.isEmpty) return null;
    if (schema.unReadCount <= 0) {
      schema.unReadCount = await _messageStorage.unReadCountByTargetId(schema.targetId);
    }
    if (checkDuplicated) {
      SessionSchema? exist = await query(schema.targetId);
      if (exist != null) {
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    SessionSchema? added = await _sessionStorage.insert(schema);
    if (added != null) addSink.add(added);
    return added;
  }

  Future<bool> delete(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return false;
    bool deleted = await _sessionStorage.delete(targetId);
    if (deleted) deleteSink.add(targetId);
    return deleted;
  }

  Future<SessionSchema?> query(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return null;
    return await _sessionStorage.query(targetId);
  }

  Future<List<SessionSchema>> queryListRecent({int? offset, int? limit}) {
    return _sessionStorage.queryListRecent(offset: offset, limit: limit);
  }

  Future<bool> setLastMessage(SessionSchema? session, MessageSchema? lastMessage, {bool notify = false}) async {
    if (session == null || session.targetId.isEmpty || lastMessage == null) return false;
    session.lastMessageTime = lastMessage.sendTime;
    session.lastMessageOptions = lastMessage.toMap();
    bool success = await _sessionStorage.updateLastMessage(session);
    if (success && notify) queryAndNotify(session.targetId);
    return success;
  }

  Future<bool> setUnReadCount(String? targetId, int? unread, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty) return false;
    unread = unread ?? await _messageStorage.unReadCountByTargetId(targetId);
    bool success = await _sessionStorage.updateUnReadCount(targetId, unread);
    if (success && notify) queryAndNotify(targetId);
    return success;
  }

  Future<bool> setTop(String? targetId, bool top, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty) return false;
    bool success = await _sessionStorage.updateIsTop(targetId, top);
    if (success && notify) queryAndNotify(targetId);
    return success;
  }

  Future queryAndNotify(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return;
    SessionSchema? updated = await _sessionStorage.query(targetId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
