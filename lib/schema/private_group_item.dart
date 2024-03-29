import 'dart:convert';

import 'package:nmobile/utils/map_extension.dart';
import 'package:nmobile/utils/util.dart';

class PrivateGroupItemPerm {
  static const black = -20;
  static const quit = -10;
  static const none = 0;
  static const normal = 10;
  static const admin = 20;
  static const owner = 30;
}

class PrivateGroupItemSchema {
  int? id;

  String groupId;
  int permission;
  int? expiresAt;

  String? inviter;
  String? invitee;
  String? inviterRawData;
  String? inviteeRawData;
  String? inviterSignature;
  String? inviteeSignature;

  Map<String, dynamic> data = Map();

  Map<String, dynamic>? temp; // no_sql

  PrivateGroupItemSchema({
    this.id,
    required this.groupId,
    this.permission = PrivateGroupItemPerm.none,
    this.expiresAt,
    this.inviter,
    this.invitee,
    this.inviterRawData,
    this.inviteeRawData,
    this.inviterSignature,
    this.inviteeSignature,
  });

  static PrivateGroupItemSchema? create(
    String? groupId, {
    int? permission,
    int? expiresAt,
    String? inviter,
    String? invitee,
    String? inviterRawData,
    String? inviteeRawData,
    String? inviterSignature,
    String? inviteeSignature,
  }) {
    if (groupId == null || groupId.isEmpty) return null;
    return PrivateGroupItemSchema(
      groupId: groupId,
      permission: permission ?? PrivateGroupItemPerm.none,
      expiresAt: expiresAt,
      inviter: inviter,
      invitee: invitee,
      inviterRawData: inviterRawData,
      inviteeRawData: inviteeRawData,
      inviterSignature: inviterSignature,
      inviteeSignature: inviteeSignature,
    );
  }

  Map<String, dynamic> createRawDataMap() {
    Map<String, dynamic> map = {};
    map['groupId'] = groupId;
    map['permission'] = permission;
    map['expiresAt'] = expiresAt;
    map['inviter'] = inviter;
    map['invitee'] = invitee;
    return map.sortByKey();
  }

  static PrivateGroupItemSchema? fromRawData(Map<String, dynamic>? data, {String? inviterRawData, String? inviteeRawData, String? inviterSignature, String? inviteeSignature}) {
    if (data == null || data.isEmpty || (data['groupId'] == null) || (data['groupId']?.toString().isEmpty == true)) return null;
    var schema = PrivateGroupItemSchema(
      groupId: data['groupId'],
      permission: data['permission'] ?? PrivateGroupItemPerm.none,
      expiresAt: data['expiresAt'],
      inviter: data['inviter'],
      invitee: data['invitee'],
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
      'inviter_raw_data': inviterRawData,
      'invitee_raw_data': inviteeRawData,
      'inviter_signature': inviterSignature,
      'invitee_signature': inviteeSignature,
      'data': jsonEncode(data),
    };
    return map.sortByKey();
  }

  static PrivateGroupItemSchema fromMap(Map<String, dynamic> e) {
    var schema = PrivateGroupItemSchema(
      id: e['id'],
      groupId: e['group_id'] ?? "",
      permission: e['permission'] ?? PrivateGroupItemPerm.none,
      expiresAt: e['expires_at'],
      inviter: e['inviter'],
      invitee: e['invitee'],
      inviterRawData: e['inviter_raw_data'],
      inviteeRawData: e['invitee_raw_data'],
      inviterSignature: e['inviter_signature'],
      inviteeSignature: e['invitee_signature'],
    );
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) schema.data.addAll(data);
    }
    return schema;
  }

  @override
  String toString() {
    return 'PrivateGroupItemSchema{id: $id, groupId: $groupId, permission: $permission, expiresAt: $expiresAt, inviter: $inviter, invitee: $invitee, inviterRawData: $inviterRawData, inviteeRawData: $inviteeRawData, inviterSignature: $inviterSignature, inviteeSignature: $inviteeSignature, data: $data, temp: $temp}';
  }
}
