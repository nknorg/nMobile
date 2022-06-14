import 'dart:async';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoCommon();

  Future<DeviceInfoSchema?> set(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactAddress.isEmpty) return null;
    DeviceInfoSchema? exist = await queryByDeviceId(schema.contactAddress, schema.deviceId);
    if (exist == null) {
      schema.createAt = schema.createAt ?? DateTime.now().millisecondsSinceEpoch;
      schema.updateAt = schema.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      exist = await DeviceInfoStorage.instance.insert(schema);
    } else {
      bool success = await DeviceInfoStorage.instance.setData(exist.id, schema.data);
      if (success) {
        exist.data = schema.data;
        exist.updateAt = DateTime.now().millisecondsSinceEpoch;
      }
    }
    return exist;
  }

  String getDeviceProfile() {
    String appName = Settings.appName;
    String appVersion = Global.build;
    String platform = PlatformName.get();
    String platformVersion = Global.deviceVersion;
    String deviceId = Global.deviceId;
    return "$appName:$appVersion:$platform:$platformVersion:$deviceId";
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    return await DeviceInfoStorage.instance.queryLatest(contactAddress);
  }

  Future<List<DeviceInfoSchema>> queryListLatest(List<String>? contactAddressList) async {
    if (contactAddressList == null || contactAddressList.isEmpty) return [];
    return await DeviceInfoStorage.instance.queryListLatest(contactAddressList);
  }

  Future<bool> updateLatest(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return false;
    return await DeviceInfoStorage.instance.setUpdate(contactAddress, deviceId, updateAt: DateTime.now().millisecondsSinceEpoch);
  }

  Future<DeviceInfoSchema?> queryByDeviceId(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return null;
    return await DeviceInfoStorage.instance.queryByDeviceId(contactAddress, deviceId);
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

  static bool isIOSDeviceVersionLess152({String deviceVersion = ""}) {
    deviceVersion = deviceVersion.isEmpty ? Global.deviceVersionName : deviceVersion;
    List<String> vList = deviceVersion.split(".");
    String vStr0 = vList.length > 0 ? vList[0] : "";
    String vStr1 = vList.length > 1 ? vList[1] : "";
    int? v0 = int.tryParse(vStr0);
    int? v1 = int.tryParse(vStr1);
    if ((v0 == null) || (v0 >= 16)) return false;
    if ((v0 == 15) && ((v1 == null) || (v1 >= 2))) return false;
    return true;
  }

  static bool isDeviceTokenNoCombineEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  //  SUPPORT:START
  static bool isMsgReadEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }
  //  SUPPORT:END

  //  SUPPORT:START
  static bool isMsgPieceEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }
  //  SUPPORT:END

  //  SUPPORT:START
  static bool isMsgImageEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }
  //  SUPPORT:END

  //  SUPPORT:START
  static bool isBurningUpdateAtEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }
//  SUPPORT:END

  // static bool isTopicPermissionEnable(String? platform, int? appVersion) {
  //   if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
  //   bool platformOK = false, versionOk = false;
  //   platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
  //   versionOk = appVersion >= 224;
  //   return platformOK && versionOk;
  // }
}
