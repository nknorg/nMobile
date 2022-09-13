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
  // TODO:GG 消除！
  int? id;
  String groupId;
  int? permission; // TODO:GG PG?
  int? expiresAt;

  String? inviter;
  String? invitee;
  int? inviteAt;
  int? invitedAt;
  String? inviterRawData;
  String? inviteeRawData;
  String? inviterSignature;
  String? inviteeSignature;

  Map<String, dynamic>? data;

  PrivateGroupItemSchema({
    this.id,
    required this.groupId,
    this.permission = PrivateGroupItemPerm.none,
    this.expiresAt,
    this.inviter,
    this.invitee,
    this.inviteAt,
    this.invitedAt,
    this.inviterRawData,
    this.inviteeRawData,
    this.inviterSignature,
    this.inviteeSignature,
    this.data,
  });

  static PrivateGroupItemSchema? create(String? groupId, {int? expiresAt, String? inviter, String? invitee, int? inviteAt, int? invitedAt, String? inviterRawData, String? inviteeRawData, String? inviterSignature, String? inviteeSignature}) {
    if (groupId == null || groupId.isEmpty) return null;
    return PrivateGroupItemSchema(
      groupId: groupId,
      expiresAt: expiresAt,
      inviter: inviter,
      invitee: invitee,
      inviteAt: inviteAt,
      invitedAt: invitedAt,
      inviterRawData: inviterRawData,
      inviteeRawData: inviteeRawData,
      inviterSignature: inviterSignature,
      inviteeSignature: inviteeSignature,
    );
  }

  Map<String, dynamic> createRawData(bool isInvitee) {
    Map<String, dynamic> map = {};
    map['groupId'] = groupId;
    map['permission'] = groupId;
    map['expiresAt'] = expiresAt;
    map['inviter'] = inviter;
    map['invitee'] = invitee;
    map['inviteAt'] = inviteAt;
    if (isInvitee) map['inviteAt'] = invitedAt;
    return map.sortByKey();
  }

  static PrivateGroupItemSchema? fromRawData(Map<String, dynamic> data, {String? inviterRawData, String? inviteeRawData, String? inviterSignature, String? inviteeSignature}) {
    if ((data['groupId'] == null) || (data['groupId']?.toString().isEmpty == true)) return null;
    var schema = PrivateGroupItemSchema(
      groupId: data['groupId'],
      permission: data['permission'],
      expiresAt: data['expiresAt'],
      inviter: data['inviter'],
      invitee: data['invitee'],
      inviteAt: data['inviteAt'],
      invitedAt: data['invitedAt'],
      inviterRawData: data['inviterRawData'],
      inviteeRawData: data['inviteeRawData'],
      inviterSignature: data['inviterSignature'],
      inviteeSignature: data['inviteeSignature'],
    );
    if (inviterRawData != null) schema.inviterRawData = inviterRawData;
    if (inviteeRawData != null) schema.inviteeRawData = inviteeRawData;
    if (inviterSignature != null) schema.inviterSignature = inviterSignature;
    if (inviteeSignature != null) schema.inviteeSignature = inviteeSignature;
    return schema;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'permission': permission,
      'expires_at': expiresAt,
      'inviter': inviter,
      'invitee': invitee,
      'invite_at': inviteAt,
      'invited_at': invitedAt,
      'inviter_raw_data': inviterRawData,
      'invitee_raw_data': inviteeRawData,
      'inviter_signature': inviterSignature,
      'invitee_signature': inviteeSignature,
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
      inviter: e['inviter'],
      invitee: e['invitee'],
      inviteAt: e['invite_at'],
      invitedAt: e['invited_at'],
      inviterRawData: e['inviter_raw_data'],
      inviteeRawData: e['invitee_raw_data'],
      inviterSignature: e['inviter_signature'],
      inviteeSignature: e['invitee_signature'],
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
    return 'PrivateGroupItemSchema{id: $id, groupId: $groupId, permission: $permission, expiresAt: $expiresAt, invitee: $invitee, inviter: $inviter, inviteAt: $inviteAt, invitedAt: $invitedAt, inviteeRawData: $inviteeRawData, inviterRawData: $inviterRawData, inviteeSignature: $inviteeSignature, inviterSignature: $inviterSignature, data: $data}';
  }
}
