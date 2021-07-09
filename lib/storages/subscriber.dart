import 'package:nmobile/common/db.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SubscriberStorage with Tag {
  static String get tableName => 'subscriber';

  Database? get db => DB.currentDatabase;

  // create_at // TODO:GG rename field
  // update_at // TODO:GG new field
  // status // TODO:GG rename + retype field
  // perm_page // TODO:GG rename field
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
    await db.execute('CREATE UNIQUE INDEX unique_index_topic_topic ON $tableName (topic)');
    await db.execute('CREATE INDEX index_topic_type ON $tableName (type)');
    await db.execute('CREATE INDEX index_topic_create_at ON $tableName (create_at)');
    await db.execute('CREATE INDEX index_topic_update_at ON $tableName (update_at)');
    await db.execute('CREATE INDEX index_topic_subscribe_at ON $tableName (subscribe_at)');
    await db.execute('CREATE INDEX index_topic_type_created_at ON $tableName (type, create_at)');
    await db.execute('CREATE INDEX index_topic_type_update_at ON $tableName (type, update_at)');
    await db.execute('CREATE INDEX index_topic_type_subscribe_at ON $tableName (type, subscribe_at)');
  }

  // Future<TopicSchema?> insert(TopicSchema? schema, {bool checkDuplicated = true}) async {
  //   if (schema == null || schema.topic.isEmpty) return null;
  //   try {
  //     Map<String, dynamic> entity = schema.toMap();
  //     int? id;
  //     if (!checkDuplicated) {
  //       id = await db?.insert(tableName, entity);
  //     } else {
  //       await db?.transaction((txn) async {
  //         List<Map<String, dynamic>> res = await txn.query(
  //           tableName,
  //           columns: ['*'],
  //           where: 'topic = ?',
  //           whereArgs: [schema.topic],
  //         );
  //         if (res != null && res.length > 0) {
  //           throw Exception(["topic duplicated!"]);
  //         } else {
  //           id = await txn.insert(tableName, entity);
  //         }
  //       });
  //     }
  //     if (id != null && id != 0) {
  //       TopicSchema? schema = TopicSchema.fromMap(entity);
  //       schema?.id = id;
  //       logger.d("$TAG - insert - success - schema:$schema");
  //       return schema;
  //     }
  //     logger.w("$TAG - insert - fail - schema:$schema");
  //   } catch (e) {
  //     if (e.toString() != "topic duplicated!") {
  //       handleError(e);
  //     }
  //   }
  //   return null;
  // }
  //
  // Future<bool> delete(int? topicId) async {
  //   if (topicId == null || topicId == 0) return false;
  //   try {
  //     int? count = await db?.delete(
  //       tableName,
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.d("$TAG - delete - success - topicId:$topicId");
  //       return true;
  //     }
  //     logger.w("$TAG - delete - fail - topicId:$topicId");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
  //
  // Future<List<TopicSchema>> queryList({String? topicType, String? orderBy, int? limit, int? offset}) async {
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: topicType != null ? 'type = ?' : null,
  //       whereArgs: topicType != null ? [topicType] : null,
  //       offset: offset ?? null,
  //       limit: limit ?? null,
  //       orderBy: orderBy ?? 'create_at desc',
  //     );
  //     if (res == null || res.isEmpty) {
  //       logger.d("$TAG - queryList - empty - topicType:$topicType");
  //       return [];
  //     }
  //     List<TopicSchema> results = <TopicSchema>[];
  //     String logText = '';
  //     res.forEach((map) {
  //       logText += "\n$map";
  //       TopicSchema? topic = TopicSchema.fromMap(map);
  //       if (topic != null) results.add(topic);
  //     });
  //     logger.d("$TAG - queryList - items:$logText");
  //     return results;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return [];
  // }
  //
  // Future<TopicSchema?> query(int? topicId) async {
  //   if (topicId == null || topicId == 0) return null;
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (res != null && res.length > 0) {
  //       TopicSchema? schema = TopicSchema.fromMap(res.first);
  //       logger.d("$TAG - query - success - topicId:$topicId - schema:$schema");
  //       return schema;
  //     }
  //     logger.d("$TAG - query - empty - topicId:$topicId");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return null;
  // }
  //
  // Future<TopicSchema?> queryByTopic(String? topic) async {
  //   if (topic == null || topic.isEmpty) return null;
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'topic = ?',
  //       whereArgs: [topic],
  //     );
  //     if (res != null && res.length > 0) {
  //       TopicSchema? schema = TopicSchema.fromMap(res.first);
  //       logger.d("$TAG - queryByTopic - success - topic:$topic - schema:$schema");
  //       return schema;
  //     }
  //     logger.d("$TAG - queryByTopic - empty - topic:$topic");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return null;
  // }
  //
  // Future<bool> setAvatar(int? topicId, String? avatarLocalPath) async {
  //   if (topicId == null || topicId == 0) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'avatar': avatarLocalPath,
  //         'update_at': DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.d("$TAG - setAvatar - success - topicId:$topicId - avatarLocalPath:$avatarLocalPath");
  //       return true;
  //     }
  //     logger.w("$TAG - setAvatar - fail - topicId:$topicId - avatarLocalPath:$avatarLocalPath");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
  //
  // Future<bool> setJoined(int? topicId, bool joined, {DateTime? subscribeAt, int? expireBlockHeight}) async {
  //   if (topicId == null || topicId == 0 || expireBlockHeight == null) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'joined': joined ? 1 : 0,
  //         'subscribe_at': subscribeAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
  //         'expire_height': expireBlockHeight,
  //         'update_at': DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.d("$TAG - setJoined - success - topicId:$topicId - joined:$joined - expireBlockHeight:$expireBlockHeight");
  //       return true;
  //     }
  //     logger.w("$TAG - setJoined - fail - topicId:$topicId - joined:$joined - expireBlockHeight:$expireBlockHeight");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
  //
  // Future<bool> setTop(int? topicId, bool top) async {
  //   if (topicId == null || topicId == 0) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'is_top': top ? 1 : 0,
  //         'update_at': DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.d("$TAG - setTop - success - topicId:$topicId - top:$top");
  //       return true;
  //     }
  //     logger.w("$TAG - setTop - fail - topicId:$topicId - top:$top");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
  //
  // Future<bool> setData(int? topicId, Map<String, dynamic>? newData) async {
  //   if (topicId == null || topicId == 0) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'data': (newData?.isNotEmpty == true) ? jsonEncode(newData) : null,
  //         'update_at': DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'id = ?',
  //       whereArgs: [topicId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.d("$TAG - setData - success - topicId:$topicId - newData:$newData");
  //       return true;
  //     }
  //     logger.w("$TAG - setData - fail - topicId:$topicId - newData:$newData");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }
}
