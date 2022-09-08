import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/map_extension.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

// class PrivateGroupType {
//   static const private = 0;
//   static const public = 1;
// }

class PrivateGroupSchema {
  int? id;
  int? createAt;
  int? updateAt;

  String groupId;
  String name;
  int? type; // TODO:GG PG ?
  String? version;

  bool isTop = false;
  int? count;
  File? avatar;

  OptionsSchema? options;
  Map<String, dynamic>? data;

  // TODO:GG PG ?
  // bool joined = false;
  // int? joinAt;
  // int? leaveAt;

  PrivateGroupSchema({
    this.id,
    required this.groupId,
    required this.name,
    this.createAt,
    this.updateAt,
    this.type,
    this.version,
    this.isTop = false,
    this.count,
    this.avatar,
    this.options,
    this.data,
  }) {
    if (this.options == null) {
      this.options = OptionsSchema();
    }
  }

  static PrivateGroupSchema? create(String? groupId, String? name) {
    if (groupId == null || groupId.isEmpty) return null;
    if (name == null || name.isEmpty) name = groupId;
    return PrivateGroupSchema(
      groupId: groupId,
      name: name,
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String get ownerPublicKey {
    int index = groupId.lastIndexOf('.');
    if (index < 0) return '';
    return groupId.substring(0, index);
  }

  String get signature {
    return data?['signature'] ?? "";
  }

  void setSignature(String? signature) {
    if (data == null) data = Map();
    data?['signature'] = signature;
  }

  Map<String, dynamic> getRawData() {
    Map<String, dynamic> data = Map();
    data['groupId'] = groupId;
    data['groupName'] = name;
    // TODO:GG PG 需要吗？burning同步延时怎么办?
    // if (deleteAfterSeconds != null) data['deleteAfterSeconds'] = deleteAfterSeconds;
    return data.sortByKey();
  }

  Future<bool> verified() async {
    try {
      Uint8List pubKey = hexDecode(ownerPublicKey);
      Uint8List data = Uint8List.fromList(Hash.sha256(json.encode(getRawData())));
      Uint8List sign = hexDecode(signature);
      return await Crypto.verify(pubKey, data, sign);
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'group_id': groupId,
      'name': name,
      'type': type,
      'version': version,
      'is_top': isTop ? 1 : 0,
      'count': count,
      'avatar': Path.convert2Local(avatar?.path),
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map;
  }

  static PrivateGroupSchema fromMap(Map<String, dynamic> e) {
    var schema = PrivateGroupSchema(
      id: e['id'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      groupId: e['group_id'] ?? "",
      name: e['name'] ?? "",
      type: e['type'],
      version: e['version'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      count: e['count'],
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
    );

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormat(e['options']);
      schema.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (schema.options == null) {
      schema.options = OptionsSchema();
    }

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormat(e['data']);
      if (schema.data == null) {
        schema.data = new Map<String, dynamic>();
      }
      if (data != null) {
        schema.data?.addAll(data);
      }
    }
    return schema;
  }

  @override
  String toString() {
    return 'PrivateGroupSchema{id: $id, createAt: $createAt, updateAt: $updateAt, groupId: $groupId, name: $name, type: $type, version: $version, isTop: $isTop, count: $count, avatar: ${avatar?.path}, options: $options, data: $data}';
  }
}
