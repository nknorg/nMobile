import 'package:nmobile/utils/map_extension.dart';

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
      'invite_time': inviteTime?.microsecondsSinceEpoch,
      'invited_time': invitedTime?.microsecondsSinceEpoch,
      'expires_at': expiresAt?.microsecondsSinceEpoch,
    };
    map = map.sortByKey();
    return map;
  }

  static PrivateGroupItemSchema fromRawData(Map<String, dynamic> data) {
    var privateGroupItemSchema = PrivateGroupItemSchema(
      groupId: data['groupId'],
      invitee: data['invitee'],
      inviter: data['inviter'],
      inviteeSignature: data['inviteeSignature'],
      inviterSignature: data['inviterSignature'],
      inviteeRawData: data['inviteeRawData'],
      inviterRawData: data['inviterRawData'],
      inviteTime: data['inviteTime'] != null ? DateTime.fromMicrosecondsSinceEpoch(data['inviteTime']) : null,
      invitedTime: data['invitedTime'] != null ? DateTime.fromMicrosecondsSinceEpoch(data['invitedTime']) : null,
      expiresAt: data['expiresAt'] != null ? DateTime.fromMicrosecondsSinceEpoch(data['expiresAt']) : null,
    );

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
      inviteTime: e['invite_time'] != null ? DateTime.fromMicrosecondsSinceEpoch(e['invite_time']) : null,
      invitedTime: e['invited_time'] != null ? DateTime.fromMicrosecondsSinceEpoch(e['invited_time']) : null,
      expiresAt: e['expires_at'] != null ? DateTime.fromMicrosecondsSinceEpoch(e['expires_at']) : null,
    );

    return privateGroupItemSchema;
  }

  @override
  String toString() {
    return 'PrivateGroupItemSchema { id: $id, groupId: $groupId, invitee: $invitee, inviter: $inviter, inviteeSignature: $inviteeSignature, inviterSignature: $inviterSignature, inviteeRawData: $inviteeRawData, inviterRawData: $inviterRawData, inviteTime: $inviteTime, invitedTime: $invitedTime, expiresAt: $expiresAt }';
  }
}
