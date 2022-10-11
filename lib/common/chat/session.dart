import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
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

  Map<String, ParallelQueue> _queues = Map();

  SessionCommon();

  Future<SessionSchema?> set(
    String? targetId,
    int type, {
    MessageSchema? newLastMsg,
    int? newLastMsgAt,
    int? unReadCount,
    int unreadChange = 0,
    bool notify = false,
  }) async {
    if (targetId == null || targetId.isEmpty) return null;
    Function func = () async {
      String topic = (type == SessionType.TOPIC) ? targetId : "";
      String group = (type == SessionType.PRIVATE_GROUP) ? targetId : "";
      // lastMsg
      List<MessageSchema> history = await chatCommon.queryMessagesByTargetIdVisible(targetId, topic, group, offset: 0, limit: 1);
      MessageSchema? existLastMsg = history.isNotEmpty ? history[0] : null;
      MessageSchema? appendLastMsg;
      if ((newLastMsg == null) && (existLastMsg == null)) {
        appendLastMsg = null;
      } else if (newLastMsg == null) {
        appendLastMsg = existLastMsg;
      } else if (existLastMsg == null) {
        appendLastMsg = newLastMsg;
      } else {
        if ((existLastMsg.sendAt ?? 0) <= (newLastMsg.sendAt ?? 0)) {
          appendLastMsg = newLastMsg;
        } else {
          appendLastMsg = existLastMsg;
        }
      }
      int appendLastMsgAt = newLastMsgAt ?? appendLastMsg?.sendAt ?? MessageOptions.getInAt(appendLastMsg?.options) ?? DateTime.now().millisecondsSinceEpoch;
      // unRead
      int appendUnreadCount;
      if (chatCommon.currentChatTargetId == targetId) {
        appendUnreadCount = 0;
      } else {
        appendUnreadCount = unReadCount ?? await chatCommon.unReadCountByTargetId(targetId, topic, group);
        if (unreadChange != 0) appendUnreadCount = appendUnreadCount + unreadChange;
        appendUnreadCount = appendUnreadCount >= 0 ? appendUnreadCount : 0;
      }
      // if ((unreadChange != 0) && (newLastMsg != null) && (newLastMsg.msgId != existLastMsg?.msgId)) {
      //   if (!newLastMsg.isOutbound && newLastMsg.canNotification) {
      //     appendUnreadCount = appendUnreadCount + unreadChange;
      //   }
      // }
      // add
      SessionSchema? exist = await query(targetId, type);
      if (exist == null) {
        SessionSchema? added = SessionSchema(
          targetId: targetId,
          type: type,
          lastMessageOptions: appendLastMsg?.toMap(),
          lastMessageAt: appendLastMsgAt,
          unReadCount: appendUnreadCount,
        );
        added = await SessionStorage.instance.insert(added);
        if ((added != null) && notify) _addSink.add(added);
        return added;
      }
      // update
      exist.lastMessageAt = appendLastMsgAt;
      exist.lastMessageOptions = appendLastMsg?.toMap();
      exist.unReadCount = appendUnreadCount;
      bool success = await SessionStorage.instance.updateLastMessageAndUnReadCount(exist);
      if (success && notify) queryAndNotify(targetId, type);
      return exist;
    };
    // queue
    if (_queues[targetId] == null) {
      _queues[targetId] = ParallelQueue("session_$targetId", onLog: (log, error) => error ? logger.w(log) : null);
    }
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
    bool success = await SessionStorage.instance.delete(targetId, type);
    if (success && notify) _deleteSink.add([targetId, type]);
    String topic = (type == SessionType.TOPIC) ? targetId : "";
    String group = (type == SessionType.PRIVATE_GROUP) ? targetId : "";
    await chatCommon.deleteByTargetId(targetId, topic, group); // await
    return success;
  }

  Future<SessionSchema?> query(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    return await SessionStorage.instance.query(targetId, type);
  }

  Future<List<SessionSchema>> queryListRecent({int offset = 0, int limit = 20}) {
    return SessionStorage.instance.queryListRecent(offset: offset, limit: limit);
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

  Future<bool> setTop(String? targetId, int? type, bool top, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await SessionStorage.instance.updateIsTop(targetId, type, top);
    if (success && notify) queryAndNotify(targetId, type);
    return success;
  }

  Future<bool> setUnReadCount(String? targetId, int? type, int unread, {bool notify = false}) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    bool success = await SessionStorage.instance.updateUnReadCount(targetId, type, unread);
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
