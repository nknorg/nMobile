/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 19/08/2020
class BlackList {
  final int id;
  final String topic;
  final String chatIdOrPubkey;
  final int indexPermiPage;
  final bool uploaded;
  final bool subscribed;

  const BlackList({
    this.id,
    this.topic,
    this.chatIdOrPubkey,
    this.indexPermiPage,
    this.uploaded,
    this.subscribed,
  });
}

class BlackListRepo {
  Future<List<BlackList>> getByTopic(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(
      tableName,
      where: '$topic = ?',
      whereArgs: [topicName],
    );
    return parseEntities(result);
  }

  Future<BlackList> getByTopicAndChatId(
      String topicName, String chatIdOrPubkey) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(
      tableName,
      where: '$topic = ? AND $cid_r_pk = ?',
      whereArgs: [topicName, chatIdOrPubkey],
    );
    final list = parseEntities(result);
    return list.isEmpty ? null : list[0];
  }

  Future<void> insertOrUpdate(BlackList bl) async {
    if (await getByTopicAndChatId(bl.topic, bl.chatIdOrPubkey) == null) {
      await insertOrIgnore(bl);
    } else
      await update(bl.topic, bl.chatIdOrPubkey, bl.indexPermiPage, bl.uploaded);
  }

  Future<void> insertOrIgnore(BlackList bl) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.insert(tableName, toEntity(bl),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> update(String topicName, String chatIdOrPubkey, int pageIndex,
      bool uploaded_) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      tableName,
      {prm_p_i: pageIndex, uploaded: uploaded_ ? 1 : 0},
      where: '$topic = ? AND $cid_r_pk = ?',
      whereArgs: [topicName, chatIdOrPubkey],
    );
  }

  Future<void> updatePermiPageIndex(
      String topicName, String chatIdOrPubkey, int pageIndex) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      tableName,
      {prm_p_i: pageIndex},
      where: '$topic = ? AND $cid_r_pk = ?',
      whereArgs: [topicName, chatIdOrPubkey],
    );
  }

  Future<void> updatePageUploaded(String topicName, int pageIndex) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      tableName,
      {uploaded: 1},
      where: '$topic = ? AND $prm_p_i = ?',
      whereArgs: [topicName, pageIndex],
    );
  }

  Future<void> delete(String topicName, String chatIdOrPubkey) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.delete(tableName,
        where: '$topic = ? AND $cid_r_pk = ?',
        whereArgs: [topicName, chatIdOrPubkey]);
  }

  Future<void> deleteAll(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    // assert(version >= SqliteStorage.currentVersion);
    await db.execute(createSqlV5);
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS'
        ' index_${tableName}_${topic}_$cid_r_pk'
        ' ON $tableName ($topic, $cid_r_pk);');
  }

  static Future<void> upgradeFromV5(
      Database db, int oldVersion, int newVersion) async {
    if (newVersion == NKNDataManager.dataBaseVersionV3) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError(
          'unsupported upgrade from $oldVersion to $newVersion.');
    }
  }

  static final createSqlV5 = '''
      CREATE TABLE IF NOT EXISTS $tableName (
        $id INTEGER PRIMARY KEY AUTOINCREMENT,
        $topic TEXT,
        $cid_r_pk TEXT,
        $prm_p_i INTEGER,
        $uploaded BOOLEAN,
        $subscribed BOOLEAN
      )''';
}

final tableName = 'blacklist';
final id = 'id';
final topic = 'topic';
final cid_r_pk = 'cid_r_pk';
final prm_p_i = 'prm_p_i';
final uploaded = 'uploaded';
final subscribed = 'subscribed';

List<BlackList> parseEntities(List<Map<String, dynamic>> rows) {
  List<BlackList> list = [];
  for (var row in rows) {
    list.add(parseEntity(row));
  }
  return list;
}

BlackList parseEntity(Map<String, dynamic> row) {
  return BlackList(
      id: row[id],
      topic: row[topic],
      chatIdOrPubkey: row[cid_r_pk],
      indexPermiPage: row[prm_p_i],
      uploaded: row[uploaded] == 1,
      subscribed: row[subscribed] == 1);
}

Map<String, dynamic> toEntity(BlackList bl) {
  return {
    topic: bl.topic,
    cid_r_pk: bl.chatIdOrPubkey,
    prm_p_i: bl.indexPermiPage,
    uploaded: bl.uploaded ? 1 : 0,
    subscribed: bl.subscribed ? 1 : 0,
  };
}
