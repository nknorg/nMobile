import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
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
  Stream<PrivateGroupSchema> get updateGroupStream => _updateGroupController.stream;

  // ignore: close_sinks
  StreamController<PrivateGroupItemSchema> _addGroupItemController = StreamController<PrivateGroupItemSchema>.broadcast();
  StreamSink<PrivateGroupItemSchema> get _addGroupItemSink => _addGroupItemController.sink;
  Stream<PrivateGroupItemSchema> get addGroupItemStream => _addGroupItemController.stream;

  // ignore: close_sinks
  StreamController<PrivateGroupItemSchema> _updateGroupItemController = StreamController<PrivateGroupItemSchema>.broadcast();
  StreamSink<PrivateGroupItemSchema> get _updateGroupItemSink => _updateGroupItemController.sink;
  Stream<PrivateGroupItemSchema> get updateGroupItemStream => _updateGroupItemController.stream; // FUTURE:GG PG used

  ///****************************************** Action *******************************************

  PrivateGroupItemSchema? createInvitationModel(String? groupId, String? invitee, String? inviter, {int? permission, int? expiresMs}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (invitee == null || invitee.isEmpty) return null;
    if (inviter == null || inviter.isEmpty) return null;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    int expiresAt = nowAt + (expiresMs ?? Global.privateGroupInviteExpiresMs);
    PrivateGroupItemSchema? schema = PrivateGroupItemSchema.create(
      groupId,
      permission: permission ?? PrivateGroupItemPerm.normal,
      expiresAt: expiresAt,
      invitee: invitee,
      inviter: inviter,
    );
    if (schema == null) return null;
    schema.inviterRawData = jsonEncode(schema.createRawDataMap());
    return schema;
  }

  Future<PrivateGroupSchema?> createPrivateGroup(String? name, {bool toast = false}) async {
    if (name == null || name.isEmpty) return null;
    String? ownerPublicKey = clientCommon.getPublicKey();
    if (ownerPublicKey == null || ownerPublicKey.isEmpty) return null;
    String groupId = '$ownerPublicKey.${Uuid().v4().replaceAll("-", "")}';
    // group
    PrivateGroupSchema? schemaGroup = PrivateGroupSchema.create(groupId, name);
    if (schemaGroup == null) return null;
    Uint8List? clientSeed = clientCommon.client?.seed;
    if (clientSeed == null) return null;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    String? signatureData = await genSignature(ownerPrivateKey, jsonEncode(schemaGroup.getRawDataMap()));
    if (signatureData == null || signatureData.isEmpty) {
      logger.e('$TAG - createPrivateGroup - group sign create fail. - pk:$ownerPrivateKey - group:$schemaGroup');
      return null;
    }
    schemaGroup.setSignature(signatureData);
    // item
    String? selfAddress = clientCommon.address;
    if (selfAddress == null || selfAddress.isEmpty) return null;
    PrivateGroupItemSchema? schemaItem = createInvitationModel(groupId, selfAddress, selfAddress, permission: PrivateGroupItemPerm.owner);
    if (schemaItem == null) return null;
    schemaItem.inviterSignature = await genSignature(ownerPrivateKey, schemaItem.inviterRawData);
    if ((schemaItem.inviterSignature == null) || (schemaItem.inviterSignature?.isEmpty == true)) {
      logger.e('$TAG - createPrivateGroup - inviter sign create fail. - pk:$ownerPrivateKey - member:$schemaItem');
      return null;
    }
    // accept self
    schemaItem = await acceptInvitation(schemaItem, ownerPrivateKey, toast: toast);
    schemaItem = (await addPrivateGroupItem(schemaItem, true, notify: true)) ?? (await queryGroupItem(groupId, ownerPublicKey));
    if (schemaItem == null) {
      logger.e('$TAG - createPrivateGroup - member create fail. - member:$schemaItem');
      return null;
    }
    // insert
    schemaGroup.version = genPrivateGroupVersion(1, schemaGroup.signature, getInviteesKey([schemaItem]));
    schemaGroup.joined = true;
    schemaGroup.count = 1;
    schemaGroup = await addPrivateGroup(schemaGroup, false, notify: true, checkDuplicated: false);
    return schemaGroup;
  }

  Future<bool> invitee(String? groupId, String? target, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // check
    String? selfAddress = clientCommon.address;
    if ((target == selfAddress) || (selfAddress == null) || selfAddress.isEmpty) {
      logger.e('$TAG - invitee - invitee self. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.invite_yourself_error));
      return false;
    }
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - invitee - has no group. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.group_no_exist));
      return false;
    }
    PrivateGroupItemSchema? inviter = await queryGroupItem(groupId, selfAddress);
    PrivateGroupItemSchema? invitee = await queryGroupItem(groupId, target);
    if ((inviter == null) || (inviter.permission == PrivateGroupItemPerm.none)) {
      logger.e('$TAG - invitee - me no inviter. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.contact_invite_group_tip));
      return false;
    } else if ((invitee != null) && (invitee.permission != PrivateGroupItemPerm.none)) {
      logger.d('$TAG - invitee - Invitee already exists.');
      if (toast) Toast.show(Global.locale((s) => s.invitee_already_exists));
      return false;
    }
    if (isAdmin(schemaGroup, inviter)) {
      if (isOwner(schemaGroup.ownerPublicKey, inviter.invitee)) {
        // nothing
      } else {
        logger.d('$TAG - invitee - Invitee no owner.');
        // FUTURE:GG PG admin invitee (send msg to invitee and let owner to receive+sync)
        return false;
      }
    } else {
      logger.d('$TAG - invitee - Invitee no adminer.');
      if (toast) Toast.show(Global.locale((s) => s.no_permission_action));
      return false;
    }
    // action
    if (invitee == null) {
      invitee = createInvitationModel(groupId, target, selfAddress);
    } else {
      invitee.permission = PrivateGroupItemPerm.normal;
      invitee.expiresAt = DateTime.now().millisecondsSinceEpoch + Global.privateGroupInviteExpiresMs;
      invitee.inviterRawData = jsonEncode(invitee.createRawDataMap());
    }
    if (invitee == null) return false;
    Uint8List? clientSeed = clientCommon.client?.seed;
    if (clientSeed == null) return false;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    invitee.inviterSignature = await genSignature(ownerPrivateKey, invitee.inviterRawData);
    if ((invitee.inviterSignature == null) || (invitee.inviterSignature?.isEmpty == true)) return false;
    chatOutCommon.sendPrivateGroupInvitee(target, schemaGroup, invitee); // await
    return true;
  }

  Future<PrivateGroupItemSchema?> acceptInvitation(PrivateGroupItemSchema? schema, Uint8List? privateKey, {bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty || privateKey == null) return null;
    // duplicated
    PrivateGroupItemSchema? itemExists = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExists != null) && (itemExists.permission != PrivateGroupItemPerm.none)) {
      logger.w('$TAG - acceptInvitation - already in group - exists:$itemExists');
      if (toast) Toast.show(Global.locale((s) => s.accepted_already));
      return null;
    }
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - acceptInvitation - expiresAt check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      if (toast) Toast.show(Global.locale((s) => s.invitation_has_expired));
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true)) {
      logger.e('$TAG - acceptInvitation - inviter incomplete data - schema:$schema');
      if (toast) Toast.show(Global.locale((s) => s.invitation_information_error));
      return null;
    }
    bool verifiedInviter = await verifiedSignature(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    if (!verifiedInviter) {
      logger.e('$TAG - acceptInvitation - signature verification failed.');
      if (toast) Toast.show(Global.locale((s) => s.invitation_signature_error));
      return null;
    }
    // set
    schema.inviteeRawData = jsonEncode(schema.createRawDataMap());
    schema.inviteeSignature = await genSignature(privateKey, schema.inviteeRawData);
    if ((schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) return null;
    return schema;
  }

  Future<PrivateGroupSchema?> insertInvitee(PrivateGroupItemSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - insertInvitee - time check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - insertInvitee - inviter incomplete data - schema:$schema');
      return null;
    }
    bool verifiedInviter = await verifiedSignature(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    bool verifiedInvitee = await verifiedSignature(schema.invitee, schema.inviteeRawData, schema.inviteeSignature);
    if (!verifiedInviter || !verifiedInvitee) {
      logger.e('$TAG - insertInvitee - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
      return null;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - insertInvitee - has no group. - groupId:${schema.groupId}');
      return null;
    }
    PrivateGroupItemSchema? itemExist = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExist != null) && (itemExist.permission != PrivateGroupItemPerm.none)) {
      logger.w('$TAG - insertInvitee - invitee is exist.');
      return null;
    }
    // member
    if (itemExist == null) {
      schema = await addPrivateGroupItem(schema, true, notify: true, checkDuplicated: false);
    } else {
      bool success = await updateGroupItemPermission(schema, true, notify: true);
      if (!success) schema = null;
    }
    if (schema == null) {
      logger.e('$TAG - insertInvitee - member create fail. - member:$schema');
      return null;
    }
    // members
    List<PrivateGroupItemSchema> members = await getMembersAll(schema.groupId);
    members.add(schema);
    // group
    List<String> splits = schemaGroup.version?.split(".") ?? [];
    int commits = (splits.length >= 2 ? (int.tryParse(splits[0]) ?? 0) : 0) + 1;
    schemaGroup.version = genPrivateGroupVersion(commits, schemaGroup.signature, getInviteesKey(members));
    schemaGroup.count = members.length;
    bool success = await updateGroupVersionCount(schema.groupId, schemaGroup.version, schemaGroup.count ?? 0, notify: true);
    return success ? schemaGroup : null;
  }

  // TODO:GG PG caller
  Future<bool> kickOut(String? groupId, String? target, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // check
    String? selfAddress = clientCommon.address;
    if ((target == selfAddress) || (selfAddress == null) || selfAddress.isEmpty) {
      logger.w('$TAG - kickOut - kickOut self. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.kick_yourself_error));
      return false;
    }
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - kickOut - has no group. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.group_no_exist));
      return false;
    }
    PrivateGroupItemSchema? adminer = await queryGroupItem(groupId, selfAddress);
    PrivateGroupItemSchema? blacker = await queryGroupItem(groupId, target);
    if ((adminer == null) || (adminer.permission == PrivateGroupItemPerm.none)) {
      logger.w('$TAG - kickOut - me no adminer. - groupId:$groupId');
      if (toast) Toast.show(Global.locale((s) => s.contact_invite_group_tip));
      return false;
    } else if ((blacker == null) || (blacker.permission == PrivateGroupItemPerm.none)) {
      logger.d('$TAG - kickOut - Member already no exists.');
      if (toast) Toast.show(Global.locale((s) => s.member_already_no_permission));
      return false;
    }
    if (isAdmin(schemaGroup, adminer)) {
      if (isOwner(schemaGroup.ownerPublicKey, adminer.invitee)) {
        // nothing
      } else {
        logger.d('$TAG - kickOut - kickOut no owner.');
        // FUTURE:GG PG admin kickOut (send msg to kickOut and let owner to receive+sync)
        return false;
      }
    } else {
      logger.d('$TAG - kickOut - kickOut no adminer.');
      if (toast) Toast.show(Global.locale((s) => s.no_permission_action));
      return false;
    }
    // action
    Uint8List? clientSeed = clientCommon.client?.seed;
    if (clientSeed == null) return false;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    blacker.permission = PrivateGroupItemPerm.none;
    blacker.expiresAt = 0;
    blacker.inviterRawData = jsonEncode(blacker.createRawDataMap());
    blacker.inviteeRawData = "";
    blacker.inviterSignature = await genSignature(ownerPrivateKey, blacker.inviterRawData);
    blacker.inviteeSignature = "";
    if ((blacker.inviterSignature == null) || (blacker.inviterSignature?.isEmpty == true)) return false;
    bool success = await updateGroupItemPermission(blacker, true, notify: true);
    if (!success) {
      logger.e('$TAG - kickOut - kickOut member sql fail.');
      return false;
    }
    // members
    List<PrivateGroupItemSchema> members = await getMembersAll(schemaGroup.groupId);
    members.add(blacker);
    List<String> memberKeys = getInviteesKey(members);
    // group
    List<String> splits = schemaGroup.version?.split(".") ?? [];
    int commits = (splits.length >= 2 ? (int.tryParse(splits[0]) ?? 0) : 0) + 1;
    schemaGroup.version = genPrivateGroupVersion(commits, schemaGroup.signature, memberKeys);
    schemaGroup.count = members.length;
    success = await updateGroupVersionCount(schemaGroup.groupId, schemaGroup.version, schemaGroup.count ?? 0, notify: true);
    if (!success) {
      logger.e('$TAG - kickOut - kickOut group sql fail.');
      return false;
    }
    // sync members
    members.forEach((m) {
      if (m.invitee != selfAddress) {
        chatOutCommon.sendPrivateGroupMemberResponse(m.invitee, schemaGroup, [blacker]).then((value) {
          chatOutCommon.sendPrivateGroupOptionResponse(m.invitee, schemaGroup, memberKeys); // await
        });
      }
    });
    return true;
  }

  ///****************************************** Sync *******************************************

  Future<bool> pushPrivateGroupOptions(String? target, String? groupId, String? remoteVersion, {bool force = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // group
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    // item
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if ((privateGroupItem == null) || (privateGroupItem.permission == PrivateGroupItemPerm.none)) {
      logger.e('$TAG - pushPrivateGroupOptions - request is not in group.');
      return false;
    }
    // version
    if (!force && (remoteVersion != null) && remoteVersion.isNotEmpty) {
      bool? versionOk = await verifiedGroupVersion(privateGroup, remoteVersion, signVersion: true);
      if (versionOk == true) {
        logger.d('$TAG - pushPrivateGroupOptions - version same - version:$remoteVersion');
        return false;
      }
    }
    // send
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    chatOutCommon.sendPrivateGroupOptionResponse(target, privateGroup, getInviteesKey(members)); // await
    return true;
  }

  Future<PrivateGroupSchema?> updatePrivateGroupOptions(String? groupId, String? rawData, String? version, String? members, String? signature) async {
    if (groupId == null || groupId.isEmpty) return null;
    if (rawData == null || rawData.isEmpty) return null;
    if (version == null || version.isEmpty) return null;
    if (members == null || members.isEmpty) return null;
    if (signature == null || signature.isEmpty) return null;
    // verified
    String ownerPubKey = getOwnerPublicKey(groupId);
    bool verifiedGroup = await verifiedSignature(ownerPubKey, rawData, signature);
    if (!verifiedGroup) {
      logger.e('$TAG - updatePrivateGroupOptions - signature verification failed.');
      return null;
    }
    // data
    Map infos = Util.jsonFormatMap(rawData) ?? Map();
    List membersKeys = Util.jsonFormatList(members) ?? [];
    int membersCount = 0;
    membersKeys.forEach((element) {
      List<String> splits = element?.toString().split("_") ?? [];
      if (splits.length >= 2) {
        int permission = int.tryParse(splits[0]) ?? PrivateGroupItemPerm.none;
        if (permission != PrivateGroupItemPerm.none) {
          membersCount++;
        }
      }
    });
    // check
    PrivateGroupSchema? exists = await queryGroup(groupId);
    if (exists == null) {
      PrivateGroupSchema? _newGroup = PrivateGroupSchema.create(groupId, infos['name'], type: infos['type']);
      if (_newGroup == null) return null;
      _newGroup.version = version;
      _newGroup.count = membersCount;
      _newGroup.options = OptionsSchema(deleteAfterSeconds: int.tryParse(infos['deleteAfterSeconds']?.toString() ?? ""));
      _newGroup.setSignature(signature);
      exists = await addPrivateGroup(_newGroup, true, notify: true, checkDuplicated: false);
      logger.i('$TAG - updatePrivateGroupOptions - group create - group:$exists');
    } else {
      List<String> splitsNative = exists.version?.split(".") ?? [];
      int nativeVersionCommits = (splitsNative.length >= 2) ? (int.tryParse(splitsNative[0]) ?? 0) : 0;
      List<String> splitsRemote = version.split(".");
      int remoteVersionCommits = (splitsRemote.length >= 2) ? (int.tryParse(splitsRemote[0]) ?? 0) : 0;
      if (nativeVersionCommits < remoteVersionCommits) {
        bool verifiedGroup = await verifiedSignature(exists.ownerPublicKey, jsonEncode(exists.getRawDataMap()), exists.signature);
        if (!verifiedGroup) {
          String? name = infos['name'];
          int? type = int.tryParse(infos['type']?.toString() ?? "");
          int? deleteAfterSeconds = int.tryParse(infos['deleteAfterSeconds']?.toString() ?? "");
          if ((name != exists.name) || (type != exists.type)) {
            exists.name = name ?? exists.name;
            exists.type = type ?? exists.type;
            await updateGroupNameType(groupId, exists.name, exists.type, notify: true);
          }
          if (deleteAfterSeconds != exists.options?.deleteAfterSeconds) {
            if (exists.options == null) exists.options = OptionsSchema();
            exists.options?.deleteAfterSeconds = deleteAfterSeconds;
            await updateGroupOptions(groupId, exists.options);
          }
          if (signature != exists.signature) {
            exists.setSignature(signature);
            await updateGroupData(groupId, exists.data, notify: true);
          }
        }
        if ((version != exists.version) || (membersCount != exists.count)) {
          exists.version = version;
          exists.count = membersCount;
          await updateGroupVersionCount(groupId, version, membersCount, notify: true);
        }
        logger.i('$TAG - updatePrivateGroupOptions - group modify - group:$exists');
      } else {
        logger.d('$TAG - updatePrivateGroupOptions - group version same - remote_version:$version - exists:$exists');
      }
    }
    return exists;
  }

  Future<bool> pushPrivateGroupMembers(String? target, String? groupId, String? remoteVersion, {bool force = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // group
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    // item
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if ((privateGroupItem == null) || (privateGroupItem.permission == PrivateGroupItemPerm.none)) {
      logger.e('$TAG - pushPrivateGroupMembers - request is not in group.');
      return false;
    }
    // version
    if (!force && (remoteVersion != null) && remoteVersion.isNotEmpty) {
      bool? versionOk = await verifiedGroupVersion(privateGroup, remoteVersion, signVersion: true);
      if (versionOk == true) {
        logger.d('$TAG - pushPrivateGroupOptions - version same - version:$remoteVersion');
        return false;
      }
    }
    // send
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    for (int i = 0; i < members.length; i += 10) {
      List<PrivateGroupItemSchema> memberSplits = members.skip(i).take(10).toList();
      chatOutCommon.sendPrivateGroupMemberResponse(target, privateGroup, memberSplits); // await
    }
    return true;
  }

  Future<PrivateGroupSchema?> updatePrivateGroupMembers(String? selfAddress, String? sender, String? groupId, String? remoteVersion, List<PrivateGroupItemSchema>? newMembers) async {
    if (sender == null || sender.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    if (remoteVersion == null || remoteVersion.isEmpty) return null;
    if (newMembers == null || newMembers.isEmpty) return null;
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - updatePrivateGroupMembers - has no group. - groupId:$groupId');
      return null;
    }
    // version (can not gen version because members just not all, just check commits(version))
    List<String> splitsNative = schemaGroup.version?.split(".") ?? [];
    int nativeVersionCommits = (splitsNative.length >= 2) ? (int.tryParse(splitsNative[0]) ?? 0) : 0;
    List<String> splitsRemote = remoteVersion.split(".");
    int remoteVersionCommits = (splitsRemote.length >= 2) ? (int.tryParse(splitsRemote[0]) ?? 0) : 0;
    if (nativeVersionCommits > remoteVersionCommits) {
      logger.d('$TAG - updatePrivateGroupMembers - sender version lower. - remote_version:$remoteVersion - exists:$schemaGroup');
      return null;
    }
    // sender (can not believe sender perm because native members maybe empty)
    PrivateGroupItemSchema? groupItem = await queryGroupItem(groupId, sender);
    if (groupItem == null) {
      if (isOwner(schemaGroup.ownerPublicKey, sender)) {
        // nothing
      } else {
        logger.w('$TAG - updatePrivateGroupMembers - sender no owner. - group:$schemaGroup - item:$groupItem');
        return null;
      }
    } else if (isOwner(schemaGroup.ownerPublicKey, selfAddress)) {
      logger.d('$TAG - updatePrivateGroupMembers - self is owner. - group:$schemaGroup - item:$groupItem');
      return null;
    } else if (groupItem.permission == PrivateGroupItemPerm.none) {
      logger.w('$TAG - updatePrivateGroupMembers - sender no permission. - group:$schemaGroup - item:$groupItem');
      return null;
    }
    // members
    int selfJoined = 0;
    for (int i = 0; i < newMembers.length; i++) {
      PrivateGroupItemSchema member = newMembers[i];
      if (member.groupId != groupId) {
        logger.e('$TAG - updatePrivateGroupMembers - groupId incomplete data. - i$i - member:$member');
        continue;
      }
      if ((member.invitee == null) || (member.invitee?.isEmpty == true) || (member.inviter == null) || (member.inviter?.isEmpty == true) || (member.inviterRawData == null) || (member.inviterRawData?.isEmpty == true) || (member.inviteeRawData == null) || (member.inviteeRawData?.isEmpty == true) || (member.inviterSignature == null) || (member.inviterSignature?.isEmpty == true) || (member.inviteeSignature == null) || (member.inviteeSignature?.isEmpty == true)) {
        logger.e('$TAG - updatePrivateGroupMembers - inviter incomplete data - i$i - member:$member');
        continue;
      }
      bool verifiedInviter = await verifiedSignature(member.inviter, member.inviterRawData, member.inviterSignature);
      bool verifiedInvitee = await verifiedSignature(member.invitee, member.inviteeRawData, member.inviteeSignature);
      if (!verifiedInviter || !verifiedInvitee) {
        logger.e('$TAG - updatePrivateGroupMembers - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
        continue;
      }
      PrivateGroupItemSchema? exists = await queryGroupItem(groupId, member.invitee);
      if (exists == null) {
        exists = await addPrivateGroupItem(member, true, notify: true, checkDuplicated: false);
        logger.i('$TAG - updatePrivateGroupMembers - add item - i$i - member:$exists');
      } else if (exists.permission != member.permission) {
        bool success = await updateGroupItemPermission(member, true, notify: true);
        if (success) exists.permission = member.permission;
      }
      if ((member.invitee?.isNotEmpty == true) && (member.invitee == selfAddress)) {
        selfJoined = (member.permission == PrivateGroupItemPerm.none) ? -1 : 1;
      }
    }
    // joined
    if (!schemaGroup.joined && (selfJoined == 1)) {
      schemaGroup.joined = true;
      bool success = await updateGroupJoined(groupId, true, notify: true);
      if (!success) schemaGroup.joined = false;
    } else if (schemaGroup.joined && selfJoined == -1) {
      schemaGroup.joined = false;
      bool success = await updateGroupJoined(groupId, false, notify: true);
      if (!success) schemaGroup.joined = true;
    }
    return schemaGroup;
  }

  ///****************************************** Common *******************************************

  String getOwnerPublicKey(String groupId) {
    String owner;
    int index = groupId.lastIndexOf('.');
    owner = groupId.substring(0, index);
    return owner;
  }

  bool isOwner(String? ownerAddress, String? itemAddress) {
    if (ownerAddress == null || ownerAddress.isEmpty) return false;
    if (itemAddress == null || itemAddress.isEmpty) return false;
    String? ownerPubKey = getPubKeyFromTopicOrChatId(ownerAddress);
    String? itemPubKey = getPubKeyFromTopicOrChatId(itemAddress);
    return (ownerPubKey?.isNotEmpty == true) && (ownerPubKey == itemPubKey);
  }

  bool isAdmin(PrivateGroupSchema? group, PrivateGroupItemSchema? item) {
    if (group == null) return false;
    if (item == null) return false;
    if (group.type == PrivateGroupType.normal) {
      return item.permission == PrivateGroupItemPerm.owner; // || item.permission == PrivateGroupItemPerm.admin
    }
    return false;
  }

  Future<String?> genSignature(Uint8List? privateKey, String? rawData) async {
    if (privateKey == null || rawData == null || rawData.isEmpty) return null;
    Uint8List signRawData = Uint8List.fromList(Hash.sha256(rawData));
    Uint8List signData = await Crypto.sign(privateKey, signRawData);
    return hexEncode(signData);
  }

  Future<bool> verifiedSignature(String? publicKey, String? rawData, String? signature) async {
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

  String genPrivateGroupVersion(int commits, String optionSignature, List<String> memberKeys) {
    memberKeys.sort((a, b) => a.compareTo(b));
    return "$commits.${hexEncode(Uint8List.fromList(Hash.md5(optionSignature + memberKeys.join(''))))}";
  }

  Future<bool?> verifiedGroupVersion(PrivateGroupSchema? privateGroup, String? checkedVersion, {bool signVersion = false}) async {
    if (privateGroup == null) return null;
    if (checkedVersion == null || checkedVersion.isEmpty) return false;
    String? nativeVersion = privateGroup.version;
    if (nativeVersion == null || nativeVersion.isEmpty) return false;
    if (signVersion) {
      List<String> splits = nativeVersion.split(".");
      int commits = splits.length >= 2 ? (int.tryParse(splits[0]) ?? -1) : -1;
      List<PrivateGroupItemSchema> members = await getMembersAll(privateGroup.groupId);
      String signVersion = genPrivateGroupVersion(commits, privateGroup.signature, getInviteesKey(members));
      return signVersion.isNotEmpty && (checkedVersion == nativeVersion) && (nativeVersion == signVersion);
    }
    return checkedVersion == nativeVersion;
  }

  List<String> getInviteesKey(List<PrivateGroupItemSchema> list) {
    List<String> ids = list.map((e) => (e.invitee?.isNotEmpty == true) ? "${e.permission}_${e.invitee}" : "").toList();
    ids.removeWhere((element) => element.isEmpty == true);
    ids.sort((a, b) => (a).compareTo(b));
    return ids;
  }

  List<Map<String, dynamic>> getMembersData(List<PrivateGroupItemSchema> list) {
    list.removeWhere((element) => element.invitee?.isEmpty == true);
    list.sort((a, b) => (a.invitee ?? "").compareTo(b.invitee ?? ""));
    List<Map<String, dynamic>> members = List.empty(growable: true);
    list.forEach((e) => members.add(e.toMap()
      ..remove('id')
      ..remove('data')));
    return members;
  }

  ///****************************************** Storage *******************************************

  Future<PrivateGroupSchema?> addPrivateGroup(PrivateGroupSchema? schema, bool sessionNotify, {bool notify = false, bool checkDuplicated = true}) async {
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
    // session
    if (sessionNotify) await sessionCommon.set(schema.groupId, SessionType.PRIVATE_GROUP, notify: true);
    return added;
  }

  Future<bool> updateGroupNameType(String? groupId, String? name, int? type, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateNameType(groupId, name, type);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupJoined(String? groupId, bool joined, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateJoined(groupId, joined);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupVersionCount(String? groupId, String? version, int userCount, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateVersionCount(groupId, version, userCount);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupAvatar(String? groupId, String? avatarLocalPath, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateAvatar(groupId, avatarLocalPath);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupOptions(String? groupId, OptionsSchema? options, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateOptions(groupId, options?.toMap());
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> updateGroupData(String? groupId, Map<String, dynamic>? data, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateData(groupId, data);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<PrivateGroupSchema?> queryGroup(String? groupId) async {
    return await PrivateGroupStorage.instance.query(groupId);
  }

  Future<List<PrivateGroupSchema>> queryGroupListJoined({int? type, String? orderBy, int offset = 0, int limit = 20}) {
    return PrivateGroupStorage.instance.queryListJoined(type: type, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<PrivateGroupItemSchema?> addPrivateGroupItem(PrivateGroupItemSchema? schema, bool sessionNotify, {bool notify = false, bool checkDuplicated = true}) async {
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
    // session
    if (sessionNotify) {
      MessageSchema? message = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: schema.invitee ?? "",
        groupId: schema.groupId,
        contentType: MessageContentType.privateGroupSubscribe,
        content: schema.invitee,
      );
      message.isOutbound = message.from == clientCommon.address;
      message.status = MessageStatus.Read;
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      message.receiveAt = DateTime.now().millisecondsSinceEpoch;
      message = await chatOutCommon.insertMessage(message, notify: true);
      if (message != null) await chatCommon.sessionHandle(message);
    }
    return added;
  }

  Future<PrivateGroupItemSchema?> queryGroupItem(String? groupId, String? invitee) async {
    return await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
  }

  Future<List<PrivateGroupItemSchema>> queryMembers(String? groupId, {int? perm, int offset = 0, int limit = 20}) async {
    return await PrivateGroupItemStorage.instance.queryList(groupId, perm: perm, limit: limit, offset: offset);
  }

  Future<List<PrivateGroupItemSchema>> getMembersAll(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return [];
    List<PrivateGroupItemSchema> members = [];
    int limit = 20;
    List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.owner, offset: 0, limit: 1);
    members.addAll(result);
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.admin, offset: offset, limit: limit);
      members.addAll(result);
      logger.d("$TAG - getMembersAll - admin - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.normal, offset: offset, limit: limit);
      members.addAll(result);
      logger.d("$TAG - getMembersAll - normal - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    return members;
  }

  Future<bool> updateGroupItemPermission(PrivateGroupItemSchema? item, bool sessionNotify, {bool notify = false}) async {
    if (item == null || item.groupId.isEmpty) return false;
    bool success = await PrivateGroupItemStorage.instance.updatePermission(
      item.groupId,
      item.invitee,
      item.permission,
      item.expiresAt,
      item.inviterRawData,
      item.inviteeRawData,
      item.inviterSignature,
      item.inviteeSignature,
    );
    if (success && notify) queryAndNotifyGroupItem(item.groupId, item.invitee);
    if (sessionNotify && (item.permission == PrivateGroupItemPerm.normal)) {
      MessageSchema? message = MessageSchema.fromSend(
        msgId: Uuid().v4(),
        from: item.invitee ?? "",
        groupId: item.groupId,
        contentType: MessageContentType.privateGroupSubscribe,
        content: item.invitee,
      );
      message.isOutbound = message.from == clientCommon.address;
      message.status = MessageStatus.Read;
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      message.receiveAt = DateTime.now().millisecondsSinceEpoch;
      message = await chatOutCommon.insertMessage(message, notify: true);
      if (message != null) await chatCommon.sessionHandle(message);
    }
    return success;
  }

  Future queryAndNotifyGroup(String? groupId) async {
    PrivateGroupSchema? updated = await PrivateGroupStorage.instance.query(groupId);
    if (updated != null) {
      _updateGroupSink.add(updated);
    }
  }

  Future queryAndNotifyGroupItem(String? groupId, String? invitee) async {
    PrivateGroupItemSchema? updated = await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
    if (updated != null) {
      _updateGroupItemSink.add(updated);
    }
  }
}
