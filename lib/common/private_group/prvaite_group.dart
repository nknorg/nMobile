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

  // TODO:GG PG 再来个item的update的 ?

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
    if (clientCommon.address == null || (clientCommon.address?.isEmpty == true)) return null;
    PrivateGroupItemSchema? schemaItem = createInvitationModel(
      groupId,
      clientCommon.address,
      clientCommon.address,
      permission: PrivateGroupItemPerm.owner,
    );
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
    PrivateGroupSchema? schemaGroup = await queryGroup(groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - invitee - has no group. - groupId:$groupId');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return false;
    }
    PrivateGroupItemSchema? inviter = await queryGroupItem(groupId, clientCommon.address);
    if (inviter == null) {
      logger.e('$TAG - invitee - has no inviter. - groupId:$groupId');
      if (toast) Toast.show('has no inviter.'); // TODO:GG PG 中文?
      return false;
    }
    if (isAdmin(schemaGroup, inviter)) {
      if (!isOwner(schemaGroup.ownerPublicKey, clientCommon.address)) {
        // FUTURE: admin invitee (send msg to invitee and let owner to receive+sync)
        return false;
      }
    }
    var invitee = await queryGroupItem(groupId, target);
    if ((invitee != null) && (invitee.permission != PrivateGroupItemPerm.none)) {
      logger.d('$TAG - invitee - Invitee already exists.');
      if (toast) Toast.show(Global.locale((s) => s.invitee_already_exists));
      return false;
    }
    // action
    var inviteeModel = createInvitationModel(groupId, target, clientCommon.address);
    if (inviteeModel == null) return false;
    Uint8List? clientSeed = clientCommon.client?.seed;
    if (clientSeed == null) return false;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    inviteeModel.inviterSignature = await genSignature(ownerPrivateKey, inviteeModel.inviterRawData);
    if ((inviteeModel.inviterSignature == null) || (inviteeModel.inviterSignature?.isEmpty == true)) return false;
    await chatOutCommon.sendPrivateGroupInvitee(target, schemaGroup, inviteeModel);
    return true;
  }

  Future<PrivateGroupItemSchema?> acceptInvitation(PrivateGroupItemSchema? schema, Uint8List? privateKey, {bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty || privateKey == null) return null;
    // duplicated
    PrivateGroupItemSchema? itemExists = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExists != null) && (itemExists.permission != PrivateGroupItemPerm.none)) {
      logger.w('$TAG - acceptInvitation - already in group - exists:$itemExists');
      if (toast) Toast.show('already in group.'); // TODO:GG PG 中文?
      return null;
    }
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
    bool verifiedInviter = await verifiedSignature(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    if (!verifiedInviter) {
      logger.e('$TAG - acceptInvitation - signature verification failed.');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // set
    schema.inviteeRawData = jsonEncode(schema.createRawDataMap());
    schema.inviteeSignature = await genSignature(privateKey, schema.inviteeRawData);
    if ((schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) return null;
    return schema;
  }

  Future<PrivateGroupSchema?> insertInvitee(PrivateGroupItemSchema? schema, {bool notify = false, bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - insertInvitee - time check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - insertInvitee - inviter incomplete data - schema:$schema');
      if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
      return null;
    }
    bool verifiedInviter = await verifiedSignature(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    bool verifiedInvitee = await verifiedSignature(schema.invitee, schema.inviteeRawData, schema.inviteeSignature);
    if (!verifiedInviter || !verifiedInvitee) {
      logger.e('$TAG - insertInvitee - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - insertInvitee - has no group. - groupId:${schema.groupId}');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return null;
    }
    PrivateGroupItemSchema? itemExist = await queryGroupItem(schema.groupId, schema.invitee);
    if ((itemExist != null) && (itemExist.permission != PrivateGroupItemPerm.none)) {
      logger.w('$TAG - insertInvitee - invitee is exist.');
      if (toast) Toast.show('invitee is exist.'); // TODO:GG PG 中文?
      return null;
    }
    // members
    List<PrivateGroupItemSchema> members = await getMembersAll(schema.groupId);
    members.add(schema);
    schema = await addPrivateGroupItem(schema, true, notify: true, checkDuplicated: false);
    if (schema == null) {
      logger.e('$TAG - insertInvitee - member create fail. - member:$schema');
      return null;
    }
    // group
    List<String> splits = schemaGroup.version?.split(".") ?? [];
    int commits = (splits.length >= 2 ? (int.tryParse(splits[0]) ?? 0) : 0) + 1;
    schemaGroup.version = genPrivateGroupVersion(commits, schemaGroup.signature, getInviteesKey(members));
    schemaGroup.count = members.length;
    await updateGroupVersionCount(schema.groupId, schemaGroup.version, schemaGroup.count ?? 0, notify: true);
    return schemaGroup;
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
      _newGroup.options = OptionsSchema(deleteAfterSeconds: int.tryParse(infos['deleteAfterSeconds']));
      _newGroup.setSignature(signature);
      exists = await addPrivateGroup(_newGroup, true, notify: true);
      logger.i('$TAG - updatePrivateGroupOptions - group create - group:$exists');
    } else {
      List<String> splitsNative = exists.version?.split(".") ?? [];
      int nativeVersionCommits = (splitsNative.length >= 2) ? (int.tryParse(splitsNative[0]) ?? 0) : 0;
      List<String> splitsRemote = version.split(".");
      int remoteVersionCommits = (splitsRemote.length >= 2) ? (int.tryParse(splitsRemote[0]) ?? 0) : 0;
      if (nativeVersionCommits < remoteVersionCommits) {
        bool verifiedGroup = await verifiedSignature(exists.ownerPublicKey, jsonEncode(exists.getRawDataMap()), exists.signature);
        if (!verifiedGroup) {
          if (infos['type'] != exists.type || infos['name'] != exists.name) {
            exists.type = infos['type'] ?? exists.type;
            exists.name = infos['name'] ?? exists.name;
            await updateGroupNameType(groupId, exists.name, exists.type, notify: true);
          }
          if (signature != exists.signature) {
            exists.setSignature(signature);
            await updateGroupData(groupId, exists.data, notify: true);
          }
          // TODO:GG PG options update ?
        }
        if (version != exists.version || membersCount != exists.count) {
          exists.version = version;
          exists.count = membersCount;
          await updateGroupVersionCount(groupId, version, membersCount, notify: true);
        }
        logger.i('$TAG - updatePrivateGroupOptions - group modify - group:$exists');
      } else {
        logger.d('$TAG - updatePrivateGroupOptions - group nothing - remote_version:$version - exists:$exists');
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
    chatOutCommon.sendPrivateGroupMemberResponse(target, privateGroup, members); // await
    return true;
  }

  Future<PrivateGroupSchema?> updatePrivateGroupMembers(String? sender, String? groupId, String? remoteVersion, List<PrivateGroupItemSchema>? newMembers) async {
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
    // version
    // List<String> splits = remoteVersion.split(".");
    // int commits = splits.length >= 2 ? (int.tryParse(splits[0]) ?? -1) : -1;
    // String signVersion = genPrivateGroupVersion(commits, schemaGroup.signature, getInviteesKey(newMembers));
    // if ((schemaGroup.version != remoteVersion) || (signVersion != remoteVersion)) {
    //   logger.e('$TAG - updatePrivateGroupMembers - version wrong. - groupId:$groupId');
    //   return null;
    // }
    // members
    bool inGroup = false;
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
      if (!inGroup && (member.invitee == clientCommon.address)) {
        inGroup = true;
      }
      PrivateGroupItemSchema? exists = await queryGroupItem(groupId, member.invitee);
      if (exists == null) {
        exists = await addPrivateGroupItem(member, true, notify: true, checkDuplicated: false);
        logger.i('$TAG - updatePrivateGroupMembers - add item - i$i - member:$exists');
      }
    }
    // joined
    if (!schemaGroup.joined && inGroup) {
      schemaGroup.joined = inGroup;
      await updateGroupJoined(groupId, schemaGroup.joined, notify: true);
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
      return item.permission == PrivateGroupItemPerm.owner;
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
    if (sessionNotify) {
      SessionSchema? added = SessionSchema(targetId: schema.groupId, type: SessionType.PRIVATE_GROUP);
      await sessionCommon.add(added, null, notify: true);
    }
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

  Future<bool> updateGroupData(String? groupId, Map<String, dynamic>? data, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupStorage.instance.updateData(groupId, data);
    if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future<PrivateGroupSchema?> queryGroup(String? groupId) async {
    return await PrivateGroupStorage.instance.query(groupId);
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
        from: clientCommon.address ?? "",
        groupId: schema.groupId,
        contentType: MessageContentType.privateGroupSubscribe,
        content: schema.invitee,
        status: MessageStatus.Read,
      );
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

  // FUTURE: adminer
  Future<bool> updateGroupItemPermission(String? groupId, String? invitee, int? permission, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    bool success = await PrivateGroupItemStorage.instance.updatePermission(groupId, invitee, permission);
    // if (success && notify) queryAndNotifyGroup(groupId);
    return success;
  }

  Future queryAndNotifyGroup(String groupId) async {
    PrivateGroupSchema? updated = await PrivateGroupStorage.instance.query(groupId);
    if (updated != null) {
      _updateGroupSink.add(updated);
    }
  }
}
