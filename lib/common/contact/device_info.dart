import 'dart:async';

import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoStorage _deviceInfoStorage = DeviceInfoStorage();

  DeviceInfoCommon();

  Future<DeviceInfoSchema?> set(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactAddress.isEmpty) return null;
    DeviceInfoSchema? exist = await _deviceInfoStorage.queryByDeviceId(schema.contactAddress, schema.deviceId);
    if (exist == null) {
      schema.createAt = schema.createAt ?? DateTime.now().millisecondsSinceEpoch;
      schema.updateAt = schema.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      exist = await _deviceInfoStorage.insert(schema);
    } else {
      bool success = await _deviceInfoStorage.update(exist.id, schema.data);
      if (success) {
        exist.updateAt = DateTime.now().millisecondsSinceEpoch;
        exist.data = schema.data;
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    return await _deviceInfoStorage.queryLatest(contactAddress);
  }

  Future<List<DeviceInfoSchema>> queryListLatest(List<String>? contactAddressList) async {
    if (contactAddressList == null || contactAddressList.isEmpty) return [];
    return await _deviceInfoStorage.queryListLatest(contactAddressList);
  }

  // DeviceInfoSchema createMe() {
  //   return DeviceInfoSchema(
  //     contactId: 1,
  //     createAt: DateTime.now(),
  //     updateAt: DateTime.now(),
  //     deviceId: Global.deviceId,
  //     data: {
  //       'appName': Settings.appName,
  //       'appVersion': Global.build,
  //       'platform': PlatformName.get(),
  //       'platformVersion': Global.deviceVersion,
  //     },
  //   );
  // }

  static bool isDeviceTokenNoCombineEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  static bool isMsgReadEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  static bool isMsgPieceEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  static bool isMsgImageEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  static bool isBurningUpdateAtEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  // static bool isTopicPermissionEnable(String? platform, int? appVersion) {
  //   if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
  //   bool platformOK = false, versionOk = false;
  //   platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
  //   versionOk = appVersion >= 224;
  //   return platformOK && versionOk;
  // }
}
