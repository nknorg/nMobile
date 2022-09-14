import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

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
import 'package:nmobile/utils/map_extension.dart';
import 'package:nmobile/utils/util.dart';
import 'package:uuid/uuid.dart';

class PrivateGroupCommon with Tag {
  static int EXPIRES_SECONDS = 3600 * 24 * 7; // 7 days TODO:GG move to settings

  // ignore: close_sinks
  StreamController<PrivateGroupSchema> _updateController = StreamController<PrivateGroupSchema>.broadcast();
  StreamSink<PrivateGroupSchema> get _updateSink => _updateController.sink;
  Stream<PrivateGroupSchema> get updateStream => _updateController.stream;

  Map<String, bool> syncDataMap = Map();
  Map<String, bool> dataComplete = Map<String, bool>();

  String getOwnerPublicKey(String groupId) {
    String owner;
    int index = groupId.lastIndexOf('.');
    owner = groupId.substring(0, index);
    return owner;
  }

  // TODO:GG PG
  bool lockSyncData(String groupId, String to) {
    if (syncDataMap['$groupId$to'] != null) {
      return false;
    }
    syncDataMap['$groupId$to'] = true;
    return true;
  }

  // TODO:GG PG
  unLockSyncData(String groupId, String to) {
    syncDataMap.remove('$groupId$to');
  }

  PrivateGroupItemSchema? createInvitationModel(String? groupId, String? invitee, String? inviter, {int? inviteAt, int? expiresSec}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (invitee == null || invitee.isEmpty) return null;
    if (inviter == null || inviter.isEmpty) return null;

    inviteAt = inviteAt ?? DateTime.now().millisecondsSinceEpoch;
    int expiresAt = inviteAt + (expiresSec ?? EXPIRES_SECONDS) * 1000;
    PrivateGroupItemSchema? schema = PrivateGroupItemSchema.create(groupId, expiresAt: expiresAt, invitee: invitee, inviter: inviter, inviteAt: inviteAt);
    if (schema == null) return null;

    schema.inviterRawData = jsonEncode(schema.createRawData(false));
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
    if (!(await schema.verifiedInviter())) {
      logger.e('$TAG - acceptInvitation - signature verification failed.');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // set
    schema.invitedAt = nowAt;
    schema.inviteeRawData = jsonEncode(schema.createRawData(true));
    // TODO:GG PG 优化
    schema.inviteeSignature = hexEncode(await Crypto.sign(privateKey, Uint8List.fromList(Hash.sha256(schema.inviteeRawData ?? ""))));
    return schema;
  }

  Future<PrivateGroupSchema?> addInvitee(PrivateGroupItemSchema? schema, {bool notify = false, bool toast = false}) async {
    if (schema == null || schema.groupId.isEmpty) return null;
    // check
    int? expiresAt = schema.expiresAt;
    int invitedAt = schema.invitedAt ?? DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt == null) || (expiresAt < invitedAt)) {
      logger.d('$TAG - addInvitee - time check fail - expiresAt:$expiresAt - invitedAt:$invitedAt');
      if (toast) Toast.show('expiresAt is null. or now time is after then expires time.'); // TODO:GG PG 中文?
      return null;
    }
    if ((schema.invitee == null) || (schema.invitee?.isEmpty == true) || (schema.inviter == null) || (schema.inviter?.isEmpty == true) || (schema.inviterRawData == null) || (schema.inviterRawData?.isEmpty == true) || (schema.inviteeRawData == null) || (schema.inviteeRawData?.isEmpty == true) || (schema.inviterSignature == null) || (schema.inviterSignature?.isEmpty == true) || (schema.inviteeSignature == null) || (schema.inviteeSignature?.isEmpty == true)) {
      logger.e('$TAG - addInvitee - inviter incomplete data - schema:$schema');
      if (toast) Toast.show('inviter incomplete data.'); // TODO:GG PG 中文?
      return null;
    }
    bool inviterVerified = await schema.verifiedInviter();
    bool inviteeVerified = await schema.verifiedInvitee();
    if (!inviterVerified || !inviteeVerified) {
      logger.e('$TAG - addInvitee - signature verification failed. - inviterVerified:$inviterVerified - inviteeVerified:$inviteeVerified');
      if (toast) Toast.show('signature verification failed.'); // TODO:GG PG 中文?
      return null;
    }
    // exists
    PrivateGroupSchema? schemaGroup = await PrivateGroupStorage.instance.query(schema.groupId);
    if (schemaGroup == null) {
      logger.e('$TAG - addInvitee - has no group. - groupId:${schema.groupId}');
      if (toast) Toast.show('has no group.'); // TODO:GG PG 中文?
      return null;
    }
    PrivateGroupItemSchema? schemaGroupItem = await PrivateGroupItemStorage.instance.queryByInvitee(schema.groupId, schema.invitee);
    if (schemaGroupItem != null) {
      logger.e('$TAG - addInvitee - invitee is exist.');
      if (toast) Toast.show('invitee is exist.'); // TODO:GG PG 中文?
      return null;
    }
    // members
    List<PrivateGroupItemSchema> members = [];
    int limit = 20;
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupItemSchema> result = await PrivateGroupItemStorage.instance.queryList(schema.groupId, offset: offset, limit: limit);
      members.addAll(result);
      logger.d("$TAG - addInvitee - groupId:${schema.groupId} - offset:$offset - current_len:${result.length} - total_len:${members.length}");
      if (result.length < limit) break;
    }
    members.add(schema);
    schemaGroupItem = await PrivateGroupItemStorage.instance.insert(schema);
    if (schemaGroupItem == null) return null;
    // group
    schemaGroup.count = members.length;
    schemaGroup.version = genPrivateGroupVersion(schemaGroup.signature, members.map((e) => e.invitee ?? "").toList());
    bool success = await PrivateGroupStorage.instance.updateVersionCount(schema.groupId, schemaGroup.version, schemaGroup.count ?? 0);
    if (success && notify) queryAndNotify(schema.groupId);
    return schemaGroup;
  }

  // TODO:GG 位置
  List<Map<String, dynamic>> getMembersData(List<PrivateGroupItemSchema> list) {
    List<Map<String, dynamic>> members = List.empty(growable: true);
    list
      ..sort((a, b) => (a.invitee ?? "").compareTo(b.invitee ?? ""))
      ..forEach((e) => members.add(e.toMap()..remove('id')));
    return members;
  }

  String genPrivateGroupVersion(String optionSignature, List<String> memberPks) {
    memberPks.sort((a, b) => a.compareTo(b));
    return hexEncode(Uint8List.fromList(Hash.md5(optionSignature + memberPks.join(''))));
  }

  Future<PrivateGroupSchema?> createPrivateGroup(String? name, {bool toast = false}) async {
    if (name == null || name.isEmpty) return null;
    String? ownerPublicKey = clientCommon.getPublicKey();
    if (ownerPublicKey == null || ownerPublicKey.isEmpty) return null;
    String groupId = '$ownerPublicKey.${Uuid().v4()}';

    // group
    PrivateGroupSchema? schemaGroup = PrivateGroupSchema.create(groupId, name);
    if (schemaGroup == null) return null;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(clientCommon.client?.seed ?? Uint8List.fromList([]));
    Uint8List groupSignData = Uint8List.fromList(Hash.sha256(json.encode(schemaGroup.getRawData())));
    // TODO:GG PG 优化
    schemaGroup.setSignature(hexEncode(await Crypto.sign(ownerPrivateKey, groupSignData)));
    // item
    PrivateGroupItemSchema? schemaItem = createInvitationModel(
      groupId,
      ownerPublicKey,
      ownerPublicKey,
      inviteAt: DateTime.now().millisecondsSinceEpoch,
      expiresSec: EXPIRES_SECONDS,
    );
    if (schemaItem == null) return null;
    schemaItem.inviterRawData = jsonEncode(schemaItem.createRawData(false));
    Uint8List inviterSignData = Uint8List.fromList(Hash.sha256(schemaItem.inviterRawData ?? ""));
    // TODO:GG PG 优化
    schemaItem.inviterSignature = hexEncode(await Crypto.sign(ownerPrivateKey, inviterSignData));
    // accept self
    schemaItem = await acceptInvitation(schemaItem, ownerPrivateKey, toast: toast);
    await PrivateGroupItemStorage.instance.insert(schemaItem);
    // update
    schemaGroup.count = 1;
    schemaGroup.version = genPrivateGroupVersion(schemaGroup.signature, [schemaGroup.ownerPublicKey]);
    schemaGroup = await PrivateGroupStorage.instance.insert(schemaGroup);
    return schemaGroup;
  }

  // TODO:GG 很多地方都没包装
  Future<PrivateGroupSchema?> addPrivateGroup(PrivateGroupSchema schema) async {
    return await PrivateGroupStorage.instance.insert(schema);
  }

  Future<PrivateGroupSchema?> initializationPrivateGroup(PrivateGroupSchema privateGroupSchema) async {
    return await PrivateGroupStorage.instance.insert(privateGroupSchema);
  }

  Future<bool> syncPrivateGroupOptions(String? groupId, String? membersRaw, String? optionsRaw, String? signature, String? version, {bool notify = false}) async {
    if (groupId == null || groupId.isEmpty) return false;
    if (signature == null || signature.isEmpty) return false;
    // if (membersRaw == null || membersRaw.isEmpty) return false;
    // if (optionsRaw == null || optionsRaw.isEmpty) return false;
    // if (version == null || version.isEmpty) return false;
    // verified
    String ownerPubKey = getOwnerPublicKey(groupId);
    Uint8List signData = Uint8List.fromList(Hash.sha256(optionsRaw));
    // TODO:GG PG 优化
    bool verified = await Crypto.verify(hexDecode(ownerPubKey), signData, hexDecode(signature));
    if (!verified) {
      logger.w('$TAG - syncPrivateGroupOptions - signature verification failed.');
      return false;
    }
    Map members = Util.jsonFormat(membersRaw) ?? Map();
    Map options = Util.jsonFormat(optionsRaw) ?? Map();
    // check
    PrivateGroupSchema? schemaGroup = PrivateGroupSchema.create(groupId, options['groupName']);
    if (schemaGroup == null) return false;
    schemaGroup.version = version;
    schemaGroup.count = members.length;
    schemaGroup.options = OptionsSchema(deleteAfterSeconds: options['deleteAfterSeconds']);
    schemaGroup.setSignature(signature);
    PrivateGroupSchema? exists = await queryByGroupId(groupId);
    if (exists == null) {
      await PrivateGroupStorage.instance.insert(schemaGroup);
    } else {
      if (members.length < (exists.count ?? 0)) {
        logger.w('$TAG - syncPrivateGroupOptions - members_len <  exists_count - members:$members - exists:$exists');
        return false;
      }
      var myVersion = exists.version;
      bool myVerified = await exists.verified();
      if ((version != myVersion) || !myVerified) {
        await PrivateGroupStorage.instance.updateVersionCount(groupId, schemaGroup.version, schemaGroup.count ?? 0);
        await PrivateGroupStorage.instance.updateData(groupId, schemaGroup.data);
      }
    }
    if (notify) queryAndNotify(groupId);
    return true;
  }

  // TODO:GG 看到这了
  Future<bool> syncPrivateGroupMember(String syncGroupId, String syncVersion, List members) async {
    for (int i = 0; i < members.length; i++) {
      var m = members[i];
      logger.d('$TAG - syncPrivateGroupMember - $m');
      int? expiresAt = m['expires_at'];

      String? groupId = m['group_id'];
      int? inviteAt = m['invite_at'];
      int? invitedAt = m['invited_at'];
      String? invitee = m['invitee'];
      String? inviteeRawData = m['invitee_raw_data'];
      String? inviteeSignature = m['invitee_signature'];
      String? inviter = m['inviter'];
      String? inviterRawData = m['inviter_raw_data'];
      String? inviterSignature = m['inviter_signature'];

      if (groupId == null || inviteAt == null || invitedAt == null || invitee == null || inviteeRawData == null || inviteeSignature == null || inviter == null || inviterRawData == null || inviterSignature == null) {
        Toast.show('sync incomplete data.');
        logger.d('$TAG - syncPrivateGroupMember - sync incomplete data.');
        continue;
      }

      if (groupId != syncGroupId) {
        Toast.show('groupId incomplete data.');
        logger.d('$TAG - syncPrivateGroupMember - groupId incomplete data.');
      }

      if (expiresAt == null) {
        Toast.show('expiresAt is null.');
        logger.d('$TAG - syncPrivateGroupMember - expiresAt is null.');
        continue;
      }
      DateTime expiresTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      if (DateTime.fromMillisecondsSinceEpoch(invitedAt).isAfter(expiresTime)) {
        Toast.show('now time is after then expires time.');
        logger.d('$TAG - syncPrivateGroupMember - now time is after then expires time.');
        continue;
      }

      // TODO:GG 这块得改
      bool inviterVerified = await Crypto.verify(hexDecode(inviter), Uint8List.fromList(Hash.sha256(inviterRawData)), hexDecode(inviterSignature));
      bool inviteeVerified = await Crypto.verify(hexDecode(invitee), Uint8List.fromList(Hash.sha256(inviteeRawData)), hexDecode(inviteeSignature));

      if (!inviterVerified || !inviteeVerified) {
        Toast.show('signature verification failed.');
        logger.d('$TAG - syncPrivateGroupMember - signature verification failed.');
        continue;
      }
      // update private group
      var privateGroupSchema = await PrivateGroupStorage.instance.query(groupId);
      if (privateGroupSchema == null) {
        Toast.show('has no group ID.');
        logger.d('$TAG - syncPrivateGroupMember - has no group ID.');
        continue;
      }
      var privateGroupItemSchema = await PrivateGroupItemStorage.instance.queryByInvitee(syncGroupId, invitee);
      if (privateGroupItemSchema != null) {
        logger.d('$TAG - syncPrivateGroupMember - invitee is exist.');
        continue;
      }

      PrivateGroupItemSchema? groupItem = PrivateGroupItemSchema.create(
        groupId,
        invitee: invitee,
        inviteAt: inviteAt,
        inviteeRawData: inviteeRawData,
        inviteeSignature: inviteeSignature,
        inviter: inviter,
        invitedAt: invitedAt,
        inviterRawData: inviterRawData,
        inviterSignature: inviterSignature,
        expiresAt: expiresAt,
      );
      await PrivateGroupItemStorage.instance.insert(groupItem);
    }

    var privateGroup = await PrivateGroupStorage.instance.query(syncGroupId);
    var privateGroupMembers = await PrivateGroupItemStorage.instance.queryList(syncGroupId);
    if (privateGroup != null && privateGroupMembers != null) {
      var version = genPrivateGroupVersion(privateGroup.signature, privateGroupMembers.map((e) => e.invitee!).toList());
      if (version == syncVersion) {
        var session = await SessionStorage.instance.query(syncGroupId, SessionType.PRIVATE_GROUP);
        if (session == null) {
          chatOutCommon.sendPrivateGroupSubscribe(syncGroupId);
        }
      }
    }

    return true;
  }

  Future<bool> checkDataComplete(String groupId) async {
    var privateGroup = await PrivateGroupStorage.instance.query(groupId);
    var privateGroupMembers = await PrivateGroupItemStorage.instance.queryList(groupId);
    if (privateGroup != null && privateGroupMembers != null) {
      var version = genPrivateGroupVersion(privateGroup.signature, privateGroupMembers.map((e) => e.invitee!).toList());
      if (version == privateGroup.version) {
        dataComplete[groupId] = true;
        return true;
      }
    }
    dataComplete[groupId] = false;
    return false;
  }

  Future<bool> invitee(String address, PrivateGroupSchema privateGroup) async {
    if (!await checkDataComplete(privateGroup.groupId)) {
      Toast.show(Global.locale((s) => s.data_synchronization));
      logger.d('Data synchronization.');
      return false;
    }
    var inv = await PrivateGroupItemStorage.instance.queryByInvitee(privateGroup.groupId, address);
    if (inv != null) {
      Toast.show(Global.locale((s) => s.invitee_already_exists));
      logger.d('Invitee already exists.');
      return false;
    }

    Uint8List ownerSeed = clientCommon.client!.seed;
    // TODO:GG PG 优化
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(ownerSeed);
    var inviteeModel = privateGroupCommon.createInvitationModel(privateGroup.groupId, address, clientCommon.getPublicKey()!);
    if (inviteeModel == null) return false;
    // TODO:GG PG 优化
    inviteeModel?.inviterSignature = hexEncode(await Crypto.sign(ownerPrivateKey, Uint8List.fromList(Hash.sha256(inviteeModel.inviterRawData!))));
    await chatOutCommon.sendPrivateGroupInvitee(address, privateGroup, inviteeModel);
    return true;
  }

  Future<bool> responsePrivateGroupOptionRequest(String to, String groupId) async {
    if (!await checkDataComplete(groupId)) {
      Toast.show(Global.locale((s) => s.data_synchronization));
      logger.d('Data synchronization.');
      return false;
    }

    var privateGroup = await queryByGroupId(groupId);
    var privateGroupMembers = await PrivateGroupItemStorage.instance.queryList(groupId);
    await chatOutCommon.sendPrivateGroupOptionSync(to, privateGroup!, privateGroupMembers!.map((e) => e.invitee!).toList());

    return true;
  }

  Future<bool> responsePrivateGroupMemberKeyRequest(String to, String groupId) async {
    if (!await checkDataComplete(groupId)) {
      Toast.show(Global.locale((s) => s.data_synchronization));
      logger.d('Data synchronization.');
      return false;
    }

    var privateGroup = await queryByGroupId(groupId);
    var privateGroupMembers = await PrivateGroupItemStorage.instance.queryList(groupId);
    await chatOutCommon.sendPrivateGroupMemberKeyResponse(to, privateGroup!, privateGroupMembers!.map((e) => e.invitee!).toList());

    return true;
  }

  Future<bool> responsePrivateGroupMemberRequest(String to, String groupId) async {
    if (!await checkDataComplete(groupId)) {
      Toast.show(Global.locale((s) => s.data_synchronization));
      logger.d('Data synchronization.');
      return false;
    }

    var privateGroup = await queryByGroupId(groupId);
    var privateGroupMembers = await PrivateGroupItemStorage.instance.queryList(groupId);
    var privateGroupItem = await PrivateGroupItemStorage.instance.queryByInvitee(groupId, to);
    if (privateGroupItem == null) {
      logger.d('request is not in group.');
      return false;
    }

    await chatOutCommon.sendPrivateGroupMemberSync(to, privateGroup!, privateGroupMembers!);

    return true;
  }

  Future<PrivateGroupSchema?> queryByGroupId(String groupId, {bool notify = true}) async {
    var updated = await PrivateGroupStorage.instance.query(groupId);
    // if (updated != null && notify) _updateSink.add(updated);
    return updated;
  }

  Future<List<PrivateGroupItemSchema>?> queryMembers(String groupId) async {
    var list = await PrivateGroupItemStorage.instance.queryList(groupId);
    return list;
  }

  Future<List<PrivateGroupItemSchema>?> queryMembersByLimit(String groupId, {int offset = 0, int limit = 20}) async {
    var list = await PrivateGroupItemStorage.instance.queryList(groupId, limit: limit, offset: offset);
    return list;
  }

  Future<bool> setAvatar(String groupId, String? avatarLocalPath, {bool notify = false}) async {
    bool success = await PrivateGroupStorage.instance.setAvatar(groupId, avatarLocalPath);
    if (success && notify) queryAndNotify(groupId);
    return success;
  }

  // TODO:GG 所有的STORAGE都检查一下，要不要
  Future queryAndNotify(String groupId) async {
    PrivateGroupSchema? updated = await queryByGroupId(groupId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
