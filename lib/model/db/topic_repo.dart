/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/db/sqlite_storage.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/options.dart';
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

class Topic with Tag {
  final int id;
  final String topic;
  // final int numSubscribers;
  final String avatarUri;
  final int themeId;
  final int timeUpdate;
  final int blockHeightExpireAt;
  final bool isTop;
  final String _options; // json for OptionsSchema.
  TopicType _type;
  String _name;
  String _owner;
  OptionsSchema _optionsSchema;

  Topic(
      {this.id,
      this.topic,
      // this.numSubscribers,
      this.avatarUri = '',
      this.themeId,
      this.timeUpdate,
      this.blockHeightExpireAt,
      this.isTop = false,
      options = ''})
      : _options = options,
        assert(topic != null && topic.isNotEmpty) {
    _type = isPrivateTopic(topic) ? TopicType.private : TopicType.public;

    if (_type == TopicType.private) {
      int index = topic.lastIndexOf('.');
      _name = topic.substring(0, index);
      _owner = topic.substring(index + 1);
      assert(_name.isNotEmpty);
      assert(isValidPubkey(_owner));
    } else {
      _name = topic;
      _owner = null;
    }
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

  String get name => _name;

  String get owner => _owner;

  TopicType get type => _type;

  bool get isPrivate => type == TopicType.private;

  String get shortName => isPrivate ? name + '.' + owner.substring(0, 8) : name;

  OptionsSchema get options {
    return _options == null ? null : _optionsSchema ??= OptionsSchema.parseEntity(jsonDecode(_options));
  }

  bool isOwner(String accountPubkey) => accountPubkey == owner;
}

enum TopicType { private, public }

extension TopicTypeString on TopicType {
  String get toStr => this == TopicType.private ? 'private' : 'public';
}

class TopicRepo with Tag {
  Future<List<Topic>> getAllTopics() async {
    Database currentDataBase = await NKNDataManager().currentDatabase();

    if (currentDataBase != null){
      List<Map<String, dynamic>> result = await currentDataBase.query(tableName);
      return parseEntities(result);
    }
    return null;
  }

  Future<Topic> getTopicByName(String topicName) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await currentDataBase.query(tableName, where: '$topic = ?', whereArgs: [topicName]);
    if (result == null || result.length == 0){
      return null;
    }
    else{
      List topicList = parseEntities(result);
      return topicList[0];
    }
  }

  Future<void> insertTopicByTopicName(String topicName) async{
    if (topicName == null){
      NLog.w('Wrong!!! topicName is null');
      return;
    }
    Topic topic = await getTopicByName(topicName);
    Database currentDataBase = await NKNDataManager().currentDatabase();
    /// need create New Topic
    if (topic == null){
      final themeId = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
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
      int result = await currentDataBase.insert(tableName, toEntity(topic), conflictAlgorithm: ConflictAlgorithm.ignore);
      if (result > 0){
        NLog.w('Insert topic success__'+topicName);
      }
    }
    else{
      if (topicName != null){
        NLog.w('Insert Topic is Exists__'+topicName);
      }
    }
  }

  Future<void> updateOwnerExpireBlockHeight(String topicName, int expiresAt) async {
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

  // Future<void> updateSubscribersCount(String topicName, int numSubscribers) async {
  //   Database currentDataBase = await NKNDataManager().currentDatabase();
  //   await currentDataBase.update(
  //     tableName,
  //     {count: numSubscribers},
  //     where: '$topic = ?',
  //     whereArgs: [topicName],
  //   );
  // }

  Future<void> delete(String topicName) async {
    Database currentDataBase = await NKNDataManager().currentDatabase();
    await currentDataBase.delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= SqliteStorage.currentVersion);

    NLog.w('topic_repo__CREATE UNIQUE INDEX index_');
    await db.execute(createSqlV5);
    await db.execute('CREATE UNIQUE INDEX index_${tableName}_$topic ON $tableName ($topic);');
  }

  static Future<void> upgradeFromV5(Database db, int oldVersion, int newVersion) async {
    assert(newVersion >= SqliteStorage.currentVersion);
    if (newVersion == SqliteStorage.currentVersion) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError('unsupported upgrade from $oldVersion to $newVersion.');
    }
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
        $options TEXT
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
  if (subs.topic != null){
    insertTopic = subs.topic;
  }
  // if (subs.numSubscribers > 0){
  //   numSubscribers = subs.numSubscribers;
  // }
  if (subs.avatarUri != null){
    avatarUri = subs.avatarUri;
  }
  if (subs.themeId > 0){
    themeId = subs.themeId;
  }
  if (subs.timeUpdate > 0){
    timeUpdate = subs.timeUpdate;
  }
  if (subs.blockHeightExpireAt > 0){
    blockHeightExpireAt = subs.blockHeightExpireAt;
  }
  if (subs.isTop != null){
    isTop = subs.isTop;
  }
  if (subs.options != null){
    _options = subs.options?.toJson();
  }
  return {
    topic: insertTopic,
    count: numSubscribers,
    avatar: avatarUri,
    theme_id: themeId,
    time_update: timeUpdate,
    expire_at: blockHeightExpireAt,
    is_top: isTop?1:0,
    options: _options,
  };
}