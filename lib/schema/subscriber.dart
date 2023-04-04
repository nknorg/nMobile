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
  String topic; // (required) <-> topic
  String clientAddress; // (required) <-> chat_id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  int? status; // <-> status
  int? permPage; // <-> perm_page
  Map<String, dynamic>? data; // <-> data[...]

  Map<String, dynamic>? temp; // no_sql

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

  String get pubKey {
    return getPubKeyFromTopicOrChatId(clientAddress) ?? clientAddress;
  }

  bool get canBeKick {
    int _status = (status ?? SubscriberStatus.None);
    return _status == SubscriberStatus.InvitedSend || _status == SubscriberStatus.InvitedReceipt || _status == SubscriberStatus.Subscribed;
  }

  int? isPermissionProgress() {
    int? status = data?['permission_progress'];
    return status;
  }

  int? getProgressPermissionNonce() {
    int? nonce = data?['progress_permission_nonce'];
    if (nonce == null || nonce < 0) return null;
    return nonce;
  }

  double getProgressPermissionFee() {
    double? fee = data?['progress_permission_fee'];
    if (fee == null || fee < 0) return 0;
    return fee;
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

  static SubscriberSchema fromMap(Map<String, dynamic> e) {
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
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);

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
    return 'SubscriberSchema{id: $id, topic: $topic, clientAddress: $clientAddress, createAt: $createAt, updateAt: $updateAt, status: $status, permPage: $permPage, data: $data, temp: $temp}';
  }
}
