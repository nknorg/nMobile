import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class SessionCommon with Tag {
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

  Map<String, ParallelQueue> _queues = Map();

  Future<SessionSchema?> add(
    String? targetId,
    int? type, {
    MessageSchema? lastMsg,
    int? lastMsgAt,
    int? unReadCount,
    bool notify = true,
  }) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    Function func = () async {
      logger.d('$TAG - session_add - START - targetId:$targetId - type:$type - unread:$unReadCount - timeAt:$lastMsgAt - message:$lastMsg');
      // lastMsg
      if (lastMsg == null) {
        List<MessageSchema> history = await messageCommon.queryListByTargetVisible(targetId, type, offset: 0, limit: 1);
        lastMsg = history.isNotEmpty ? history[0] : null;
      }
      // lastMsgAt
      if ((lastMsgAt == null) || (lastMsgAt == 0)) {
        lastMsgAt = lastMsg?.sendAt;
      }
      // unReadCount
      if ((unReadCount == null) || ((unReadCount ?? -1) < 0)) {
        if (lastMsg != null) {
          unReadCount = ((lastMsg?.isOutbound == false) && (lastMsg?.canNotification == true)) ? 1 : 0;
        }
      }
      // senderName
      String? senderName;
      if ((type == SessionType.TOPIC) || (type == SessionType.PRIVATE_GROUP)) {
        if (lastMsg != null) {
          ContactSchema? _sender = await contactCommon.query(lastMsg?.sender, fetchWalletAddress: false);
          if (_sender?.displayName.isNotEmpty == true) {
            senderName = _sender?.displayName ?? " ";
          }
        }
      }
      // schema
      SessionSchema? added = SessionSchema(
        targetId: targetId,
        type: type,
        lastMessageOptions: lastMsg?.toMap(),
        lastMessageAt: lastMsgAt ?? DateTime.now().millisecondsSinceEpoch,
        unReadCount: unReadCount ?? 0,
      );
      if (senderName?.isNotEmpty == true) {
        added.data = {"senderName": senderName};
      }
      logger.d('$TAG - session_add - END - targetId:${added.targetId} - type${added.type} - unread:${added.unReadCount} - timeAt:${added.lastMessageAt} - data:${added.data} - message:${added.lastMessageOptions}');
      // insert
      added = await SessionStorage.instance.insert(added);
      if ((added != null) && notify) _addSink.add(added);
      return added;
    };
    // queue
    _queues[targetId] = _queues[targetId] ?? ParallelQueue("session_$targetId", onLog: (log, error) => error ? logger.w(log) : null);
    return await _queues[targetId]?.add(() async {
      try {
        return await func();
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<SessionSchema?> update(
    String? targetId,
    int? type, {
    MessageSchema? lastMsg,
    int? lastMsgAt,
    int? unReadCount,
    int? unreadChange,
    bool notify = true,
  }) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    Function func = () async {
      SessionSchema? exist = await query(targetId, type);
      if (exist == null) {
        logger.w("$TAG - session_update - empty - schema:$targetId - type:$type");
        return null;
      }
      logger.d('$TAG - session_update - START - targetId:$targetId - type:$type - unread:$unReadCount - change:$unreadChange - timeAt:$lastMsgAt - message:$lastMsg');
      // lastMsg
      MessageSchema? oldLastMsg;
      Map<String, dynamic> oldLastMessageOptions = exist.lastMessageOptions ?? Map();
      if ((lastMsg != null) && oldLastMessageOptions.isNotEmpty) {
        oldLastMsg = MessageSchema.fromMap(oldLastMessageOptions);
      }
      if (oldLastMsg == null) {
        List<MessageSchema> history = await messageCommon.queryListByTargetVisible(targetId, type, offset: 0, limit: 1);
        oldLastMsg = history.isNotEmpty ? history[0] : null;
      }
      MessageSchema? newLastMsg;
      if (lastMsg == null) {
        newLastMsg = oldLastMsg;
      } else if (oldLastMsg == null) {
        newLastMsg = lastMsg;
      } else {
        if (lastMsg.sendAt >= oldLastMsg.sendAt) {
          newLastMsg = lastMsg;
        } else {
          newLastMsg = oldLastMsg;
        }
      }
      // lastMsgAt
      int newLastMsgAt = lastMsgAt ?? newLastMsg?.sendAt ?? exist.lastMessageAt;
      // unReadCount
      int newUnReadCount;
      if (unReadCount != null) {
        newUnReadCount = unReadCount;
      } else if (unreadChange != null) {
        newUnReadCount = (messageCommon.isTargetMessagePageVisible(exist.targetId)) ? 0 : (exist.unReadCount + unreadChange);
      } else {
        newUnReadCount = (messageCommon.isTargetMessagePageVisible(exist.targetId)) ? 0 : exist.unReadCount;
      }
      newUnReadCount = (newUnReadCount >= 0) ? newUnReadCount : 0;
      // senderName
      if ((type == SessionType.TOPIC) || (type == SessionType.PRIVATE_GROUP)) {
        String? newSenderName;
        if (newLastMsg != null) {
          ContactSchema? _sender = await contactCommon.query(newLastMsg.sender, fetchWalletAddress: false);
          if (_sender?.displayName.isNotEmpty == true) {
            newSenderName = _sender?.displayName ?? " ";
          }
        }
        if (newSenderName != exist.data["senderName"]?.toString()) {
          Map<String, dynamic>? newData = {"senderName": newSenderName};
          bool success = await SessionStorage.instance.setData(targetId, type, newData);
          if (success) exist.data = newData;
        }
      }
      exist.lastMessageOptions = newLastMsg?.toMap();
      exist.lastMessageAt = newLastMsgAt;
      exist.unReadCount = newUnReadCount;
      logger.d('$TAG - session_update - END - targetId:$targetId - type:$type - unread:${exist.unReadCount} - timeAt:${exist.lastMessageAt} - message:${exist.lastMessageOptions}');
      bool success = await SessionStorage.instance.setLastMessageAndUnReadCount(exist);
      if (success && notify) queryAndNotify(targetId, type);
    };
    // queue
    _queues[targetId] = _queues[targetId] ?? ParallelQueue("session_$targetId", onLog: (log, error) => error ? logger.w(log) : null);
    return await _queues[targetId]?.add(() async {
      try {
        return await func();
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<bool> delete(String? targetId, int? type, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await messageCommon.onSessionDelete(targetId, type);
    if (success) success = await SessionStorage.instance.delete(targetId, type);
    if (success && notify) _deleteSink.add([targetId, type]);
    return success;
  }

  Future<SessionSchema?> query(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    return await SessionStorage.instance.query(targetId, type);
  }

  Future<List<SessionSchema>> queryListRecent({int offset = 0, final limit = 20}) {
    return SessionStorage.instance.queryListRecent(offset: offset, limit: limit);
  }

  Future<List<SessionSchema>> queryListBySearch(String query) {
    return SessionStorage.instance.queryListBySearch(query);
  }

  Future<int> totalUnReadCount() {
    return SessionStorage.instance.querySumUnReadCount();
  }

  /*Future<bool> setLastMessageAndUnReadCount(String? targetId, int type, MessageSchema? lastMessage, int unread, {int? sendAt, bool notify = false}) async {
    if (targetId == null || targetId.isEmpty) return false;
    SessionSchema session = SessionSchema(targetId: targetId, type: type);
    session.lastMessageAt = sendAt ?? lastMessage?.sendAt ?? MessageOptions.getInAt(lastMessage?.options);
    session.lastMessageOptions = lastMessage?.toMap();
    session.unReadCount = unread;
    bool success = await SessionStorage.instance.updateLastMessageAndUnReadCount(session);
    if (success && notify) queryAndNotify(session.targetId, type);
    return success;
  }*/

  /*Future<bool> setLastMessage(String? targetId, MessageSchema lastMessage, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty) return false;
    SessionSchema session = SessionSchema(targetId: targetId, type: SessionSchema.getTypeByMessage(lastMessage));
    session.lastMessageAt = lastMessage.sendAt ?? DateTime.now().millisecondsSinceEpoch;
    session.lastMessageOptions = lastMessage.toMap();
    bool success = await SessionStorage.instance.updateLastMessage(session);
    if (success && notify) queryAndNotify(session.targetId);
    return success;
  }*/

  Future<bool> setUnReadCount(String? targetId, int? type, int unread, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await SessionStorage.instance.setUnReadCount(targetId, type, unread);
    if (success && notify) queryAndNotify(targetId, type);
    return success;
  }

  Future<bool> setTop(String? targetId, int? type, bool top, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await SessionStorage.instance.setTop(targetId, type, top);
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

/*Future<MessageSchema?> findLastMessage(SessionSchema? session, {bool checkOptions = false}) async {
    if (session == null) return null;
    MessageSchema? message;
    if (checkOptions && session.lastMessageOptions != null && (session.lastMessageOptions?.isNotEmpty == true)) {
      message = MessageSchema.fromMap(session.lastMessageOptions!);
    } else {
      List<MessageSchema> history = await _messageStorage.queryListByTargetIdWithNotDeleteAndPiece(session.targetId, offset: 0, limit: 1);
      if (history.isNotEmpty) {
        message = history[0];
        // session.lastMessageOptions = message.toMap();
      }
    }
    // session.lastMessageTime = message?.sendTime;
    return message;
  }*/
}
