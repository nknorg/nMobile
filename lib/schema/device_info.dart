import 'dart:convert';

import 'package:nmobile/utils/utils.dart';

class DeviceInfoSchema {
  int? id; // <- id
  int contactId; // (required) <-> contact_id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  String? deviceId; //  <-> device_id

  Map<String, dynamic>? data; // [*]<-> data[*, appName, appVersion, platform, platformVersion, ...]

  DeviceInfoSchema({
    this.id,
    this.createAt,
    this.updateAt,
    required this.contactId,
    this.deviceId,
    this.data,
  }) {
    if (this.createAt == null) {
      this.createAt = DateTime.now().millisecondsSinceEpoch;
    }
    if (this.updateAt == null) {
      this.updateAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  String get appName {
    String? appName;
    if (data?.isNotEmpty == true) {
      String? name = data!['appName']?.toString();
      if (name?.isNotEmpty == true) {
        appName = name;
      }
    }
    return appName ?? "";
  }

  int get appVersion {
    int? appVersion;
    if (data?.isNotEmpty == true) {
      String? version = data!['appVersion']?.toString();
      if (version?.isNotEmpty == true) {
        appVersion = int.parse(version!);
      }
    }
    return appVersion ?? 0;
  }

  String get platform {
    String? platform;
    if (data?.isNotEmpty == true) {
      String? name = data!['platform']?.toString();
      if (name?.isNotEmpty == true) {
        platform = name;
      }
    }
    return platform ?? "";
  }

  int get platformVersion {
    int? platformVersion;
    if (data?.isNotEmpty == true) {
      String? version = data!['platformVersion']?.toString();
      if (version?.isNotEmpty == true) {
        platformVersion = int.parse(version!);
      }
    }
    return platformVersion ?? 0;
  }

  Map<String, dynamic> toMap() {
    if (data == null) {
      data = new Map<String, dynamic>();
    }
    Map<String, dynamic> map = {
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'contact_id': contactId,
      'device_id': deviceId,
      'data': (data?.isNotEmpty == true) ? jsonEncode(data) : '{}',
    };
    return map;
  }

  static DeviceInfoSchema fromMap(Map e) {
    var deviceInfo = DeviceInfoSchema(
      id: e['id'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      contactId: e['contact_id'] ?? 0,
      deviceId: e['device_id'],
    );

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (deviceInfo.data == null) {
        deviceInfo.data = new Map<String, dynamic>();
      }
      if (data != null) {
        deviceInfo.data?.addAll(data);
      }
    }
    return deviceInfo;
  }

  @override
  String toString() {
    return 'DeviceInfoSchema{id: $id, createAt: $createAt, updateAt: $updateAt, contactId: $contactId, deviceId: $deviceId, data: $data}';
  }
}
