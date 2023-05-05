import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SessionStorage with Tag {
  static String get tableName => 'Session';

  static SessionStorage instance = SessionStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_session", timeout: Duration(seconds: 10), onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `target_id` VARCHAR(200),
        `type` INT,
        `last_message_at` BIGINT,
        `last_message_options` TEXT,
        `is_top` BOOLEAN DEFAULT 0,
        `un_read_count` INT,
        `data` TEXT
      )''';

  SessionStorage();

  static create(Database db) async {
    // TODO:GG data_upgrade
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_session_target_id_type` ON `$tableName` (`target_id`, `type`)');
    await db.execute('CREATE INDEX `index_session_is_top_last_message_at` ON `$tableName` (`is_top`, `last_message_at`)');
    await db.execute('CREATE INDEX `index_session_type_is_top_last_message_at` ON `$tableName` (`type`, `is_top`, `last_message_at`)');
  }

  Future<SessionSchema?> insert(SessionSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null) return null;
    Map<String, dynamic> entity = await schema.toMap();
    return await _queue.add(() async {
      try {
        int? id;
        if (!unique) {
          id = await db?.transaction((txn) {
            return txn.insert(tableName, entity);
          });
        } else {
          id = await db?.transaction((txn) async {
            List<Map<String, dynamic>> res = await txn.query(
              tableName,
              columns: ['*'],
              where: 'target_id = ? AND type = ?',
              whereArgs: [schema.targetId, schema.type],
              offset: 0,
              limit: 1,
            );
            if (res != null && res.length > 0) {
              logger.w("$TAG - insert - duplicated - db_exist:${res.first} - insert_new:$schema");
              entity = res.first;
              return null;
            } else {
              return await txn.insert(tableName, entity);
            }
          });
        }
        SessionSchema added = SessionSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<bool> delete(String? targetId, int? type) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty || type == null) return false;
    return await _queue.add(() async {
          try {
            int? result = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            if (result != null && result > 0) {
              // logger.v("$TAG - delete - success - targetId:$targetId - type:$type");
              return true;
            }
            // logger.v("$TAG - delete - empty - targetId:$targetId - type:$type");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<SessionSchema?> query(String? targetId, int? type) async {
    if (db?.isOpen != true) return null;
    if (targetId == null || targetId.isEmpty || type == null) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND type = ?',
          whereArgs: [targetId, type],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        SessionSchema schema = SessionSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - targetId:$targetId - type:$type - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - targetId:$targetId - type:$type");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<SessionSchema>> queryListRecent({int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          offset: offset,
          limit: limit,
          orderBy: 'is_top desc, last_message_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListRecent - empty");
        return [];
      }
      List<SessionSchema> result = <SessionSchema>[];
      // String logText = '';
      res.forEach((map) {
        SessionSchema item = SessionSchema.fromMap(map);
        // logText += "\n      $item";
        result.add(item);
      });
      // logger.v("$TAG - queryListRecent - success - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<int> unReadCount() async {
    if (db?.isOpen != true) return 0;
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['SUM(un_read_count)'],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - unReadCount - count:$count");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<bool> updateLastMessageAndUnReadCount(SessionSchema? schema) async {
    if (db?.isOpen != true) return false;
    if (schema == null || schema.targetId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'last_message_at': schema.lastMessageAt,
                  'last_message_options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
                  'un_read_count': schema.unReadCount,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [schema.targetId, schema.type],
              );
            });
            // logger.v("$TAG - updateLastMessageAndUnReadCount - count:$count - schema:$schema");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateIsTop(String? targetId, int? type, bool isTop) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty || type == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_top': isTop ? 1 : 0,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            // logger.v("$TAG - updateIsTop - targetId:$targetId - type:$type - isTop:$isTop");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateUnReadCount(String? targetId, int? type, int unread) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty || type == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'un_read_count': unread,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            // logger.v("$TAG - updateUnReadCount - targetId:$targetId - type:$type - unread:$unread");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setData(String? targetId, int? type, Map<String, dynamic>? newData) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty || type == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'data': newData != null ? jsonEncode(newData) : null,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setData - success - targetId:$targetId - type:$type - data:$newData");
              return true;
            }
            logger.w("$TAG - setData - fail - targetId:$targetId - type:$type - data:$newData");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }
}
