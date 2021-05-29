import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage {
  static String get tableName => 'Messages';

  Database? get db => DB.currentDatabase;

  MessageStorage();

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pid TEXT,
        msg_id TEXT,
        sender TEXT,
        receiver TEXT,
        target_id TEXT,
        type TEXT,
        topic TEXT,
        content TEXT,
        options TEXT,
        is_read BOOLEAN DEFAULT 0,
        is_success BOOLEAN DEFAULT 0,
        is_outbound BOOLEAN DEFAULT 0,
        is_send_error BOOLEAN DEFAULT 0,
        receive_time INTEGER,
        send_time INTEGER,
        delete_time INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX index_messages_pid ON Messages (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id ON Messages (msg_id)');
    await db.execute('CREATE INDEX index_messages_sender ON Messages (sender)');
    await db.execute('CREATE INDEX index_messages_receiver ON Messages (receiver)');
    await db.execute('CREATE INDEX index_messages_target_id ON Messages (target_id)');
    await db.execute('CREATE INDEX index_messages_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_messages_send_time ON Messages (send_time)');
    await db.execute('CREATE INDEX index_messages_delete_time ON Messages (delete_time)');
    // query message
    await db.execute('CREATE INDEX index_messages_target_id_is_outbound ON Messages (target_id, is_outbound)');
    await db.execute('CREATE INDEX index_messages_target_id_type ON Messages (target_id, type)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (schema == null) return null;
    // duplicated
    if (schema.contentType != ContentType.piece) {
      List<MessageSchema> exists = await queryList(schema.msgId);
      if (exists.isNotEmpty) {
        logger.d("insertMessage - exists:$exists");
        return exists[0];
      }
    }
    // insert
    try {
      Map<String, dynamic> map = schema.toMap();
      int? id = await db?.insert(tableName, map);
      if (id != null && id > 0) {
        schema = MessageSchema.fromMap(map);
        logger.d("insertMessage - success - schema:$schema");
        return schema;
      }
    } catch (e) {
      handleError(e);
    }
    logger.w("insertMessage - fail - schema:$schema");
    return null;
  }

  Future<bool> delete(MessageSchema? schema) async {
    if (schema == null) return false;
    try {
      int? result = await db?.delete(
        tableName,
        where: 'msg_id = ?',
        whereArgs: [schema.msgId],
      );
      if (result != null && result > 0) {
        logger.d("deleteMessage - success - schema:$schema");
        return true;
      }
    } catch (e) {
      handleError(e);
    }
    logger.w("deleteMessage - fail - schema:$schema");
    return false;
  }

  Future<List<MessageSchema>> queryList(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (res == null || res.isEmpty) {
        logger.d("queryList - empty - msgId:$msgId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      res.forEach((map) => result.add(MessageSchema.fromMap(map)));
      logger.d("queryList - success - msgId:$msgId - length:${result.length} - items:$result");
      return result;
    } catch (e) {
      handleError(e);
    }
    logger.w("queryList - fail - msgId:$msgId");
    return [];
  }

  Future<int> queryCount(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("queryCount - msgId:$msgId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("queryCount - fail - msgId:$msgId");
    return 0;
  }

  Future<List<MessageSchema>> queryListCanReadByTargetId(String? targetId, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        orderBy: 'send_time desc',
        where: 'target_id = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [targetId, ContentType.piece, ContentType.receipt],
        limit: limit,
        offset: offset,
      );
      if (res == null || res.isEmpty) {
        logger.d("queryListCanReadByTargetId - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("queryListCanReadByTargetId - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    logger.w("queryListCanReadByTargetId - fail - targetId:$targetId");
    return [];
  }

  Future<List<MessageSchema>> queryListUnRead() async {
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'is_outbound = ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [0, 0, ContentType.piece, ContentType.receipt],
      );
      if (res == null || res.isEmpty) {
        logger.d("queryListUnRead - empty");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("queryListUnRead- length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    logger.w("queryListUnRead - fail");
    return [];
  }

  Future<List<MessageSchema>> queryListUnReadByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'target_id = ? AND is_outbound = ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [targetId, 0, 0, ContentType.piece, ContentType.receipt],
      );
      if (res == null || res.isEmpty) {
        logger.d("queryListUnReadByTargetId - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("queryListUnReadByTargetId - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    logger.w("queryListUnReadByTargetId - fail - targetId:$targetId");
    return [];
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'pid': pid != null ? hexEncode(pid) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("updatePid - count:$count - msgId:$msgId - pid:$pid}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("updatePid - fail - msgId:$msgId - pid:$pid}");
    return false;
  }

  Future<bool> updateOptions(String? msgId, Map<String, dynamic>? options) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'options': options != null ? jsonEncode(options) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("updateOptions - count:$count - msgId:$msgId - options:$options}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("updateOptions - fail - msgId:$msgId");
    return false;
  }

  Future<bool> updateDeleteTime(String? msgId, DateTime? deleteTime) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'delete_time': deleteTime?.millisecondsSinceEpoch,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("updateDeleteTime - count:$count - msgId:$msgId - deleteTime:$deleteTime}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("updateDeleteTime - fail - msgId:$msgId");
    return false;
  }

  Future<int> unReadCount() async {
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'is_outbound = ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [0, 0, ContentType.piece, ContentType.receipt],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("unReadCountByNotSender - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("unReadCountByNotSender - fail");
    return 0;
  }

  Future<int> unReadCountByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return 0;
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'is_outbound = ? AND target_id = ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [0, targetId, 0, ContentType.piece, ContentType.receipt],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("unReadCountByTargetId - targetId:$targetId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("unReadCountByTargetId - fail - targetId:$targetId");
    return 0;
  }

  Future<bool> updateMessageStatus(MessageSchema? schema) async {
    if (schema == null) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'is_outbound': schema.isOutbound ? 1 : 0,
          'is_send_error': schema.isSendError ? 1 : 0,
          'is_success': schema.isSuccess ? 1 : 0,
          'is_read': schema.isRead ? 1 : 0,
        },
        where: 'msg_id = ?',
        whereArgs: [schema.msgId],
      );
      logger.d("updateMessageStatus - schema:$schema");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    logger.w("updateMessageStatus - fail - schema:$schema");
    return false;
  }

  /// TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO

  /// ContentType is text, textExtension, media, audio counted to not read
  Future<List<SessionSchema>> getLastSession(int skip, int limit) async {
    List<Map<String, dynamic>>? res = await db?.query(
      '$tableName as m',
      columns: [
        'm.*',
        '(SELECT COUNT(id) from $tableName WHERE target_id = m.target_id AND is_outbound = 0 AND is_read = 0 '
            'AND (type = "text" '
            'or type = "textExtension" '
            'or type = "media" '
            'or type = "audio")) as not_read',
        'MAX(send_time)'
      ],
      where: "type = ? or type = ? or type = ? or type = ? or type = ?",
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.image,
        ContentType.audio,
      ],
      groupBy: 'm.target_id',
      orderBy: 'm.send_time desc',
      limit: limit,
      offset: skip,
    );

    List<SessionSchema> list = <SessionSchema>[];
    if (res != null && res.length > 0) {
      for (var i = 0, length = res.length; i < length; i++) {
        var item = res[i];
        SessionSchema? model = await SessionSchema.fromMap(item);
        if (model != null) {
          list.add(model);
        }
      }
    }
    if (list.length > 0) {
      return list;
    }
    return [];
  }

  Future<SessionSchema?> getUpdateSession(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return null;
    List<Map<String, dynamic>>? res = await db?.query(
      '$tableName',
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0 AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
      whereArgs: [
        targetId,
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.audio,
        ContentType.image,
      ],
      orderBy: 'send_time desc',
    );

    if (res != null && res.length > 0) {
      Map info = res[0];
      SessionSchema? model = await SessionSchema.fromMap(info);
      model?.notReadCount = res.length;
      return model;
    } else {
      List<Map<String, dynamic>>? countResult = await db?.query(
        '$tableName',
        where: 'target_id = ? AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
        whereArgs: [
          targetId,
          ContentType.text,
          ContentType.textExtension,
          ContentType.media,
          ContentType.audio,
          ContentType.image,
        ],
        orderBy: 'send_time desc',
      );
      if (countResult != null && countResult.length > 0) {
        Map info = countResult[0];
        SessionSchema? model = await SessionSchema.fromMap(info);
        model?.notReadCount = 0;
        return model;
      }
    }
    return null;
  }

  Future<int> deleteTargetChat(String targetId) async {
    return await db?.delete(tableName, where: 'target_id = ?', whereArgs: [targetId]) ?? 0;
  }
}
