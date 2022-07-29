import 'dart:convert';
import 'dart:io';

import 'package:nmobile/schema/private_group_option.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

// TODO:GG PG check
class PrivateGroupSchema {
  int? id;
  String groupId;
  String name;
  String? version;
  int? count;
  File? avatar;
  bool isTop;
  PrivateGroupOptionSchema? options;

  DateTime? createAt;
  DateTime? updateAt;

  PrivateGroupSchema({
    this.id,
    this.groupId = '',
    required this.name,
    this.version,
    this.count,
    this.avatar,
    this.isTop = false,
    this.options,
    this.createAt,
    this.updateAt,
  }) {
    if (this.options == null) {
      this.options = PrivateGroupOptionSchema(groupId: groupId, groupName: this.name);
    }
    if (this.createAt == null) {
      this.createAt = DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'name': name,
      'avatar': Path.convert2Local(avatar?.path),
      'count': count,
      'version': version,
      'is_top': isTop ? 1 : 0,
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'create_at': createAt?.millisecondsSinceEpoch,
      'update_at': updateAt?.millisecondsSinceEpoch,
    };
    return map;
  }

  static PrivateGroupSchema fromMap(Map<String, dynamic> e) {
    var privateGroupSchema = PrivateGroupSchema(
      id: e['id'],
      groupId: e['group_id'],
      name: e['name'],
      version: e['version'],
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
      count: e['count'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      createAt: e['create_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['create_at']) : null,
      updateAt: e['update_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['update_at']) : null,
    );

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormat(e['options']);
      privateGroupSchema.options = PrivateGroupOptionSchema.fromMap(options ?? Map());
    }

    return privateGroupSchema;
  }

  String get ownerPublicKey {
    String owner;
    int index = groupId.lastIndexOf('.');
    owner = groupId.substring(0, index);

    return owner;
  }

  @override
  String toString() {
    return 'PrivateGroupSchema { id: $id, groupId: $groupId, name: $name, version: $version, count: $count, avatar: ${avatar?.path}, isTop: $isTop, createAt: $createAt, updateAt: $updateAt }';
  }
}
