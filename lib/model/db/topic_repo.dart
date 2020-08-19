/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/group_chat_helper.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 19/08/2020

class Topic with Tag {
  final int id;
  final String topic;
  final int numSubscribers;
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
      this.numSubscribers,
      // ignore: avoid_init_to_null
      this.avatarUri = null,
      this.themeId,
      this.timeUpdate,
      this.blockHeightExpireAt,
      this.isTop = false,
      // ignore: avoid_init_to_null
      options = null})
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
        numSubscribers: numSubscribers,
        avatarUri: avatarUri,
        themeId: themeId,
        timeUpdate: timeUpdate,
        blockHeightExpireAt: blockHeightExpireAt,
        isTop: isTop,
        options: options);
  }

  String get name => _name;

  String get owner => _owner;

  TopicType get type => _type;

  bool get isPrivate => type == TopicType.private;

  String get shortName => isPrivate ? name + '.' + owner.substring(0, 8) : name;

  OptionsSchema get options {
    LOG(tag).w('option: $_options, jsonDecode: ${jsonDecode(_options)}');
    return _options == null ? null : _optionsSchema ??= OptionsSchema.parseEntity(jsonDecode(_options));
  }

  bool isOwner(String accountPubkey) => accountPubkey == owner;
}

enum TopicType { private, public }

extension TopicTypeString on TopicType {
  String get toStr => this == TopicType.private ? 'private' : 'public';
}

class TopicRepo with Tag {
  LOG _log;
  final Future<Database> _db;

  TopicRepo(this._db) {
    _log = LOG(tag);
  }

  // @Query("SELECT * from topic")
  Future<List<Topic>> getAllTopics() async {
    _log.i('getAllTopics()');
    List<Map<String, dynamic>> result = await (await _db).query(tableName);
    return parseEntities(result);
  }

  Future<List<String>> getAllTopicNames() async {
    _log.i('getAllTopicNames()');
    final rows = await getAllTopics();
    final result = <String>[];
    for (var row in rows) {
      result.add(row.name);
    }
    return result;
  }

  // @Query("SELECT * from topic WHERE topic = :topic LIMIT 1 OFFSET 0")
  Future<Topic> getTopicByName(String topicName) async {
    _log.i('getTopicByName($topicName)');
    List<Map<String, dynamic>> result = await (await _db).query(tableName, where: '$topic = ?', whereArgs: [topicName]);
    final list = parseEntities(result);
    if (list.isNotEmpty) {
      if (list.length > 1) _log.w("getTopicByName, size: ${list.length}");
      return list[0];
    }
    _log.w('getTopicByName($topicName), null');
    return null;
  }

  Future<void> insertOrUpdateTime(Topic topic) async {
    _log.i('insertOrUpdateTime(${topic.topic})');
    if (await getTopicByName(topic.topic) == null) {
      await insertOrIgnore(topic);
    } else {
      await updateTimeUpdate(topic.topic, topic.timeUpdate);
    }
  }

  // @Insert(onConflict = OnConflictStrategy.IGNORE)
  Future<void> insertOrIgnore(Topic topic) async {
    _log.i('insertOrIgnore(${topic.topic})');
    await (await _db).insert(tableName, toEntity(topic), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // @Query("""UPDATE topic SET time_update = :timeUpdate WHERE topic = :topic""")
  Future<void> updateTimeUpdate(String topicName, int timeUpdate) async {
    _log.i('updateTimeUpdate($topicName, $timeUpdate)');
    await (await _db).update(
      tableName,
      {time_update: timeUpdate},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  // @Query("""UPDATE topic SET expire_at = :expireAt WHERE topic = :topic""")
  Future<void> updateOwnerExpireBlockHeight(String topicName, int expiresAt) async {
    _log.i('updateOwnerExpireBlockHeight($topicName, $expiresAt)');
    await (await _db).update(
      tableName,
      {expire_at: expiresAt},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  // @Query("""UPDATE topic SET avatar = :avatarUri WHERE topic = :topic""")
  Future<void> updateAvatar(String topicName, String avatarUri) async {
    _log.i('updateAvatar($topicName, $avatarUri)');
    await (await _db).update(
      tableName,
      {avatar: avatarUri},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  Future<int> updateIsTop(String topicName, bool isTop) async {
    _log.i('updateIsTop($topicName, $isTop)');
    return await (await _db).update(
      tableName,
      {is_top: isTop ? 1 : 0},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  // @Query("""UPDATE topic SET number = :numSubscribers WHERE topic = :topic""")
  Future<void> updateSubscribersCount(String topicName, int numSubscribers) async {
    _log.i('updateSubscribersCount($topicName, $numSubscribers)');
    await (await _db).update(
      tableName,
      {count: numSubscribers},
      where: '$topic = ?',
      whereArgs: [topicName],
    );
  }

  // @Query("DELETE FROM topic WHERE topic = :topic")
  Future<void> delete(String topicName) async {
    _log.i('delete($topicName)');
    await (await _db).delete(tableName, where: '$topic = ?', whereArgs: [topicName]);
  }

  static Future<void> create(Database db, int version) async {
    assert(version >= 5);
    await db.execute(deleteSql);
    await db.execute(createSqlV5);

    // equivalent to PRIMARY KEY
    // await db.execute('CREATE     INDEX index_${tableName}_$id    ON tableName ($id);');
    await db.execute('CREATE UNIQUE INDEX index_${tableName}_$topic ON $tableName ($topic);');
  }

  static Future<void> upgradeFromV5(Database db, int oldVersion, int newVersion) async {
    assert(newVersion >= 5);
    if (newVersion == 5) {
      await create(db, newVersion);
    } else {
      throw UnsupportedError('unsupported upgrade from $oldVersion to $newVersion.');
    }
  }

  static final deleteSql = '''DROP TABLE Topic;''';
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
    numSubscribers: row[count],
    avatarUri: row[avatar],
    themeId: row[theme_id],
    timeUpdate: row[time_update],
    blockHeightExpireAt: row[expire_at],
    isTop: row[is_top] == 1,
    options: opt,
  );
}

Map<String, dynamic> toEntity(Topic subs) {
  return {
//    id: subs.id,
    topic: subs.topic,
    count: subs.numSubscribers,
    avatar: subs.avatarUri,
    theme_id: subs.themeId,
    time_update: subs.timeUpdate,
    expire_at: subs.blockHeightExpireAt,
    is_top: subs.isTop,
    options: subs.options?.toJson(),
  };
}

//@Entity(
//    tableName = "topic",
//    indices = [Index("topic", unique = true)]
//)
//data class Topic(
//@PrimaryKey(autoGenerate = true)
//@ColumnInfo(name = "id", index = true) val id: Long,
//
//// TopicType.Private/TopicType.Public
////@ColumnInfo(name = "type", index = true) val type: String,
//@ColumnInfo(name = "topic"/*, index = true*/) val topic: String,
////@ColumnInfo(name = "owner", index = true) val owner: String?,
//@ColumnInfo(name = "count") val numSubscribers: Int,
//
//@ColumnInfo(name = "avatar") val avatarUri: String?,
//@ColumnInfo(name = "theme_id") val themeId: Int,
//
//@ColumnInfo(name = "time_update") val timeUpdate: Long,
//@ColumnInfo(name = "expire_at") val blockHeightExpireAt: Int,

//@ColumnInfo(name = "is_top") val isTop: Boolean
//)
