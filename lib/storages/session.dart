import 'dart:convert';

import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SessionStorage with Tag {
  static String get tableName => 'Session';

  Database? get db => DB.currentDatabase;

  SessionStorage();

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_id TEXT,
        is_topic BOOLEAN DEFAULT 0,
        last_message_time INTEGER,
        last_message_options TEXT,
        un_read_count INTEGER,
        is_top BOOLEAN DEFAULT 0,
      )''');
    // index
    await db.execute('CREATE INDEX index_session_target_id ON Session (target_id)');
    await db.execute('CREATE INDEX index_session_is_topic ON Session (is_topic)');
    await db.execute('CREATE INDEX index_session_un_read_count ON Session (un_read_count)');
    // query session
    await db.execute('CREATE INDEX index_session_top_last_message_time ON Session (is_top, last_message_time)');
  }

  Future<SessionSchema?> insert(SessionSchema? schema, {bool canDuplicated = false}) async {
    if (schema == null) return null;
    try {
      Map<String, dynamic> entity = await schema.toMap();
      int? id;
      if (canDuplicated) {
        id = await db?.insert(tableName, entity);
      } else {
        await db?.transaction((txn) async {
          List<Map<String, dynamic>>? res = await txn.query(
            tableName,
            columns: ['*'],
            where: 'target_id = ?',
            whereArgs: [schema.targetId],
          );
          if (res != null && res.length > 0) {
            throw Exception(["session duplicated!"]);
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        SessionSchema schema = SessionSchema.fromMap(entity);
        schema.id = id;
        logger.d("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - fail - schema:$schema");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<bool> delete(String targetId) async {
    if (targetId.isEmpty) return false;
    try {
      int? result = await db?.delete(
        tableName,
        where: 'target_id = ?',
        whereArgs: [targetId],
      );
      if (result != null && result > 0) {
        logger.d("$TAG - delete - success - targetId:$targetId");
        return true;
      }
      logger.w("$TAG - delete - empty - targetId:$targetId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<SessionSchema?> query(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'target_id = ?',
        whereArgs: [targetId],
      );
      if (res != null && res.length > 0) {
        SessionSchema schema = SessionSchema.fromMap(res.first);
        logger.d("$TAG - query - success - targetId:$targetId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - query - empty - targetId:$targetId ");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<SessionSchema>> queryListRecent({int offset = 0, int limit = 20}) async {
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        orderBy: 'is_top desc, send_time desc',
        limit: limit,
        offset: offset,
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListRecent - empty");
        return [];
      }
      List<SessionSchema> result = <SessionSchema>[];
      String logText = '';
      res.forEach((map) {
        SessionSchema item = SessionSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListRecent - success - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<bool> updateLastMessage(SessionSchema? schema) async {
    if (schema == null || schema.targetId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'last_message_time': schema.lastMessageTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
        },
        where: 'target_id = ?',
        whereArgs: [schema.targetId],
      );
      logger.d("$TAG - updateLastMessage - count:$count - schema:$schema}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateUnReadCount(String? targetId, int unread) async {
    if (targetId == null || targetId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'un_read_count': unread,
        },
        where: 'target_id = ?',
        whereArgs: [targetId],
      );
      logger.d("$TAG - updateUnReadCount - targetId:$targetId - unread:$unread");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateIsTop(String? targetId, bool isTop) async {
    if (targetId == null || targetId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'is_top': isTop ? 1 : 0,
        },
        where: 'target_id = ?',
        whereArgs: [targetId],
      );
      logger.d("$TAG - updateIsTop - targetId:$targetId - isTop:$isTop");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
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
      where: "type = ? or type = ? or type = ? or type = ? or type = ? or type = ?",
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.image,
        ContentType.nknImage,
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
        SessionSchema? model = SessionSchema.fromMap(item);
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
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0 AND (type = ? or type = ? or type = ? or type = ? or type = ? or type = ?)',
      whereArgs: [
        targetId,
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.image,
        ContentType.nknImage,
        ContentType.audio,
      ],
      orderBy: 'send_time desc',
    );

    if (res != null && res.length > 0) {
      Map info = res[0];
      SessionSchema? model = SessionSchema.fromMap(info);
      model?.notReadCount = res.length;
      return model;
    } else {
      List<Map<String, dynamic>>? countResult = await db?.query(
        '$tableName',
        where: 'target_id = ? AND (type = ? or type = ? or type = ? or type = ? or type = ? or type = ?)',
        whereArgs: [
          targetId,
          ContentType.text,
          ContentType.textExtension,
          ContentType.media,
          ContentType.image,
          ContentType.nknImage,
          ContentType.audio,
        ],
        orderBy: 'send_time desc',
      );
      if (countResult != null && countResult.length > 0) {
        Map info = countResult[0];
        SessionSchema? model = SessionSchema.fromMap(info);
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
