import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite/sqflite.dart';

class SessionStorage with Tag {
  static String get tableName => 'Session';

  Database? get db => dbCommon.database;

  SessionStorage();

  static create(Database db) async {
    // create table
    await db.execute('''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `target_id` VARCHAR(200),
        `type` INT,
        `last_message_at` BIGINT,
        `last_message_options` TEXT,
        `un_read_count` INT,
        `is_top` BOOLEAN DEFAULT 0
      )''');

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_session_target_id` ON `$tableName` (`target_id`)');
    await db.execute('CREATE INDEX `index_session_is_top_last_message_at` ON `$tableName` (`is_top`, `last_message_at`)');
    await db.execute('CREATE INDEX `index_session_type_is_top_last_message_at` ON `$tableName` (`type`, `is_top`, `last_message_at`)');
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
            logger.w("$TAG - insert - duplicated - schema:$schema");
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        SessionSchema schema = SessionSchema.fromMap(entity);
        schema.id = id;
        logger.v("$TAG - insert - success - schema:$schema");
        return schema;
      } else {
        SessionSchema? exists = await query(schema.targetId);
        if (exists != null) {
          logger.i("$TAG - insert - exists - schema:$exists");
        } else {
          logger.w("$TAG - insert - fail - schema:$schema");
        }
      }
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
        logger.v("$TAG - delete - success - targetId:$targetId");
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
        logger.v("$TAG - query - success - targetId:$targetId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - query - empty - targetId:$targetId ");
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
        offset: offset ?? null,
        limit: limit ?? null,
        orderBy: 'is_top desc, last_message_at DESC',
      );
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListRecent - empty");
        return [];
      }
      List<SessionSchema> result = <SessionSchema>[];
      String logText = '';
      res.forEach((map) {
        SessionSchema item = SessionSchema.fromMap(map);
        logText += "\n      $item";
        result.add(item);
      });
      logger.v("$TAG - queryListRecent - success - length:${result.length} - items:$logText");
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
          'last_message_at': schema.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch,
          'last_message_options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
          'un_read_count': schema.unReadCount,
        },
        where: 'target_id = ?',
        whereArgs: [schema.targetId],
      );
      logger.v("$TAG - updateLastMessageAndUnReadCount - count:$count - schema:$schema");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<bool> updateLastMessage(SessionSchema? schema) async {
  //   if (schema == null || schema.targetId.isEmpty) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'last_message_at': schema.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch,
  //         'last_message_options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
  //       },
  //       where: 'target_id = ?',
  //       whereArgs: [schema.targetId],
  //     );
  //     logger.v("$TAG - updateLastMessage - count:$count - schema:$schema");
  //     return (count ?? 0) > 0;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }

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
      logger.v("$TAG - updateIsTop - targetId:$targetId - isTop:$isTop");
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
      logger.v("$TAG - updateUnReadCount - targetId:$targetId - unread:$unread");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
