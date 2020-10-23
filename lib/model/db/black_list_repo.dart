/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:nmobile/model/db/sqlite_storage.dart';
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
  final Future<Database> _db;

  BlackListRepo(this._db);

  // @Query("SELECT * from blacklist WHERE topic = :topic")
  Future<List<BlackList>> getByTopic(String topicName) async {
    List<Map<String, dynamic>> result = await (await _db).query(
      tableName,
      where: '$topic = ?',
      whereArgs: [topicName],
    );
    return parseEntities(result);
  }

  // @Query("SELECT * from blacklist WHERE topic = :topic AND chat_id = :chatId")
  Future<BlackList> getByTopicAndChatId(String topicName, String chatIdOrPubkey) async {
    List<Map<String, dynamic>> result = await (await _db).query(
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

  // @Insert(onConflict = OnConflictStrategy.IGNORE)
  Future<void> insertOrIgnore(BlackList bl) async {
    await (await _db).insert(tableName, toEntity(bl), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // @Query(
  //        """UPDATE blacklist SET prm_p_i = :prm_p_i, uploaded = :uploaded
  //            WHERE topic = :topic AND chat_id = :chatId"""
  //    )
  Future<void> update(String topicName, String chatIdOrPubkey, int pageIndex, bool uploaded_) async {
    await (await _db).update(
      tableName,
      {prm_p_i: pageIndex, uploaded: uploaded_ ? 1 : 0},
      where: '$topic = ? AND $cid_r_pk = ?',
      whereArgs: [topicName, chatIdOrPubkey],
    );
  }

  // @Query("UPDATE blacklist SET prm_p_i = :prm_p_i WHERE topic = :topic AND chat_id = :chatId")
  Future<void> updatePermiPageIndex(String topicName, String chatIdOrPubkey, int pageIndex) async {
    await (await _db).update(
      tableName,
      {prm_p_i: pageIndex},
      where: '$topic = ? AND $cid_r_pk = ?',
      whereArgs: [topicName, chatIdOrPubkey],
    );
  }

  // @Query("""UPDATE blacklist SET uploaded = 1 WHERE topic = :topic AND prm_p_i = :pageIndex""")
  Future<void> updatePageUploaded(String topicName, int pageIndex) async {
    await (await _db).update(
      tableName,
      {uploaded: 1},
      where: '$topic = ? AND $prm_p_i = ?',
      whereArgs: [topicName, pageIndex],
    );
  }

  // @Query("DELETE FROM blacklist WHERE topic = :topic AND chat_id = :chatId")
  Future<void> delete(String topicName, String chatIdOrPubkey) async {
    await (await _db).delete(tableName, where: '$topic = ? AND $cid_r_pk = ?', whereArgs: [topicName, chatIdOrPubkey]);
  }

  // @Query("DELETE FROM blacklist WHERE topic = :topic")
  Future<void> deleteAll(String topicName) async {
    await (await _db).delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= SqliteStorage.currentVersion);
    // no table before version 5.
    //await db.execute(deleteSql);
    await db.execute(createSqlV5);
    await db.execute('CREATE UNIQUE INDEX'
        ' index_${tableName}_${topic}_$cid_r_pk'
        ' ON $tableName ($topic, $cid_r_pk);');
  }

  static Future<void> upgradeFromV5(Database db, int oldVersion, int newVersion) async {
    assert(newVersion >= SqliteStorage.currentVersion);
    if (newVersion == SqliteStorage.currentVersion) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError('unsupported upgrade from $oldVersion to $newVersion.');
    }
  }

  static final createSqlV5 = '''
      CREATE TABLE $tableName (
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
//    id: bl.id,
    topic: bl.topic,
    cid_r_pk: bl.chatIdOrPubkey,
    prm_p_i: bl.indexPermiPage,
    uploaded: bl.uploaded ? 1 : 0,
    subscribed: bl.subscribed ? 1 : 0,
  };
}

//@Entity(
//    tableName = "blacklist",
//    indices = [Index("topic", "chat_id", unique = true)]
//)
//data class BlackList(
//@PrimaryKey(autoGenerate = true)
//@ColumnInfo(name = "id", index = true) val id: Long,
//
//@ColumnInfo(name = "topic") val topic: String,
//@ColumnInfo(name = "chat_id") val chatId: String,
//
//@ColumnInfo(name = "prm_p_i") val indexPermissionPage: Int,
//@ColumnInfo(name = "uploaded") val uploaded: Boolean,
//@ColumnInfo(name = "subscribed") val subscribed: Boolean // only record for `subscriber` table.
//)
