import 'dart:convert';

import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/utils.dart';

class SessionType {
  static const CONTACT = "contact";
  static const TOPIC = "topic";
}

class SessionSchema {
  int? id; // <-> id
  String targetId; // (required) <-> target_id
  String type; // (required) <-> type

  int? lastMessageAt; // <-> last_message_at
  Map<String, dynamic>? lastMessageOptions; // <-> last_message_options

  bool isTop; // <-> is_top
  int unReadCount; // <-> un_read_count

  SessionSchema({
    this.id,
    required this.targetId,
    required this.type,
    this.lastMessageAt,
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

  static String getTypeByMessage(MessageSchema? msg) {
    if (msg?.isTopic == true) {
      return SessionType.TOPIC;
    } else {
      return SessionType.CONTACT;
    }
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
    };
    return map;
  }

  static SessionSchema fromMap(Map e) {
    var schema = SessionSchema(
      id: e['id'],
      targetId: e['target_id'] ?? "",
      type: e['type'] ?? "",
      lastMessageAt: e['last_message_at'],
      lastMessageOptions: e['last_message_options'] != null ? jsonFormat(e['last_message_options']) : null,
      isTop: (e['is_top'] != null && e['is_top'] == 1) ? true : false,
      unReadCount: e['un_read_count'] ?? 0,
    );
    return schema;
  }

  @override
  String toString() {
    return 'SessionSchema{id: $id, targetId: $targetId, type: $type, unReadCount: $unReadCount, isTop: $isTop, lastMessageAt: $lastMessageAt, lastMessageOptions: $lastMessageOptions}';
  }
}
