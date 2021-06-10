import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:nmobile/utils/utils.dart';

class SessionSchema extends Equatable {
  int? id; // <-> id
  String targetId; // (required) <-> target_id
  bool isTopic = false; // (required) <-> is_topic
  DateTime? lastMessageTime; // <-> last_message_time
  Map<String, dynamic>? lastMessageOptions; // <-> last_message_options
  int unReadCount; // <-> un_read_count
  bool isTop; // <-> is_top

  SessionSchema({
    this.id,
    required this.targetId,
    required this.isTopic,
    this.lastMessageTime,
    this.lastMessageOptions,
    this.unReadCount = 0,
    this.isTop = false,
  });

  @override
  List<Object?> get props => [targetId];

  Future<Map<String, dynamic>> toMap() async {
    Map<String, dynamic> map = {
      'id': id,
      'target_id': targetId,
      'is_topic': isTopic ? 1 : 0,
      'last_message_time': lastMessageTime?.millisecondsSinceEpoch,
      'un_read_count': unReadCount,
      'is_top': isTop ? 1 : 0,
    };
    map["last_message_options"] = lastMessageOptions != null ? jsonEncode(lastMessageOptions) : null;
    return map;
  }

  static SessionSchema fromMap(Map e) {
    var schema = SessionSchema(
      id: e['id'],
      targetId: e['target_id'] ?? "",
      isTopic: (e['is_topic'] != null && e['is_topic'] == 1) ? true : false,
      lastMessageTime: e['last_message_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['last_message_time']) : null,
      lastMessageOptions: e['last_message_options'] != null ? jsonFormat(e['last_message_options']) : null,
      unReadCount: e['un_read_count'] ?? 0,
      isTop: (e['is_top'] != null && e['is_top'] == 1) ? true : false,
    );
    return schema;
  }

  @override
  String toString() {
    return 'SessionSchema{id: $id, targetId: $targetId, isTopic: $isTopic, unReadCount: $unReadCount, isTop: $isTop, lastMessageTime: $lastMessageTime, lastMessageOptions: $lastMessageOptions}';
  }
}
