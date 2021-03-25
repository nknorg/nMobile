/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:nmobile/model/db/nkn_data_manager.dart';
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
  final int memberStatus;

  const Subscriber({
    this.id,
    this.topic,
    this.chatId,
    this.indexPermiPage,
    this.timeCreate,
    this.blockHeightExpireAt,
    this.memberStatus,
  });
}

class MemberStatus {
  static const int DefaultNotMember = 0;
  static const int MemberInvited = 1;
  static const int MemberPublished = 2;
  static const int MemberSubscribed = 3;
  static const int MemberPublishRejected = 4;
  static const int MemberJoinedButNotInvited = 5;
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

  Future<List<Subscriber>> getAllMemberByTopic(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ? AND $subscribed = ?',
        whereArgs: [topicName, '1'],
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

  Future<Subscriber> getByTopicAndChatId(
      String topicName, String chatId) async {
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(tableName,
        where: '$topic = ? AND $chat_id = ?',
        whereArgs: [topicName, chatId],
        orderBy: '$time_create ASC');

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
      NLog.w('Insert thing is____'+toEntity(subscriber).toString());
      var insertResult = await cdb.insert(tableName, toEntity(subscriber),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (insertResult != null && insertResult > 0){
        return true;
      }
      return false;
    }

    /// update Logic
    else {
      NLog.w('Update Subscriber is____'+subscriber.memberStatus.toString());
      await updateMemberStatus(subscriber, subscriber.memberStatus);
    }
    return true;
  }

  Future <bool> updateMemberStatus(Subscriber updateSub,int memberStatus) async{
    Database cdb = await NKNDataManager().currentDatabase();
    int result = await cdb.update(
      tableName,
      {'member_status': memberStatus},
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [updateSub.topic, updateSub.chatId],
    );
    return result>0;
  }

  Future<List<Subscriber>> findAllSubscribersWithPermitIndex(String topicName,int permitIndex) async{
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      tableName,
      where: '$topic = ? AND $prm_p_i = ?',
      whereArgs: [topicName,permitIndex],
    );
    NLog.w('findAllSubscribersWithPermitIndex__'+res.length.toString());
    List<Subscriber> members = parseEntities(res);

    return members;
  }

  Future<void> updatePermitIndex(Subscriber sub, int pageIndex) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.update(
      tableName,
      {prm_p_i: pageIndex},
      where: '$topic = ? AND $chat_id = ?',
      whereArgs: [sub.topic, sub.chatId],
    );
    if (res > 0){
      NLog.w('updatePermitIndex __'+pageIndex.toString()+'Success');
    }
    else{
      NLog.w('updatePermitIndex __'+pageIndex.toString()+'Failed');
    }
  }

  Future<int> findMaxPermitIndex(String topicName) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var result = await cdb.query(
        tableName,
        where: '$topic = ?',
        whereArgs: [topicName],
        orderBy: '$prm_p_i  ASC');

    if (result != null){
      Subscriber sub = parseEntity(result[0]);
      return sub.indexPermiPage;
    }
    return 0;
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
    assert(version >= NKNDataManager.dataBaseVersionV3);

    await db.execute(createSqlV5);
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS index_${tableName}_${topic}_$chat_id ON $tableName ($topic, $chat_id);');
    await db.execute(
        'CREATE        INDEX IF NOT EXISTS index_${tableName}_$time_create      ON $tableName ($time_create);');
    NLog.w('CREATE UNIQUE INDEX');
  }

  static Future<void> updateTopicTableToV4(Database db) async{
    await db.execute(
        'ALTER TABLE subscriber ADD COLUMN member_status INTEGER DEFAULT 0');
    await db.execute(
        'ALTER TABLE subscriber DROP COLUMN uploaded');
    await db.execute(
        'ALTER TABLE subscriber DROP COLUMN upload_done');
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
        $upload_done BOOLEAN,
        $member_status BOOLEAN
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
final member_status = 'member_status';


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
    memberStatus: row['member_status'],
  );
}

Map<String, dynamic> toEntity(Subscriber subs) {
  return {
    topic: subs.topic,
    chat_id: subs.chatId,
    prm_p_i: subs.indexPermiPage,
    time_create: subs.timeCreate,
    expire_at: subs.blockHeightExpireAt,
    member_status: subs.memberStatus,
  };
}
