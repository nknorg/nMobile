import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SubscribersSchema {
  int id;
  String topic;
  String addr;
  String meta;
  DateTime expiresAt;

  SubscribersSchema({
    this.id,
    this.topic,
    this.addr,
    this.meta,
    this.expiresAt,
  });

  static String get tableName => 'Subscribers';

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE Subscribers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        addr TEXT,
        meta TEXT,
        expires_at INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX subscribers_index_topic ON Subscribers (topic)');
    await db.execute('CREATE INDEX subscribers_index_addr ON Subscribers (addr)');
    await db.execute('CREATE INDEX subscribers_index_expires_at ON Subscribers (expires_at)');
  }

  toEntity() {
    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'addr': addr,
      'meta': meta,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
    };

    return map;
  }

  static SubscribersSchema parseEntity(Map e) {
    var res = SubscribersSchema(
      id: e['id'],
      topic: e['topic'],
      addr: e['addr'],
      meta: e['meta'],
      expiresAt: e['expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['expires_at']) : null,
    );

    return res;
  }

  Future<bool> insert(Database db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      int n = await db.insert(SubscribersSchema.tableName, toEntity());
      return n > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      return false;
    }
  }

  static Future<bool> deleteSubscribersByTopic(Database db, String topic) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var count = await db.delete(
        SubscribersSchema.tableName,
        where: 'topic = ?',
        whereArgs: [topic],
      );
      return count > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static Future<Map<String, dynamic>> getSubscribersByTopic(Database db, String topic) async {
    Map<String, dynamic> subscribers = {};
    try {
      TopicSchema topicSchema = TopicSchema(topic: topic);
      List<SubscribersSchema> list = await topicSchema.querySubscribers(db);
      if (list == null || list.length == 0) return subscribers;
      for (SubscribersSchema schema in list) {
        subscribers[schema.addr] = schema.meta;
      }
      return subscribers;
    } catch (e) {
      return subscribers;
    }
  }
}
