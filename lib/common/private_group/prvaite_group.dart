import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
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
  Stream<PrivateGroupSchema> get updateGroupStream => _updateGroupController.stream;

  // ignore: close_sinks
  StreamController<PrivateGroupItemSchema> _addGroupItemController = StreamController<PrivateGroupItemSchema>.broadcast();
  StreamSink<PrivateGroupItemSchema> get _addGroupItemSink => _addGroupItemController.sink;
  Stream<PrivateGroupItemSchema> get addGroupItemStream => _addGroupItemController.stream;

  Map<String, bool> dataComplete = Map();

  // TODO:GG PG 如果不完整，怎么同步 ?
  Future<bool> checkDataComplete(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    var version = genPrivateGroupVersion(privateGroup?.signature ?? "", getInviteesId(members));
    if ((version == privateGroup?.version) && (privateGroup?.version != null)) {
      dataComplete[groupId] = true;
      return true;
    }
    dataComplete[groupId] = false;
    return false;
  }

  ///****************************************** Action *******************************************

  PrivateGroupItemSchema? createInvitationModel(String? groupId, String? invitee, String? inviter, {int? expiresMs}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (invitee == null || invitee.isEmpty) return null;
    if (inviter == null || inviter.isEmpty) return null;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    int expiresAt = nowAt + (expiresMs ?? Global.privateGroupInviteExpiresMs);
    PrivateGroupItemSchema? schema = PrivateGroupItemSchema.create(groupId, expiresAt: expiresAt, invitee: invitee, inviter: inviter);
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
    PrivateGroupItemSchema? schemaItem = createInvitationModel(groupId, clientCommon.address, clientCommon.address);
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
    var inviteeModel = createInvitationModel(groupId, target, clientCommon.address);
    if (inviteeModel == null) return false;
    Uint8List? clientSeed = clientCommon.client?.seed;
    if (clientSeed == null) return false;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientSeed);
    inviteeModel.inviterSignature = await genSignature(ownerPrivateKey, inviteeModel.inviterRawData);
    if ((inviteeModel.inviterSignature == null) || (inviteeModel.inviterSignature?.isEmpty == false)) return false;
    // TODO:GG PG 防止频发的机制
    await chatOutCommon.sendPrivateGroupInvitee(target, schemaGroup, inviteeModel);
    return true;
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

  // Map<String, dynamic>? data = received.content['data'];
  Future<PrivateGroupSchema?> receiveAccept(String? groupId, Map<String, dynamic>? data, {bool toast = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    if (data == null || data.isEmpty) return null;
    // add to private group
    PrivateGroupItemSchema? newItem = PrivateGroupItemSchema.fromRawData(data);
    if (newItem == null) {
      logger.e('$TAG - receiveAccept - invitee nil.');
      if (toast) Toast.show('invitee nil.'); // TODO:GG PG 中文?
      return null;
    }
    PrivateGroupSchema? groupSchema = await addInvitee(newItem, notify: true, toast: false);
    if (groupSchema == null) {
      logger.e('$TAG - receiveAccept - Invitee accept fail.');
      if (toast) Toast.show('group accept fail.'); // TODO:GG PG 中文?
      return null;
    }
    // sync members
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    if (members.length <= 0) {
      logger.e('$TAG - receiveAccept - has no this group info');
      if (toast) Toast.show('has no this group info.'); // TODO:GG PG 中文?
      return null;
    }
    // TODO:GG PG 防止频发的机制
    chatOutCommon.sendPrivateGroupOptionResponse(newItem.invitee, groupSchema, getInviteesId(members)); // await
    for (int i = 0; i < members.length; i += 10) {
      List<PrivateGroupItemSchema> memberSplits = members.skip(i).take(10).toList();
      // TODO:GG PG 防止频发的机制
      chatOutCommon.sendPrivateGroupMemberResponse(newItem.invitee, groupSchema, memberSplits); // await
    }
    members.forEach((m) {
      // TODO:GG PG 防止频发的机制
      chatOutCommon.sendPrivateGroupMemberResponse(m.invitee, groupSchema, [newItem]); // await
    });
    return groupSchema;
  }

  Future<PrivateGroupSchema?> addInvitee(PrivateGroupItemSchema? schema, {bool notify = false, bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < nowAt)) {
      logger.w('$TAG - addInvitee - time check fail - expiresAt:$expiresAt - nowAt:$nowAt');
      if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - addInvitee - inviter incomplete data - schema:$schema');
      if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
      return null;
    }
    bool verifiedInviter = await verifiedSignature(schema.inviter, schema.inviterRawData, schema.inviterSignature);
    bool verifiedInvitee = await verifiedSignature(schema.invitee, schema.inviteeRawData, schema.inviteeSignature);
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
    List<PrivateGroupItemSchema> members = await getMembersAll(schema.groupId);
    members.add(schema);
    schemaGroupItem = await addPrivateGroupItem(schema, notify: true, checkDuplicated: false);
    if (schemaGroupItem == null) {
      logger.e('$TAG - addInvitee - member create fail. - member:$schemaGroupItem');
      return null;
    }
    // group
    schemaGroup.count = members.length;
    schemaGroup.version = genPrivateGroupVersion(schemaGroup.signature, getInviteesId(members));
    await updateGroupVersionCount(schemaGroupItem.groupId, schemaGroup.version, schemaGroup.count ?? 0, notify: true);
    return schemaGroup;
  }

  ///****************************************** Sync *******************************************

  Future<bool> pushPrivateGroupOptions(String? target, String? groupId, String? remoteVersion, {bool force = false, bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
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
    chatOutCommon.sendPrivateGroupOptionResponse(target, privateGroup, getInviteesId(members)); // await
    return true;
  }

  Future<PrivateGroupSchema?> updatePrivateGroupOptions(String? groupId, String? rawData, String? version, String? membersIds, String? signature, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return null;
    if (rawData == null || rawData.isEmpty) return null;
    if (version == null || version.isEmpty) return null;
    if (membersIds == null || membersIds.isEmpty) return null;
    if (signature == null || signature.isEmpty) return null;
    // verified
    String ownerPubKey = getOwnerPublicKey(groupId);
    bool verifiedGroup = await verifiedSignature(ownerPubKey, rawData, signature);
    if (!verifiedGroup) {
      logger.e('$TAG - updatePrivateGroupOptions - signature verification failed.');
      return null;
    }
    Map infos = Util.jsonFormat(rawData) ?? Map();
    Map members = Util.jsonFormat(membersIds) ?? Map();
    // check
    PrivateGroupSchema? exists = await queryGroup(groupId);
    if (exists == null) {
      PrivateGroupSchema? _newGroup = PrivateGroupSchema.create(groupId, infos['name'], type: infos['type']);
      if (_newGroup == null) return null;
      _newGroup.version = version;
      _newGroup.count = members.length;
      _newGroup.setSignature(signature);
      exists = await addPrivateGroup(_newGroup, notify: true);
    } else {
      if (members.length < (exists.count ?? 0)) {
        // TODO:GG 根据这个来判断吗？
        logger.w('$TAG - syncPrivateGroupOptions - members_len <  exists_count - members:$members - exists:$exists');
        return null;
      }
      if (version != exists.version) {
        // TODO:GG 这块参考chatCOmmon里的做？
        await updateGroupVersionCount(groupId, version, members.length, notify: true);
      }
      bool verifiedGroup = await verifiedSignature(exists.ownerPublicKey, jsonEncode(exists.getRawDataMap()), exists.signature);
      if (!verifiedGroup) {
        exists.type = infos['type'] ?? exists.type;
        // TODO:GG PG
        exists.name = infos['name'] ?? exists.name;
        await updateGroupName(groupId, exists.name, notify: true);
        exists.setSignature(signature);
        await updateGroupData(groupId, exists.data, notify: true);
      }
    }
    return exists;
  }

  Future<bool> pushPrivateGroupMembers(String? target, String? groupId, String? latestVersion, {bool force = false, bool toast = false}) async {
    if (target == null || target.isEmpty) return false;
    if (groupId == null || groupId.isEmpty) return false;
    PrivateGroupSchema? privateGroup = await queryGroup(groupId);
    if (privateGroup == null) return false;
    if (privateGroup.version == latestVersion) {
      logger.d('$TAG - pushPrivateGroupMembers - version same - version:$latestVersion');
      return false;
    }
    if (!await checkDataComplete(groupId)) {
      logger.w('$TAG - pushPrivateGroupMembers - Data synchronization.');
      if (toast) Toast.show(Global.locale((s) => s.data_synchronization));
      return false;
    }
    PrivateGroupItemSchema? privateGroupItem = await queryGroupItem(groupId, target);
    if (privateGroupItem == null) {
      logger.e('$TAG - pushPrivateGroupMembers - request is not in group.');
      return false;
    }
    // TODO:GG PG 防止频发的机制
    List<PrivateGroupItemSchema> members = await getMembersAll(groupId);
    chatOutCommon.sendPrivateGroupMemberResponse(target, privateGroup, members); // await
    return true;
  }

  Future<List<PrivateGroupItemSchema>?> updatePrivateGroupMembers(String? syncGroupId, String? syncVersion, List<PrivateGroupItemSchema>? syncMembers, {bool toast = false}) async {
    if (syncGroupId == null || syncGroupId.isEmpty) return null;
    if (syncVersion == null || syncVersion.isEmpty) return null;
    if (syncMembers == null || syncMembers.isEmpty) return null;
    // exists
    PrivateGroupSchema? schemaGroup = await queryGroup(syncGroupId);
    if (schemaGroup == null) {
      logger.e('$TAG - updatePrivateGroupMembers - has no group. - groupId:$syncGroupId');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return null;
    }
    // members
    for (int i = 0; i < syncMembers.length; i++) {
      PrivateGroupItemSchema member = syncMembers[i];
      logger.d('$TAG - updatePrivateGroupMembers - for_each - i$i - member:$member');
      if (member.groupId != syncGroupId) {
        logger.e('$TAG - updatePrivateGroupMembers - groupId incomplete data. - i$i - member:$member');
        if (toast) Toast.show('groupId incomplete data.'); // TODO:GG PG 中文?
        continue;
      }
      int? expiresAt = member.expiresAt;
      int nowAt = DateTime.now().millisecondsSinceEpoch;
      if ((expiresAt == null) || (expiresAt < nowAt)) {
        logger.w('$TAG - updatePrivateGroupMembers - time check fail - expiresAt:$expiresAt - nowAt:$nowAt');
        if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
        continue;
      }
      if ((member.invitee == null) || (member.invitee?.isEmpty == true) || (member.inviter == null) || (member.inviter?.isEmpty == true) || (member.inviterRawData == null) || (member.inviterRawData?.isEmpty == true) || (member.inviteeRawData == null) || (member.inviteeRawData?.isEmpty == true) || (member.inviterSignature == null) || (member.inviterSignature?.isEmpty == true) || (member.inviteeSignature == null) || (member.inviteeSignature?.isEmpty == true)) {
        logger.e('$TAG - updatePrivateGroupMembers - inviter incomplete data - i$i - member:$member');
        if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
        continue;
      }
      bool verifiedInviter = await verifiedSignature(member.inviter, member.inviterRawData, member.inviterSignature);
      bool verifiedInvitee = await verifiedSignature(member.invitee, member.inviteeRawData, member.inviteeSignature);
      if (!verifiedInviter || !verifiedInvitee) {
        logger.e('$TAG - updatePrivateGroupMembers - signature verification failed. - verifiedInviter:$verifiedInviter - verifiedInvitee:$verifiedInvitee');
        if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
        continue;
      }
      PrivateGroupItemSchema? exists = await queryGroupItem(syncGroupId, member.invitee);
      if (exists == null) {
        exists = await addPrivateGroupItem(member, notify: true, checkDuplicated: false);
        // TODO:GG PG 是不是在这里插入数据，对方入群了?
      }
    }
    // TODO:GG PG 下面这是什么原理？
    // members
    List<PrivateGroupItemSchema> members = await getMembersAll(syncGroupId);
    // session
    var version = genPrivateGroupVersion(schemaGroup.signature, getInviteesId(members));
    if (version == syncVersion) {
      var session = await SessionStorage.instance.query(syncGroupId, SessionType.PRIVATE_GROUP);
      // TODO:GG PG 还没想好
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

  String genPrivateGroupVersion(String optionSignature, List<String> memberIds) {
    memberIds.sort((a, b) => a.compareTo(b));
    return hexEncode(Uint8List.fromList(Hash.md5(optionSignature + memberIds.join(''))));
  }

  Future<bool?> verifiedGroupVersion(PrivateGroupSchema? privateGroup, String? checkVersion, {bool signVersion = false}) async {
    if (privateGroup == null) return null;
    if (checkVersion == null || checkVersion.isEmpty) return false;
    String? nativeVersion = privateGroup.version;
    if (nativeVersion == null || nativeVersion.isEmpty) return false;
    if (signVersion) {
      List<PrivateGroupItemSchema> members = await getMembersAll(privateGroup.groupId);
      String signVersion = genPrivateGroupVersion(privateGroup.signature, getInviteesId(members));
      return signVersion.isNotEmpty && (checkVersion == nativeVersion) && (nativeVersion == signVersion);
    }
    return checkVersion == nativeVersion;
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

  List<String> getInviteesId(List<PrivateGroupItemSchema> list) {
    List<String> ids = list.map((e) => e.invitee ?? "").toList();
    ids.removeWhere((element) => element.isEmpty);
    ids.sort((a, b) => (a).compareTo(b));
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

  Future<PrivateGroupSchema?> queryGroup(String? groupId) async {
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

  Future<PrivateGroupItemSchema?> queryGroupItem(String? groupId, String? invitee) async {
    return await PrivateGroupItemStorage.instance.queryByInvitee(groupId, invitee);
  }

  Future<List<PrivateGroupItemSchema>> queryMembers(String? groupId, {int offset = 0, int limit = 20}) async {
    return await PrivateGroupItemStorage.instance.queryList(groupId, limit: limit, offset: offset);
  }

  Future<List<PrivateGroupItemSchema>> getMembersAll(String? groupId) async {
    if (groupId == null || groupId.isEmpty) return [];
    List<PrivateGroupItemSchema> members = [];
    int limit = 20;
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await queryMembers(groupId, offset: offset, limit: limit);
      members.addAll(result);
      logger.d("$TAG - getMembersAll - groupId:$groupId - offset:$offset - current_len:${result.length} - total_len:${members.length}");
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
