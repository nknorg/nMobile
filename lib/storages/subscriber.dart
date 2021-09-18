import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite/sqflite.dart';

class SubscriberStorage with Tag {
  // static String get tableName => 'Subscribers';
  static String get tableName => 'subscriber';

  Database? get db => dbCommon.database;

  // create_at // TODO:GG rename field
  // update_at // TODO:GG new field
  // status // TODO:GG rename(member_status) + retype field
  // perm_page // TODO:GG rename field + 需要放进data里吗
  // data // TODO:GG new field
  // subscribed BOOLEAN, // TODO:GG delete
  // uploaded BOOLEAN, // TODO:GG delete
  // upload_done BOOLEAN, // TODO:GG delete
  // expire_at INTEGER // TODO:GG delete
  static create(Database db) async {
    // create table
    await db.execute('''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `topic` VARCHAR(200),
        `chat_id` VARCHAR(200),
        `create_at` BIGINT,
        `update_at` BIGINT,
        `status` INT,
        `perm_page` INT,
        `data` TEXT
      )''');

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_subscriber_topic_chat_id` ON `$tableName` (`topic`, `chat_id`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_create_at` ON `$tableName` (`topic`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_update_at` ON `$tableName` (`topic`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_create_at` ON `$tableName` (`topic`, `status`, `create_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_status_update_at` ON `$tableName` (`topic`, `status`, `update_at`)');
    await db.execute('CREATE INDEX `index_subscriber_topic_perm_status` ON `$tableName` (`topic`, `perm_page`, `status`)');
  }

  Future<SubscriberSchema?> insert(SubscriberSchema? schema, {bool checkDuplicated = true}) async {
    if (schema == null || schema.topic.isEmpty || schema.clientAddress.isEmpty) return null;
    try {
      Map<String, dynamic> entity = schema.toMap();
      int? id;
      if (!checkDuplicated) {
        id = await db?.insert(tableName, entity);
      } else {
        await db?.transaction((txn) async {
          List<Map<String, dynamic>> res = await txn.query(
            tableName,
            columns: ['*'],
            where: 'topic = ? AND chat_id = ?',
            whereArgs: [schema.topic, schema.clientAddress],
          );
          if (res != null && res.length > 0) {
            logger.w("$TAG - insert - duplicated - schema:$schema");
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        SubscriberSchema? schema = SubscriberSchema.fromMap(entity);
        schema?.id = id;
        logger.v("$TAG - insert - success - schema:$schema");
        return schema;
      } else {
        SubscriberSchema? exists = await queryByTopicChatId(schema.topic, schema.clientAddress);
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

  Future<bool> delete(int? subscriberId) async {
    if (subscriberId == null || subscriberId == 0) return false;
    try {
      int? count = await db?.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [subscriberId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - delete - success - subscriberId:$subscriberId");
        return true;
      }
      logger.w("$TAG - delete - fail - subscriberId:$subscriberId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<int> deleteByTopic(String? topic) async {
  //   if (topic == null || topic.isEmpty) return 0;
  //   try {
  //     int? count = await db?.delete(
  //       tableName,
  //       where: 'topic = ?',
  //       whereArgs: [topic],
  //     );
  //     if (count != null && count > 0) {
  //       logger.v("$TAG - deleteByTopic - success - topic:$topic");
  //       return count;
  //     }
  //     logger.w("$TAG - deleteByTopic - fail - topic:$topic");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return 0;
  // }

  Future<SubscriberSchema?> query(int? subscriberId) async {
    if (subscriberId == null || subscriberId == 0) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [subscriberId],
      );
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
  }

  Future<SubscriberSchema?> queryByTopicChatId(String? topic, String? chatId) async {
    if (topic == null || topic.isEmpty || chatId == null || chatId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'topic = ? AND chat_id = ?',
        whereArgs: [topic, chatId],
      );
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
  }

  Future<List<SubscriberSchema>> queryListByTopic(String? topic, {int? status, String? orderBy, int? limit, int? offset}) async {
    if (topic == null || topic.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: status != null ? 'topic = ? AND status = ?' : 'topic = ?',
        whereArgs: status != null ? [topic, status] : [topic],
        offset: offset ?? null,
        limit: limit ?? null,
        orderBy: orderBy ?? 'create_at ASC',
      );
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
  }

  Future<List<SubscriberSchema>> queryListByTopicPerm(String? topic, int? permPage) async {
    if (topic == null || topic.isEmpty || permPage == null) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'topic = ? AND perm_page = ?',
        whereArgs: [topic, permPage],
      );
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
  }

  Future<int> queryCountByTopic(String? topic, {int? status}) async {
    if (topic == null || topic.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: status != null ? 'topic = ? AND status = ?' : 'topic = ?',
        whereArgs: status != null ? [topic, status] : [topic],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - queryCountByTopic - topic:$topic - count:$status");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<int> queryCountByTopicPermPage(String? topic, int permPage, {int? status}) async {
    if (topic == null || topic.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: status != null ? 'topic = ? AND perm_page = ? AND status = ?' : 'topic = ? AND perm_page = ?',
        whereArgs: status != null ? [topic, permPage, status] : [topic, permPage],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - queryCountByTopicPermPage - topic:$topic - permPage:$permPage - count:$status");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<int> queryMaxPermPageByTopic(String? topic) async {
    if (topic == null || topic.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'topic = ?',
        whereArgs: [topic],
        orderBy: 'perm_page DESC',
      );
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
  }

  Future<bool> setStatus(int? subscriberId, int? status) async {
    if (subscriberId == null || subscriberId == 0 || status == null) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'status': status,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [subscriberId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setStatus - success - subscriberId:$subscriberId - status:$status");
        return true;
      }
      logger.w("$TAG - setStatus - fail - subscriberId:$subscriberId - status:$status");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setPermPage(int? subscriberId, int? permPage) async {
    if (subscriberId == null || subscriberId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'perm_page': permPage,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [subscriberId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setPermPage - success - subscriberId:$subscriberId - permPage:$permPage");
        return true;
      }
      logger.w("$TAG - setPermPage - fail - subscriberId:$subscriberId - permPage:$permPage");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<bool> setData(int? subscriberId, Map<String, dynamic>? newData) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'data': (newData?.isNotEmpty == true) ? jsonEncode(newData) : null,
  //         'update_at': DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'id = ?',
  //       whereArgs: [subscriberId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.v("$TAG - setData - success - subscriberId:$subscriberId - newData:$newData");
  //       return true;
  //     }
  //     logger.w("$TAG - setData - fail - subscriberId:$subscriberId - newData:$newData");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
}
