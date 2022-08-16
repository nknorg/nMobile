import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/private_group_option.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/map_extension.dart';
import 'package:uuid/uuid.dart';

const EXPIRES_SECONDS = 3600 * 24 * 7; // 7 days

// TODO:GG PG check
class PrivateGroupCommon with Tag {
  // ignore: close_sinks
  StreamController<PrivateGroupSchema> _updateController = StreamController<PrivateGroupSchema>.broadcast();
  StreamSink<PrivateGroupSchema> get _updateSink => _updateController.sink;
  Stream<PrivateGroupSchema> get updateStream => _updateController.stream;

  Map syncDataMap = Map();

  PrivateGroupStorage _privateGroupStorage = PrivateGroupStorage();
  PrivateGroupItemStorage _privateGroupItemStorage = PrivateGroupItemStorage();
  SessionStorage _sessionStorage = SessionStorage();

  Map<String, bool> dataComplete = Map<String, bool>();

  String genPrivateGroupId(String owner) {
    return '$owner.${Uuid().v4()}';
  }

  String getOwnerPublicKey(String groupId) {
    String owner;
    int index = groupId.lastIndexOf('.');
    owner = groupId.substring(0, index);

    return owner;
  }

  bool lockSyncData(String groupId, String to) {
    if (syncDataMap['$groupId$to'] != null) {
      return false;
    }
    syncDataMap['$groupId$to'] = true;
    return true;
  }

  unLockSyncData(String groupId, String to) {
    syncDataMap.remove('$groupId$to');
  }

  PrivateGroupItemSchema createInvitationModel(String groupId, String invitee, String inviter, {DateTime? inviteTime, Duration? expiresAt}) {
    PrivateGroupItemSchema schema = PrivateGroupItemSchema(groupId: groupId);
    schema.invitee = invitee;
    schema.inviter = inviter;
    if (inviteTime != null) {
      schema.inviteTime = inviteTime;
    } else {
      schema.inviteTime = DateTime.now();
    }

    if (expiresAt != null) {
      schema.expiresAt = schema.inviteTime?.add(expiresAt);
    } else {
      schema.expiresAt = schema.inviteTime?.add(Duration(seconds: EXPIRES_SECONDS));
    }

    Map<String, dynamic> map = {};
    map['groupId'] = schema.groupId;
    map['invitee'] = schema.invitee;
    map['inviter'] = schema.inviter;
    map['inviteTime'] = schema.inviteTime!.millisecondsSinceEpoch;
    map['expiresAt'] = schema.expiresAt!.millisecondsSinceEpoch;
    map = map.sortByKey();
    schema.inviterRawData = jsonEncode(map);
    return schema;
  }

  PrivateGroupItemSchema createModelFromInvitationRawData(
    String inviterRawData, {
    String? inviterSignature,
  }) {
    Map<String, dynamic> map = jsonDecode(inviterRawData);
    PrivateGroupItemSchema schema = PrivateGroupItemSchema.fromRawData(map, inviterRawData: inviterRawData, inviterSignature: inviterSignature);
    return schema;
  }

  Future<bool> acceptInvitation(PrivateGroupItemSchema schema, Uint8List privateKey) async {
    DateTime now = DateTime.now();
    if (schema.expiresAt == null) {
      // TODO:GG PG 开关+中文？
      Toast.show('expiresAt is null.');
      logger.d('$TAG - acceptInvitation - expiresAt is null.');
      return false;
    }
    DateTime expiresTime = schema.expiresAt!;
    if (now.isAfter(expiresTime)) {
      // TODO:GG PG 开关+中文？
      Toast.show('now time is after then expires time.');
      logger.d('$TAG - acceptInvitation - now time is after then expires time.');
      return false;
    }
    schema.invitedTime = now;

    if (schema.invitee == null || schema.inviter == null || schema.inviterRawData == null || schema.inviterSignature == null) {
      // TODO:GG PG 开关+中文？
      Toast.show('inviter incomplete data.');
      logger.d('$TAG - acceptInvitation - inviter incomplete data.');
      return false;
    }

    bool verified = await Crypto.verify(hexDecode(schema.inviter!), Uint8List.fromList(Hash.sha256(schema.inviterRawData!)), hexDecode(schema.inviterSignature!));

    if (!verified) {
      // TODO:GG PG 开关+中文？
      Toast.show('signature verification failed.');
      logger.d('$TAG - acceptInvitation - signature verification failed.');
      return false;
    }

    Map<String, dynamic> map = {};
    map['groupId'] = schema.groupId;
    map['invitee'] = schema.invitee;
    map['inviter'] = schema.inviter;
    map['inviteTime'] = schema.inviteTime!.millisecondsSinceEpoch;
    map['expiresAt'] = schema.expiresAt!.millisecondsSinceEpoch;
    schema.invitedTime = now;
    map['invitedTime'] = schema.invitedTime!.millisecondsSinceEpoch;
    map = map.sortByKey();
    schema.inviteeRawData = jsonEncode(map);
    schema.inviteeSignature = hexEncode(await Crypto.sign(privateKey, Uint8List.fromList(Hash.sha256(schema.inviteeRawData!))));
    return true;
  }

  Future<bool> addInvitee(PrivateGroupItemSchema schema) async {
    if (schema.expiresAt == null) {
      Toast.show('expiresAt is null.');
      logger.d('$TAG - addInvitee - expiresAt is null.');
      return false;
    }
    DateTime expiresTime = schema.expiresAt!;
    if (schema.invitedTime!.isAfter(expiresTime)) {
      Toast.show('now time is after then expires time.');
      logger.d('$TAG - addInvitee - now time is after then expires time.');
      return false;
    }

    if (schema.invitee == null || schema.inviteeRawData == null || schema.inviteeSignature == null || schema.inviter == null || schema.inviterRawData == null || schema.inviterSignature == null) {
      Toast.show('inviter incomplete data.');
      logger.d('$TAG - addInvitee - inviter incomplete data.');
      return false;
    }

    bool inviterVerified = await Crypto.verify(hexDecode(schema.inviter!), Uint8List.fromList(Hash.sha256(schema.inviterRawData!)), hexDecode(schema.inviterSignature!));
    bool inviteeVerified = await Crypto.verify(hexDecode(schema.invitee!), Uint8List.fromList(Hash.sha256(schema.inviteeRawData!)), hexDecode(schema.inviteeSignature!));
    if (!inviterVerified || !inviteeVerified) {
      Toast.show('signature verification failed.');
      logger.d('$TAG - addInvitee - signature verification failed.');
      return false;
    }
    // update private group
    var privateGroupSchema = await _privateGroupStorage.query(schema.groupId);
    if (privateGroupSchema == null) {
      Toast.show('has no group ID.');
      logger.d('$TAG - addInvitee - has no group ID.');
      return false;
    }
    var privateGroupItemSchema = await _privateGroupItemStorage.queryByInvitee(schema.groupId, schema.invitee!);
    if (privateGroupItemSchema != null) {
      logger.d('$TAG - addInvitee - invitee is exist.');
      return false;
    }

    // get all members public key
    var members = await _privateGroupItemStorage.query(schema.groupId);
    members?.add(schema);

    privateGroupSchema.count = members?.length;
    // generate version
    privateGroupSchema.version = genPrivateGroupVersion(privateGroupSchema.options!.signature!, members!.map((e) => e.invitee!).toList());

    await Future.wait([
      _privateGroupStorage.update(schema.groupId, privateGroupSchema),
      _privateGroupItemStorage.insert(schema),
    ]);
    queryAndNotify(schema.groupId);
    return true;
  }

  List<Map<String, dynamic>> getMembersData(List<PrivateGroupItemSchema> list) {
    List<Map<String, dynamic>> members = List.empty(growable: true);
    list
      ..sort((a, b) => a.invitee!.compareTo(b.invitee!))
      ..forEach((e) {
        var map = e.toMap();
        map.remove('id');
        members.add(map);
      });
    return members;
  }

  String genPrivateGroupVersion(String optionSignature, List<String> list) {
    list.sort((a, b) => a.compareTo(b));
    return hexEncode(Uint8List.fromList(Hash.md5(optionSignature + list.join(''))));
  }

  Future<PrivateGroupSchema?> createPrivateGroup(String name) async {
    if (name.isNotEmpty == true) {
      Uint8List ownerPublicKey = clientCommon.client!.publicKey;
      Uint8List ownerSeed = clientCommon.client!.seed;
      Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(ownerSeed);
      String groupId = genPrivateGroupId(hexEncode(ownerPublicKey));
      DateTime now = DateTime.now();
      Duration expiresAt = Duration(seconds: EXPIRES_SECONDS);

      PrivateGroupSchema privateGroupSchema = PrivateGroupSchema(name: name, groupId: groupId);
      // options
      // options signature
      privateGroupSchema.options!.signature = hexEncode(await Crypto.sign(ownerPrivateKey, Uint8List.fromList(Hash.sha256(json.encode(privateGroupSchema.options!.getData())))));

      // member
      PrivateGroupItemSchema privateGroupItemSchema = createInvitationModel(groupId, hexEncode(ownerPublicKey), hexEncode(ownerPublicKey), inviteTime: now, expiresAt: expiresAt);

      // inviter signature
      privateGroupItemSchema.inviterSignature = hexEncode(await Crypto.sign(ownerPrivateKey, Uint8List.fromList(Hash.sha256(privateGroupItemSchema.inviterRawData!))));

      // accept invitation
      await acceptInvitation(privateGroupItemSchema, ownerPrivateKey);

      // update private group
      privateGroupSchema.count = 1;
      // generate version
      privateGroupSchema.version = genPrivateGroupVersion(privateGroupSchema.options!.signature!, [privateGroupSchema.ownerPublicKey]);

      await Future.wait([
        _privateGroupStorage.insert(privateGroupSchema),
        _privateGroupItemStorage.insert(privateGroupItemSchema),
      ]);

      return privateGroupSchema;
    }
    return null;
  }

  Future<PrivateGroupSchema?> addPrivateGroup(PrivateGroupSchema schema) async {
    return await _privateGroupStorage.insert(schema);
  }

  Future<PrivateGroupSchema?> initializationPrivateGroup(PrivateGroupSchema privateGroupSchema) async {
    return await _privateGroupStorage.insert(privateGroupSchema);
  }

  Future<bool> addOrUpdate(PrivateGroupSchema schema) async {
    var query = await _privateGroupStorage.query(schema.groupId);
    try {
      if (query != null) {
        await _privateGroupStorage.update(schema.groupId, schema);
      } else {
        await _privateGroupStorage.insert(schema);
      }
      return true;
    } catch (e) {
      logger.e(e);
      return false;
    }
  }

  Future<bool> syncPrivateGroupOptions(String to, String groupId, String membersRaw, String optionsRaw, String signature, String version) async {
    String ownerPubkey = getOwnerPublicKey(groupId);
    bool verified = await Crypto.verify(hexDecode(ownerPubkey), Uint8List.fromList(Hash.sha256(optionsRaw)), hexDecode(signature));

    if (!verified) {
      logger.d('signature verification failed.');
      return false;
    }

    List members = jsonDecode(membersRaw);
    Map options = jsonDecode(optionsRaw);
    var privateGroup = await queryByGroupId(groupId);

    var addModel = PrivateGroupSchema(
      groupId: groupId,
      name: options['groupName'],
      version: version,
      count: members.length,
      options: PrivateGroupOptionSchema(
        groupId: options['groupId'],
        groupName: options['groupName'],
        avatarBgColor: Color(options['avatarBgColor']),
        avatarNameColor: Color(options['avatarNameColor']),
        deleteAfterSeconds: options['deleteAfterSeconds'],
        signature: signature,
      ),
    );

    if (privateGroup == null) {
      await addOrUpdate(addModel);
    } else {
      if (members.length < (privateGroup.count ?? 0)) {
        return false;
      }

      var myVersion = privateGroup.version;
      bool myVerified = await privateGroup.options?.verified() ?? false;

      if (version != myVersion || !myVerified) {
        await addOrUpdate(addModel);
      }
    }
    await queryAndNotify(groupId);

    chatOutCommon.sendPrivateGroupMemberRequest(to, groupId, members.cast());
    return true;
  }

  Future<bool> syncPrivateGroupMember(String syncGroupId, String syncVersion, List members) async {
    for (int i = 0; i < members.length; i++) {
      var m = members[i];
      logger.d('$TAG - syncPrivateGroupMember - $m');
      int? expiresAt = m['expires_at'];

      String? groupId = m['group_id'];
      int? inviteTime = m['invite_time'];
      int? invitedTime = m['invited_time'];
      String? invitee = m['invitee'];
      String? inviteeRawData = m['invitee_raw_data'];
      String? inviteeSignature = m['invitee_signature'];
      String? inviter = m['inviter'];
      String? inviterRawData = m['inviter_raw_data'];
      String? inviterSignature = m['inviter_signature'];

      if (groupId == null || inviteTime == null || invitedTime == null || invitee == null || inviteeRawData == null || inviteeSignature == null || inviter == null || inviterRawData == null || inviterSignature == null) {
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
      if (DateTime.fromMillisecondsSinceEpoch(invitedTime).isAfter(expiresTime)) {
        Toast.show('now time is after then expires time.');
        logger.d('$TAG - syncPrivateGroupMember - now time is after then expires time.');
        continue;
      }

      bool inviterVerified = await Crypto.verify(hexDecode(inviter), Uint8List.fromList(Hash.sha256(inviterRawData)), hexDecode(inviterSignature));
      bool inviteeVerified = await Crypto.verify(hexDecode(invitee), Uint8List.fromList(Hash.sha256(inviteeRawData)), hexDecode(inviteeSignature));

      if (!inviterVerified || !inviteeVerified) {
        Toast.show('signature verification failed.');
        logger.d('$TAG - syncPrivateGroupMember - signature verification failed.');
        continue;
      }
      // update private group
      var privateGroupSchema = await _privateGroupStorage.query(groupId);
      if (privateGroupSchema == null) {
        Toast.show('has no group ID.');
        logger.d('$TAG - syncPrivateGroupMember - has no group ID.');
        continue;
      }
      var privateGroupItemSchema = await _privateGroupItemStorage.queryByInvitee(syncGroupId, invitee);
      if (privateGroupItemSchema != null) {
        logger.d('$TAG - syncPrivateGroupMember - invitee is exist.');
        continue;
      }

      await _privateGroupItemStorage.insert(PrivateGroupItemSchema(
        groupId: groupId,
        invitee: invitee,
        inviteeRawData: inviteeRawData,
        inviteeSignature: inviteeSignature,
        inviter: inviter,
        inviterRawData: inviterRawData,
        inviterSignature: inviterSignature,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
        inviteTime: DateTime.fromMillisecondsSinceEpoch(inviteTime),
        invitedTime: DateTime.fromMillisecondsSinceEpoch(invitedTime),
      ));
    }

    var privateGroup = await _privateGroupStorage.query(syncGroupId);
    var privateGroupMembers = await _privateGroupItemStorage.query(syncGroupId);
    if (privateGroup != null && privateGroupMembers != null) {
      var version = genPrivateGroupVersion(privateGroup.options!.signature!, privateGroupMembers.map((e) => e.invitee!).toList());
      if (version == syncVersion) {
        var session = await _sessionStorage.query(syncGroupId, SessionType.PRIVATE_GROUP);
        if (session == null) {
          chatOutCommon.sendPrivateGroupSubscribe(syncGroupId);
        }
      }
    }

    return true;
  }

  Future<bool> checkDataComplete(String groupId) async {
    var privateGroup = await _privateGroupStorage.query(groupId);
    var privateGroupMembers = await _privateGroupItemStorage.query(groupId);
    if (privateGroup != null && privateGroupMembers != null) {
      var version = genPrivateGroupVersion(privateGroup.options!.signature!, privateGroupMembers.map((e) => e.invitee!).toList());
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
    var inv = await _privateGroupItemStorage.queryByInvitee(privateGroup.groupId, address);
    if (inv != null) {
      Toast.show(Global.locale((s) => s.invitee_already_exists));
      logger.d('Invitee already exists.');
      return false;
    }

    Uint8List ownerSeed = clientCommon.client!.seed;
    Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(ownerSeed);
    var inviteeModel = privateGroupCommon.createInvitationModel(privateGroup.groupId, address, clientCommon.getPublicKey()!);
    inviteeModel.inviterSignature = hexEncode(await Crypto.sign(ownerPrivateKey, Uint8List.fromList(Hash.sha256(inviteeModel.inviterRawData!))));
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
    var privateGroupMembers = await _privateGroupItemStorage.query(groupId);
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
    var privateGroupMembers = await _privateGroupItemStorage.query(groupId);
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
    var privateGroupMembers = await _privateGroupItemStorage.query(groupId);
    var privateGroupItem = await _privateGroupItemStorage.queryByInvitee(groupId, to);
    if (privateGroupItem == null) {
      logger.d('request is not in group.');
      return false;
    }

    await chatOutCommon.sendPrivateGroupMemberSync(to, privateGroup!, privateGroupMembers!);

    return true;
  }

  Future<PrivateGroupSchema?> queryByGroupId(String groupId, {bool notify = true}) async {
    var updated = await _privateGroupStorage.query(groupId);
    if (updated != null && notify) _updateSink.add(updated);
    return updated;
  }

  Future<List<PrivateGroupItemSchema>?> queryMembers(String groupId) async {
    var list = await _privateGroupItemStorage.query(groupId);
    return list;
  }

  Future<List<PrivateGroupItemSchema>?> queryMembersByLimit(String groupId, {String? orderBy, int offset = 0, int limit = 20}) async {
    var list = await _privateGroupItemStorage.queryLimit(groupId, limit: limit, offset: offset, orderBy: orderBy);
    return list;
  }

  Future<bool> setAvatar(String groupId, String? avatarLocalPath, {bool notify = false}) async {
    bool success = await _privateGroupStorage.setAvatar(groupId, avatarLocalPath);
    if (success && notify) queryAndNotify(groupId);
    return success;
  }

  Future queryAndNotify(String groupId) async {
    PrivateGroupSchema? updated = await queryByGroupId(groupId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
