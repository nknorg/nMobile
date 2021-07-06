import 'dart:convert';
import 'dart:io';

import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';

import 'option.dart';

class TopicType {
  static int publicTopic = 1;
  static int privateTopic = 2;
}

class TopicSchema {
  int? id;
  String topic;
  int? type; // TODO:GG 原版DB里没这个字段(原版最最后才加的)
  DateTime? subscribeAt;
  DateTime? expireAt;
  File? avatar;
  int? count;
  bool joined = false; // TODO:GG 原版没这个字段(原版最后才加的)
  bool isTop = false;
  OptionsSchema? options;

  TopicSchema({
    this.id,
    required this.topic,
    this.type,
    this.subscribeAt,
    this.expireAt,
    this.avatar,
    this.count,
    this.joined = false,
    this.isTop = false,
    this.options,
  }) : assert(topic.isNotEmpty) {
    if (type == null) {
      type = isPrivateTopicReg(topic) ? TopicType.privateTopic : TopicType.publicTopic;
    }
    if (options == null) {
      options = OptionsSchema();
    }
  }

  bool get isPrivate {
    return this.type != null && this.type == TopicType.privateTopic;
  }

  String? get owner {
    String? owner;
    if (type == TopicType.privateTopic) {
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
    if (type == TopicType.privateTopic) {
      int index = topic.lastIndexOf('.');
      topicName = topic.substring(0, index);
    } else {
      topicName = topic;
    }
    return topicName;
  }

  String get topicNameShort {
    String topicNameShort;
    if (type == TopicType.privateTopic) {
      int index = topic.lastIndexOf('.');
      String topicName = topic.substring(0, index);
      if (owner?.isNotEmpty == true) {
        if ((owner?.length ?? 0) > 8) {
          topicNameShort = topicName + '.' + (owner?.substring(0, 8) ?? "");
        } else {
          topicNameShort = topicName + '.' + (owner ?? "");
        }
      } else {
        topicNameShort = topicName;
      }
    } else {
      topicNameShort = topic;
    }
    return topicNameShort;
  }

  Map<String, dynamic> toMap() {
    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'type': type,
      'time_update': subscribeAt?.millisecondsSinceEpoch,
      'expire_at': expireAt?.millisecondsSinceEpoch,
      'avatar': (avatar is File?) ? Path.getLocalFile(avatar?.path) : null,
      'count': count,
      'joined': joined ? 1 : 0,
      'is_top': isTop ? 1 : 0,
      'options': options != null ? jsonEncode(options!.toMap()) : null,
    };
    return map;
  }

  static TopicSchema? fromMap(Map<String, dynamic>? e) {
    if (e == null) return null;
    var topicSchema = TopicSchema(
      id: e['id'],
      topic: e['topic'] ?? "",
      type: e['type'],
      subscribeAt: e['time_update'] != null ? DateTime.fromMillisecondsSinceEpoch(e['time_update']) : null,
      expireAt: e['expire_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['expire_at']) : null,
      avatar: Path.getCompleteFile(e['avatar']) != null ? File(Path.getCompleteFile(e['avatar'])!) : null,
      count: e['count'],
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      options: OptionsSchema.fromMap(jsonFormat(e['options']) ?? Map()),
    );
    if (topicSchema.options == null) {
      topicSchema.options = OptionsSchema();
    }
    // SUPPORT:START
    if (topicSchema.options!.backgroundColor == null) {
      topicSchema.options!.backgroundColor = e['theme_id'];
    }
    // SUPPORT:END
    return topicSchema;
  }
}
