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
  int createAt;
  int updateAt;

  String groupId;
  int type;
  String? version;

  String name;
  int count;
  File? avatar;

  bool joined;
  bool isTop;

  OptionsSchema options = OptionsSchema();
  Map<String, dynamic> data = Map();

  PrivateGroupSchema({
    this.id,
    this.createAt = 0,
    this.updateAt = 0,
    required this.groupId,
    this.type = PrivateGroupType.normal,
    this.version,
    required this.name,
    this.count = 0,
    this.avatar,
    this.joined = false,
    this.isTop = false,
  }) {
    if (createAt == 0) createAt = DateTime.now().millisecondsSinceEpoch;
    if (updateAt == 0) updateAt = DateTime.now().millisecondsSinceEpoch;
  }

  static PrivateGroupSchema? create(String? groupId, String? name, {int? type, bool? joined, String? version}) {
    if (groupId == null || groupId.isEmpty) return null;
    if (name == null || name.isEmpty) name = groupId;
    return PrivateGroupSchema(
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
      groupId: groupId,
      type: type ?? PrivateGroupType.normal,
      name: name,
      version: version,
      joined: joined ?? false,
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
    return data['signature'] ?? "";
  }

  int? get quitCommits {
    return int.tryParse(data["quit_at_version_commits"]?.toString() ?? "");
  }

  Map<String, int> get receivedMessages {
    Map<String, dynamic> values = data['receivedMessages'] ?? Map();
    return values.map((key, value) => MapEntry(key.toString(), int.tryParse(value?.toString() ?? "") ?? 0))..removeWhere((key, value) => key.isEmpty || value == 0);
  }

  int get optionsRequestAt {
    return int.tryParse(data['optionsRequestAt']?.toString() ?? "0") ?? 0;
  }

  String get optionsRequestedVersion {
    return data['optionsRequestedVersion']?.toString() ?? "";
  }

  int get membersRequestAt {
    return int.tryParse(data['membersRequestAt']?.toString() ?? "0") ?? 0;
  }

  String get membersRequestedVersion {
    return data['membersRequestedVersion']?.toString() ?? "";
  }

  Map<String, dynamic> getRawDataMap() {
    Map<String, dynamic> data = Map();
    data['groupId'] = groupId;
    data['type'] = type;
    data['name'] = name;
    data['deleteAfterSeconds'] = options.deleteAfterSeconds;
    return data.sortByKey();
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'create_at': createAt,
      'update_at': updateAt,
      'group_id': groupId,
      'type': type,
      'version': version,
      'name': name,
      'count': count,
      'avatar': Path.convert2Local(avatar?.path),
      'joined': joined ? 1 : 0,
      'is_top': isTop ? 1 : 0,
      'options': jsonEncode(options.toMap()),
      'data': jsonEncode(data),
    };
    return map;
  }

  static PrivateGroupSchema fromMap(Map<String, dynamic> e) {
    var schema = PrivateGroupSchema(
      id: e['id'],
      createAt: e['create_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updateAt: e['update_at'] ?? DateTime.now().millisecondsSinceEpoch,
      groupId: e['group_id'] ?? "",
      type: e['type'] ?? PrivateGroupType.normal,
      version: e['version'],
      name: e['name'] ?? e['group_id'] ?? "",
      count: e['count'] ?? 0,
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
    );
    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormatMap(e['options']);
      schema.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) schema.data.addAll(data);
    }
    return schema;
  }

  @override
  String toString() {
    return 'PrivateGroupSchema{id: $id, createAt: $createAt, updateAt: $updateAt, groupId: $groupId, type: $type, version: $version, name: $name, count: $count, avatar: $avatar, joined: $joined, isTop: $isTop, options: $options, data: $data}';
  }
}
