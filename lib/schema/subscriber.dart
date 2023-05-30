import 'dart:convert';

import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/utils/util.dart';

class SubscriberStatus {
  static const int None = 0;
  static const int InvitedSend = 1;
  static const int InvitedReceipt = 2;
  static const int Subscribed = 3;
  static const int Unsubscribed = 4;
}

class SubscriberSchema {
  static const int PermPageSize = 10;

  int? id; // (required) <-> id
  int createAt; // <-> create_at
  int updateAt; // <-> update_at

  String topicId; // (required) <-> topic_id
  String contactAddress; // (required) <-> contact_address

  int status; // <-> status
  int? permPage; // <-> perm_page

  Map<String, dynamic> data = Map(); // <-> data[...]

  Map<String, dynamic>? temp; // no_sql

  SubscriberSchema({
    this.id,
    this.createAt = 0,
    this.updateAt = 0,
    required this.topicId,
    required this.contactAddress,
    this.status = SubscriberStatus.None,
    this.permPage,
  }) {
    if (createAt == 0) createAt = DateTime.now().millisecondsSinceEpoch;
    if (updateAt == 0) updateAt = DateTime.now().millisecondsSinceEpoch;
  }

  static SubscriberSchema? create(String? topicId, String? contactAddress, int? status, int? permPage) {
    if ((topicId == null) || topicId.isEmpty || (contactAddress == null) || contactAddress.isEmpty) return null;
    return SubscriberSchema(
      topicId: topicId,
      contactAddress: contactAddress,
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
      status: status ?? SubscriberStatus.None,
      permPage: permPage,
    );
  }

  String get pubKey {
    return getPubKeyFromTopicOrChatId(contactAddress) ?? contactAddress;
  }

  bool get canBeKick {
    return (status == SubscriberStatus.InvitedSend) || (status == SubscriberStatus.InvitedReceipt) || (status == SubscriberStatus.Subscribed);
  }

  int? isPermissionProgress() {
    return int.tryParse(data['permission_progress']?.toString() ?? "");
  }

  int? getProgressPermissionNonce() {
    int? nonce = int.tryParse(data['progress_permission_nonce']?.toString() ?? "");
    if (nonce == null || nonce < 0) return null;
    return nonce;
  }

  double getProgressPermissionFee() {
    double? fee = double.tryParse(data['progress_permission_fee']?.toString() ?? "");
    if (fee == null || fee < 0) return 0;
    return fee;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'create_at': createAt,
      'update_at': updateAt,
      'topic_id': topicId,
      'contact_address': contactAddress,
      'status': status,
      'perm_page': permPage,
      'data': jsonEncode(data),
    };
    return map;
  }

  static SubscriberSchema fromMap(Map<String, dynamic> e) {
    var subscribeSchema = SubscriberSchema(
      id: e['id'],
      createAt: e['create_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updateAt: e['update_at'] ?? DateTime.now().millisecondsSinceEpoch,
      topicId: e['topic_id'] ?? "",
      contactAddress: e['contact_address'] ?? "",
      status: e['status'] ?? SubscriberStatus.None,
      permPage: e['perm_page'],
    );
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) subscribeSchema.data.addAll(data);
    }
    return subscribeSchema;
  }

  @override
  String toString() {
    return 'SubscriberSchema{id: $id, createAt: $createAt, updateAt: $updateAt, topicId: $topicId, clientAddress: $contactAddress, status: $status, permPage: $permPage, data: $data, temp: $temp}';
  }
}
