import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/utils.dart';

import 'contact.dart';
import 'topic.dart';

class SessionSchema extends Equatable {
  String targetId;
  bool isTopic = false;
  DateTime? lastReceiveTime;
  Map<String, dynamic>? lastReceiveOptions;
  int unReadCount;
  bool isTop;

  TopicSchema? topic;
  ContactSchema? contact;
  MessageSchema? message;

  SessionSchema({
    required this.targetId,
    required this.isTopic,
    this.lastReceiveTime,
    this.lastReceiveOptions,
    this.unReadCount = 0,
    this.isTop = false,
  });

  @override
  List<Object?> get props => [targetId];

  Future<Map<String, dynamic>> toMap() async {
    Map<String, dynamic> map = {
      'target_id': targetId,
      'is_topic': isTopic ? 1 : 0,
      'last_receive_time': lastReceiveTime?.millisecondsSinceEpoch,
      'un_read_count': unReadCount,
      'is_top': isTop ? 1 : 0,
    };
    Map<String, dynamic>? options = message?.toMap();
    map["last_receive_options"] = options != null ? jsonEncode(options) : '{}';
    return map;
  }

  static Future<SessionSchema?> fromMap(Map e) async {
    var schema = SessionSchema(
      targetId: e['target_id'] ?? "",
      isTopic: (e['is_topic'] != null && e['is_topic'] == 1) ? true : false,
      lastReceiveTime: e['last_receive_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['last_receive_time']) : null,
      lastReceiveOptions: e['last_receive_options'] != null ? jsonFormat(e['last_receive_options']) : null,
      unReadCount: e['un_read_count'] ?? 0,
      isTop: (e['is_top'] != null && e['is_top'] == 1) ? true : false,
    );
    if (schema.targetId.isEmpty) return null;
    // topic + contact
    if (schema.isTopic) {
      schema.topic = await TopicStorage().queryTopicByTopicName(schema.targetId);
    } else {
      schema.contact = await contactCommon.queryByClientAddress(schema.targetId);
    }
    // message
    if (schema.lastReceiveOptions != null && schema.lastReceiveOptions!.isNotEmpty) {
      schema.message = MessageSchema.fromMap(schema.lastReceiveOptions!);
    } else {
      List<MessageSchema> history = await MessageStorage().queryListCanReadByTargetId(schema.targetId, offset: 0, limit: 1);
      if (history.isNotEmpty) {
        schema.message = history[0];
      }
    }
    return schema;
  }
}
