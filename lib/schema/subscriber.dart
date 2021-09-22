import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/utils.dart';

class SubscriberStatus {
  static const int None = 0;
  static const int InvitedSend = 1;
  static const int InvitedReceipt = 2;
  static const int Subscribed = 3;
  static const int Unsubscribed = 4;
  // static const int DefaultNotMember = 0;
  // static const int MemberInvited = 1;
  // static const int MemberPublished = 2;
  // static const int MemberSubscribed = 3;
  // static const int MemberPublishRejected = 4;
  // static const int MemberJoinedButNotInvited = 5;
}

class SubscriberSchema {
  static const int PermPageSize = 10;

  int? id; // (required) <-> id
  String topic; // (required) <-> topic
  String clientAddress; // (required) <-> chat_id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  int? status; // <-> status
  int? permPage; // <-> perm_page
  Map<String, dynamic>? data; // <-> data[...]

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

  bool get canBeKick {
    int _status = (status ?? SubscriberStatus.None);
    return _status == SubscriberStatus.InvitedSend || _status == SubscriberStatus.InvitedReceipt || _status == SubscriberStatus.Subscribed;
  }

  Future<ContactSchema?> getContact({bool emptyAdd = false}) async {
    ContactSchema? _contact = await contactCommon.queryByClientAddress(clientAddress);
    if (_contact != null || !emptyAdd) return _contact;
    return await contactCommon.addByType(clientAddress, ContactType.none, notify: true, checkDuplicated: false);
  }

  static SubscriberSchema? create(String? topic, String? clientAddress, int? status, int? permPage) {
    if (topic?.isNotEmpty == true && clientAddress?.isNotEmpty == true) {
      return SubscriberSchema(
        topic: topic!,
        clientAddress: clientAddress!,
        createAt: DateTime.now().millisecondsSinceEpoch,
        updateAt: DateTime.now().millisecondsSinceEpoch,
        status: status,
        permPage: permPage,
      );
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'chat_id': clientAddress,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
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
      createAt: e['create_at'],
      updateAt: e['update_at'],
      status: e['status'],
      permPage: e['perm_page'],
    );

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (subscribeSchema.data == null) {
        subscribeSchema.data = new Map<String, dynamic>();
      }
      if (data != null) {
        subscribeSchema.data?.addAll(data);
      }
    }
    return subscribeSchema;
  }

  @override
  String toString() {
    return 'SubscriberSchema{id: $id, topic: $topic, clientAddress: $clientAddress, createAt: $createAt, updateAt: $updateAt, status: $status, permPage: $permPage, data: $data}';
  }
}
