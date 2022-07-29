import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/map_extension.dart';

// TODO:GG PG check
class PrivateGroupOptionSchema {
  String? rawData;

  String groupId;
  String groupName;

  Color? avatarBgColor;
  Color? avatarNameColor;
  int? deleteAfterSeconds;

  String? signature;

  PrivateGroupOptionSchema({
    this.rawData,
    required this.groupId,
    required this.groupName,
    this.avatarBgColor,
    this.avatarNameColor,
    this.deleteAfterSeconds,
    this.signature,
  }) {
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    if (avatarBgColor == null) {
      avatarBgColor = application.theme.randomBackgroundColorList[random];
    }
    if (avatarNameColor == null) {
      avatarNameColor = application.theme.randomColorList[random];
    }
    if (rawData == null) {
      rawData = jsonEncode(getData());
    }
  }

  Future<bool> verified() async {
    String ownerPubkey = privateGroupCommon.getOwnerPublicKey(groupId);
    try {
      return await Crypto.verify(hexDecode(ownerPubkey), Uint8List.fromList(Hash.sha256(json.encode(getData()))), hexDecode(signature!));
    } catch (e) {
      logger.e(e);
      return false;
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map['data'] = Map<String, dynamic>();
    map['data']['groupId'] = groupId;
    map['data']['groupName'] = groupName;
    if (avatarBgColor != null) map['data']['avatarBgColor'] = avatarBgColor?.value;
    if (avatarNameColor != null) map['data']['avatarNameColor'] = avatarNameColor?.value;
    if (deleteAfterSeconds != null) map['data']['deleteAfterSeconds'] = deleteAfterSeconds;
    map['data'] = (map['data'] as Map<String, dynamic>).sortByKey();

    map['signature'] = signature;
    return map;
  }

  Map<String, dynamic> getData() {
    Map<String, dynamic> data = {};
    data = Map<String, dynamic>();
    data['groupId'] = groupId;
    data['groupName'] = groupName;
    if (avatarBgColor != null) data['avatarBgColor'] = avatarBgColor?.value;
    if (avatarNameColor != null) data['avatarNameColor'] = avatarNameColor?.value;
    if (deleteAfterSeconds != null) data['deleteAfterSeconds'] = deleteAfterSeconds;
    data = data.sortByKey();

    return data;
  }

  static PrivateGroupOptionSchema fromMap(Map map) {
    PrivateGroupOptionSchema schema = PrivateGroupOptionSchema(
      groupId: map['data']['groupId'],
      groupName: map['data']['groupName'],
      avatarBgColor: map['data']['avatarBgColor'] != null ? Color(map['data']['avatarBgColor']) : null,
      avatarNameColor: map['data']['avatarNameColor'] != null ? Color(map['data']['avatarNameColor']) : null,
      deleteAfterSeconds: map['data']['deleteAfterSeconds'],
      signature: map['signature'],
    );
    return schema;
  }
}
