/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/db/sqlite_storage.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
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
  Future<List<Subscriber>> getByTopic(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ? AND $subscribed = ?',
        whereArgs: [topicName, 1],
        orderBy: '$time_create ASC');
    return parseEntities(result);
  }

  Future<List<Subscriber>> getByTopicExceptNone(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ?',
        whereArgs: [topicName],
        orderBy: '$time_create ASC');
    return parseEntities(result);
  }

  Future<List<String>> getAllSubscriberByTopic(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ?',
        whereArgs: [topicName],
        orderBy: '$time_create ASC');

    List<String> members = List();
    NLog.w('Result Length is_____'+result.length.toString());
    for (Map subInfo in result) {
      members.add(subInfo['chat_id']);
      NLog.w('Result Length is_____'+subInfo.toString());
    }
    return members;
  }

  Future<int> getCountOfTopic(topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    return Sqflite.firstIntValue(await cdb.query(
      tableName,
      columns: ['COUNT(*)'],
      where: '$topic = ? AND $subscribed = ?',
      whereArgs: [topicName, 1],
    ));
  }

  // Future<int> batchUpdateSubscriberList(List <Subscriber> subs) async{
  //   Database cdb = await NKNDataManager.instance.currentDatabase();
  //   Batch dbBatch = cdb.batch();
  //   for(Subscriber sub in subs){
  //     String topicV = sub.topic;
  //     String chatIDV = sub.chatId;
  //     int prm_p_iV = sub.indexPermiPage;
  //     int time_createV = sub.timeCreate;
  //     int expire_atV = sub.blockHeightExpireAt;
  //     bool uploadedV = sub.uploaded?true:false;
  //     bool subscribedV = sub.subscribed?true:false;
  //     bool upload_doneV = sub.uploadDone?true:false;
  //
  //     List<Map<String, dynamic>> result =
  //     await cdb.query(tableName, where: '$topic = ? AND $chat_id = ?', whereArgs: [topicV, chatIDV], orderBy: '$time_create ASC');
  //     final list = parseEntities(result);
  //
  //     if (list.length == 0){
  //       String insertSql = 'INSERT INTO $tableName($topic,$chat_id,$prm_p_i,$time_create,$expire_at,$uploaded,$subscribed,$upload_done)'+
  //           ' VALUES ("$topicV","$chatIDV","$prm_p_iV","$time_createV","$expire_atV","$uploadedV","$subscribedV","$upload_doneV")';
  //       dbBatch.execute(insertSql);
  //     }
  //     else{
  //       await cdb.query(tableName, where: '$topic = ?', whereArgs: [topicV], orderBy: '$time_create ASC');
  //       // final list = parseEntities(result);
  //       // for (Subscriber sub in list){
  //       //   Global.debugLog('database exsits topic:'+sub.topic+'__chatID:'+sub.chatId);
  //       // }
  //     }
  //   }
  //   List resultList = await dbBatch.commit();
  //   for (dynamic result in resultList){
  //     NLog.w('batchUpdateSubscriberList result is__'+result.toString());
  //   }
  //   return resultList.length;
  // }

  Future<Subscriber> getByTopicAndChatId(
      String topicName, String chatId) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ? AND $chat_id = ?',
        whereArgs: [topicName, chatId],
        orderBy: '$time_create ASC');

    NLog.w('Result is_____'+result.toString());
    NLog.w('Result is_____'+topicName.toString());
    NLog.w('Result is_____'+chatId.toString());

    final list = parseEntities(result);
    if (list.length > 0){
      return list[0];
    }
    return null;
  }

  Future<bool> insertSubscriber(Subscriber subscriber) async {
    Database cdb = await NKNDataManager().currentDatabase();
    Subscriber querySubscriber =
        await getByTopicAndChatId(subscriber.topic, subscriber.chatId);

    if (subscriber.chatId.length < 64) {
      return false;
    }

    /// insert Logic
    if (querySubscriber == null) {
      int insertResult = await cdb.insert(tableName, toEntity(subscriber),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (insertResult > 0) {
        return true;
      }
      return false;
    }

    /// update Logic
    else {
      if (subscriber.chatId == NKNClientCaller.currentChatId) {
        await updateOwnerIsMe(subscriber.topic, subscriber.chatId,
            subscriber.subscribed, subscriber.uploadDone);
      } else {
        await update(
            subscriber.topic,
            subscriber.chatId,
            subscriber.indexPermiPage,
            subscriber.uploaded,
            subscriber.subscribed,
            subscriber.uploadDone);
      }
    }
    return true;
  }

  Future<void> update(String topicName, String chatId, int pageIndex,
      bool uploaded_, bool subscribed_, bool uploadDone) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
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

  Future<void> updateOwnerIsMe(String topicName, String chatId,
      bool subscribed_, bool uploadDone) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      tableName,
      {
        subscribed: subscribed_ ? 1 : 0,
        upload_done: uploadDone ? 1 : 0,
      },
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [topicName, chatId],
    );
  }

  Future<void> updatePermiPageIndex(
      String topicName, String chatId, int pageIndex) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      tableName,
      {prm_p_i: pageIndex},
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [topicName, chatId],
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

  Future<bool> delete(String topicName, String chatId) async {
    Database cdb = await NKNDataManager().currentDatabase();
    if (topicName != null && chatId != null) {
      int result = await cdb.delete(tableName,
          where: '$topic = ? AND $chat_id = ?', whereArgs: [topicName, chatId]);
      if (result != null && result > 0 && chatId != null) {
        NLog.w('Delete subscriber__' + chatId);
        return true;
      }
    } else {
      NLog.w('Wrong!!! topicName or chatId is null');
    }
    return false;
  }

  Future<void> deleteAll(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    if (topicName != null) {
      int result = await cdb
          .delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
      if (result > 0) {
        NLog.w('deleteAll by topicName__' + result.toString());
      }
    } else {
      NLog.w('Wrong topicName is null');
    }
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= SqliteStorage.currentVersion);

    await db.execute(createSqlV5);
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS index_${tableName}_${topic}_$chat_id ON $tableName ($topic, $chat_id);');
    await db.execute(
        'CREATE        INDEX IF NOT EXISTS index_${tableName}_$time_create      ON $tableName ($time_create);');
    NLog.w('CREATE UNIQUE INDEX');
  }

  static Future<void> upgradeFromV5(
      Database db, int oldVersion, int newVersion) async {
    if (newVersion == SqliteStorage.currentVersion) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError(
          'unsupported upgrade from $oldVersion to $newVersion.');
    }
  }

  static final deleteSql = '''DROP TABLE IF EXISTS Subscribers;''';
  static final createSqlV5 = '''
      CREATE TABLE IF NOT EXISTS $tableName(
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
