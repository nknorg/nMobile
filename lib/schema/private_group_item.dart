import 'package:nmobile/utils/map_extension.dart';

// TODO:GG PG check
class PrivateGroupItemSchema {
  int? id;
  String groupId;
  String? invitee;
  String? inviter;
  String? inviteeSignature;
  String? inviterSignature;
  String? inviteeRawData;
  String? inviterRawData;
  DateTime? inviteTime;
  DateTime? invitedTime;
  DateTime? expiresAt;

  PrivateGroupItemSchema({
    this.id,
    required this.groupId,
    this.invitee,
    this.inviter,
    this.inviteeSignature,
    this.inviterSignature,
    this.inviteeRawData,
    this.inviterRawData,
    this.inviteTime,
    this.invitedTime,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'invitee': invitee,
      'inviter': inviter,
      'invitee_signature': inviteeSignature,
      'inviter_signature': inviterSignature,
      'invitee_raw_data': inviteeRawData,
      'inviter_raw_data': inviterRawData,
      'invite_time': inviteTime?.millisecondsSinceEpoch,
      'invited_time': invitedTime?.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
    };
    map = map.sortByKey();
    return map;
  }

  static PrivateGroupItemSchema fromRawData(
    Map<String, dynamic> data, {
    String? inviterSignature,
    String? inviterRawData,
    String? inviteeSignature,
    String? inviteeRawData,
  }) {
    var privateGroupItemSchema = PrivateGroupItemSchema(
      groupId: data['groupId'],
      invitee: data['invitee'],
      inviter: data['inviter'],
      inviteeSignature: data['inviteeSignature'],
      inviterSignature: data['inviterSignature'],
      inviteeRawData: data['inviteeRawData'],
      inviterRawData: data['inviterRawData'],
      inviteTime: data['inviteTime'] != null ? DateTime.fromMillisecondsSinceEpoch(data['inviteTime']) : null,
      invitedTime: data['invitedTime'] != null ? DateTime.fromMillisecondsSinceEpoch(data['invitedTime']) : null,
      expiresAt: data['expiresAt'] != null ? DateTime.fromMillisecondsSinceEpoch(data['expiresAt']) : null,
    );

    if (inviterSignature != null) privateGroupItemSchema.inviterSignature = inviterSignature;
    if (inviterRawData != null) privateGroupItemSchema.inviterRawData = inviterRawData;
    if (inviteeSignature != null) privateGroupItemSchema.inviteeSignature = inviteeSignature;
    if (inviteeRawData != null) privateGroupItemSchema.inviteeRawData = inviteeRawData;
    return privateGroupItemSchema;
  }

  static PrivateGroupItemSchema fromMap(Map<String, dynamic> e) {
    var privateGroupItemSchema = PrivateGroupItemSchema(
      id: e['id'],
      groupId: e['group_id'],
      invitee: e['invitee'],
      inviter: e['inviter'],
      inviteeSignature: e['invitee_signature'],
      inviterSignature: e['inviter_signature'],
      inviteeRawData: e['invitee_raw_data'],
      inviterRawData: e['inviter_raw_data'],
      inviteTime: e['invite_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['invite_time']) : null,
      invitedTime: e['invited_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['invited_time']) : null,
      expiresAt: e['expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['expires_at']) : null,
    );

    return privateGroupItemSchema;
  }

  @override
  String toString() {
    return 'PrivateGroupItemSchema { id: $id, groupId: $groupId, invitee: $invitee, inviter: $inviter, inviteeSignature: $inviteeSignature, inviterSignature: $inviterSignature, inviteeRawData: $inviteeRawData, inviterRawData: $inviterRawData, inviteTime: $inviteTime, invitedTime: $invitedTime, expiresAt: $expiresAt }';
  }
}
