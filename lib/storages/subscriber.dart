import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class SubscriberStorage with Tag {
  // static String get tableName => 'Subscribers';
  // static String get tableName => 'subscriber';
  static String get tableName => 'Subscriber_3'; // v5

  Database? get db => dbCommon.database;

  Lock _lock = new Lock();

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `topic` VARCHAR(200),
        `chat_id` VARCHAR(200),
        `create_at` BIGINT,
        `update_at` BIGINT,
        `status` INT,
        `perm_page` INT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_subscriber_topic_chat_id` ON `$tableName` (`topic`, `chat_id`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_create_at` ON `$tableName` (`topic`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_update_at` ON `$tableName` (`topic`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_create_at` ON `$tableName` (`topic`, `status`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_update_at` ON `$tableName` (`topic`, `status`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_perm_status` ON `$tableName` (`topic`, `perm_page`, `status`)');
  }

  Future<SubscriberSchema?> insert(SubscriberSchema? schema, {bool checkDuplicated = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.topic.isEmpty || schema.clientAddress.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
    return await _lock.synchronized(() async {
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
              where: 'topic = ? AND chat_id = ?',
              whereArgs: [schema.topic, schema.clientAddress],
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
          SubscriberSchema? schema = SubscriberSchema.fromMap(entity);
          schema?.id = id;
          logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        } else {
          logger.i("$TAG - insert - exists - schema:$schema");
        }
      } catch (e) {
        handleError(e);
      }
      return null;
    });
  }

  // Future<bool> delete(int? subscriberId) async {
  //   if (db?.isOpen != true) return false;
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   return await _lock.synchronized(() async {
  //     try {
  //       int? count = await db?.transaction((txn) {
  //         return txn.delete(
  //           tableName,
  //           where: 'id = ?',
  //           whereArgs: [subscriberId],
  //         );
  //       });
  //       if (count != null && count > 0) {
  //         logger.v("$TAG - delete - success - subscriberId:$subscriberId");
  //         return true;
  //       }
  //       logger.w("$TAG - delete - fail - subscriberId:$subscriberId");
  //     } catch (e) {
  //       handleError(e);
  //     }
  //     return false;
  //   });
  // }

  // Future<int> deleteByTopic(String? topic) async {
  // if (db?.isOpen != true) return 0;
  //   if (topic == null || topic.isEmpty) return 0;
  //   return await _lock.synchronized(() async {
  //     try {
  //       int? count = await db?.transaction((txn) {
  //         return txn.delete(
  //           tableName,
  //           where: 'topic = ?',
  //           whereArgs: [topic],
  //         );
  //       });
  //       if (count != null && count > 0) {
  //         logger.v("$TAG - deleteByTopic - success - topic:$topic");
  //         return count;
  //       }
  //       logger.w("$TAG - deleteByTopic - fail - topic:$topic");
  //     } catch (e) {
  //       handleError(e);
  //     }
  //     return 0;
  //   });
  // }

  Future<SubscriberSchema?> query(int? subscriberId) async {
    if (db?.isOpen != true) return null;
    if (subscriberId == null || subscriberId == 0) return null;
    // return await _lock.synchronized(() async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'id = ?',
          whereArgs: [subscriberId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema? schema = SubscriberSchema.fromMap(res.first);
        logger.v("$TAG - query - success - subscriberId:$subscriberId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - query - empty - subscriberId:$subscriberId");
    } catch (e) {
      handleError(e);
    }
    return null;
    // });
  }

  Future<SubscriberSchema?> queryByTopicChatId(String? topic, String? chatId) async {
    if (db?.isOpen != true) return null;
    if (topic == null || topic.isEmpty || chatId == null || chatId.isEmpty) return null;
    // return await _lock.synchronized(() async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'topic = ? AND chat_id = ?',
          whereArgs: [topic, chatId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        SubscriberSchema? schema = SubscriberSchema.fromMap(res.first);
        logger.v("$TAG - queryByTopicChatId - success - topic:$topic - chatId:$chatId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - queryByTopicChatId - empty -  - topic:$topic - chatId:$chatId");
    } catch (e) {
      handleError(e);
    }
    return null;
    // });
  }

  Future<List<SubscriberSchema>> queryListByTopic(String? topic, {int? status, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (topic == null || topic.isEmpty) return [];
    // return await _lock.synchronized(() async {
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
        logger.v("$TAG - queryListByTopic - empty - topic:$topic - status:$status");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n      $map";
        SubscriberSchema? subscriber = SubscriberSchema.fromMap(map);
        if (subscriber != null) results.add(subscriber);
      });
      logger.v("$TAG - queryListByTopic - items:$logText");
      return results;
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<List<SubscriberSchema>> queryListByTopicPerm(String? topic, int? permPage, int limit) async {
    if (db?.isOpen != true) return [];
    if (topic == null || topic.isEmpty || permPage == null) return [];
    // return await _lock.synchronized(() async {
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
        logger.v("$TAG - queryListByTopicPerm - empty - topic:$topic - permPage:$permPage");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n      $map";
        SubscriberSchema? subscriber = SubscriberSchema.fromMap(map);
        if (subscriber != null) results.add(subscriber);
      });
      logger.v("$TAG - queryListByTopicPerm - items:$logText");
      return results;
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<int> queryCountByTopic(String? topic, {int? status}) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    // return await _lock.synchronized(() async {
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
      logger.v("$TAG - queryCountByTopic - topic:$topic - count:$status");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
    // });
  }

  Future<int> queryCountByTopicPermPage(String? topic, int permPage, {int? status}) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    // return await _lock.synchronized(() async {
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
      logger.v("$TAG - queryCountByTopicPermPage - topic:$topic - permPage:$permPage - count:$status");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
    // });
  }

  Future<int> queryMaxPermPageByTopic(String? topic) async {
    if (db?.isOpen != true) return 0;
    if (topic == null || topic.isEmpty) return 0;
    // return await _lock.synchronized(() async {
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
        SubscriberSchema? schema = SubscriberSchema.fromMap(res.first);
        logger.v("$TAG - queryMaxPermPageByTopic - success - topic:$topic - schema:$schema");
        return schema?.permPage ?? 0;
      }
      logger.v("$TAG - queryMaxPermPageByTopic - empty - topic:$topic");
      return 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
    // });
  }

  Future<bool> setStatus(int? subscriberId, int? status) async {
    if (db?.isOpen != true) return false;
    if (subscriberId == null || subscriberId == 0 || status == null) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            {
              'status': status,
              'update_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [subscriberId],
          );
        });
        if (count != null && count > 0) {
          logger.v("$TAG - setStatus - success - subscriberId:$subscriberId - status:$status");
          return true;
        }
        logger.w("$TAG - setStatus - fail - subscriberId:$subscriberId - status:$status");
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> setPermPage(int? subscriberId, int? permPage) async {
    if (db?.isOpen != true) return false;
    if (subscriberId == null || subscriberId == 0) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            {
              'perm_page': permPage,
              'update_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [subscriberId],
          );
        });
        if (count != null && count > 0) {
          logger.v("$TAG - setPermPage - success - subscriberId:$subscriberId - permPage:$permPage");
          return true;
        }
        logger.w("$TAG - setPermPage - fail - subscriberId:$subscriberId - permPage:$permPage");
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> setData(int? subscriberId, Map<String, dynamic>? newData) async {
    if (db?.isOpen != true) return false;
    if (subscriberId == null || subscriberId == 0) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            {
              'data': (newData?.isNotEmpty == true) ? jsonEncode(newData) : null,
              'update_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [subscriberId],
          );
        });
        if (count != null && count > 0) {
          logger.v("$TAG - setData - success - subscriberId:$subscriberId - newData:$newData");
          return true;
        }
        logger.w("$TAG - setData - fail - subscriberId:$subscriberId - newData:$newData");
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }
}
