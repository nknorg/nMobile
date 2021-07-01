import 'dart:convert';

import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoSchema {
  int? id; // <- id
  DateTime? createAt; // <-> create_at
  DateTime? updateAt; // <-> update_at
  int contactId; // (required) <-> contact_id
  String? profileVersion; // <-> profile_version
  String? deviceToken; //  <-> device_token
  Map<String, dynamic>? extraInfo; // [*]<-> data[*, appName, appVersion, platform, platformVersion, ...]

  DeviceInfoSchema({
    this.id,
    this.createAt,
    this.updateAt,
    required this.contactId,
    this.profileVersion,
    this.deviceToken,
    this.extraInfo,
  }) {
    if (this.createAt == null) {
      this.createAt = DateTime.now();
    }
    if (this.updateAt == null) {
      this.updateAt = DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    if (extraInfo == null) {
      extraInfo = new Map<String, dynamic>();
    }
    Map<String, dynamic> map = {
      'create_at': createAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'contact_id': contactId,
      'profile_version': profileVersion ?? Uuid().v4(),
      'device_token': deviceToken,
      'data': extraInfo != null ? jsonEncode(extraInfo) : '{}',
    };
    return map;
  }

  static DeviceInfoSchema fromMap(Map e) {
    var deviceInfo = DeviceInfoSchema(
      id: e['id'],
      createAt: e['create_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['create_at']) : null,
      updateAt: e['update_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['update_at']) : null,
      contactId: e['contact_id'] ?? 0,
      profileVersion: e['profile_version'],
      deviceToken: e['device_token'],
    );

    if (e['data'] != null) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (deviceInfo.extraInfo == null) {
        deviceInfo.extraInfo = new Map<String, dynamic>();
      }
      if (data != null) {
        deviceInfo.extraInfo?.addAll(data);
      }
    }
    return deviceInfo;
  }

  String get appName {
    String? appName;
    if (extraInfo != null && extraInfo!.isNotEmpty) {
      String? name = extraInfo!['appName']?.toString();
      if (name?.isNotEmpty == true) {
        appName = name;
      }
    }
    return appName ?? "";
  }

  int get appVersion {
    int? appVersion;
    if (extraInfo != null && extraInfo!.isNotEmpty) {
      String? version = extraInfo!['appVersion']?.toString();
      if ((version?.isNotEmpty == true) && (version is int)) {
        appVersion = int.parse(version!);
      }
    }
    return appVersion ?? 0;
  }

  String get platform {
    String? platform;
    if (extraInfo != null && extraInfo!.isNotEmpty) {
      String? name = extraInfo!['platform']?.toString();
      if (name?.isNotEmpty == true) {
        platform = name;
      }
    }
    return platform ?? "";
  }

  int get platformVersion {
    int? platformVersion;
    if (extraInfo != null && extraInfo!.isNotEmpty) {
      String? version = extraInfo!['platformVersion']?.toString();
      if ((version?.isNotEmpty == true) && (version is int)) {
        platformVersion = int.parse(version!);
      }
    }
    return platformVersion ?? 0;
  }

  @override
  String toString() {
    return 'DeviceInfoSchema{id: $id, createAt: $createAt, updateAt: $updateAt, contactId: $contactId, profileVersion: $profileVersion, deviceToken: $deviceToken, extraInfo: $extraInfo}';
  }
}
