import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';

class TopicType {
  static const publicTopic = 1;
  static const privateTopic = 2;
}

class TopicSchema {
  static final minRefreshCount = 30;

  int? id; // (required) <-> id
  String topic; // (required) <-> topic
  int? type; // (required) <-> type
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  bool joined = false; // <-> joined
  int? subscribeAt; // <-> subscribe_at
  int? expireBlockHeight; // <-> expire_height

  File? avatar; // <-> avatar
  int? count; // <-> count
  bool isTop = false; // <-> is_top

  OptionsSchema? options; // <-> options
  Map<String, dynamic>? data; // <-> data[...]

  TopicSchema({
    this.id,
    required this.topic,
    this.type,
    this.createAt,
    this.updateAt,
    this.joined = false,
    this.subscribeAt,
    this.expireBlockHeight,
    this.avatar,
    this.count,
    this.isTop = false,
    this.options,
    this.data,
  }) {
    this.type = this.type ?? (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic);

    if (options == null) {
      options = OptionsSchema();
    }
  }

  static TopicSchema? create(String? topic, {int? type, int expireHeight = 0}) {
    if (topic?.isNotEmpty == true) {
      return TopicSchema(
        topic: topic!,
        type: type ?? (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic),
        createAt: DateTime.now().millisecondsSinceEpoch,
        updateAt: DateTime.now().millisecondsSinceEpoch,
        joined: expireHeight > 0 ? true : false,
        subscribeAt: expireHeight > 0 ? DateTime.now().millisecondsSinceEpoch : null,
        expireBlockHeight: expireHeight > 0 ? expireHeight : null,
      );
    }
    return null;
  }

  bool get isPrivate {
    int type = this.type ?? (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic);
    return type == TopicType.privateTopic;
  }

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
      if (index > 0) {
        topicName = topic.substring(0, index);
      } else {
        topicName = topic;
      }
    } else {
      topicName = topic;
    }
    return topicName;
  }

  String get topicShort {
    String topicNameShort;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      if (index > 0) {
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
    } else {
      topicNameShort = topic;
    }
    return topicNameShort;
  }

  String? get displayAvatarPath {
    String? avatarLocalPath = avatar?.path;
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return null;
    }
    String? completePath = Path.getCompleteFile(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
      return null;
    }
    return completePath;
  }

  Future<File?> get displayAvatarFile async {
    String? completePath = displayAvatarPath;
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

  bool isOwner(String? clientAddress) {
    if (!isPrivate || clientAddress == null || clientAddress.isEmpty) return false;
    String? accountPubKey = getPubKeyFromTopicOrChatId(clientAddress);
    return accountPubKey?.isNotEmpty == true && accountPubKey == ownerPubKey;
  }

  Future<bool> shouldResubscribe({int? globalHeight}) async {
    if ((expireBlockHeight == null) || (expireBlockHeight! <= 0)) return true;
    globalHeight = globalHeight ?? (await Global.getBlockHeight());
    if (globalHeight != null && globalHeight > 0) {
      return (expireBlockHeight! - globalHeight) < Global.topicWarnBlockExpireHeight;
    } else {
      return true;
    }
  }

  Map<String, dynamic> newDataByAppendSubscribe(bool subscribe, bool isProgress) {
    Map<String, dynamic> newData = data ?? Map();
    if (subscribe) {
      if (isProgress) {
        newData['subscribe_progress'] = true;
      } else {
        newData.remove('subscribe_progress');
      }
      newData.remove('unsubscribe_progress');
    } else {
      if (isProgress) {
        newData['unsubscribe_progress'] = true;
      } else {
        newData.remove('unsubscribe_progress');
      }
      newData.remove('subscribe_progress');
    }
    return newData;
  }

  bool isSubscribeProgress() {
    bool? isProgress = data?['subscribe_progress'];
    if (isProgress == null) return false;
    return isProgress;
  }

  bool isUnSubscribeProgress() {
    bool? isProgress = data?['unsubscribe_progress'];
    if (isProgress == null) return false;
    return isProgress;
  }

  Map<String, dynamic> newDataByLastRefreshSubscribersAt(int? lastRefreshSubscribersAt) {
    Map<String, dynamic> newData = data ?? Map();
    newData['last_refresh_subscribers_at'] = lastRefreshSubscribersAt;
    return newData;
  }

  int lastRefreshSubscribersAt() {
    int? lastRefreshSubscribersAt = data?['last_refresh_subscribers_at'];
    return lastRefreshSubscribersAt ?? 0;
  }

  bool shouldRefreshSubscribers(int lastRefreshAt, int subscribersCount, {int minBetween = 5 * 60 * 1000}) {
    if (subscribersCount <= minRefreshCount) return false;
    int needBetween = subscribersCount * (5 * 60 * 1000); // 300s * count
    if (needBetween < minBetween) needBetween = minBetween;
    if ((DateTime.now().millisecondsSinceEpoch - lastRefreshAt) <= needBetween) return false;
    return true;
  }

  Map<String, dynamic> toMap() {
    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'type': type,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'joined': joined ? 1 : 0,
      'subscribe_at': subscribeAt,
      'expire_height': expireBlockHeight,
      'avatar': Path.getLocalFile(avatar?.path),
      'count': count,
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
      createAt: e['create_at'],
      updateAt: e['update_at'],
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      subscribeAt: e['subscribe_at'],
      expireBlockHeight: e['expire_height'],
      avatar: Path.getCompleteFile(e['avatar']) != null ? File(Path.getCompleteFile(e['avatar'])!) : null,
      count: e['count'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      data: (e['data']?.toString().isNotEmpty == true) ? jsonFormat(e['data']) : null,
    );

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = jsonFormat(e['options']);
      topicSchema.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (topicSchema.options == null) {
      topicSchema.options = OptionsSchema();
    }

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (topicSchema.data == null) {
        topicSchema.data = new Map<String, dynamic>();
      }
      if (data != null) {
        topicSchema.data?.addAll(data);
      }
    }

    // SUPPORT:START
    if (e['theme_id'] != null && (e['theme_id'] is int) && e['theme_id'] != 0) {
      topicSchema.options!.avatarBgColor = Color(e['theme_id']);
    }
    // SUPPORT:END
    return topicSchema;
  }

  @override
  String toString() {
    return 'TopicSchema{id: $id, topic: $topic, type: $type, createAt: $createAt, updateAt: $updateAt, joined: $joined, subscribeAt: $subscribeAt, expireBlockHeight: $expireBlockHeight, avatar: $avatar, count: $count, isTop: $isTop, options: $options, data: $data}';
  }
}
