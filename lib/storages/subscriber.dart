import 'dart:convert';

import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SubscriberStorage with Tag {
  static String get tableName => 'subscriber';

  Database? get db => DB.currentDatabase;

  // create_at // TODO:GG rename field
  // update_at // TODO:GG new field
  // status // TODO:GG rename + retype field
  // perm_page // TODO:GG rename field + 需要放进data里吗
  // data // TODO:GG new field
  // uploaded BOOLEAN, // TODO:GG replace by status
  // upload_done BOOLEAN, // TODO:GG replace by status
  // subscribed BOOLEAN, // TODO:GG replace by status
  // expire_at INTEGER // TODO:GG delete
  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        chat_id TEXT,
        create_at INTEGER,
        update_at INTEGER,
        status INTEGER,
        perm_page INTEGER,
        data TEXT
      )''');
    // index
    await db.execute('CREATE UNIQUE INDEX unique_index_subscriber_topic_chat_id ON $tableName (topic, chat_id)');
    await db.execute('CREATE INDEX index_subscriber_topic ON $tableName (topic)');
    await db.execute('CREATE INDEX index_subscriber_create_at ON $tableName (create_at)');
    await db.execute('CREATE INDEX index_subscriber_update_at ON $tableName (update_at)');
    await db.execute('CREATE INDEX index_subscriber_topic_created_at ON $tableName (topic, create_at)');
    await db.execute('CREATE INDEX index_subscriber_topic_update_at ON $tableName (topic, update_at)');
    await db.execute('CREATE INDEX index_subscriber_topic_status_created_at ON $tableName (topic, status, create_at)');
    await db.execute('CREATE INDEX index_subscriber_topic_status_update_at ON $tableName (topic, status, update_at)');
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
            throw Exception(["subscriber duplicated!"]);
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        SubscriberSchema? schema = SubscriberSchema.fromMap(entity);
        schema?.id = id;
        logger.d("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - fail - schema:$schema");
    } catch (e) {
      if (e.toString() != "subscriber duplicated!") {
        handleError(e);
      }
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
        logger.d("$TAG - delete - success - subscriberId:$subscriberId");
        return true;
      }
      logger.w("$TAG - delete - fail - subscriberId:$subscriberId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

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
        logger.d("$TAG - query - success - subscriberId:$subscriberId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - query - empty - subscriberId:$subscriberId");
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
        logger.d("$TAG - queryByTopicChatId - success - topic:$topic - chatId:$chatId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryByTopicChatId - empty -  - topic:$topic - chatId:$chatId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<SubscriberSchema>> queryListByTopic(String? topic, {int? status, String? orderBy, int? limit, int? offset}) async {
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: status != null ? 'topic = ? AND status >= ?' : 'topic = ?',
        whereArgs: status != null ? [topic, status] : [topic],
        offset: offset ?? null,
        limit: limit ?? null,
        orderBy: orderBy ?? 'create_at asc',
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListByTopic - empty - topic:$topic - status:$status");
        return [];
      }
      List<SubscriberSchema> results = <SubscriberSchema>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n$map";
        SubscriberSchema? subscriber = SubscriberSchema.fromMap(map);
        if (subscriber != null) results.add(subscriber);
      });
      logger.d("$TAG - queryListByTopic - items:$logText");
      return results;
    } catch (e) {
      handleError(e);
    }
    return [];
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
        logger.d("$TAG - setStatus - success - subscriberId:$subscriberId - status:$status");
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
        logger.d("$TAG - setPermPage - success - subscriberId:$subscriberId - permPage:$permPage");
        return true;
      }
      logger.w("$TAG - setPermPage - fail - subscriberId:$subscriberId - permPage:$permPage");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setData(int? subscriberId, Map<String, dynamic>? newData) async {
    if (subscriberId == null || subscriberId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'data': (newData?.isNotEmpty == true) ? jsonEncode(newData) : null,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [subscriberId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setData - success - subscriberId:$subscriberId - newData:$newData");
        return true;
      }
      logger.w("$TAG - setData - fail - subscriberId:$subscriberId - newData:$newData");
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
