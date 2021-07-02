import 'dart:async';

import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';

import '../settings.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoStorage _deviceInfoStorage = DeviceInfoStorage();

  DeviceInfoCommon();

  Future<DeviceInfoSchema?> add(DeviceInfoSchema? schema, {bool replace = false}) async {
    if (schema == null || schema.contactId == 0) return null;
    if (replace) {
      DeviceInfoSchema? exist = await _deviceInfoStorage.queryByDeviceId(schema.contactId, schema.deviceId);
      if (exist != null) {
        bool success = await _deviceInfoStorage.update(schema.contactId, schema.data);
        return success ? schema : exist;
      }
    }
    schema.createAt = schema.createAt ?? DateTime.now();
    schema.updateAt = schema.updateAt ?? DateTime.now();
    DeviceInfoSchema? added = await _deviceInfoStorage.insert(schema);
    return added;
  }

  Future<DeviceInfoSchema?> queryLatest(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    return await _deviceInfoStorage.queryLatest(contactId);
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

  bool isMsgPieceEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }

  bool isBurningUpdateTimeEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == PlatformName.android) || (platform == PlatformName.ios);
    versionOk = appVersion >= 224;
    return platformOK && versionOk;
  }
}
