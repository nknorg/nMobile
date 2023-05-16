import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SubscriberStorage with Tag {
  // static String get tableName => 'Subscribers';
  // static String get tableName => 'subscriber';
  static String get tableName => 'Subscriber_3'; // v5

  static SubscriberStorage instance = SubscriberStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_subscriber", onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `topic` VARCHAR(100),
        `contact_address` VARCHAR(100),
        `status` INT,
        `perm_page` INT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_subscriber_topic_contact_address` ON `$tableName` (`topic`, `contact_address`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_create_at` ON `$tableName` (`topic`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_update_at` ON `$tableName` (`topic`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_create_at` ON `$tableName` (`topic`, `status`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_update_at` ON `$tableName` (`topic`, `status`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_perm_status` ON `$tableName` (`topic`, `perm_page`, `status`)');
  }

  Future<SubscriberSchema?> insert(SubscriberSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.topic.isEmpty || schema.contactAddress.isEmpty) return null;
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
              where: 'topic = ? AND contact_address = ?',
              whereArgs: [schema.topic, schema.contactAddress],
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
        SubscriberSchema added = SubscriberSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<SubscriberSchema?> query(String? topic, String? contactAddress) async {
    if (db?.isOpen != true) return null;
    if (topic == null || topic.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic = ? AND contact_address = ?',
          whereArgs: [topic, contactAddress],
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - topic:$topic - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty -  - topic:$topic - contactAddress:$contactAddress");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<SubscriberSchema>> queryListByTopic(String? topic, {int? status, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (topic == null || topic.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: status != null ? 'topic = ? AND status = ?' : 'topic = ?',
          whereArgs: status != null ? [topic, status] : [topic],
          offset: offset,
          limit: limit,
          orderBy: orderBy ?? 'create_at ASC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTopic - empty - topic:$topic - status:$status");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        SubscriberSchema subscriber = SubscriberSchema.fromMap(map);
        results.add(subscriber);
      });
      // logger.v("$TAG - queryListByTopic - topic:$topic - status:$status - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<SubscriberSchema>> queryListByTopicPerm(String? topic, int? permPage, int limit) async {
    if (db?.isOpen != true) return [];
    if (topic == null || topic.isEmpty || permPage == null) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic = ? AND perm_page = ?',
          whereArgs: [topic, permPage],
          offset: 0,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTopicPerm - empty - topic:$topic - permPage:$permPage");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        SubscriberSchema subscriber = SubscriberSchema.fromMap(map);
        results.add(subscriber);
      });
      // logger.v("$TAG - queryListByTopicPerm - topic:$topic - permPage:$permPage - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<int> queryCountByTopic(String? topic, {int? status}) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: status != null ? 'topic = ? AND status = ?' : 'topic = ?',
          whereArgs: status != null ? [topic, status] : [topic],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - queryCountByTopic - topic:$topic - count:$status");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<int> queryCountByTopicPermPage(String? topic, int permPage, {int? status}) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: status != null ? 'topic = ? AND perm_page = ? AND status = ?' : 'topic = ? AND perm_page = ?',
          whereArgs: status != null ? [topic, permPage, status] : [topic, permPage],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - queryCountByTopicPermPage - topic:$topic - permPage:$permPage - count:$status");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<int> queryMaxPermPageByTopic(String? topic) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic = ?',
          whereArgs: [topic],
          orderBy: 'perm_page DESC',
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
        // logger.v("$TAG - queryMaxPermPageByTopic - success - topic:$topic - schema:$schema");
        return schema.permPage ?? 0;
      }
      // logger.v("$TAG - queryMaxPermPageByTopic - empty - topic:$topic");
      return 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<bool> setStatus(String? topic, String? contactAddress, int? status) async {
    if (db?.isOpen != true) return false;
    if (topic == null || topic.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'status': status,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic = ? AND contact_address = ?',
                whereArgs: [topic, contactAddress],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setStatus - success - topic:$topic - contactAddress:$contactAddress - status:$status");
              return true;
            }
            logger.w("$TAG - setStatus - fail - topic:$topic - contactAddress:$contactAddress - status:$status");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setPermPage(String? topic, String? contactAddress, int? permPage) async {
    if (db?.isOpen != true) return false;
    if (topic == null || topic.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'perm_page': permPage,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic = ? AND contact_address = ?',
                whereArgs: [topic, contactAddress],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setPermPage - success - topic:$topic - contactAddress:$contactAddress - permPage:$permPage");
              return true;
            }
            logger.w("$TAG - setPermPage - fail - topic:$topic - contactAddress:$contactAddress - permPage:$permPage");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<Map<String, dynamic>?> setData(String? topic, String? contactAddress, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (topic == null || topic.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'topic = ? AND contact_address = ?',
                whereArgs: [topic, contactAddress],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - topic:$topic - contactAddress:$contactAddress");
                return null;
              }
              SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data ?? Map<String, dynamic>();
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
                where: 'topic = ? AND contact_address = ?',
                whereArgs: [topic, contactAddress],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - topic:$topic - contactAddress:$contactAddress - newData:$data");
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
