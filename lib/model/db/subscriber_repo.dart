/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:nmobile/model/db/sqlite_storage.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 19/08/2020
class Subscriber {
  final int id;
  final String topic;
  final String chatId;
  final int indexPermiPage;
  final int timeCreate;
  final int blockHeightExpireAt;
  final bool uploaded;
  final bool subscribed;
  final bool uploadDone;

  const Subscriber({
    this.id,
    this.topic,
    this.chatId,
    this.indexPermiPage,
    this.timeCreate,
    this.blockHeightExpireAt,
    this.uploaded,
    this.subscribed,
    this.uploadDone,
  });
}

class SubscriberRepo with Tag {
  LOG _log;
  final Future<Database> _db;

  SubscriberRepo(this._db) {
    _log = LOG(tag);
  }

  // """SELECT * from subscriber WHERE topic = :topic AND subscribed = 1 ORDER BY time_create ASC"""
  Future<List<Subscriber>> getByTopic(String topicName) async {
    _log.i('getByTopic($topicName)');
    List<Map<String, dynamic>> result =
        await (await _db).query(tableName, where: '$topic = ? AND $subscribed = ?', whereArgs: [topicName, 1], orderBy: '$time_create ASC');
    _log.i('getByTopic($topicName), result: ${result.length}');
    return parseEntities(result);
  }

  // """SELECT * from subscriber WHERE topic = :topic ORDER BY time_create ASC"""
  Future<List<Subscriber>> getByTopicExceptNone(String topicName) async {
    _log.i('getByTopicExceptNone($topicName)');
    List<Map<String, dynamic>> result = await (await _db).query(tableName, where: '$topic = ?', whereArgs: [topicName], orderBy: '$time_create ASC');
    return parseEntities(result);
  }

  // @Query(
  //        """SELECT chat_id from subscriber WHERE topic = :topic AND subscribed = 1
  //            ORDER BY time_create ASC"""
  //    )
  Future<List<String>> getTopicChatIds(String topicName) async {
    _log.i('getTopicChatIds($topicName)');
    List<Map<String, dynamic>> rows =
        await (await _db).query(tableName, columns: [chat_id], where: '$topic = ? AND $subscribed = ?', whereArgs: [topicName, 1], orderBy: '$time_create ASC');
    List<String> list = [];
    for (var row in rows) {
      list.add(row[chat_id]);
    }
    return list;
  }

  // "SELECT COUNT(*) FROM subscriber WHERE topic = :topic AND subscribed = 1"
  Future<int> getCountOfTopic(topicName) async {
    _log.i('getCountOfTopic($topicName)');
    return Sqflite.firstIntValue(await (await _db).query(
      tableName,
      columns: ['COUNT(*)'],
      where: '$topic = ? AND $subscribed = ?',
      whereArgs: [topicName, 1],
    ));
  }

  // """SELECT * from subscriber WHERE topic = :topic AND chat_id = :chatId ORDER BY time_create ASC"""
  Future<Subscriber> getByTopicAndChatId(String topicName, String chatId) async {
    _log.i('getByTopicAndChatId($topicName, $chatId)');
    List<Map<String, dynamic>> result =
        await (await _db).query(tableName, where: '$topic = ? AND $chat_id = ?', whereArgs: [topicName, chatId], orderBy: '$time_create ASC');
    final list = parseEntities(result);
    return list.isEmpty ? null : list[0];
  }

  Future<void> insertOrUpdate(Subscriber subs) async {
    _log.i('insertOrUpdate(${subs.chatId})');
    if (await getByTopicAndChatId(subs.topic, subs.chatId) == null) {
      await insertOrIgnore(subs);
    } else
      await update(subs.topic, subs.chatId, subs.indexPermiPage, subs.uploaded, subs.subscribed, subs.uploadDone);
  }

  Future<void> insertOrUpdateOwnerIsMe(Subscriber subs) async {
    _log.i('insertOrUpdateOwnerIsMe(${subs.chatId})');
    if (await getByTopicAndChatId(subs.topic, subs.chatId) == null) {
      await insertOrIgnore(subs);
    } else
      await updateOwnerIsMe(subs.topic, subs.chatId, subs.subscribed, subs.uploadDone);
  }

  // onConflict = OnConflictStrategy.IGNORE
  Future<void> insertOrIgnore(Subscriber subs) async {
    _log.i('insertOrIgnore(${subs.chatId})');
    await (await _db).insert(tableName, toEntity(subs), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // """UPDATE subscriber SET prm_p_i = :prm_p_i, uploaded = :uploaded, subscribed = :subscribed,
  //            upload_done = :upload_done
  //            WHERE topic = :topic AND chat_id = :chatId"""
  Future<void> update(String topicName, String chatId, int pageIndex, bool uploaded_, bool subscribed_, bool uploadDone) async {
    _log.i('update($topicName, $chatId, $pageIndex, $uploaded_, $subscribed_, $uploadDone)');
    await (await _db).update(
      tableName,
      {
        prm_p_i: pageIndex,
        uploaded: uploaded_ ? 1 : 0,
        subscribed: subscribed_ ? 1 : 0,
        upload_done: uploadDone ? 1 : 0,
      },
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [topicName, chatId],
    );
  }

  // @Query(
  //      """UPDATE subscriber SET subscribed = :subscribed, upload_done = :upload_done
  //            WHERE topic = :topic AND chat_id = :chatId"""
  //  )
  Future<void> updateOwnerIsMe(String topicName, String chatId, bool subscribed_, bool uploadDone) async {
    _log.i('updateOwnerIsMe($topicName, $chatId, $subscribed_, $uploadDone)');
    await (await _db).update(
      tableName,
      {
        subscribed: subscribed_ ? 1 : 0,
        upload_done: uploadDone ? 1 : 0,
      },
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [topicName, chatId],
    );
  }

  // @Query("""UPDATE subscriber SET prm_p_i = :prm_p_i WHERE topic = :topic AND chat_id = :chatId""")
  Future<void> updatePermiPageIndex(String topicName, String chatId, int pageIndex) async {
    _log.i('updatePermiPageIndex($topicName, $chatId, $pageIndex)');
    await (await _db).update(
      tableName,
      {prm_p_i: pageIndex},
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [topicName, chatId],
    );
  }

  // @Query("""UPDATE subscriber SET uploaded = 1 WHERE topic = :topic AND prm_p_i = :pageIndex""")
  Future<void> updatePageUploaded(String topicName, int pageIndex) async {
    _log.i('updatePageUploaded($topicName, $pageIndex)');
    await (await _db).update(
      tableName,
      {uploaded: 1},
      where: '$topic = ? AND $prm_p_i = ?',
      whereArgs: [topicName, pageIndex],
    );
  }

  // @Query("DELETE FROM subscriber WHERE topic = :topic AND chat_id = :chatId")
  Future<void> delete(String topicName, String chatId) async {
    _log.i('delete($topicName, $chatId)');
    await (await _db).delete(tableName, where: '$topic = ? AND $chat_id = ?', whereArgs: [topicName, chatId]);
  }

  //@Query("DELETE FROM subscriber WHERE topic = :topic")
  Future<void> deleteAll(String topicName) async {
    _log.i('deleteAll($topicName)');
    await (await _db).delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= SqliteStorage.currentVersion);
    await db.execute(deleteSql);
    await db.execute(createSqlV5);

    await db.execute('CREATE UNIQUE INDEX index_${tableName}_${topic}_$chat_id ON $tableName ($topic, $chat_id);');
    await db.execute('CREATE        INDEX index_${tableName}_$time_create      ON $tableName ($time_create);');
  }

  static Future<void> upgradeFromV5(Database db, int oldVersion, int newVersion) async {
    assert(newVersion >= SqliteStorage.currentVersion);
    if (newVersion == SqliteStorage.currentVersion) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError('unsupported upgrade from $oldVersion to $newVersion.');
    }
  }

  static final deleteSql = '''DROP TABLE IF EXISTS Subscribers;''';
  static final createSqlV5 = '''
      CREATE TABLE $tableName (
        $id INTEGER PRIMARY KEY AUTOINCREMENT,
        $topic TEXT,
        $chat_id TEXT,
        $prm_p_i INTEGER,
        $time_create INTEGER,
        $expire_at INTEGER,
        $uploaded BOOLEAN,
        $subscribed BOOLEAN,
        $upload_done BOOLEAN
      )''';
}

final tableName = 'subscriber';
final id = 'id';
final topic = 'topic';
final chat_id = 'chat_id';
final prm_p_i = 'prm_p_i';
final time_create = 'time_create';
final expire_at = 'expire_at';
final uploaded = 'uploaded';
final subscribed = 'subscribed';
final upload_done = 'upload_done';

List<Subscriber> parseEntities(List<Map<String, dynamic>> rows) {
  List<Subscriber> list = [];
  for (var row in rows) {
    list.add(parseEntity(row));
  }
  return list;
}

Subscriber parseEntity(Map<String, dynamic> row) {
  return Subscriber(
    id: row[id],
    topic: row[topic],
    chatId: row[chat_id],
    indexPermiPage: row[prm_p_i],
    timeCreate: row[time_create],
    blockHeightExpireAt: row[expire_at],
    uploaded: row[uploaded] == 1,
    subscribed: row[subscribed] == 1,
    uploadDone: row[upload_done] == 1,
  );
}

Map<String, dynamic> toEntity(Subscriber subs) {
  return {
//    id: subs.id,
    topic: subs.topic,
    chat_id: subs.chatId,
    prm_p_i: subs.indexPermiPage,
    time_create: subs.timeCreate,
    expire_at: subs.blockHeightExpireAt,
    uploaded: subs.uploaded ? 1 : 0,
    subscribed: subs.subscribed ? 1 : 0,
    upload_done: subs.uploadDone ? 1 : 0,
  };
}
