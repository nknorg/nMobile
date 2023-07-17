import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SubscriberStorage with Tag {
  // static String get tableName => 'Subscribers';
  // static String get tableName => 'subscriber';
  // static String get tableName => 'Subscriber_3'; // v5
  static String get tableName => 'subscriber_v7'; // v7

  static SubscriberStorage instance = SubscriberStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = dbCommon.subscribeQueue;

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `topic_id` VARCHAR(100),
        `contact_address` VARCHAR(100),
        `status` INT,
        `perm_page` INT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    try {
      await db.execute('CREATE UNIQUE INDEX `index_unique_subscriber_topic_id_contact_address` ON `$tableName` (`topic_id`, `contact_address`)');
      await db.execute('CREATE INDEX `index_subscriber_topic_id_create_at` ON `$tableName` (`topic_id`, `create_at`)');
      await db.execute('CREATE INDEX `index_subscriber_topic_id_status_create_at` ON `$tableName` (`topic_id`, `status`, `create_at`)');
      await db.execute('CREATE INDEX `index_subscriber_topic_id_perm_status` ON `$tableName` (`topic_id`, `perm_page`, `status`)');
    } catch (e) {
      if (e.toString().contains("exists") != true) throw e;
    }
  }

  Future<SubscriberSchema?> insert(SubscriberSchema? schema, {bool unique = true}) async {
    if (schema == null || schema.topicId.isEmpty || schema.contactAddress.isEmpty) return null;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - insert\n - topicId:${schema.topicId}\n - address:${schema.contactAddress}"); // await
      }
      return null;
    }
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
              where: 'topic_id = ? AND contact_address = ?',
              whereArgs: [schema.topicId, schema.contactAddress],
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

  Future<SubscriberSchema?> query(String? topicId, String? contactAddress) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - query\n - topicId:$topicId\n - address:$contactAddress"); // await
      }
      return null;
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic_id = ? AND contact_address = ?',
          whereArgs: [topicId, contactAddress],
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - topicId:$topicId - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty -  - topicId:$topicId - contactAddress:$contactAddress");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<SubscriberSchema>> queryListByTopicId(String? topicId, {int? status, int offset = 0, final limit = 20}) async {
    if (topicId == null || topicId.isEmpty) return [];
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - queryListByTopicId\n - topicId:$topicId"); // await
      }
      return [];
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: status != null ? 'topic_id = ? AND status = ?' : 'topic_id = ?',
          whereArgs: status != null ? [topicId, status] : [topicId],
          offset: offset,
          limit: limit,
          orderBy: 'create_at ASC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTopicId - empty - topicId:$topicId - status:$status");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        SubscriberSchema subscriber = SubscriberSchema.fromMap(map);
        results.add(subscriber);
      });
      // logger.v("$TAG - queryListByTopicId - topicId:$topicId - status:$status - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<SubscriberSchema>> queryListByTopicIdPerm(String? topicId, int? permPage, int limit) async {
    if (topicId == null || topicId.isEmpty || permPage == null) return [];
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - queryListByTopicIdPerm\n - topicId:$topicId\n - permPage:$permPage"); // await
      }
      return [];
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic_id = ? AND perm_page = ?',
          whereArgs: [topicId, permPage],
          offset: 0,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTopicIdPerm - empty - topicId:$topicId - permPage:$permPage");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        SubscriberSchema subscriber = SubscriberSchema.fromMap(map);
        results.add(subscriber);
      });
      // logger.v("$TAG - queryListByTopicIdPerm - topicId:$topicId - permPage:$permPage - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<int> queryCountByTopicId(String? topicId, {int? status}) async {
    if (topicId == null || topicId.isEmpty) return 0;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - queryCountByTopicId\n - topicId:$topicId\n - status:$status"); // await
      }
      return 0;
    }
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: status != null ? 'topic_id = ? AND status = ?' : 'topic_id = ?',
          whereArgs: status != null ? [topicId, status] : [topicId],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - queryCountByTopicId - topicId:$topicId - count:$status");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<int> queryCountByTopicIdPerm(String? topicId, int permPage, {int? status}) async {
    if (topicId == null || topicId.isEmpty) return 0;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - queryCountByTopicIdPerm\n - topicId:$topicId\n - permPage:$permPage\n - status:$status"); // await
      }
      return 0;
    }
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: status != null ? 'topic_id = ? AND perm_page = ? AND status = ?' : 'topic_id = ? AND perm_page = ?',
          whereArgs: status != null ? [topicId, permPage, status] : [topicId, permPage],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - queryCountByTopicIdPerm - topicId:$topicId - permPage:$permPage - count:$status");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<int> queryMaxPermPageByTopicId(String? topicId) async {
    if (topicId == null || topicId.isEmpty) return 0;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - queryMaxPermPageByTopicId\n - topicId:$topicId"); // await
      }
      return 0;
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic_id = ?',
          whereArgs: [topicId],
          orderBy: 'perm_page DESC',
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
        // logger.v("$TAG - queryMaxPermPageByTopicId - success - topicId:$topicId - schema:$schema");
        return schema.permPage ?? 0;
      }
      // logger.v("$TAG - queryMaxPermPageByTopicId - empty - topicId:$topicId");
      return 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<bool> setStatus(String? topicId, String? contactAddress, int status) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - setStatus\n - topicId:$topicId\n - address:$contactAddress\n - status:$status"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'status': status,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic_id = ? AND contact_address = ?',
                whereArgs: [topicId, contactAddress],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setStatus - success - topicId:$topicId - contactAddress:$contactAddress - status:$status");
              return true;
            }
            logger.w("$TAG - setStatus - fail - topicId:$topicId - contactAddress:$contactAddress - status:$status");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setPermPage(String? topicId, String? contactAddress, int? permPage) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - setPermPage\n - topicId:$topicId\n - address:$contactAddress\n - permPage:$permPage"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'perm_page': permPage,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'topic_id = ? AND contact_address = ?',
                whereArgs: [topicId, contactAddress],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setPermPage - success - topicId:$topicId - contactAddress:$contactAddress - permPage:$permPage");
              return true;
            }
            logger.w("$TAG - setPermPage - fail - topicId:$topicId - contactAddress:$contactAddress - permPage:$permPage");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<Map<String, dynamic>?> setData(String? topicId, String? contactAddress, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SUBSCRIBER CLOSED - setData\n - topicId:$topicId\n - address:$contactAddress\n - added:$added\n - removeKeys:$removeKeys"); // await
      }
      return null;
    }
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'topic_id = ? AND contact_address = ?',
                whereArgs: [topicId, contactAddress],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - topicId:$topicId - contactAddress:$contactAddress");
                return null;
              }
              SubscriberSchema schema = SubscriberSchema.fromMap(res.first);
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
                where: 'topic_id = ? AND contact_address = ?',
                whereArgs: [topicId, contactAddress],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - topicId:$topicId - contactAddress:$contactAddress - newData:$data");
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
