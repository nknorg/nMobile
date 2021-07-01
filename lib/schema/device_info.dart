import 'dart:convert';

import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoSchema {
  int? id; // <- id
  DateTime? createAt; // <-> create_at
  DateTime? updateAt; // <-> update_at
  int contactId; // (required) <-> contact_id
  String? deviceId; //  <-> device_id
  Map<String, dynamic>? data; // [*]<-> data[*, appName, appVersion, platform, platformVersion, ...]
  String? dataVersion; // <-> data_version

  DeviceInfoSchema({
    this.id,
    this.createAt,
    this.updateAt,
    required this.contactId,
    this.deviceId,
    this.data,
    this.dataVersion,
  }) {
    if (this.createAt == null) {
      this.createAt = DateTime.now();
    }
    if (this.updateAt == null) {
      this.updateAt = DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    if (data == null) {
      data = new Map<String, dynamic>();
    }
    Map<String, dynamic> map = {
      'create_at': createAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'contact_id': contactId,
      'device_id': deviceId,
      'data': data != null ? jsonEncode(data) : '{}',
      'data_version': dataVersion ?? Uuid().v4(),
    };
    return map;
  }

  static DeviceInfoSchema fromMap(Map e) {
    var deviceInfo = DeviceInfoSchema(
      id: e['id'],
      createAt: e['create_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['create_at']) : null,
      updateAt: e['update_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['update_at']) : null,
      contactId: e['contact_id'] ?? 0,
      deviceId: e['device_id'],
      dataVersion: e['data_version'],
    );

    if (e['data'] != null) {
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

  String get appName {
    String? appName;
    if (data != null && data!.isNotEmpty) {
      String? name = data!['appName']?.toString();
      if (name?.isNotEmpty == true) {
        appName = name;
      }
    }
    return appName ?? "";
  }

  int get appVersion {
    int? appVersion;
    if (data != null && data!.isNotEmpty) {
      String? version = data!['appVersion']?.toString();
      if ((version?.isNotEmpty == true) && (version is int)) {
        appVersion = int.parse(version!);
      }
    }
    return appVersion ?? 0;
  }

  String get platform {
    String? platform;
    if (data != null && data!.isNotEmpty) {
      String? name = data!['platform']?.toString();
      if (name?.isNotEmpty == true) {
        platform = name;
      }
    }
    return platform ?? "";
  }

  int get platformVersion {
    int? platformVersion;
    if (data != null && data!.isNotEmpty) {
      String? version = data!['platformVersion']?.toString();
      if ((version?.isNotEmpty == true) && (version is int)) {
        platformVersion = int.parse(version!);
      }
    }
    return platformVersion ?? 0;
  }

  @override
  String toString() {
    return 'DeviceInfoSchema{id: $id, createAt: $createAt, updateAt: $updateAt, contactId: $contactId, dataVersion: $dataVersion, deviceId: $deviceId, data: $data}';
  }
}
