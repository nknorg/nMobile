import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';
import 'package:uuid/uuid.dart';

class PrivateGroupCommon with Tag {
  // ignore: close_sinks
  StreamController<PrivateGroupSchema> _addGroupController = StreamController<PrivateGroupSchema>.broadcast();
  StreamSink<PrivateGroupSchema> get _addGroupSink => _addGroupController.sink;
  Stream<PrivateGroupSchema> get addGroupStream => _addGroupController.stream;

  // ignore: close_sinks
  StreamController<PrivateGroupSchema> _updateGroupController = StreamController<PrivateGroupSchema>.broadcast();
  StreamSink<PrivateGroupSchema> get _updateGroupSink => _updateGroupController.sink;
  Stream<PrivateGroupSchema> get updateGroupStream => _updateGroupController.stream; // TODO:GG 有的地方用错了?

  // ignore: close_sinks
  StreamController<PrivateGroupItemSchema> _addGroupItemController = StreamController<PrivateGroupItemSchema>.broadcast();
  StreamSink<PrivateGroupItemSchema> get _addGroupItemSink => _addGroupItemController.sink;
  Stream<PrivateGroupItemSchema> get addGroupItemStream => _addGroupItemController.stream;

  static const int EXPIRES_SECONDS = 3600 * 24 * 7; // 7 days TODO:GG move to settings?

  Map<String, bool> dataComplete = Map();

  ///****************************************** Action *******************************************

  // TODO:GG 如果不完整，怎么同步?
  Future<bool> checkDataComplete(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(groupId);
    var version = genPrivateGroupVersion(privateGroup?.signature ?? "", getInviteesId(members));
    if ((version == privateGroup?.version) && (privateGroup?.version != null)) {
      dataComplete[groupId] = true;
      return true;
    }
    dataComplete[groupId] = false;
    return false;
  }

  Future<bool> invitee(String? groupId, String? target, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    if (!await checkDataComplete(groupId)) {
      logger.w('$TAG - invitee - Data synchronization.');
      if (toast) Toast.show(Global.locale((s) => s.data_synchronization));
      return false;
    }
    // check
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - invitee - has no group. - groupId:$groupId');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return false;
    }
    var invitee = await queryGroupItem(groupId, target);
    if (invitee != null) {
      logger.d('$TAG - invitee - Invitee already exists.');
      if (toast) Toast.show(Global.locale((s) => s.invitee_already_exists));
      return false;
    }
    // action
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientCommon.client?.seed ?? Uint8List.fromList([]));
    var inviteeModel = createInvitationModel(groupId, target, clientCommon.getPublicKey());
    if (inviteeModel == null) return false;
    inviteeModel.inviterSignature = await genSignature(ownerPrivateKey, inviteeModel.inviterRawData);
    if ((inviteeModel.inviterSignature == null) || (inviteeModel.inviterSignature?.isEmpty == false)) return false;
    await chatOutCommon.sendPrivateGroupInvitee(target, schemaGroup, inviteeModel);
    return true;
  }

  // TODO:GG 接受邀请?

  Future<bool> toSyncPrivateGroupOptionSync(String? target, String? groupId, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    if (!await checkDataComplete(groupId)) {
      logger.w('$TAG - toSyncPrivateGroupOptionRequest - Data synchronization.');
      if (toast) Toast.show(Global.locale((s) => s.data_synchronization));
      return false;
    }
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(groupId);
    await chatOutCommon.sendPrivateGroupOptionSync(target, privateGroup, getInviteesId(members));
    return true;
  }

  Future<bool> toSyncPrivateGroupMemberKey(String? target, String? groupId, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    if (!await checkDataComplete(groupId)) {
      logger.w('$TAG - toSyncPrivateGroupMemberKey - Data synchronization.');
      if (toast) Toast.show(Global.locale((s) => s.data_synchronization));
      return false;
    }
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(groupId);
    await chatOutCommon.sendPrivateGroupMemberKeyResponse(target, privateGroup, getInviteesId(members));
    return true;
  }

  Future<bool> toSyncPrivateGroupMember(String? target, String? groupId, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    if (!await checkDataComplete(groupId)) {
      logger.w('$TAG - toSyncPrivateGroupMemberKey - Data synchronization.');
      if (toast) Toast.show(Global.locale((s) => s.data_synchronization));
      return false;
    }
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(groupId);
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if (privateGroupItem == null) {
      logger.e('$TAG - toSyncPrivateGroupMember - request is not in group.');
      return false;
    }
    await chatOutCommon.sendPrivateGroupMemberSync(target, privateGroup, members);
    return true;
  }

  ///****************************************** Group *******************************************

  Future<PrivateGroupSchema?> createPrivateGroup(String? name, {bool toast = false}) async {
    if (name == null || name.isEmpty) return null;
    String? ownerPublicKey = clientCommon.getPublicKey();
    if (ownerPublicKey == null || ownerPublicKey.isEmpty) return null;
    String groupId = '$ownerPublicKey.${Uuid().v4()}';
    // group
    PrivateGroupSchema? schemaGroup = PrivateGroupSchema.create(groupId, name);
    if (schemaGroup == null) return null;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientCommon.client?.seed ?? Uint8List.fromList([]));
    String? signatureData = await genSignature(ownerPrivateKey, jsonEncode(schemaGroup.getRawDataMap()));
    if (signatureData == null || signatureData.isEmpty) {
      logger.e('$TAG - createPrivateGroup - group sign create fail. - pk:$ownerPrivateKey - group:$schemaGroup');
      return null;
    }
    schemaGroup.setSignature(signatureData);
    // item
    PrivateGroupItemSchema? schemaItem = createInvitationModel(
      groupId,
      ownerPublicKey,
      ownerPublicKey,
      inviteAt: DateTime.now().millisecondsSinceEpoch,
      expiresSec: EXPIRES_SECONDS,
    );
    if (schemaItem == null) return null;
    schemaItem.inviterSignature = await genSignature(ownerPrivateKey, schemaItem.inviterRawData);
    if ((schemaItem.inviterSignature == null) || (schemaItem.inviterSignature?.isEmpty == true)) {
      logger.e('$TAG - createPrivateGroup - inviter sign create fail. - pk:$ownerPrivateKey - member:$schemaItem');
      return null;
    }
    // accept self
    schemaItem = await acceptInvitation(schemaItem, ownerPrivateKey, toast: toast);
    schemaItem = (await addPrivateGroupItem(schemaItem)) ?? (await queryGroupItem(groupId, ownerPublicKey));
    if (schemaItem == null) {
      logger.e('$TAG - createPrivateGroup - member create fail. - member:$schemaItem');
      return null;
    }
    // update
    schemaGroup.count = 1;
    schemaGroup.version = genPrivateGroupVersion(schemaGroup.signature, [schemaGroup.ownerPublicKey]);
    schemaGroup = await addPrivateGroup(schemaGroup, notify: true);
    return schemaGroup;
  }

  Future<PrivateGroupSchema?> addInvitee(PrivateGroupItemSchema? schema, {bool notify = false, bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int invitedAt = schema.invitedAt ?? DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < invitedAt)) {
      logger.w('$TAG - addInvitee - time check fail - expiresAt:$expiresAt - invitedAt:$invitedAt');
      if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - addInvitee - inviter incomplete data - schema:$schema');
      if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
      return null;
    }
    bool verifiedInviter = await verifiedSign(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    bool verifiedInvitee = await verifiedSign(schema.invitee, schema.inviteeRawData, schema.inviteeSignature);
    if (!verifiedInviter || !verifiedInvitee) {
      logger.e('$TAG - addInvitee - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - addInvitee - has no group. - groupId:${schema.groupId}');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return null;
    }
    PrivateGroupItemSchema? schemaGroupItem = await queryGroupItem(schema.groupId, schema.invitee);
    if (schemaGroupItem != null) {
      logger.w('$TAG - addInvitee - invitee is exist.');
      if (toast) Toast.show('invitee is exist.'); // TODO:GG PG 中文?
      return null;
    }
    // members
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(schema.groupId);
    members.add(schema);
    schemaGroupItem = await addPrivateGroupItem(schema, notify: true, checkDuplicated: false);
    if (schemaGroupItem == null) {
      logger.e('$TAG - addInvitee - member create fail. - member:$schemaGroupItem');
      return null;
    }
    // group
    schemaGroup.count = members.length;
    schemaGroup.version = genPrivateGroupVersion(schemaGroup.signature, getInviteesId(members));
    await updateGroupVersionCount(schema.groupId, schemaGroup.version, schemaGroup.count ?? 0, notify: true);
    return schemaGroup;
  }

  Future<PrivateGroupSchema?> syncPrivateGroupInfo(String? groupId, String? version, String? membersIds, String? rawData, String? signature, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    if (version == null || version.isEmpty) return null;
    if (membersIds == null || membersIds.isEmpty) return null;
    if (rawData == null || rawData.isEmpty) return null;
    if (signature == null || signature.isEmpty) return null;
    // verified
    String ownerPubKey = getOwnerPublicKey(groupId);
    bool verifiedOwner = await verifiedSign(ownerPubKey, rawData, signature);
    if (!verifiedOwner) {
      logger.e('$TAG - syncPrivateGroupInfo - signature verification failed.');
      return null;
    }
    Map members = Util.jsonFormat(membersIds) ?? Map();
    Map options = Util.jsonFormat(rawData) ?? Map();
    // check
    PrivateGroupSchema? exists = await queryGroup(groupId);
    if (exists == null) {
      PrivateGroupSchema? _newGroup = PrivateGroupSchema.create(groupId, options['groupName']);
      if (_newGroup == null) return null;
      _newGroup.version = version;
      _newGroup.count = members.length;
      _newGroup.options = OptionsSchema(deleteAfterSeconds: options['deleteAfterSeconds']);
      _newGroup.setSignature(signature);
      exists = await addPrivateGroup(_newGroup, notify: true);
    } else {
      if (members.length < (exists.count ?? 0)) {
        logger.w('$TAG - syncPrivateGroupInfo - members_len <  exists_count - members:$members - exists:$exists');
        return null;
      }
      if (version != exists.version) {
        await updateGroupVersionCount(groupId, version, members.length, notify: true);
      }
      bool verifiedOwner = await verifiedSign(exists.ownerPublicKey, jsonEncode(exists.getRawDataMap()), exists.signature);
      if (!verifiedOwner) {
        exists.name = options['groupName'] ?? exists.name;
        await updateGroupName(groupId, exists.name, notify: true);
        exists.setSignature(signature);
        await updateGroupData(groupId, exists.data, notify: true);
      }
    }
    return exists;
  }

  ///****************************************** Members *******************************************

  PrivateGroupItemSchema? createInvitationModel(String? groupId, String? invitee, String? inviter, {int? inviteAt, int? expiresSec}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (invitee == null || invitee.isEmpty) return null;
    if (inviter == null || inviter.isEmpty) return null;
    inviteAt = inviteAt ?? DateTime.now().millisecondsSinceEpoch;
    int expiresAt = inviteAt + (expiresSec ?? EXPIRES_SECONDS) * 1000;
    PrivateGroupItemSchema? schema = PrivateGroupItemSchema.create(groupId, expiresAt: expiresAt, invitee: invitee, inviter: inviter, inviteAt: inviteAt);
    if (schema == null) return null;
    schema.inviterRawData = jsonEncode(schema.createRawDataMap(false));
    return schema;
  }

  PrivateGroupItemSchema? createInvitationModelFromRawData(String? inviterRawData, {String? inviterSignature}) {
    if (inviterRawData == null || inviterRawData.isEmpty) return null;
    Map<String, dynamic>? map = Util.jsonFormat(inviterRawData) ?? Map();
    return PrivateGroupItemSchema.fromRawData(map, inviterRawData: inviterRawData, inviterSignature: inviterSignature);
  }

  Future<PrivateGroupItemSchema?> acceptInvitation(PrivateGroupItemSchema? schema, Uint8List? privateKey, {bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty || privateKey == null) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - acceptInvitation - expiresAt check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true)) {
      logger.e('$TAG - acceptInvitation - inviter incomplete data - schema:$schema');
      if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
      return null;
    }
    bool verifiedInviter = await verifiedSign(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    if (!verifiedInviter) {
      logger.e('$TAG - acceptInvitation - signature verification failed.');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // set
    schema.invitedAt = nowAt;
    schema.inviteeRawData = jsonEncode(schema.createRawDataMap(true));
    schema.inviteeSignature = await genSignature(privateKey, schema.inviteeRawData);
    if ((schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) return null;
    return schema;
  }

  Future<List<PrivateGroupItemSchema>?> syncPrivateGroupMember(String? syncGroupId, String? syncVersion, List<PrivateGroupItemSchema>? syncMembers, {bool toast = false}) async {
    if (syncGroupId == null || syncGroupId.isEmpty) return null;
    if (syncVersion == null || syncVersion.isEmpty) return null;
    if (syncMembers == null || syncMembers.isEmpty) return null;
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(syncGroupId);
    if (schemaGroup == null) {
      logger.e('$TAG - syncPrivateGroupMember - has no group. - groupId:$syncGroupId');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return null;
    }
    // members
    for (int i = 0; i < syncMembers.length; i++) {
      PrivateGroupItemSchema member = syncMembers[i];
      logger.d('$TAG - syncPrivateGroupMember - for_each - i$i - member:$member');
      if (member.groupId != syncGroupId) {
        logger.e('$TAG - syncPrivateGroupMember - groupId incomplete data. - i$i - member:$member');
        if (toast) Toast.show('groupId incomplete data.'); // TODO:GG PG 中文?
        continue;
      }
      int? expiresAt = member.expiresAt;
      int invitedAt = member.invitedAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((expiresAt == null) || (expiresAt < invitedAt)) {
        logger.w('$TAG - syncPrivateGroupMember - time check fail - expiresAt:$expiresAt - invitedAt:$invitedAt');
        if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
        continue;
      }
      if ((member.invitee == null) || (member.invitee?.isEmpty == true) || (member.inviter == null) || (member.inviter?.isEmpty == true) || (member.inviterRawData == null) || (member.inviterRawData?.isEmpty == true) || (member.inviteeRawData == null) || (member.inviteeRawData?.isEmpty == true) || (member.inviterSignature == null) || (member.inviterSignature?.isEmpty == true) || (member.inviteeSignature == null) || (member.inviteeSignature?.isEmpty == true)) {
        logger.e('$TAG - syncPrivateGroupMember - inviter incomplete data - i$i - member:$member');
        if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
        continue;
      }
      bool verifiedInviter = await verifiedSign(member.inviter, member.inviterRawData, member.inviterSignature);
      bool verifiedInvitee = await verifiedSign(member.invitee, member.inviteeRawData, member.inviteeSignature);
      if (!verifiedInviter || !verifiedInvitee) {
        logger.e('$TAG - syncPrivateGroupMember - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
        if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
        continue;
      }
      PrivateGroupItemSchema? exists = await queryGroupItem(syncGroupId, member.invitee);
      if (exists == null) {
        exists = await addPrivateGroupItem(member, notify: true, checkDuplicated: false);
      }
    }
    // members
    List<PrivateGroupItemSchema> members = await getMembersByGroupId(syncGroupId);
    // session
    var version = genPrivateGroupVersion(schemaGroup.signature, getInviteesId(members));
    if (version == syncVersion) {
      var session = await SessionStorage.instance.query(syncGroupId, SessionType.PRIVATE_GROUP);
      if (session == null) await chatOutCommon.sendPrivateGroupSubscribe(syncGroupId);
    }
    return members;
  }

  ///****************************************** Common *******************************************

  String getOwnerPublicKey(String groupId) {
    String owner;
    int index = groupId.lastIndexOf('.');
    owner = groupId.substring(0, index);
    return owner;
  }

  Future<bool> verifiedSign(String? publicKey, String? rawData, String? signature) async {
    if (publicKey == null || publicKey.isEmpty) return false;
    if (rawData == null || rawData.isEmpty) return false;
    if (signature == null || signature.isEmpty) return false;
    try {
      Uint8List pubKey = hexDecode(publicKey);
      Uint8List data = Uint8List.fromList(Hash.sha256(rawData));
      Uint8List sign = hexDecode(signature);
      return await Crypto.verify(pubKey, data, sign);
    } catch (e) {
      return false;
    }
  }

  Future<String?> genSignature(Uint8List? privateKey, String? rawData) async {
    if (privateKey == null || rawData == null || rawData.isEmpty) return null;
    Uint8List signRawData = Uint8List.fromList(Hash.sha256(rawData));
    Uint8List signData = await Crypto.sign(privateKey, signRawData);
    return hexEncode(signData);
  }

  String genPrivateGroupVersion(String optionSignature, List<String> memberPks) {
    memberPks.sort((a, b) => a.compareTo(b));
    return hexEncode(Uint8List.fromList(Hash.md5(optionSignature + memberPks.join(''))));
  }

  List<Map<String, dynamic>> getMembersData(List<PrivateGroupItemSchema> list) {
    List<Map<String, dynamic>> members = List.empty(growable: true);
    list
      ..sort((a, b) => (a.invitee ?? "").compareTo(b.invitee ?? ""))
      ..forEach((e) => members.add(e.toMap()..remove('id')));
    return members;
  }

  List<String> getInviteesId(List<PrivateGroupItemSchema> list) {
    List<String> ids = list.map((e) => e.invitee ?? "").toList();
    ids.removeWhere((element) => element.isEmpty);
    return ids;
  }

  ///****************************************** Storage *******************************************

  Future<PrivateGroupSchema?> addPrivateGroup(PrivateGroupSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    if (checkDuplicated) {
      PrivateGroupSchema? exist = await queryGroup(schema.groupId);
      if (exist != null) {
        logger.i("$TAG - addPrivateGroup - duplicated - schema:$exist");
        return null;
      }
    }
    PrivateGroupSchema? added = await PrivateGroupStorage.instance.insert(schema);
    if (added != null && notify) _addGroupSink.add(added);
    return added;
  }

  Future<bool> updateGroupName(String? groupId, String? name, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateName(groupId, name);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupAvatar(String? groupId, String? avatarLocalPath, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateAvatar(groupId, avatarLocalPath);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupVersionCount(String? groupId, String? version, int userCount, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateVersionCount(groupId, version, userCount);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupData(String? groupId, Map<String, dynamic>? data, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateData(groupId, data);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<PrivateGroupSchema?> queryGroup(String groupId) async {
    return await PrivateGroupStorage.instance.query(groupId);
  }

  Future<PrivateGroupItemSchema?> addPrivateGroupItem(PrivateGroupItemSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    if (checkDuplicated) {
      PrivateGroupItemSchema? exist = await queryGroupItem(schema.groupId, schema.invitee);
      if (exist != null) {
        logger.i("$TAG - addPrivateGroupItem - duplicated - schema:$exist");
        return null;
      }
    }
    PrivateGroupItemSchema? added = await PrivateGroupItemStorage.instance.insert(schema);
    if (added != null && notify) _addGroupItemSink.add(added);
    return added;
  }

  Future<PrivateGroupItemSchema?> queryGroupItem(String groupId, String? invitee) async {
    return await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
  }

  Future<List<PrivateGroupItemSchema>> queryMembers(String groupId, {int offset = 0, int limit = 20}) async {
    return await PrivateGroupItemStorage.instance.queryList(groupId, limit: limit, offset: offset);
  }

  Future<List<PrivateGroupItemSchema>> getMembersByGroupId(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return [];
    List<PrivateGroupItemSchema> members = [];
    int limit = 20;
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, offset: offset, limit: limit);
      members.addAll(result);
      logger.d("$TAG - getMembersByGroupId - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    return members;
  }

  Future queryAndNotifyGroup(String groupId) async {
    PrivateGroupSchema? updated = await PrivateGroupStorage.instance.query(groupId);
    if (updated != null) {
      _updateGroupSink.add(updated);
    }
  }
}
