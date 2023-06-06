import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
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
  Stream<PrivateGroupItemSchema> get updateGroupItemStream => _updateGroupItemController.stream;

  ///****************************************** Member *******************************************

  PrivateGroupItemSchema? createInvitationModel(String? groupId, String? invitee, String? inviter, {int? permission, int? expiresMs}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (invitee == null || invitee.isEmpty) return null;
    if (inviter == null || inviter.isEmpty) return null;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    int expiresAt = nowAt + (expiresMs ?? Settings.timeoutGroupInviteMs);
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
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return null;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    String? signatureData = await genSignature(ownerPrivateKey, jsonEncode(schemaGroup.getRawDataMap()));
    if (signatureData == null || signatureData.isEmpty) {
      logger.e('$TAG - createPrivateGroup - group sign create fail. - pk:$ownerPrivateKey - group:$schemaGroup');
      return null;
    }
    schemaGroup.data['signature'] = signatureData;
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
    schemaItem = await acceptInvitation(schemaItem, inviteePrivateKey: ownerPrivateKey, toast: toast);
    schemaItem = (await addPrivateGroupItem(schemaItem, true, notify: true)) ?? (await queryGroupItem(groupId, ownerPublicKey));
    if (schemaItem == null) {
      logger.e('$TAG - createPrivateGroup - member create fail. - member:$schemaItem');
      return null;
    }
    // insert
    schemaGroup.joined = true;
    schemaGroup.count = 1;
    schemaGroup.data["version"] = genPrivateGroupVersion(1, schemaGroup.signature, [schemaItem]);
    schemaGroup = await addPrivateGroup(schemaGroup, notify: true);
    logger.i('$TAG - createPrivateGroup - success - group:$schemaGroup - owner:$schemaItem');
    return schemaGroup;
  }

  Future<bool> invitee(String? groupId, String? target, {bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // check
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - invitee - has no group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.group_no_exist));
      return false;
    }
    String? selfAddress = clientCommon.address;
    if ((target == selfAddress) || (selfAddress == null) || selfAddress.isEmpty) {
      logger.e('$TAG - invitee - invitee self. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.invite_yourself_error));
      return false;
    }
    PrivateGroupItemSchema? myself = await queryGroupItem(groupId, selfAddress);
    PrivateGroupItemSchema? invitee = await queryGroupItem(groupId, target);
    if ((myself == null) || (myself.permission <= PrivateGroupItemPerm.none)) {
      logger.e('$TAG - invitee - me no in group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.contact_invite_group_tip));
      return false;
    } else if ((invitee != null) && (invitee.permission > PrivateGroupItemPerm.none)) {
      logger.d('$TAG - invitee - Invitee already exists.');
      if (toast) Toast.show(Settings.locale((s) => s.invitee_already_exists));
      return false;
    } else if ((invitee != null) && (invitee.permission == PrivateGroupItemPerm.black)) {
      logger.d('$TAG - invitee - Invitee again black.');
      invitee.permission = PrivateGroupItemPerm.none;
      await updateGroupItemPermission(invitee, false);
    }
    if (isAdmin(schemaGroup, myself)) {
      if (isOwner(schemaGroup.ownerPublicKey, myself.invitee)) {
        // nothing
      } else {
        logger.d('$TAG - invitee - Invitee no owner.');
        // FUTURE:GG PG admin invitee (send msg to invitee and let owner to receive+sync)
        return false;
      }
    } else {
      logger.d('$TAG - invitee - Invitee no adminer.');
      if (toast) Toast.show(Settings.locale((s) => s.no_permission_action));
      return false;
    }
    // action
    if (invitee == null) {
      invitee = createInvitationModel(groupId, target, selfAddress);
      logger.i('$TAG - invitee - new - invitee:$invitee - group:$schemaGroup');
    } else {
      invitee.permission = PrivateGroupItemPerm.normal;
      invitee.expiresAt = DateTime.now().millisecondsSinceEpoch + Settings.timeoutGroupInviteMs;
      invitee.inviterRawData = jsonEncode(invitee.createRawDataMap());
      logger.i('$TAG - invitee - repeat - invitee:$invitee - group:$schemaGroup');
    }
    if (invitee == null) return false;
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return false;
    Uint8List inviterPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    invitee.inviterSignature = await genSignature(inviterPrivateKey, invitee.inviterRawData);
    if ((invitee.inviterSignature == null) || (invitee.inviterSignature?.isEmpty == true)) return false;
    logger.i('$TAG - invitee - success - invitee:$invitee - group:$schemaGroup');
    var result = await chatOutCommon.sendPrivateGroupInvitee(target, schemaGroup, invitee);
    return result != null;
  }

  Future<PrivateGroupItemSchema?> acceptInvitation(PrivateGroupItemSchema? schema, {Uint8List? inviteePrivateKey, bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // duplicated
    PrivateGroupItemSchema? itemExists = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExists != null) && (itemExists.permission > PrivateGroupItemPerm.none)) {
      logger.w('$TAG - acceptInvitation - already in group - exists:$itemExists');
      if (toast) Toast.show(Settings.locale((s) => s.accepted_already));
      return null;
    }
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - acceptInvitation - expiresAt check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      if (toast) Toast.show(Settings.locale((s) => s.invitation_has_expired));
      return null;
    } else if ((schema.permission != PrivateGroupItemPerm.normal) && (schema.permission != PrivateGroupItemPerm.owner)) {
      logger.e('$TAG - acceptInvitation - inviter incomplete permission - schema:$schema');
      if (toast) Toast.show(Settings.locale((s) => s.invitation_information_error));
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true)) {
      logger.e('$TAG - acceptInvitation - inviter incomplete data - schema:$schema');
      if (toast) Toast.show(Settings.locale((s) => s.invitation_information_error));
      return null;
    } else if (schema.inviterRawData != jsonEncode(schema.createRawDataMap())) {
      logger.e('$TAG - acceptInvitation - inviter incomplete raw_data - schema:$schema');
      if (toast) Toast.show(Settings.locale((s) => s.invitation_information_error));
      return null;
    }
    String? inviterPubKey = getPubKeyFromTopicOrChatId(schema.inviter ?? "");
    bool verifiedInviter = await verifiedSignature(inviterPubKey, schema.inviterRawData, schema.inviterSignature);
    if (!verifiedInviter) {
      logger.e('$TAG - acceptInvitation - signature verification failed.');
      if (toast) Toast.show(Settings.locale((s) => s.invitation_signature_error));
      return null;
    }
    // set
    if (inviteePrivateKey == null) {
      Uint8List? clientSeed = clientCommon.getSeed();
      if (clientSeed == null) return null;
      inviteePrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    }
    schema.inviteeRawData = jsonEncode(schema.createRawDataMap());
    schema.inviteeSignature = await genSignature(inviteePrivateKey, schema.inviteeRawData);
    if ((schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) return null;
    logger.i('$TAG - acceptInvitation - success - invitee:$schema');
    return schema;
  }

  Future<PrivateGroupSchema?> onInviteeAccept(PrivateGroupItemSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - onInviteeAccept - time check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      return null;
    } else if (schema.permission != PrivateGroupItemPerm.normal) {
      logger.e('$TAG - onInviteeAccept - inviter incomplete permission - schema:$schema');
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - onInviteeAccept - inviter incomplete data - schema:$schema');
      return null;
    } else if ((schema.inviterRawData != jsonEncode(schema.createRawDataMap())) || (schema.inviteeRawData != jsonEncode(schema.createRawDataMap()))) {
      logger.e('$TAG - onInviteeAccept - inviter incomplete raw_data - schema:$schema');
      return null;
    }
    String? inviterPubKey = getPubKeyFromTopicOrChatId(schema.inviter ?? "");
    bool verifiedInviter = await verifiedSignature(inviterPubKey, schema.inviterRawData, schema.inviterSignature);
    String? inviteePubKey = getPubKeyFromTopicOrChatId(schema.invitee ?? "");
    bool verifiedInvitee = await verifiedSignature(inviteePubKey, schema.inviteeRawData, schema.inviteeSignature);
    if (!verifiedInviter || !verifiedInvitee) {
      logger.e('$TAG - onInviteeAccept - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
      return null;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - onInviteeAccept - has no group. - groupId:${schema.groupId}');
      return null;
    }
    PrivateGroupItemSchema? itemExist = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExist != null) && (itemExist.permission > PrivateGroupItemPerm.none)) {
      logger.i('$TAG - onInviteeAccept - invitee is exist.');
      return schemaGroup;
    } else if ((itemExist != null) && (itemExist.permission == PrivateGroupItemPerm.quit)) {
      if ((expiresAt - Settings.timeoutGroupInviteMs) < (itemExist.expiresAt ?? 0)) {
        logger.i('$TAG - onInviteeAccept - invitee later by quit.');
        return null;
      }
    } else if ((itemExist != null) && (itemExist.permission == PrivateGroupItemPerm.black)) {
      logger.i('$TAG - onInviteeAccept - invitee is black.');
      return null;
    }
    // member
    if (itemExist == null) {
      schema = await addPrivateGroupItem(schema, true, notify: true);
      logger.i('$TAG - onInviteeAccept - new - invitee:$schema - group:$schemaGroup');
    } else {
      bool success = await updateGroupItemPermission(schema, true, notify: true);
      if (!success) schema = null;
      logger.i('$TAG - onInviteeAccept - repeat - invitee:$schema - group:$schemaGroup');
    }
    if (schema == null) {
      logger.e('$TAG - onInviteeAccept - member create fail. - member:$schema');
      return null;
    }
    // group
    int commits = (getPrivateGroupVersionCommits(schemaGroup.version) ?? 0) + 1;
    List<PrivateGroupItemSchema> members = await getMembersAll(schema.groupId);
    schemaGroup.data["version"] = genPrivateGroupVersion(commits, schemaGroup.signature, members);
    var data = await setGroupVersion(schema.groupId, schemaGroup.version);
    if (data == null) {
      logger.e('$TAG - onInviteeAccept - set version fail. - invitee:$schema - group:$schemaGroup');
      return null;
    }
    schemaGroup.count = members.length;
    await setCount(schema.groupId, schemaGroup.count, notify: true);
    logger.i('$TAG - onInviteeAccept - success - invitee:$schema - group:$schemaGroup');
    return schemaGroup;
  }

  Future<bool> quit(String? groupId, {bool toast = false, bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    // check
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - quit - has no group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.group_no_exist));
      return false;
    }
    String? selfAddress = clientCommon.address;
    if ((selfAddress == null) || selfAddress.isEmpty) {
      logger.w('$TAG - quit - groupId:$groupId - selfAddress:$selfAddress');
      return false;
    } else if (isOwner(schemaGroup.ownerPublicKey, selfAddress)) {
      logger.e('$TAG - quit - owner quit deny. - groupId:$groupId');
      return false;
    }
    PrivateGroupItemSchema? myself = await queryGroupItem(groupId, selfAddress);
    if ((myself == null) || (myself.permission <= PrivateGroupItemPerm.none)) {
      logger.d('$TAG - quit - Member already no exists.');
      if (toast) Toast.show(Settings.locale((s) => s.tip_ask_group_owner_permission));
      return false;
    }
    // action
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return false;
    Uint8List inviterPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    myself.permission = PrivateGroupItemPerm.quit;
    myself.expiresAt = DateTime.now().millisecondsSinceEpoch;
    myself.inviterRawData = "";
    myself.inviteeRawData = jsonEncode(myself.createRawDataMap());
    myself.inviterSignature = "";
    myself.inviteeSignature = await genSignature(inviterPrivateKey, myself.inviteeRawData);
    // message
    List<PrivateGroupItemSchema> owners = await queryMembers(groupId, perm: PrivateGroupItemPerm.owner, limit: 1);
    if (owners.length <= 0) return false;
    bool success = await chatOutCommon.sendPrivateGroupQuit(owners[0].inviter, myself);
    if (!success) {
      logger.e('$TAG - quit - quit group join msg fail.');
      return false;
    }
    // native (no item modify to avoid be sync members by different group_version)
    schemaGroup.joined = false;
    await setJoined(groupId, schemaGroup.joined);
    int? quitCommits = getPrivateGroupVersionCommits(schemaGroup.version);
    await setQuitCommits(groupId, quitCommits, notify: notify);
    logger.i('$TAG - quit - success - self:$myself - group:$schemaGroup');
    return true;
  }

  Future<bool> onMemberQuit(PrivateGroupItemSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.groupId.isEmpty) return false;
    // check
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - onMemberQuit - inviter incomplete data - schema:$schema');
      return false;
    } else if ((schema.inviteeRawData != jsonEncode(schema.createRawDataMap()))) {
      logger.e('$TAG - onInviteeAccept - invitee incomplete raw_data - schema:$schema');
      return false;
    } else if (schema.permission != PrivateGroupItemPerm.quit) {
      logger.e('$TAG - onMemberQuit - invitee incomplete permission - schema:$schema');
      return false;
    }
    String? inviteePubKey = getPubKeyFromTopicOrChatId(schema.invitee ?? "");
    bool verifiedInvitee = await verifiedSignature(inviteePubKey, schema.inviteeRawData, schema.inviteeSignature);
    if (!verifiedInvitee) {
      logger.e('$TAG - onMemberQuit - signature verification failed. - verifiedInvitee:$verifiedInvitee');
      return false;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - onMemberQuit - has no group. - groupId:${schema.groupId}');
      return false;
    }
    String? selfAddress = clientCommon.address;
    if ((schema.invitee == selfAddress) || (selfAddress == null) || selfAddress.isEmpty) {
      logger.w('$TAG - onMemberQuit - groupId:${schema.groupId} - target:${schema.invitee}');
      return false;
    }
    PrivateGroupItemSchema? myself = await queryGroupItem(schema.groupId, selfAddress);
    PrivateGroupItemSchema? lefter = await queryGroupItem(schema.groupId, schema.invitee);
    if ((myself == null) || (myself.permission <= PrivateGroupItemPerm.none)) {
      logger.w('$TAG - onMemberQuit - me no in group. - groupId:${schema.groupId}');
      return false;
    } else if ((lefter == null) || (lefter.permission < PrivateGroupItemPerm.none)) {
      logger.d('$TAG - onMemberQuit - Member already no exists.');
      return false;
    }
    if (isAdmin(schemaGroup, myself)) {
      if (isOwner(schemaGroup.ownerPublicKey, myself.invitee)) {
        // nothing
      } else {
        logger.d('$TAG - onMemberQuit - onQuit no owner.');
        // FUTURE:GG PG admin kickOut (send msg to kickOut and let owner to receive+sync)
        return false;
      }
    } else {
      logger.d('$TAG - onMemberQuit - onQuit no adminer.');
      return false;
    }
    // action
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return false;
    Uint8List inviterPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    lefter.permission = PrivateGroupItemPerm.quit;
    lefter.expiresAt = DateTime.now().millisecondsSinceEpoch;
    lefter.inviterRawData = jsonEncode(lefter.createRawDataMap());
    lefter.inviteeRawData = "";
    lefter.inviterSignature = await genSignature(inviterPrivateKey, lefter.inviterRawData);
    lefter.inviteeSignature = "";
    if ((lefter.inviterSignature == null) || (lefter.inviterSignature?.isEmpty == true)) return false;
    bool success = await updateGroupItemPermission(lefter, false, notify: notify);
    if (!success) {
      logger.e('$TAG - onMemberQuit - kickOut member sql fail.');
      return false;
    }
    // group
    int commits = (getPrivateGroupVersionCommits(schemaGroup.version) ?? 0) + 1;
    List<PrivateGroupItemSchema> members = await getMembersAll(schemaGroup.groupId);
    schemaGroup.data["version"] = genPrivateGroupVersion(commits, schemaGroup.signature, members);
    var data = await setGroupVersion(schemaGroup.groupId, schemaGroup.version);
    if (data == null) {
      logger.e('$TAG - onMemberQuit - kickOut group sql fail.');
      return false;
    }
    schemaGroup.count = members.length;
    await setCount(schemaGroup.groupId, schemaGroup.count, notify: notify);
    // sync members
    members.add(lefter);
    members.removeWhere((m) => m.invitee == selfAddress);
    List<String> addressList = members.map((e) => e.invitee ?? "").toList()..removeWhere((element) => element.isEmpty);
    chatOutCommon.sendPrivateGroupMemberResponse(addressList, schemaGroup, [lefter]).then((success) async {
      if (success) {
        success = await chatOutCommon.sendPrivateGroupOptionResponse(addressList, schemaGroup);
        if (success) {
          logger.i('$TAG - onMemberQuit - success - lefter:$lefter - group:$schemaGroup');
        } else {
          logger.w('$TAG - onMemberQuit - sync members member fail - lefter:$lefter - group:$schemaGroup');
        }
      } else if (addressList.isNotEmpty) {
        logger.w('$TAG - onMemberQuit - sync members options fail - lefter:$lefter - group:$schemaGroup');
      }
    }); // await
    return true;
  }

  Future<bool> kickOut(String? groupId, String? target, {bool notify = false, bool toast = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    if (target == null || target.isEmpty) return false;
    // check
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - kickOut - has no group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.group_no_exist));
      return false;
    }
    String? selfAddress = clientCommon.address;
    if ((target == selfAddress) || (selfAddress == null) || selfAddress.isEmpty) {
      logger.w('$TAG - kickOut - kickOut self. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.kick_yourself_error));
      return false;
    }
    PrivateGroupItemSchema? myself = await queryGroupItem(groupId, selfAddress);
    PrivateGroupItemSchema? blacker = await queryGroupItem(groupId, target);
    if ((myself == null) || (myself.permission <= PrivateGroupItemPerm.none)) {
      logger.w('$TAG - kickOut - me no in group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.contact_invite_group_tip));
      return false;
    } else if ((blacker == null) || (blacker.permission <= PrivateGroupItemPerm.none)) {
      logger.d('$TAG - kickOut - Member already no exists.');
      if (toast) Toast.show(Settings.locale((s) => s.member_already_no_permission));
      return false;
    }
    if (isAdmin(schemaGroup, myself)) {
      if (isOwner(schemaGroup.ownerPublicKey, myself.invitee)) {
        // nothing
      } else {
        logger.d('$TAG - kickOut - kickOut no owner.');
        // FUTURE:GG PG admin kickOut (send msg to kickOut and let owner to receive+sync)
        return false;
      }
    } else {
      logger.d('$TAG - kickOut - kickOut no adminer.');
      if (toast) Toast.show(Settings.locale((s) => s.no_permission_action));
      return false;
    }
    // action
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return false;
    Uint8List inviterPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    blacker.permission = PrivateGroupItemPerm.black;
    blacker.expiresAt = DateTime.now().millisecondsSinceEpoch;
    blacker.inviterRawData = jsonEncode(blacker.createRawDataMap());
    blacker.inviteeRawData = "";
    blacker.inviterSignature = await genSignature(inviterPrivateKey, blacker.inviterRawData);
    blacker.inviteeSignature = "";
    if ((blacker.inviterSignature == null) || (blacker.inviterSignature?.isEmpty == true)) return false;
    bool success = await updateGroupItemPermission(blacker, false, notify: notify);
    if (!success) {
      logger.e('$TAG - kickOut - kickOut member sql fail.');
      return false;
    }
    // group
    int commits = (getPrivateGroupVersionCommits(schemaGroup.version) ?? 0) + 1;
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    schemaGroup.data["version"] = genPrivateGroupVersion(commits, schemaGroup.signature, members);
    var data = await setGroupVersion(groupId, schemaGroup.version);
    if (data == null) {
      logger.e('$TAG - kickOut - kickOut group sql fail.');
      return false;
    }
    schemaGroup.count = members.length;
    await setCount(groupId, schemaGroup.count, notify: notify);
    // sync members
    members.add(blacker);
    members.removeWhere((m) => m.invitee == selfAddress);
    List<String> addressList = members.map((e) => e.invitee ?? "").toList()..removeWhere((element) => element.isEmpty);
    success = await chatOutCommon.sendPrivateGroupMemberResponse(addressList, schemaGroup, [blacker]);
    if (success) {
      success = await chatOutCommon.sendPrivateGroupOptionResponse(addressList, schemaGroup);
      if (success) {
        logger.i('$TAG - kickOut - success - lefter:$blacker - group:$schemaGroup');
      } else {
        logger.w('$TAG - kickOut - sync members member fail - lefter:$blacker - group:$schemaGroup');
      }
    } else if (addressList.isNotEmpty) {
      logger.w('$TAG - kickOut - sync members options fail - lefter:$blacker - group:$schemaGroup');
    }
    return success;
  }

  ///****************************************** Action *******************************************

  Future<bool> setOptionsBurning(String? groupId, int? burningSeconds, {bool notify = false, bool toast = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    // check
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - setOptionsBurning - has no group. - groupId:$groupId');
      if (toast) Toast.show(Settings.locale((s) => s.group_no_exist));
      return false;
    }
    String? selfAddress = clientCommon.address;
    if ((selfAddress == null) || selfAddress.isEmpty || !isOwner(schemaGroup.ownerPublicKey, selfAddress)) {
      logger.w('$TAG - setOptionsBurning - no permission.');
      if (toast) Toast.show(Settings.locale((s) => s.only_owner_can_modify));
      return false;
    }
    // delete_sec
    var options = await setGroupOptionsBurn(groupId, burningSeconds, notify: notify);
    if (options == null) {
      logger.e('$TAG - setOptionsBurning - options sql fail.');
      return false;
    }
    schemaGroup.options = options;
    // signature
    Uint8List? clientSeed = clientCommon.getSeed();
    if (clientSeed == null) return false;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    String? signatureData = await genSignature(ownerPrivateKey, jsonEncode(schemaGroup.getRawDataMap()));
    if (signatureData == null || signatureData.isEmpty) {
      logger.e('$TAG - setOptionsBurning - group sign create fail. - pk:$ownerPrivateKey - group:$schemaGroup');
      return false;
    }
    schemaGroup.data["signature"] = signatureData;
    var data = await setGroupSignature(groupId, schemaGroup.signature, notify: true);
    if (data == null) {
      logger.e('$TAG - setOptionsBurning - signature sql fail.');
      return false;
    }
    // version
    int commits = (getPrivateGroupVersionCommits(schemaGroup.version) ?? 0) + 1;
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    schemaGroup.data["version"] = genPrivateGroupVersion(commits, schemaGroup.signature, members);
    data = await setGroupVersion(schemaGroup.groupId, schemaGroup.version, notify: notify);
    if (data == null) {
      logger.e('$TAG - setOptionsBurning - version sql fail.');
      return false;
    }
    logger.i('$TAG - setOptionsBurning - success - options:${schemaGroup.options}');
    // sync members
    members.removeWhere((m) => m.invitee == selfAddress);
    List<String> addressList = members.map((e) => e.invitee ?? "").toList()..removeWhere((element) => element.isEmpty);
    return await chatOutCommon.sendPrivateGroupOptionResponse(addressList, schemaGroup);
  }

  ///****************************************** Sync *******************************************

  Future<bool> pushPrivateGroupOptions(String? target, String? groupId, String? remoteVersion, {bool force = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    // group
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    // version
    if (!force && (remoteVersion != null) && remoteVersion.isNotEmpty) {
      if (privateGroup.version == remoteVersion) {
        logger.d('$TAG - pushPrivateGroupOptions - version same - version:$remoteVersion');
        return false;
      }
    }
    // item
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if (privateGroupItem == null) {
      logger.e('$TAG - pushPrivateGroupOptions - request is not in group.');
      return false;
    } else if (privateGroupItem.permission <= PrivateGroupItemPerm.none) {
      return await pushPrivateGroupMembers(target, groupId, remoteVersion, force: true);
    }
    // send
    return await chatOutCommon.sendPrivateGroupOptionResponse([target], privateGroup);
  }

  Future<PrivateGroupSchema?> updatePrivateGroupOptions(String? groupId, String? rawData, String? version, int? count, String? signature) async {
    if (groupId == null || groupId.isEmpty) return null;
    if (rawData == null || rawData.isEmpty) return null;
    if (version == null || version.isEmpty) return null;
    if (count == null) return null;
    if (signature == null || signature.isEmpty) return null;
    Map infos = Util.jsonFormatMap(rawData) ?? Map();
    // verified
    String ownerPubKey = getOwnerPublicKey(groupId);
    bool verifiedGroup = await verifiedSignature(ownerPubKey, rawData, signature);
    if (!verifiedGroup) {
      logger.e('$TAG - updatePrivateGroupOptions - signature verification failed.');
      return null;
    }
    // check
    PrivateGroupSchema? exists = await queryGroup(groupId);
    if (exists == null) {
      PrivateGroupSchema? _newGroup = PrivateGroupSchema.create(groupId, infos['name'], type: infos['type']);
      if (_newGroup == null) return null;
      _newGroup.count = count;
      _newGroup.options = OptionsSchema(deleteAfterSeconds: int.tryParse(infos['deleteAfterSeconds']?.toString() ?? ""));
      _newGroup.data['signature'] = signature;
      _newGroup.data['version'] = version;
      exists = await addPrivateGroup(_newGroup, notify: true);
      logger.i('$TAG - updatePrivateGroupOptions - group create - group:$exists');
    } else {
      int nativeVersionCommits = getPrivateGroupVersionCommits(exists.version) ?? 0;
      int remoteVersionCommits = getPrivateGroupVersionCommits(version) ?? 0;
      if (nativeVersionCommits < remoteVersionCommits) {
        bool verifiedGroup = await verifiedSignature(exists.ownerPublicKey, jsonEncode(exists.getRawDataMap()), signature);
        if ((exists.signature != signature) || !verifiedGroup) {
          String? name = infos['name'];
          int? type = int.tryParse(infos['type']?.toString() ?? "");
          int? deleteAfterSeconds = int.tryParse(infos['deleteAfterSeconds']?.toString() ?? "");
          if ((name != exists.name) || (type != exists.type)) {
            exists.name = name ?? exists.name;
            exists.type = type ?? exists.type;
            await setNameType(groupId, exists.name, exists.type, notify: true);
          }
          if (deleteAfterSeconds != exists.options.deleteAfterSeconds) {
            var options = await setGroupOptionsBurn(groupId, deleteAfterSeconds, notify: true);
            if (options != null) exists.options = options;
          }
          if (signature != exists.signature) {
            exists.data["signature"] = signature;
            await setGroupSignature(groupId, exists.signature, notify: true);
          }
        }
        if (version != exists.version) {
          exists.data["version"] = version;
          await setGroupVersion(groupId, version);
        }
        if (count != exists.count) {
          exists.count = count;
          await setCount(groupId, count, notify: true);
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
    // version
    if (!force && (remoteVersion != null) && remoteVersion.isNotEmpty) {
      int nativeCommits = getPrivateGroupVersionCommits(privateGroup.version) ?? 0;
      List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
      String nativeVersion = genPrivateGroupVersion(nativeCommits, privateGroup.signature, members);
      if (nativeVersion == remoteVersion) {
        logger.d('$TAG - pushPrivateGroupOptions - version same. - remote_version:$remoteVersion - exists:$privateGroup');
        return false;
      }
    }
    // item
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if (privateGroupItem == null) {
      logger.e('$TAG - pushPrivateGroupMembers - request is not in group.');
      return false;
    } else if (privateGroupItem.permission <= PrivateGroupItemPerm.none) {
      return await chatOutCommon.sendPrivateGroupMemberResponse([target], privateGroup, [privateGroupItem]);
    }
    // send
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId, all: true);
    for (int i = 0; i < members.length; i += 10) {
      List<PrivateGroupItemSchema> memberSplits = members.skip(i).take(10).toList();
      await chatOutCommon.sendPrivateGroupMemberResponse([target], privateGroup, memberSplits);
    }
    return true;
  }

  Future<PrivateGroupSchema?> updatePrivateGroupMembers(String? sender, String? groupId, String? remoteVersion, List<PrivateGroupItemSchema>? modifyMembers) async {
    if (sender == null || sender.isEmpty) return null;
    if (groupId == null || groupId.isEmpty) return null;
    if (remoteVersion == null || remoteVersion.isEmpty) return null;
    if (modifyMembers == null || modifyMembers.isEmpty) return null;
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - updatePrivateGroupMembers - has no group. - groupId:$groupId');
      return null;
    }
    // version (can not gen version because members just not all, just check commits(version))
    int nativeCommits = getPrivateGroupVersionCommits(schemaGroup.version) ?? 0;
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    String nativeVersion = genPrivateGroupVersion(nativeCommits, schemaGroup.signature, members);
    String? nativeVersionKeys = getPrivateGroupVersionKeys(nativeVersion);
    String? remoteVersionKeys = getPrivateGroupVersionKeys(remoteVersion);
    if ((nativeVersionKeys != null) && (nativeVersionKeys.isNotEmpty) && (nativeVersionKeys == remoteVersionKeys)) {
      if (!schemaGroup.joined) {
        int remoteCommits = getPrivateGroupVersionCommits(remoteVersion) ?? 0;
        if ((schemaGroup.quitCommits ?? remoteCommits) < remoteCommits) {
          logger.i('$TAG - updatePrivateGroupMembers - version commits no same after quit. - remote_version:$remoteVersion - exists:$schemaGroup');
        } else {
          logger.d('$TAG - updatePrivateGroupMembers - version commits same after quit. - remote_version:$remoteVersion - exists:$schemaGroup');
          return null;
        }
      } else {
        logger.d('$TAG - updatePrivateGroupMembers - members_keys version same. - remote_version:$remoteVersion - exists:$schemaGroup');
        return null;
      }
    }
    // sender (can not believe sender perm because native members maybe empty)
    String? selfAddress = clientCommon.address;
    PrivateGroupItemSchema? senderItem = await queryGroupItem(groupId, sender);
    if (senderItem == null) {
      if (isOwner(schemaGroup.ownerPublicKey, sender)) {
        // nothing
      } else {
        logger.w('$TAG - updatePrivateGroupMembers - sender no owner. - group:$schemaGroup - item:$senderItem');
        return null;
      }
    } else if (isOwner(schemaGroup.ownerPublicKey, selfAddress)) {
      logger.d('$TAG - updatePrivateGroupMembers - self is owner. - group:$schemaGroup - item:$senderItem');
      return null;
    } else if (senderItem.permission <= PrivateGroupItemPerm.none) {
      logger.w('$TAG - updatePrivateGroupMembers - sender no permission. - group:$schemaGroup - item:$senderItem');
      return null;
    }
    // members
    int selfJoined = 0;
    for (int i = 0; i < modifyMembers.length; i++) {
      PrivateGroupItemSchema member = modifyMembers[i];
      if (member.groupId != groupId) {
        logger.e('$TAG - updatePrivateGroupMembers - groupId incomplete data. - i$i - member:$member');
        continue;
      }
      // verify
      if ((member.invitee == null) || (member.invitee?.isEmpty == true) || (member.inviter == null) || (member.inviter?.isEmpty == true)) {
        logger.e('$TAG - updatePrivateGroupMembers - inviter incomplete people - i$i - member:$member');
        continue;
      }
      if ((member.inviterRawData == null) || (member.inviterRawData?.isEmpty == true) || (member.inviterSignature == null) || (member.inviterSignature?.isEmpty == true)) {
        logger.e('$TAG - updatePrivateGroupMembers - inviter incomplete inviter - i$i - member:$member');
        continue;
      }
      String? inviterPubKey = getPubKeyFromTopicOrChatId(member.inviter ?? "");
      bool verifiedInviter = await verifiedSignature(inviterPubKey, member.inviterRawData, member.inviterSignature);
      if (!verifiedInviter) {
        logger.e('$TAG - updatePrivateGroupMembers - signature verification inviter failed. - verifiedInviter:$verifiedInviter');
        continue;
      }
      if (member.permission > PrivateGroupItemPerm.none) {
        if ((member.inviteeRawData == null) || (member.inviteeRawData?.isEmpty == true) || (member.inviteeSignature == null) || (member.inviteeSignature?.isEmpty == true)) {
          logger.e('$TAG - updatePrivateGroupMembers - inviter incomplete invitee - i$i - member:$member');
          continue;
        }
        String? inviteePubKey = getPubKeyFromTopicOrChatId(member.invitee ?? "");
        bool verifiedInvitee = await verifiedSignature(inviteePubKey, member.inviteeRawData, member.inviteeSignature);
        if (!verifiedInvitee) {
          logger.e('$TAG - updatePrivateGroupMembers - signature verification invitee failed. - verifiedInvitee:$verifiedInvitee');
          continue;
        }
      }
      // sync
      PrivateGroupItemSchema? exists = await queryGroupItem(groupId, member.invitee);
      if (exists == null) {
        exists = await addPrivateGroupItem(member, null, notify: true);
        logger.i('$TAG - updatePrivateGroupMembers - add item - i$i - member:$exists');
      } else if (exists.permission != member.permission) {
        bool success = await updateGroupItemPermission(member, null, notify: true);
        if (success) exists.permission = member.permission;
        logger.i('$TAG - updatePrivateGroupMembers - update item permission - i$i - member:$exists');
      }
      if ((member.invitee?.isNotEmpty == true) && (member.invitee == selfAddress)) {
        selfJoined = (member.permission <= PrivateGroupItemPerm.none) ? -1 : 1;
        if (schemaGroup.quitCommits != null) {
          logger.i('$TAG - updatePrivateGroupMembers - update item quitCommits - i$i - member:$exists');
          var data = await setQuitCommits(groupId, null);
          if (data != null) schemaGroup.data = data;
        }
      }
    }
    // joined
    if (!schemaGroup.joined && (selfJoined == 1)) {
      schemaGroup.joined = true;
      bool success = await setJoined(groupId, true, notify: true);
      if (!success) schemaGroup.joined = false;
      logger.i('$TAG - updatePrivateGroupMembers - update self joined - true - group:$schemaGroup');
    } else if (schemaGroup.joined && selfJoined == -1) {
      schemaGroup.joined = false;
      bool success = await setJoined(groupId, false, notify: true);
      if (!success) schemaGroup.joined = true;
      logger.i('$TAG - updatePrivateGroupMembers - update self joined - false - group:$schemaGroup');
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
      return (item.permission == PrivateGroupItemPerm.owner) || (item.permission == PrivateGroupItemPerm.admin);
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

  String genPrivateGroupVersion(int commits, String optionSignature, List<PrivateGroupItemSchema> list) {
    List<String> memberKeys = list.map((e) => (e.invitee?.isNotEmpty == true) ? "${e.permission}_${e.invitee}" : "").toList();
    memberKeys.removeWhere((element) => element.isEmpty == true);
    memberKeys.sort((a, b) => a.compareTo(b));
    return "$commits.${hexEncode(Uint8List.fromList(Hash.md5(optionSignature + memberKeys.join(''))))}";
  }

  int? getPrivateGroupVersionCommits(String? version) {
    if (version == null || version.isEmpty) return null;
    List<String> splits = version.split(".");
    if (splits.length < 2) return null;
    int? commits = int.tryParse(splits[0]);
    return commits ?? null;
  }

  String? getPrivateGroupVersionKeys(String? version) {
    if (version == null || version.isEmpty) return null;
    List<String> splits = version.split(".");
    if (splits.length < 2) return null;
    splits.removeAt(0);
    return splits.join();
  }

  /*String? increasePrivateGroupVersion(String? version) {
    if (version == null || version.isEmpty) return null;
    List<String> splits = version.split(".");
    if (splits.length < 2) return null;
    int? commits = int.tryParse(splits[0]);
    if (commits == null) return null;
    splits[0] = (commits + 1).toString() + ".";
    return splits.join();
  }*/

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

  Future<PrivateGroupSchema?> addPrivateGroup(PrivateGroupSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    PrivateGroupSchema? added = await PrivateGroupStorage.instance.insert(schema);
    if ((added != null) && notify) _addGroupSink.add(added);
    return added;
  }

  Future<bool> setNameType(String? groupId, String name, int type, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.setNameType(groupId, name, type);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> setJoined(String? groupId, bool joined, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.setJoined(groupId, joined);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> setCount(String? groupId, int userCount, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    if (userCount < 0) userCount = 0;
    bool success = await PrivateGroupStorage.instance.setCount(groupId, userCount);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<bool> setAvatar(String? groupId, String? avatarLocalPath, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.setAvatar(groupId, avatarLocalPath);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<OptionsSchema?> setGroupOptionsBurn(String? groupId, int? burningSeconds, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    OptionsSchema? options = await PrivateGroupStorage.instance.setBurning(groupId, burningSeconds);
    if (options != null) {
      logger.i("$TAG - setGroupOptionsBurn - success - burningSeconds:$burningSeconds - options:$options - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setGroupOptionsBurn - fail - burningSeconds:$burningSeconds - options:$options - groupId:$groupId");
    }
    return options;
  }

  Future<Map<String, dynamic>?> setGroupVersion(String? groupId, String? version, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    var data = await PrivateGroupStorage.instance.setData(groupId, {
      "version": version,
    });
    if (data != null) {
      logger.i("$TAG - setGroupVersion - success - version:$version - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setGroupVersion - fail - version:$version - data:$data - groupId:$groupId");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setGroupSignature(String? groupId, String? signature, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    var data = await PrivateGroupStorage.instance.setData(groupId, {
      "signature": signature,
    });
    if (data != null) {
      logger.i("$TAG - setGroupSignature - success - signature:$signature - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setGroupSignature - fail - signature:$signature - data:$data - groupId:$groupId");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setQuitCommits(String? groupId, int? commits, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    Map<String, dynamic>? data = await PrivateGroupStorage.instance.setData(groupId, {
      "quit_at_version_commits": commits,
    });
    if (data != null) {
      logger.i("$TAG - setQuitCommits - success - commits:$commits - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setQuitCommits - fail - commits:$commits - data:$data - group:$groupId");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setReceivedMessages(String? groupId, Map adds, List<String> dels, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    var data = await PrivateGroupStorage.instance.setDataItemMapChange(groupId, "receivedMessages", adds, dels);
    if (data != null) {
      logger.i("$TAG - setReceivedMessages - success - adds:$adds - dels:$dels - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setReceivedMessages - fail - adds:$adds - dels:$dels - data:$data - groupId:$groupId");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setGroupOptionsRequestInfo(String? groupId, String? version, {int? timeAt, bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    Map<String, dynamic>? data = await PrivateGroupStorage.instance.setData(groupId, {
      "optionsRequestAt": timeAt ?? DateTime.now().millisecondsSinceEpoch,
      "optionsRequestedVersion": version,
    });
    if (data != null) {
      logger.i("$TAG - setGroupOptionsRequestInfo - success - timeAt:$timeAt - version:$version - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setGroupOptionsRequestInfo - fail - timeAt:$timeAt - version:$version - data:$data - groupId:$groupId");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setGroupMembersRequestInfo(String? groupId, String? version, {int? timeAt, bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    Map<String, dynamic>? data = await PrivateGroupStorage.instance.setData(groupId, {
      "membersRequestAt": timeAt ?? DateTime.now().millisecondsSinceEpoch,
      "membersRequestedVersion": version,
    });
    if (data != null) {
      logger.i("$TAG - setGroupMembersRequestInfo - success - timeAt:$timeAt - version:$version - data:$data - groupId:$groupId");
      if (notify) queryAndNotifyGroup(groupId);
    } else {
      logger.w("$TAG - setGroupMembersRequestInfo - fail - timeAt:$timeAt - version:$version - data:$data - groupId:$groupId");
    }
    return data;
  }

  Future<PrivateGroupSchema?> queryGroup(String? groupId) async {
    return await PrivateGroupStorage.instance.query(groupId);
  }

  Future<List<PrivateGroupSchema>> queryGroupListJoined({int? type, bool orderDesc = true, int offset = 0, final limit = 20}) {
    return PrivateGroupStorage.instance.queryListByJoined(true, type: type, orderDesc: orderDesc, offset: offset, limit: limit);
  }

  Future<PrivateGroupItemSchema?> addPrivateGroupItem(PrivateGroupItemSchema? schema, bool? sessionNotify, {bool notify = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    PrivateGroupItemSchema? added = await PrivateGroupItemStorage.instance.insert(schema);
    if (added == null) return null;
    if (notify) _addGroupItemSink.add(added);
    // session
    String selfAddress = clientCommon.address ?? "";
    if (selfAddress.isEmpty) return added;
    if (sessionNotify == null) {
      if (added.permission == PrivateGroupItemPerm.normal) {
        PrivateGroupItemSchema? mine = await queryGroupItem(schema.groupId, selfAddress);
        sessionNotify = (added.invitee == selfAddress) || ((mine?.expiresAt ?? 1) < (added.expiresAt ?? 0));
      }
    }
    if (sessionNotify == true) {
      MessageSchema? message = MessageSchema.fromSend(
        schema.groupId,
        SessionType.PRIVATE_GROUP,
        MessageContentType.privateGroupSubscribe,
        schema.invitee,
      );
      message.deviceId = "";
      message.sender = schema.invitee ?? "";
      message.isOutbound = schema.invitee == selfAddress;
      message.status = MessageStatus.Read;
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      message.receiveAt = DateTime.now().millisecondsSinceEpoch;
      await chatInCommon.onMessageReceive(message);
    }
    return added;
  }

  Future<PrivateGroupItemSchema?> queryGroupItem(String? groupId, String? invitee) async {
    return await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
  }

  Future<List<PrivateGroupItemSchema>> queryMembers(String? groupId, {int? perm, int offset = 0, final limit = 20}) async {
    return await PrivateGroupItemStorage.instance.queryList(groupId, perm: perm, limit: limit, offset: offset);
  }

  Future<List<PrivateGroupItemSchema>> getMembersAll(String? groupId, {bool all = false}) async {
    if (groupId == null || groupId.isEmpty) return [];
    List<PrivateGroupItemSchema> members = [];
    final limit = 20;
    // owner
    List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.owner, offset: 0, limit: 1);
    members.addAll(result);
    // admin
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.admin, offset: offset, limit: limit);
      members.addAll(result);
      logger.v("$TAG - getMembersAll - admin - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    // normal
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.normal, offset: offset, limit: limit);
      members.addAll(result);
      logger.v("$TAG - getMembersAll - normal - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    // none
    if (all) {
      for (int offset = 0; true; offset += limit) {
        List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.none, offset: offset, limit: limit);
        members.addAll(result);
        logger.v("$TAG - getMembersAll - none - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
        if (result.length < limit) break;
      }
    }
    // quit
    if (all) {
      for (int offset = 0; true; offset += limit) {
        List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.quit, offset: offset, limit: limit);
        members.addAll(result);
        logger.v("$TAG - getMembersAll - quit - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
        if (result.length < limit) break;
      }
    }
    // black
    if (all) {
      for (int offset = 0; true; offset += limit) {
        List<PrivateGroupItemSchema> result = await queryMembers(groupId, perm: PrivateGroupItemPerm.black, offset: offset, limit: limit);
        members.addAll(result);
        logger.v("$TAG - getMembersAll - black - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
        if (result.length < limit) break;
      }
    }
    return members;
  }

  Future<bool> updateGroupItemPermission(PrivateGroupItemSchema? item, bool? sessionNotify, {bool notify = false}) async {
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
    if (!success) return false;
    if (notify) queryAndNotifyGroupItem(item.groupId, item.invitee);
    // session
    String selfAddress = clientCommon.address ?? "";
    if (selfAddress.isEmpty) return true;
    if (sessionNotify == null) {
      if (item.permission == PrivateGroupItemPerm.normal) {
        PrivateGroupItemSchema? mine = await queryGroupItem(item.groupId, selfAddress);
        sessionNotify = (item.invitee == selfAddress) || ((mine?.expiresAt ?? 1) < (item.expiresAt ?? 0));
      }
    }
    // session
    if (sessionNotify == true) {
      MessageSchema? message = MessageSchema.fromSend(
        item.groupId,
        SessionType.PRIVATE_GROUP,
        MessageContentType.privateGroupSubscribe,
        item.invitee,
      );
      message.deviceId = "";
      message.sender = item.invitee ?? "";
      message.isOutbound = item.invitee == selfAddress;
      message.status = MessageStatus.Read;
      message.sendAt = DateTime.now().millisecondsSinceEpoch;
      message.receiveAt = DateTime.now().millisecondsSinceEpoch;
      await chatInCommon.onMessageReceive(message);
    }
    return success;
  }

  Future queryAndNotifyGroup(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return;
    PrivateGroupSchema? updated = await PrivateGroupStorage.instance.query(groupId);
    if (updated != null) {
      _updateGroupSink.add(updated);
    }
  }

  Future queryAndNotifyGroupItem(String? groupId, String? invitee) async {
    if (groupId == null || groupId.isEmpty) return;
    if (invitee == null || invitee.isEmpty) return;
    PrivateGroupItemSchema? updated = await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
    if (updated != null) {
      _updateGroupItemSink.add(updated);
    }
  }
}
