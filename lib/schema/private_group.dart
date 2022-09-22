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
  int? id;
  String groupId;
  String name;
  int? type;
  String? version;
  bool joined = false;

  int? createAt;
  int? updateAt;
  bool isTop = false;
  int? count;
  File? avatar;

  OptionsSchema? options;
  Map<String, dynamic>? data;

  PrivateGroupSchema({
    this.id,
    required this.groupId,
    required this.name,
    this.type = PrivateGroupType.normal,
    this.version,
    this.joined = false,
    this.createAt,
    this.updateAt,
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

  static PrivateGroupSchema? create(String? groupId, String? name, {int? type, bool? joined, String? version}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (name == null || name.isEmpty) name = groupId;
    return PrivateGroupSchema(
      groupId: groupId,
      name: name,
      type: type ?? PrivateGroupType.normal,
      joined: joined ?? false,
      version: version,
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String get ownerPublicKey {
    int index = groupId.lastIndexOf('.');
    if (index < 0) return '';
    return groupId.substring(0, index);
  }

  String? get displayAvatarPath {
    String? avatarLocalPath = avatar?.path;
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return null;
    }
    String? completePath = Path.convert2Complete(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
      return null;
    }
    return completePath;
  }

  Future<File?> get displayAvatarFile async {
    String? completePath = displayAvatarPath;
    if (completePath == null || completePath.isEmpty) {
      return Future.value(null);
    }

    File avatarFile = File(completePath);
    bool exits = await avatarFile.exists();
    if (!exits) {
      return Future.value(null);
    }
    return avatarFile;
  }

  String get signature {
    return data?['signature'] ?? "";
  }

  void setSignature(String? signature) {
    if (data == null) data = Map();
    data?['signature'] = signature;
  }

  int get optionsRequestAt {
    return int.tryParse(data?['optionsRequestAt']?.toString() ?? "0") ?? 0;
  }

  void setOptionsRequestAt(int? timeAt) {
    if (data == null) data = Map();
    data?['optionsRequestAt'] = timeAt;
  }

  String get optionsRequestedVersion {
    return data?['optionsRequestedVersion']?.toString() ?? "";
  }

  void setOptionsRequestedVersion(String? version) {
    if (data == null) data = Map();
    data?['optionsRequestedVersion'] = version;
  }

  int get membersRequestAt {
    return int.tryParse(data?['membersRequestAt']?.toString() ?? "0") ?? 0;
  }

  void setMembersRequestAt(int? timeAt) {
    if (data == null) data = Map();
    data?['membersRequestAt'] = timeAt;
  }

  String get membersRequestedVersion {
    return data?['membersRequestedVersion']?.toString() ?? "";
  }

  void setMembersRequestedVersion(String? version) {
    if (data == null) data = Map();
    data?['membersRequestedVersion'] = version;
  }

  Map<String, dynamic> getRawDataMap() {
    Map<String, dynamic> data = Map();
    data['groupId'] = groupId;
    data['name'] = name;
    data['type'] = type ?? PrivateGroupType.normal;
    data['deleteAfterSeconds'] = options?.deleteAfterSeconds;
    return data.sortByKey();
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'group_id': groupId,
      'name': name,
      'type': type ?? PrivateGroupType.normal,
      'version': version,
      'joined': joined ? 1 : 0,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
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
      groupId: e['group_id'] ?? "",
      name: e['name'] ?? "",
      type: e['type'] ?? PrivateGroupType.normal,
      version: e['version'],
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      createAt: e['create_at'],
      updateAt: e['update_at'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      count: e['count'],
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
    );

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormatMap(e['options']);
      schema.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (schema.options == null) {
      schema.options = OptionsSchema();
    }

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
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
