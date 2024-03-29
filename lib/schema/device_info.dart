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
  int createAt; // <-> create_at
  int updateAt; // <-> update_at

  String contactAddress; // (required) <-> contact_address
  String deviceId; //  <-> device_id
  String deviceToken; // <-> device_token

  int onlineAt; // <-> online_at

  Map<String, dynamic>? data; // [*]<-> data[*, appName, appVersion, platform, platformVersion, ...]

  DeviceInfoSchema({
    this.id,
    this.createAt = 0,
    this.updateAt = 0,
    required this.contactAddress,
    required this.deviceId,
    this.deviceToken = "",
    required this.onlineAt,
    this.data,
  }) {
    if (createAt == 0) createAt = DateTime.now().millisecondsSinceEpoch;
    if (updateAt == 0) updateAt = DateTime.now().millisecondsSinceEpoch;
    if (this.data == null) this.data = Map();
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
    Map<String, dynamic> map = {
      'create_at': createAt,
      'update_at': updateAt,
      'contact_address': contactAddress,
      'device_id': deviceId.replaceAll("\n", "").trim(),
      'device_token': deviceToken.replaceAll("\n", "").trim(),
      'online_at': onlineAt,
      'data': jsonEncode(data ?? Map()),
    };
    return map;
  }

  static DeviceInfoSchema fromMap(Map e) {
    var deviceInfo = DeviceInfoSchema(
      id: e['id'],
      createAt: e['create_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updateAt: e['update_at'] ?? DateTime.now().millisecondsSinceEpoch,
      contactAddress: e['contact_address'] ?? "",
      deviceId: e['device_id']?.replaceAll("\n", "").trim() ?? "",
      deviceToken: e['device_token']?.replaceAll("\n", "").trim() ?? "",
      onlineAt: e['online_at'] ?? 0,
      data: (e['data']?.toString().isNotEmpty == true) ? Util.jsonFormatMap(e['data']) : null,
    );
    return deviceInfo;
  }

  @override
  String toString() {
    return 'DeviceInfoSchema{id: $id, createAt: $createAt, updateAt: $updateAt, contactAddress: $contactAddress, deviceId: $deviceId, deviceToken: $deviceToken, onlineAt: $onlineAt, data: $data}';
  }
}
