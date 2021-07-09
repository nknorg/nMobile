import 'dart:convert';

import 'package:nmobile/utils/utils.dart';

class SubscriberStatus {
  static const int DefaultNotMember = 0;
  static const int MemberInvited = 1;
  static const int MemberPublished = 2;
  static const int MemberSubscribed = 3;
  static const int MemberPublishRejected = 4;
  static const int MemberJoinedButNotInvited = 5;
}

class SubscriberSchema {
  int? id; // (required) <-> id
  String topic; // (required) <-> topic
  String clientAddress; // (required) <-> chat_id
  DateTime? createAt; // <-> create_at
  DateTime? updateAt; // <-> update_at
  int? status; // <-> status
  int? permPage; // <-> perm_page
  Map<String, dynamic>? data; // <-> data[permissions, ...]

  SubscriberSchema({
    this.id,
    required this.topic,
    required this.clientAddress,
    this.createAt,
    this.updateAt,
    this.status,
    this.permPage,
    this.data,
  });

  bool get joined {
    return (status ?? SubscriberStatus.DefaultNotMember) > SubscriberStatus.MemberJoinedButNotInvited;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'chat_id': clientAddress,
      'create_at': createAt?.millisecondsSinceEpoch ?? DateTime.now(),
      'update_at': updateAt?.millisecondsSinceEpoch ?? DateTime.now(),
      'status': status,
      'perm_page': permPage,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map;
  }

  static SubscriberSchema? fromMap(Map<String, dynamic>? e) {
    if (e == null) return null;
    var subscribeSchema = SubscriberSchema(
      id: e['id'],
      topic: e['topic'] ?? "",
      clientAddress: e['chat_id'] ?? "",
      createAt: e['create_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['create_at']) : DateTime.now(),
      updateAt: e['update_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['update_at']) : DateTime.now(),
      status: e['status'],
      permPage: e['perm_page'],
      data: (e['data']?.toString().isNotEmpty == true) ? jsonFormat(e['data']) : null,
    );
    return subscribeSchema;
  }

  @override
  String toString() {
    return 'SubscriberSchema{id: $id, topic: $topic, clientAddress: $clientAddress, createAt: $createAt, updateAt: $updateAt, status: $status, permPage: $permPage, data: $data}';
  }
}
