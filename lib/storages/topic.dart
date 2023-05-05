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
  static String get tableName => 'Topic_3'; // v5

  static TopicStorage instance = TopicStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_topic", timeout: Duration(seconds: 10), onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `topic` VARCHAR(200),
        `type` INT,
        `create_at` BIGINT,
        `update_at` BIGINT,
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
    await db.execute('CREATE UNIQUE INDEX `index_unique_topic_topic` ON `$tableName` (`topic`)');
    await db.execute('CREATE INDEX `index_topic_create_at` ON `$tableName` (`create_at`)');
    await db.execute('CREATE INDEX `index_topic_update_at` ON `$tableName` (`update_at`)');
    await db.execute('CREATE INDEX `index_topic_type_create_at` ON `$tableName` (`type`, `create_at`)');
    await db.execute('CREATE INDEX `index_topic_type_update_at` ON `$tableName` (`type`, `update_at`)');
    await db.execute('CREATE INDEX `index_topic_joined_type_create_at` ON `$tableName` (`joined`, `type`, `create_at`)');
    await db.execute('CREATE INDEX `index_topic_joined_type_update_at` ON `$tableName` (`joined`, `type`, `update_at`)');
  }

  Future<TopicSchema?> insert(TopicSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.topic.isEmpty) return null;
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
              where: 'topic = ?',
              whereArgs: [schema.topic],
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

  Future<TopicSchema?> query(int? topicId) async {
    if (db?.isOpen != true) return null;
    if (topicId == null || topicId == 0) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'id = ?',
          whereArgs: [topicId],
          offset: 0,
          limit: 1,
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

  Future<TopicSchema?> queryByTopic(String? topic) async {
    if (db?.isOpen != true) return null;
    if (topic == null || topic.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic = ?',
          whereArgs: [topic],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        TopicSchema schema = TopicSchema.fromMap(res.first);
        // logger.v("$TAG - queryByTopic - success - topic:$topic - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - queryByTopic - empty - topic:$topic");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<TopicSchema>> queryList({int? topicType, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (topicType != null) ? 'type = ?' : null,
          whereArgs: (topicType != null) ? [topicType] : null,
          offset: offset,
          limit: limit,
          orderBy: orderBy ?? 'create_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - topicType:$topicType");
        return [];
      }
      List<TopicSchema> results = <TopicSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        TopicSchema topic = TopicSchema.fromMap(map);
        results.add(topic);
      });
      // logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<TopicSchema>> queryListJoined({int? topicType, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (topicType != null) ? 'joined = ? AND type = ?' : 'joined = ?',
          whereArgs: (topicType != null) ? [1, topicType] : [1],
          offset: offset,
          limit: limit,
          orderBy: orderBy ?? 'create_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - topicType:$topicType");
        return [];
      }
      List<TopicSchema> results = <TopicSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        TopicSchema topic = TopicSchema.fromMap(map);
        results.add(topic);
      });
      // logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> setJoined(int? topicId, bool joined, {int? subscribeAt, int? expireBlockHeight, int? createAt}) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId == 0) return false;
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
                where: 'id = ?',
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

  Future<bool> setAvatar(int? topicId, String? avatarLocalPath) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId == 0) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'avatar': avatarLocalPath,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
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

  Future<bool> setCount(int? topicId, int userCount) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId == 0) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'count': userCount,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
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

  Future<bool> setTop(int? topicId, bool top) async {
    if (db?.isOpen != true) return false;
    if (topicId == null || topicId == 0) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_top': top ? 1 : 0,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
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

  Future<Map<String, dynamic>?> setData(int? topicId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (topicId == null || topicId == 0) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'id = ?',
                whereArgs: [topicId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - topicId:$topicId");
                return null;
              }
              TopicSchema schema = TopicSchema.fromMap(res.first);
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
                where: 'id = ?',
                whereArgs: [topicId],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - topic:${schema.topic} - newData:$data");
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
