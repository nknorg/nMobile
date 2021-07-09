import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';

import 'option.dart';

class TopicType {
  static int publicTopic = 1;
  static int privateTopic = 2;
}

class TopicSchema {
  int? id; // (required) <-> id
  String topic; // (required) <-> topic
  int? type; // (required) <-> type
  DateTime? createAt; // <-> create_at
  DateTime? updateAt; // <-> update_at
  DateTime? subscribeAt; // <-> subscribe_at
  int? expireBlockHeight; // <-> expire_height
  File? avatar; // <-> avatar
  int? count; // <-> count
  bool joined = false; // <-> joined
  bool isTop = false; // <-> is_top
  OptionsSchema? options; // <-> options
  Map<String, dynamic>? data; // <-> data[permissions, ...]

  TopicSchema({
    this.id,
    required this.topic,
    this.type,
    this.createAt,
    this.updateAt,
    this.subscribeAt,
    this.expireBlockHeight,
    this.avatar,
    this.count,
    this.joined = false,
    this.isTop = false,
    this.options,
    this.data,
  }) {
    if (options == null) {
      options = OptionsSchema();
    }
  }

  static TopicSchema? create(String? topic) {
    if (topic?.isNotEmpty == true) {
      return TopicSchema(topic: topic!, createAt: DateTime.now(), updateAt: DateTime.now());
    }
    return null;
  }

  bool get isPrivate {
    int type = this.type ?? (isPrivateTopicReg(topic) ? TopicType.privateTopic : TopicType.publicTopic);
    return type == TopicType.privateTopic;
  }

  Future<bool> get isJoined async {
    // TODO:GG topic fetchBlockHeight
    return joined; // && (expireBlockHeight ?? now).isAfter(now);
  }

  bool isOwner(String? accountPubKey) => (accountPubKey?.isNotEmpty == true) && (accountPubKey == ownerPubKey);

  String? get ownerPubKey {
    String? owner;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      owner = topic.substring(index + 1);
      if (owner.isEmpty) owner = null;
    } else {
      owner = null;
    }
    return owner;
  }

  String get topicName {
    String topicName;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      topicName = topic.substring(0, index);
    } else {
      topicName = topic;
    }
    return topicName;
  }

  String get topicShort {
    String topicNameShort;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      String topicName = topic.substring(0, index);
      if (ownerPubKey?.isNotEmpty == true) {
        if ((ownerPubKey?.length ?? 0) > 8) {
          topicNameShort = topicName + '.' + (ownerPubKey?.substring(0, 8) ?? "");
        } else {
          topicNameShort = topicName + '.' + (ownerPubKey ?? "");
        }
      } else {
        topicNameShort = topicName;
      }
    } else {
      topicNameShort = topic;
    }
    return topicNameShort;
  }

  Future<File?> get displayAvatarFile async {
    String? avatarLocalPath = avatar?.path;
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return Future.value(null);
    }
    String? completePath = Path.getCompleteFile(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
      return Future.value(null);
    }
    File avatarFile = File(completePath);
    bool exits = await avatarFile.exists();
    if (!exits) {
      return Future.value(null);
    }
    return avatarFile;
  }

  Map<String, dynamic> toMap() {
    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'type': isPrivate ? TopicType.privateTopic : TopicType.publicTopic,
      'create_at': createAt?.millisecondsSinceEpoch ?? DateTime.now(),
      'update_at': updateAt?.millisecondsSinceEpoch ?? DateTime.now(),
      'subscribe_at': subscribeAt?.millisecondsSinceEpoch,
      'expire_height': expireBlockHeight,
      'avatar': Path.getLocalFile(avatar?.path),
      'count': count,
      'joined': joined ? 1 : 0,
      'is_top': isTop ? 1 : 0,
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map;
  }

  static TopicSchema? fromMap(Map<String, dynamic>? e) {
    if (e == null) return null;
    var topicSchema = TopicSchema(
      id: e['id'],
      topic: e['topic'] ?? "",
      type: e['type'],
      createAt: e['create_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['create_at']) : DateTime.now(),
      updateAt: e['update_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['update_at']) : DateTime.now(),
      subscribeAt: e['subscribe_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['subscribe_at']) : null,
      expireBlockHeight: e['expire_height'],
      avatar: Path.getCompleteFile(e['avatar']) != null ? File(Path.getCompleteFile(e['avatar'])!) : null,
      count: e['count'],
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      options: OptionsSchema.fromMap(jsonFormat(e['options']) ?? Map()),
      data: (e['data']?.toString().isNotEmpty == true) ? jsonFormat(e['data']) : null,
    );
    if (topicSchema.options == null) {
      topicSchema.options = OptionsSchema();
    }
    // SUPPORT:START
    if (e['theme_id'] != null && (e['theme_id'] is int) && e['theme_id'] != 0) {
      topicSchema.options!.backgroundColor = Color(e['theme_id']);
    }
    // SUPPORT:END
    return topicSchema;
  }

  @override
  String toString() {
    return 'TopicSchema{id: $id, topic: $topic, type: $type, createAt: $createAt, updateAt: $updateAt, subscribeAt: $subscribeAt, expireBlockHeight: $expireBlockHeight, avatar: $avatar, count: $count, joined: $joined, isTop: $isTop, options: $options, data: $data}';
  }
}
