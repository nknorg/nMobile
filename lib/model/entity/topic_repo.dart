/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/model/entity/options.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 19/08/2020

final tableName = 'topic';
final id = 'id';
final topic = 'topic';
final count = 'count';
final avatar = 'avatar';
final theme_id = 'theme_id';
final time_update = 'time_update';
final expire_at = 'expire_at';
final is_top = 'is_top';
final options = 'options'; // json

class TopicType {
  static int publicTopic = 1;
  static int privateTopic = 2;
}

class Topic with Tag {
  final int id;
  final String topic;
  final String avatarUri;
  final int themeId;
  final int timeUpdate;
  final int blockHeightExpireAt;
  final bool isTop;
  final String _options; // json for OptionsSchema.

  String topicName;
  String owner;
  String topicShort;
  OptionsSchema _optionsSchema;

  bool acceptAll = false;
  int topicType;

  Topic(
      {this.id,
      this.topic,
      this.avatarUri = '',
      this.themeId,
      this.timeUpdate,
      this.blockHeightExpireAt,
      this.isTop = false,

      options = ''})
      : _options = options,
        assert(topic != null && topic.isNotEmpty) {

    NLog.w('TopicName is____'+topic);
    topicType = isPrivateTopicReg(topic)?TopicType.privateTopic:TopicType.publicTopic;

    if (topicType == TopicType.privateTopic) {

      int index = topic.lastIndexOf('.');
      topicName = topic.substring(0, index);
      owner = topic.substring(index + 1);
      assert(topicName.isNotEmpty);
      assert(isValidPubkey(owner));

      topicShort = topicName + '.' + owner.substring(0, 8);
    } else {
      topicName = topic;
      owner = null;

      topicShort = topicName;
    }
  }

  bool isPrivateTopic(){
    if (this.topicType == TopicType.privateTopic){
      return true;
    }
    return false;
  }

  static spotName({@required String name}) => Topic(topic: name);

  @deprecated
  Topic copyWith({@required avatarUri}) {
    return Topic(
        id: id,
        topic: topic,
        // numSubscribers: numSubscribers,
        avatarUri: avatarUri,
        themeId: themeId,
        timeUpdate: timeUpdate,
        blockHeightExpireAt: blockHeightExpireAt,
        isTop: isTop,
        options: _options);
  }

  OptionsSchema get options {
    return _options == null
        ? null
        : _optionsSchema ??= OptionsSchema.parseEntity(jsonDecode(_options));
  }

  bool isOwner(String accountPubkey) => accountPubkey == owner;



  Future<int> updateTopicToAcceptAll(bool accept) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    return await currentDataBase.update(
      tableName,
      {'accept_all': accept ? 1 : 0},
      where: '$id = ?',
      whereArgs: [id],
    );
  }
}

class TopicRepo with Tag {
  Future<List<Topic>> getAllTopics() async {
    Database currentDataBase = await NKNDataManager().currentDatabase();

    if (currentDataBase != null) {
      List<Map<String, dynamic>> result =
          await currentDataBase.query(tableName);
      return parseEntities(result);
    }
    return null;
  }

  Future<Topic> getTopicByName(String topicName) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await currentDataBase
        .query(tableName, where: '$topic = ?', whereArgs: [topicName]);
    if (result == null || result.length == 0) {
      return null;
    } else {
      List topicList = parseEntities(result);
      return topicList[0];
    }
  }

  Future<void> insertTopicByTopicName(String topicName) async {
    if (topicName == null) {
      NLog.w('Wrong!!! topicName is null');
      return;
    }
    Topic topic = await getTopicByName(topicName);
    Database currentDataBase = await NKNDataManager().currentDatabase();

    /// need create New Topic
    if (topic == null) {
      final themeId =
          Random().nextInt(DefaultTheme.headerBackgroundColor.length);
      String topicOption = OptionsSchema.random(themeId: themeId).toJson();

      topic = Topic(
        id: 0,
        topic: topicName,
        themeId: themeId,
        timeUpdate: DateTime.now().millisecondsSinceEpoch,
        blockHeightExpireAt: 0,
        isTop: false,
        options: topicOption,
      );
      int result = await currentDataBase.insert(tableName, toEntity(topic),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (result > 0) {
        NLog.w('Insert topic success__' + topicName);
      }
    } else {
      if (topicName != null) {
        NLog.w('Insert Topic is Exists__' + topicName);
      }
    }
  }

  Future<void> updateOwnerExpireBlockHeight(
      String topicName, int expiresAt) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    await currentDataBase.update(
      tableName,
      {expire_at: expiresAt},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  Future<void> updateAvatar(String topicName, String avatarUri) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    await currentDataBase.update(
      tableName,
      {avatar: avatarUri},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  Future<int> updateIsTop(String topicName, bool isTop) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    return await currentDataBase.update(
      tableName,
      {is_top: isTop ? 1 : 0},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  Future<void> delete(String topicName) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    await currentDataBase
        .delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= NKNDataManager.dataBaseVersionV3);

    NLog.w('topic_repo__CREATE UNIQUE INDEX index_');
    await db.execute(createSqlV5);
    await db.execute(
        'CREATE UNIQUE INDEX index_${tableName}_$topic ON $tableName ($topic);');
  }

  static Future<void> updateTopicTableToV4(Database db) async{
    await db.execute(
        'ALTER TABLE $topic ADD COLUMN type INTEGER DEFAULT 0');

    await db.execute(
        'ALTER TABLE $topic ADD COLUMN accept_all BOOLEAN DEFAULT 0');

    await db.execute(
        'ALTER TABLE $topic ADD COLUMN joined BOOLEAN DEFAULT 0');
  }

  static final deleteSql = '''DROP TABLE IF EXISTS Topic;''';
  static final createSqlV5 = '''
      CREATE TABLE $tableName (
        $id INTEGER PRIMARY KEY AUTOINCREMENT,
        $topic TEXT,
        $count INTEGER,
        $avatar TEXT,
        $theme_id INTEGER,
        $time_update INTEGER,
        $expire_at INTEGER,
        $is_top BOOLEAN DEFAULT 0,
        $options TEXT,
        type INTEGER DEFAULT 0,
        accept_all BOOLEAN DEFAULT 0,
        joined BOOLEAN DEFAULT 0
      )''';
}

List<Topic> parseEntities(List<Map<String, dynamic>> rows) {
  List<Topic> list = [];
  for (var row in rows) {
    list.add(parseEntity(row));
  }
  return list;
}

Topic parseEntity(Map<String, dynamic> row) {
  var opt = row[options];
  var dec = jsonDecode(opt);
  if (dec is String) {
    opt = dec;
  }
  return Topic(
    id: row[id],
    topic: row[topic],
    // numSubscribers: row[count],
    avatarUri: row[avatar],
    themeId: row[theme_id],
    timeUpdate: row[time_update],
    blockHeightExpireAt: row[expire_at],
    isTop: row[is_top] == 1,
    options: opt,
  );
}

Map<String, dynamic> toEntity(Topic subs) {
  String insertTopic = '';
  int numSubscribers = 0;
  String avatarUri = '';
  int themeId = 0;
  int timeUpdate = 0;
  int blockHeightExpireAt = 0;
  bool isTop = false;
  String _options = '';
  if (subs.topic != null) {
    insertTopic = subs.topic;
  }
  if (subs.avatarUri != null) {
    avatarUri = subs.avatarUri;
  }
  if (subs.themeId > 0) {
    themeId = subs.themeId;
  }
  if (subs.timeUpdate > 0) {
    timeUpdate = subs.timeUpdate;
  }
  if (subs.blockHeightExpireAt > 0) {
    blockHeightExpireAt = subs.blockHeightExpireAt;
  }
  if (subs.isTop != null) {
    isTop = subs.isTop;
  }
  if (subs.options != null) {
    _options = subs.options?.toJson();
  }
  return {
    topic: insertTopic,
    count: numSubscribers,
    avatar: avatarUri,
    theme_id: themeId,
    time_update: timeUpdate,
    expire_at: blockHeightExpireAt,
    is_top: isTop ? 1 : 0,
    options: _options,
  };
}
