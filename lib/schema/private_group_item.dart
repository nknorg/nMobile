import 'dart:convert';

import 'package:nmobile/utils/map_extension.dart';
import 'package:nmobile/utils/util.dart';

class PrivateGroupItemPerm {
  static const none = 0;
  static const owner = 1;
  static const admin = 2;
  static const normal = 3;
}

class PrivateGroupItemSchema {
  int? id;
  String groupId;
  int? permission; // TODO:GG PG ??
  int? expiresAt;

  String? invitee;
  String? inviter;
  int? inviteeAt;
  int? invitedAt;
  String? inviteeRawData;
  String? inviterRawData;
  String? inviteeSignature;
  String? inviterSignature;

  Map<String, dynamic>? data;

  PrivateGroupItemSchema({
    this.id,
    required this.groupId,
    this.permission = PrivateGroupItemPerm.none,
    this.expiresAt,
    this.invitee,
    this.inviter,
    this.inviteeAt,
    this.invitedAt,
    this.inviteeRawData,
    this.inviterRawData,
    this.inviteeSignature,
    this.inviterSignature,
    this.data,
  });

  static PrivateGroupItemSchema? create(String? groupId, {int? expiresAt, String? invitee, String? inviter, int? inviteeAt, int? invitedAt, String? inviteeRawData, String? inviterRawData, String? inviteeSignature, String? inviterSignature}) {
    if (groupId == null || groupId.isEmpty) return null;
    return PrivateGroupItemSchema(
      groupId: groupId,
      invitee: invitee,
      expiresAt: expiresAt,
      inviteeAt: inviteeAt,
      invitedAt: invitedAt,
      inviteeRawData: inviteeRawData,
      inviterRawData: inviterRawData,
      inviteeSignature: inviteeSignature,
      inviterSignature: inviterSignature,
    );
  }

  static PrivateGroupItemSchema fromRawData(Map<String, dynamic> data, {String? inviteeRawData, String? inviterRawData, String? inviteeSignature, String? inviterSignature}) {
    var schema = PrivateGroupItemSchema(
      groupId: data['groupId'],
      permission: data['permission'],
      expiresAt: data['expiresAt'],
      invitee: data['invitee'],
      inviter: data['inviter'],
      inviteeAt: data['inviteeAt'],
      invitedAt: data['invitedAt'],
      inviteeRawData: data['inviteeRawData'],
      inviterRawData: data['inviterRawData'],
      inviteeSignature: data['inviteeSignature'],
      inviterSignature: data['inviterSignature'],
    );
    if (inviteeRawData != null) schema.inviteeRawData = inviteeRawData;
    if (inviterRawData != null) schema.inviterRawData = inviterRawData;
    if (inviteeSignature != null) schema.inviteeSignature = inviteeSignature;
    if (inviterSignature != null) schema.inviterSignature = inviterSignature;
    return schema;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'permission': permission,
      'expires_at': expiresAt,
      'invitee': invitee,
      'inviter': inviter,
      'invitee_at': inviteeAt,
      'invited_at': invitedAt,
      'invitee_raw_data': inviteeRawData,
      'inviter_raw_data': inviterRawData,
      'invitee_signature': inviteeSignature,
      'inviter_signature': inviterSignature,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map.sortByKey();
  }

  static PrivateGroupItemSchema fromMap(Map<String, dynamic> e) {
    var schema = PrivateGroupItemSchema(
      id: e['id'],
      groupId: e['group_id'] ?? "",
      permission: e['permission'],
      expiresAt: e['expires_at'],
      invitee: e['invitee'],
      inviter: e['inviter'],
      inviteeAt: e['invitee_at'],
      invitedAt: e['invited_at'],
      inviteeRawData: e['invitee_raw_data'],
      inviterRawData: e['inviter_raw_data'],
      inviteeSignature: e['invitee_signature'],
      inviterSignature: e['inviter_signature'],
    );

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormat(e['data']);
      if (schema.data == null) {
        schema.data = new Map<String, dynamic>();
      }
      if (data != null) {
        schema.data?.addAll(data);
      }
    }
    return schema;
  }

  @override
  String toString() {
    return 'PrivateGroupItemSchema{id: $id, groupId: $groupId, permission: $permission, expiresAt: $expiresAt, invitee: $invitee, inviter: $inviter, inviteeAt: $inviteeAt, invitedAt: $invitedAt, inviteeRawData: $inviteeRawData, inviterRawData: $inviterRawData, inviteeSignature: $inviteeSignature, inviterSignature: $inviterSignature, data: $data}';
  }
}
