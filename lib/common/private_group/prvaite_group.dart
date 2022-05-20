import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/utils/map_extension.dart';
import 'package:uuid/uuid.dart';

import '../../schema/private_group.dart';
import '../../storages/private_group_item.dart';
import '../../utils/hash.dart';
import '../../utils/logger.dart';
import '../locator.dart';

const EXPIRES_SECONDS = 3600 * 24 * 7; // 7 days

class PrivateGroupCommon with Tag {
  PrivateGroupStorage _privateGroupStorage = PrivateGroupStorage();
  PrivateGroupItemStorage _privateGroupItemStorage = PrivateGroupItemStorage();

  genPrivateGroupId(String owner) {
    return '$owner.${Uuid().v4()}';
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
    map['inviteTime'] = schema.inviteTime!.microsecondsSinceEpoch;
    map['expiresAt'] = schema.expiresAt!.microsecondsSinceEpoch;
    map = map.sortByKey();
    schema.inviterRawData = jsonEncode(map);
    return schema;
  }

  PrivateGroupItemSchema createModelFromInvitationRawData(String inviterRawData) {
    Map<String, dynamic> map = jsonDecode(inviterRawData);
    PrivateGroupItemSchema schema = PrivateGroupItemSchema.fromRawData(map);
    return schema;
  }

  Future<bool> acceptInvitation(PrivateGroupItemSchema schema, Uint8List privateKey) async {
    DateTime now = DateTime.now();
    if (schema.expiresAt == null) {
      logger.d('$TAG - acceptInvitation - expiresAt is null.');
      return false;
    }
    DateTime expiresTime = schema.expiresAt!;
    if (now.isAfter(expiresTime)) {
      logger.d('$TAG - acceptInvitation - now time is after then expires time.');
      return false;
    }
    schema.invitedTime = now;

    if (schema.invitee == null || schema.inviter == null || schema.inviterRawData == null || schema.inviterSignature == null) {
      logger.d('$TAG - acceptInvitation - inviter incomplete data.');
      return false;
    }

    bool verified = await Crypto.verify(hexDecode(schema.inviter!), Uint8List.fromList(Hash.sha256(schema.inviterRawData!)), hexDecode(schema.inviterSignature!));

    if (!verified) {
      logger.d('$TAG - acceptInvitation - signature verification failed.');
      return false;
    }

    Map<String, dynamic> map = {};
    map['groupId'] = schema.groupId;
    map['invitee'] = schema.invitee;
    map['inviter'] = schema.inviter;
    map['inviteTime'] = schema.inviteTime!.microsecondsSinceEpoch;
    map['expiresAt'] = schema.expiresAt!.microsecondsSinceEpoch;
    schema.invitedTime = now;
    map['invitedTime'] = schema.invitedTime!.microsecondsSinceEpoch;
    map = map.sortByKey();
    schema.inviteeRawData = jsonEncode(map);
    schema.inviteeSignature = hexEncode(await Crypto.sign(privateKey, Uint8List.fromList(Hash.sha256(schema.inviteeRawData!))));
    return true;
  }

  String genPrivateGroupVersion(String optionSignature, List<String> list) {
    list.sort((a, b) => a.compareTo(b));
    return hexEncode(Hash.md5(optionSignature + list.join('')));
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
}
