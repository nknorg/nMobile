import 'dart:convert';
import 'dart:io';

import 'package:nmobile/utils/util.dart';

class DevicePlatformName {
  static const web = "web";
  static const android = "android";
  static const ios = "ios";
  static const window = "window";
  static const mac = "mac";

  static String get() {
    return Platform.isAndroid ? android : (Platform.isIOS ? ios : "");
  }

  static List<String> list() {
    return [web, android, ios, window, mac];
  }
}

class DeviceInfoSchema {
  int? id; // <- id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  String contactAddress; // (required) <-> contact_address
  String deviceId; //  <-> device_id
  String? deviceToken; // <-> device_token

  int onlineAt; // <-> online_at

  Map<String, dynamic>? data; // [*]<-> data[*, appName, appVersion, platform, platformVersion, ...]

  DeviceInfoSchema({
    this.id,
    this.createAt,
    this.updateAt,
    required this.contactAddress,
    required this.deviceId,
    this.deviceToken,
    required this.onlineAt,
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
      String? name = data?['appName']?.toString();
      if (name?.isNotEmpty == true) {
        appName = name;
      }
    }
    return appName ?? "";
  }

  int get appVersion {
    int? appVersion;
    if (data?.isNotEmpty == true) {
      String? version = data?['appVersion']?.toString();
      if (version?.isNotEmpty == true) {
        appVersion = int.tryParse(version ?? "");
      }
    }
    return appVersion ?? 0;
  }

  String get platform {
    String? platform;
    if (data?.isNotEmpty == true) {
      String? name = data?['platform']?.toString();
      if (name?.isNotEmpty == true) {
        platform = name;
      }
    }
    return platform ?? "";
  }

  int get platformVersion {
    int? platformVersion;
    if (data?.isNotEmpty == true) {
      String? version = data?['platformVersion']?.toString();
      if (version?.isNotEmpty == true) {
        platformVersion = int.tryParse(version ?? "");
      }
    }
    return platformVersion ?? 0;
  }

  int get pingAt {
    return int.tryParse(data?['pingAt']?.toString() ?? "0") ?? 0;
  }

  int get pongAt {
    return int.tryParse(data?['pongAt']?.toString() ?? "0") ?? 0;
  }

  String get contactProfileResponseVersion {
    return data?['contactProfileResponseVersion']?.toString() ?? "";
  }

  int get contactProfileResponseAt {
    return int.tryParse(data?['contactProfileResponseAt']?.toString() ?? "0") ?? 0;
  }

  int get deviceInfoResponseAt {
    return int.tryParse(data?['deviceInfoResponseAt']?.toString() ?? "0") ?? 0;
  }

  int get latestSendMessageQueueId {
    return int.tryParse(data?['latestSendMessageQueueId']?.toString() ?? "0") ?? 0;
  }

  Map<int, String> get sendingMessageQueueIds {
    Map<String, dynamic> values = data?['sendingMessageQueueIds'] ?? Map();
    return values.map((key, value) => MapEntry(int.tryParse(key.toString()) ?? 0, value))..removeWhere((key, value) => key == 0);
  }

  int get latestReceivedMessageQueueId {
    return int.tryParse(data?['latestReceivedMessageQueueId']?.toString() ?? "0") ?? 0;
  }

  List<int> get lostReceiveMessageQueueIds {
    List<dynamic> values = data?['lostReceiveMessageQueueIds'] ?? [];
    return values.map((e) => int.tryParse(e.toString()) ?? 0).toList()..removeWhere((element) => element == 0);
  }

  Map<String, dynamic> toMap() {
    if (data == null) {
      data = new Map<String, dynamic>();
    }
    Map<String, dynamic> map = {
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'contact_address': contactAddress,
      'device_id': deviceId,
      'device_token': deviceToken,
      'online_at': onlineAt,
      'data': data != null ? jsonEncode(data) : null,
    };
    return map;
  }

  static DeviceInfoSchema fromMap(Map e) {
    var deviceInfo = DeviceInfoSchema(
      id: e['id'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      contactAddress: e['contact_address'] ?? "",
      deviceId: e['device_id'] ?? "",
      deviceToken: e['device_token'],
      onlineAt: e['online_at'],
    );

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
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
    return 'DeviceInfoSchema{id: $id, createAt: $createAt, updateAt: $updateAt, contactAddress: $contactAddress, deviceId: $deviceId, deviceToken: $deviceToken, onlineAt: $onlineAt, data: $data}';
  }
}
