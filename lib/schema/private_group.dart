import 'dart:convert';
import 'dart:io';

import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/map_extension.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

class PrivateGroupType {
  static const normal = 0;
}

class PrivateGroupSchema {
// TODO:GG 消除 !
  int? id;
  String groupId;
  String name;
  int? type; // TODO:GG PG ?
  String? version;
  int? count;

  int? createAt;
  int? updateAt;
  bool isTop = false;
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
    this.type = PrivateGroupType.normal,
    this.version,
    this.count,
    this.createAt,
    this.updateAt,
    this.isTop = false,
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

  Map<String, dynamic> getRawDataMap() {
    Map<String, dynamic> data = Map();
    data['groupId'] = groupId;
    data['groupName'] = name;
    // TODO:GG PG 需要吗？burning同步延时怎么办 ?
    // if (deleteAfterSeconds != null) data['deleteAfterSeconds'] = deleteAfterSeconds;
    return data.sortByKey();
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'name': name,
      'type': type,
      'version': version,
      'count': count,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'is_top': isTop ? 1 : 0,
      'avatar': Path.convert2Local(avatar?.path),
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map;
  }

  static PrivateGroupSchema fromMap(Map<String, dynamic> e) {
    var schema = PrivateGroupSchema(
      id: e['id'],
      groupId: e['group_id'] ?? "",
      name: e['name'] ?? "",
      type: e['type'],
      count: e['count'],
      version: e['version'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
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
    return 'PrivateGroupSchema{id: $id, groupId: $groupId, name: $name, type: $type, version: $version, count: $count, createAt: $createAt, updateAt: $updateAt, isTop: $isTop, avatar: ${avatar?.path}, options: $options, data: $data}';
  }
}
