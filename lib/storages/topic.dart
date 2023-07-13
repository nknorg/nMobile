import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class TopicStorage with Tag {
  // static String get tableName => 'Topic';
  // static String get tableName => 'topic';
  // static String get tableName => 'Topic_3'; // v5
  static String get tableName => 'topic_v7'; // v7

  static TopicStorage instance = TopicStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = dbCommon.topicQueue;

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `topic_id` VARCHAR(100),
        `type` INT,
        `joined` BOOLEAN DEFAULT 0,
        `subscribe_at` BIGINT,
        `expire_height` BIGINT,
        `avatar` TEXT,
        `count` INT,
        `is_top` BOOLEAN DEFAULT 0,
        `options` TEXT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    try {
      await db.execute('CREATE UNIQUE INDEX `index_unique_topic_topic_id` ON `$tableName` (`topic_id`)');
      await db.execute('CREATE INDEX `index_topic_is_top_create_at` ON `$tableName` (`is_top`, `create_at`)');
      await db.execute('CREATE INDEX `index_topic_type_is_top_create_at` ON `$tableName` (`type`, `is_top`, `create_at`)');
      await db.execute('CREATE INDEX `index_topic_joined_is_top_create_at` ON `$tableName` (`joined`, `is_top`, `create_at`)');
      await db.execute('CREATE INDEX `index_topic_joined_type_is_top_create_at` ON `$tableName` (`joined`, `type`, `is_top`, `create_at`)');
    } catch (e) {
      if (e.toString().contains("exists") != true) throw e;
    }
  }

  Future<TopicSchema?> insert(TopicSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.topicId.isEmpty) return null;
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
              where: 'topic_id = ?',
              whereArgs: [schema.topicId],
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
        TopicSchema added = TopicSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<TopicSchema?> query(String? topicId) async {
    if (db?.isOpen != true) return null;
    if (topicId == null || topicId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic_id = ?',
          whereArgs: [topicId],
        );
      });
      if (res != null && res.length > 0) {
        TopicSchema schema = TopicSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - topicId:$topicId - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - topicId:$topicId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<TopicSchema>> queryList({int? type, bool orderDesc = true, int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (type != null) ? 'type = ?' : null,
          whereArgs: (type != null) ? [type] : null,
          offset: offset,
          limit: limit,
          orderBy: "is_top DESC, create_at ${orderDesc ? 'DESC' : 'ASC'}",
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - type:$type");
        return [];
      }
      List<TopicSchema> results = <TopicSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        TopicSchema topic = TopicSchema.fromMap(map);
        results.add(topic);
      });
      // logger.v("$TAG - queryList - type:$type - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<TopicSchema>> queryListByJoined(bool joined, {int? type, bool orderDesc = true, int offset = 0, final limit = 20}) async {
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
      List<TopicSchema> results = <TopicSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        TopicSchema topic = TopicSchema.fromMap(map);
        results.add(topic);
      });
      // logger.v("$TAG - queryListByJoined - joined:$joined - type:$type - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> setJoined(String? topicId, bool joined, {int? subscribeAt, int? expireBlockHeight, int? createAt}) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId.isEmpty) return false;
    var values = {
      'joined': joined ? 1 : 0,
      'update_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (expireBlockHeight != null) {
      values["subscribe_at"] = subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      values["expire_height"] = expireBlockHeight;
    }
    if (createAt != null) {
      values["create_at"] = createAt;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                values,
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setJoined - success - topicId:$topicId - joined:$joined - expireBlockHeight:$expireBlockHeight");
              return true;
            }
            logger.w("$TAG - setJoined - fail - topicId:$topicId - joined:$joined - expireBlockHeight:$expireBlockHeight");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setAvatar(String? topicId, String? avatarLocalPath) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'avatar': avatarLocalPath,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setAvatar - success - topicId:$topicId - avatarLocalPath:$avatarLocalPath");
              return true;
            }
            logger.w("$TAG - setAvatar - fail - topicId:$topicId - avatarLocalPath:$avatarLocalPath");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setCount(String? topicId, int userCount) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'count': userCount,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setCount - success - topicId:$topicId - count:$count");
              return true;
            }
            logger.w("$TAG - setCount - fail - topicId:$topicId - count:$count");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setTop(String? topicId, bool top) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_top': top ? 1 : 0,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setTop - success - topicId:$topicId - top:$top");
              return true;
            }
            logger.w("$TAG - setTop - fail - topicId:$topicId - top:$top");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<Map<String, dynamic>?> setData(String? topicId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (topicId == null || topicId.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - topicId:$topicId");
                return null;
              }
              TopicSchema schema = TopicSchema.fromMap(res.first);
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
                where: 'topic_id = ?',
                whereArgs: [topicId],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - topic:${schema.topicId} - newData:$data");
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
