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
  //
  // bool isSameByData(DeviceInfoSchema? d1, DeviceInfoSchema? d2) {
  //   if (d1 == null || d2 == null || d1.data == null || d2.data == null || d1.data!.isEmpty || d2.data!.isEmpty) return false;
  //   return d1.appName == d2.appName && d1.appVersion == d2.appVersion && d1.platform == d2.platform && d1.platformVersion == d2.platformVersion;
  // }
  //
  // bool isSameByDataVersion(DeviceInfoSchema? d1, DeviceInfoSchema? d2) {
  //   if (d1 == null || d2 == null || d1.dataVersion == null || d2.dataVersion == null || d1.dataVersion!.isEmpty || d2.dataVersion!.isEmpty) return false;
  //   return d1.dataVersion == d2.dataVersion;
  // }

  // TODO:GG 其他兼容 做成func
  static const List<String> piecePlatforms = [PlatformName.android, PlatformName.ios];
  static const int pieceDeviceVersionMin = 224;
}
