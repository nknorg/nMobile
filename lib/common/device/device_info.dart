import 'dart:async';

import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoStorage _deviceInfoStorage = DeviceInfoStorage();

  DeviceInfoCommon();

  Future<DeviceInfoSchema?> addOrUpdate(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactId == 0) return null;
    DeviceInfoSchema? exist = await _deviceInfoStorage.queryByDeviceId(schema.contactId, schema.deviceId);
    if (exist != null) {
      if (schema.data == null || schema.data!.isEmpty) {
        return exist;
      }
      bool success = await _deviceInfoStorage.update(schema.contactId, schema.data!, Uuid().v4());
      return success ? schema : exist;
    }
    schema.createAt = schema.createAt ?? DateTime.now();
    schema.updateAt = schema.updateAt ?? DateTime.now();
    schema.dataVersion = Uuid().v4();
    DeviceInfoSchema? added = await _deviceInfoStorage.insert(schema);
    return added;
  }

  Future<DeviceInfoSchema?> queryLatest(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    return await _deviceInfoStorage.queryLatest(contactId);
  }
}
