import 'dart:convert';

import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
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

  Future<SessionSchema?> insert(SessionSchema? schema, {bool checkDuplicated = true}) async {
    if (schema == null) return null;
    try {
      Map<String, dynamic> entity = await schema.toMap();
      int? id;
      if (!checkDuplicated) {
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

  Future<List<SessionSchema>> queryListRecent({int? offset, int? limit}) async {
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        orderBy: 'is_top desc, send_time desc',
        offset: offset ?? null,
        limit: limit ?? null,
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

  Future<bool> updateLastMessageAndUnReadCount(SessionSchema? schema) async {
    if (schema == null || schema.targetId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'last_message_time': schema.lastMessageTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'last_message_options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
          'un_read_count': schema.unReadCount,
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
}
