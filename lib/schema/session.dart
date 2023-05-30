import 'dart:convert';

import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/util.dart';

class SessionType {
  static const CONTACT = 1;
  static const TOPIC = 2;
  static const PRIVATE_GROUP = 3;
}

class SessionSchema {
  int? id; // <-> id

  String targetId; // (required) <-> target_id
  int type; // (required) <-> type

  int lastMessageAt; // <-> last_message_at
  Map<String, dynamic>? lastMessageOptions; // <-> last_message_options

  bool isTop; // <-> is_top
  int unReadCount; // <-> un_read_count

  Map<String, dynamic> data = Map(); // <-> data

  Map<String, dynamic>? temp; // no_sql

  SessionSchema({
    this.id,
    required this.targetId,
    required this.type,
    required this.lastMessageAt,
    this.lastMessageOptions,
    this.isTop = false,
    this.unReadCount = 0,
  });

  bool get isContact {
    return type == SessionType.CONTACT;
  }

  bool get isTopic {
    return type == SessionType.TOPIC;
  }

  bool get isPrivateGroup {
    return type == SessionType.PRIVATE_GROUP;
  }

  static int getTypeByMessage(MessageSchema? msg) {
    if (msg?.isTargetContact == true) {
      return SessionType.CONTACT;
    } else if (msg?.isTargetTopic == true) {
      return SessionType.TOPIC;
    } else if (msg?.isTargetGroup == true) {
      return SessionType.PRIVATE_GROUP;
    }
    return 0;
  }

  Future<Map<String, dynamic>> toMap() async {
    Map<String, dynamic> map = {
      'id': id,
      'target_id': targetId,
      'type': type,
      'last_message_at': lastMessageAt,
      'last_message_options': (lastMessageOptions?.isNotEmpty == true) ? jsonEncode(lastMessageOptions) : null,
      'is_top': isTop ? 1 : 0,
      'un_read_count': unReadCount,
      'data': jsonEncode(data),
    };
    return map;
  }

  static SessionSchema fromMap(Map e) {
    var schema = SessionSchema(
      id: e['id'],
      targetId: e['target_id'] ?? "",
      type: e['type'] ?? 0,
      lastMessageAt: e['last_message_at'] ?? DateTime.now().millisecondsSinceEpoch,
      lastMessageOptions: e['last_message_options'] != null ? Util.jsonFormatMap(e['last_message_options']) : null,
      isTop: (e['is_top'] != null && e['is_top'] == 1) ? true : false,
      unReadCount: e['un_read_count'] ?? 0,
    );
    // data
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) schema.data.addAll(data);
    }
    return schema;
  }

  @override
  String toString() {
    return 'SessionSchema{id: $id, targetId: $targetId, type: $type, lastMessageAt: $lastMessageAt, lastMessageOptions: $lastMessageOptions, isTop: $isTop, unReadCount: $unReadCount, data: $data, temp: $temp}';
  }
}
