import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class TopicStorage {
  static String get tableName => 'Topic';

  Database get db => DB.currentDatabase;

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        count INTEGER,
        avatar TEXT,
        last_updated_time INTEGER,
        expire_at INTEGER,
        is_top BOOLEAN DEFAULT 0,
        options TEXT,
        type INTEGER DEFAULT 0,
        joined BOOLEAN DEFAULT 0
      )''');
    // index
    await db.execute('CREATE UNIQUE INDEX unique_index_topic_topic ON $tableName (topic);');
  }

  Future<int> queryCountByTopic(String topic) async {
    if (topic == null || topic.isEmpty) return 0;
    try {
      var res = await db.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      int count = Sqflite.firstIntValue(res);
      logger.d("queryCountByTopic - topic:$topic - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<TopicSchema> queryTopicByTopicName(String topic) async {
    if (topic == null || topic.isEmpty) return null;
    try {
      var res = await db.query(
        tableName,
        columns: ['*'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      if (res.length > 0) {
        TopicSchema schema = TopicSchema.fromMap(res.first);
        logger.d("queryTopicByTopicName - success - topic:$topic - schema:$schema");
        return schema;
      }
      logger.d("queryTopicByTopicName - empty - topic:$topic");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<TopicSchema> insertTopic(TopicSchema schema) async {
    if (schema == null) return null;
    try {
      TopicSchema exist = await queryTopicByTopicName(schema?.topic);
      if (exist != null) {
        logger.d("insertTopic - exist:$exist - add:$schema");
        return exist;
      }
      Map<String, dynamic> entity = schema.toMap();
      int id = await db.insert(tableName, entity);
      if (id != 0) {
        TopicSchema schema = TopicSchema.fromMap(entity);
        schema.id = id;
        logger.d("insertTopic - success - schema:$schema");
        return schema;
      }
      logger.w("insertTopic - fail - scheme:$schema");
    } catch (e) {
      logger.e(e);
    }
    return null;
  }

  Future<bool> setTop(String topic, bool top) async {
    if (topic == null || topic.isEmpty) return false;
    try {
      var count = await db.update(
        tableName,
        {'is_top': top ? 1 : 0},
        where: 'topic = ?',
        whereArgs: [topic],
      );
      if (count > 0) {
        logger.d("setTop - success - topic:$topic - top:$top");
        return true;
      }
      logger.w("setTop - fail - topic:$topic - top:$top");
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
