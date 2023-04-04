import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class PrivateGroupStorage with Tag {
  static String get tableName => 'PrivateGroup';

  static PrivateGroupStorage instance = PrivateGroupStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_private_group", timeout: Duration(seconds: 10), onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `group_id` VARCHAR(200),
        `type` INT,
        `name` VARCHAR(200),
        `version` TEXT,
        `count` INT,
        `avatar` TEXT,
        `joined` BOOLEAN DEFAULT 0,
        `is_top` BOOLEAN DEFAULT 0,
        `options` TEXT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_private_group_group_id` ON `$tableName` (`group_id`)');
    await db.execute('CREATE INDEX `index_private_group_name` ON `$tableName` (`name`)');
    await db.execute('CREATE INDEX `index_private_group_create_at` ON `$tableName` (`create_at`)');
    await db.execute('CREATE INDEX `index_private_group_update_at` ON `$tableName` (`update_at`)');
    await db.execute('CREATE INDEX `index_private_group_type_create_at` ON `$tableName` (`type`, `create_at`)');
    await db.execute('CREATE INDEX `index_private_group_type_update_at` ON `$tableName` (`type`, `update_at`)');
    await db.execute('CREATE INDEX `index_private_group_joined_type_create_at` ON `$tableName` (`joined`, `type`, `create_at`)');
    await db.execute('CREATE INDEX `index_private_group_joined_type_update_at` ON `$tableName` (`joined`, `type`, `update_at`)');
  }

  Future<PrivateGroupSchema?> insert(PrivateGroupSchema? schema, {bool checkDuplicated = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.groupId.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
    return await _queue.add(() async {
      try {
        int? id;
        if (!checkDuplicated) {
          id = await db?.transaction((txn) {
            return txn.insert(tableName, entity);
          });
        } else {
          id = await db?.transaction((txn) async {
            List<Map<String, dynamic>> res = await txn.query(
              tableName,
              columns: ['*'],
              where: 'group_id = ?',
              whereArgs: [schema.groupId],
              offset: 0,
              limit: 1,
            );
            if (res != null && res.length > 0) {
              logger.w("$TAG - insert - duplicated - schema:$schema");
              return null;
            } else {
              return await txn.insert(tableName, entity);
            }
          });
        }
        if (id != null) {
          PrivateGroupSchema schema = PrivateGroupSchema.fromMap(entity);
          schema.id = id;
          // logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        } else {
          logger.i("$TAG - insert - exists - schema:$schema");
        }
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<PrivateGroupSchema?> query(String? groupId) async {
    if (db?.isOpen != true) return null;
    if (groupId == null || groupId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'group_id = ?',
          whereArgs: [groupId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - groupId:$groupId - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - groupId:$groupId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<PrivateGroupSchema>> queryListJoined({int? type, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (type != null) ? 'joined = ? AND type = ?' : 'joined = ?',
          whereArgs: (type != null) ? [1, type] : [1],
          offset: offset,
          limit: limit,
          orderBy: orderBy ?? 'create_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - type:$type");
        return [];
      }
      List<PrivateGroupSchema> results = <PrivateGroupSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        PrivateGroupSchema group = PrivateGroupSchema.fromMap(map);
        results.add(group);
      });
      // logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> updateNameType(String? groupId, String? name, int? type) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty) return false;
    if (name == null || name.isEmpty) return false;
    if (type == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'name': name,
                  'type': type,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - updateNameType - success - groupId:$groupId - name:$name - type:$type");
              return true;
            }
            logger.w("$TAG - updateNameType - fail - groupId:$groupId - name:$name - type:$type");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateJoined(String? groupId, bool joined) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'joined': joined ? 1 : 0,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - updateJoined - success - groupId:$groupId - joined:$joined");
              return true;
            }
            logger.w("$TAG - updateJoined - fail - groupId:$groupId - joined:$joined");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateVersionCount(String? groupId, String? version, int membersCount) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'version': version,
                  'count': membersCount,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - updateVersionCount - success - groupId:$groupId - count:$count");
              return true;
            }
            logger.w("$TAG - updateVersionCount - fail - groupId:$groupId - count:$count");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateAvatar(String? groupId, String? avatarLocalPath) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'avatar': avatarLocalPath,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - updateAvatar - success - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
              return true;
            }
            logger.w("$TAG - updateAvatar - fail - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<OptionsSchema?> setBurning(String? groupId, int? burningSeconds) async {
    if (db?.isOpen != true) return null;
    if (groupId == null || groupId.isEmpty) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'group_id = ?',
                whereArgs: [groupId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setBurning - no exists - groupId:$groupId");
                return null;
              }
              PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
              OptionsSchema options = schema.options ?? OptionsSchema();
              options.deleteAfterSeconds = burningSeconds ?? 0;
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options.toMap()),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
              if (count <= 0) logger.w("$TAG - setBurning - fail - groupId:$groupId - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setData(String? groupId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (groupId == null || groupId.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'group_id = ?',
                whereArgs: [groupId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - groupId:$groupId");
                return null;
              }
              PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data ?? Map<String, dynamic>();
              data.addAll(added ?? Map());
              if ((removeKeys != null) && removeKeys.isNotEmpty) {
                removeKeys.forEach((element) => data.remove(element));
              }
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - groupId:$groupId - newData:$data");
              return (count > 0) ? data : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }
}
