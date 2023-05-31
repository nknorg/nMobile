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

  ParallelQueue _queue = ParallelQueue("storage_private_group", onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `group_id` VARCHAR(100),
        `type` INT,
        `version` TEXT,
        `name` VARCHAR(100),
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
    await db.execute('CREATE INDEX `index_private_group_is_top_create_at` ON `$tableName` (`is_top`, `create_at`)');
    await db.execute('CREATE INDEX `index_private_group_type_is_top_create_at` ON `$tableName` (`type`, `is_top`, `create_at`)');
    await db.execute('CREATE INDEX `index_private_group_joined_is_top_create_at` ON `$tableName` (`joined`, `is_top`, `create_at`)');
    await db.execute('CREATE INDEX `index_private_group_joined_type_is_top_create_at` ON `$tableName` (`joined`, `type`, `is_top`, `create_at`)');
  }

  Future<PrivateGroupSchema?> insert(PrivateGroupSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.groupId.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
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
              where: 'group_id = ?',
              whereArgs: [schema.groupId],
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
        PrivateGroupSchema added = PrivateGroupSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
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

  Future<List<PrivateGroupSchema>> queryListByJoined(bool joined, {int? type, bool orderDesc = true, int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (type != null) ? 'joined = ? AND type = ?' : 'joined = ?',
          whereArgs: (type != null) ? [joined ? 1 : 0, type] : [joined ? 1 : 0],
          offset: offset,
          limit: limit,
          orderBy: "is_top DESC, create_at ${orderDesc ? 'DESC' : 'ASC'}",
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByJoined - empty - joined:$joined - type:$type");
        return [];
      }
      List<PrivateGroupSchema> results = <PrivateGroupSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        PrivateGroupSchema group = PrivateGroupSchema.fromMap(map);
        results.add(group);
      });
      // logger.v("$TAG - queryListByJoined - joined:$joined - type:$type - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> setNameType(String? groupId, String name, int type) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty) return false;
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
              // logger.v("$TAG - setNameType - success - groupId:$groupId - name:$name - type:$type");
              return true;
            }
            logger.w("$TAG - setNameType - fail - groupId:$groupId - name:$name - type:$type");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setJoined(String? groupId, bool joined) async {
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
              // logger.v("$TAG - setJoined - success - groupId:$groupId - joined:$joined");
              return true;
            }
            logger.w("$TAG - setJoined - fail - groupId:$groupId - joined:$joined");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setVersionCount(String? groupId, String? version, int membersCount) async {
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
              // logger.v("$TAG - setVersionCount - success - groupId:$groupId - count:$count");
              return true;
            }
            logger.w("$TAG - setVersionCount - fail - groupId:$groupId - count:$count");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setAvatar(String? groupId, String? avatarLocalPath) async {
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
              // logger.v("$TAG - setAvatar - success - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
              return true;
            }
            logger.w("$TAG - setAvatar - fail - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
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
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setBurning - no exists - groupId:$groupId");
                return null;
              }
              PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
              OptionsSchema options = schema.options;
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
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - groupId:$groupId");
                return null;
              }
              PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data;
              if ((removeKeys != null) && removeKeys.isNotEmpty) {
                removeKeys.forEach((element) => data.remove(element));
              }
              data.addAll(added ?? Map());
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

  Future<Map<String, dynamic>?> setDataItemMapChange(String? groupId, String key, Map addPairs, List delKeys) async {
    if (db?.isOpen != true) return null;
    if (groupId == null || groupId.isEmpty) return null;
    if (addPairs.isEmpty && delKeys.isEmpty) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setDataItemMapChange - no exists - groupId:$groupId");
                return null;
              }
              PrivateGroupSchema schema = PrivateGroupSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data;
              Map<String, dynamic> values = data[key] ?? Map();
              if (delKeys.isNotEmpty) values.removeWhere((key, _) => delKeys.indexWhere((item) => key.toString() == item.toString()) >= 0);
              if (addPairs.isNotEmpty) values.addAll(addPairs.map((key, value) => MapEntry(key.toString(), value)));
              data[key] = values;
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ?',
                whereArgs: [groupId],
              );
              if (count <= 0) logger.w("$TAG - setDataItemMapChange - fail - groupId:$groupId - newData:$data");
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
