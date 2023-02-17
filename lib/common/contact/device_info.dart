import 'dart:async';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoCommon();

  String getDeviceProfile({DeviceInfoSchema? deviceInfo}) {
    String appName = (deviceInfo != null) ? deviceInfo.appName : Settings.appName;
    String appVersion = (deviceInfo != null) ? deviceInfo.appVersion.toString() : Global.build;
    String platform = (deviceInfo != null) ? deviceInfo.platform : PlatformName.get();
    String platformVersion = (deviceInfo != null) ? deviceInfo.platformVersion.toString() : Global.deviceVersion;
    String deviceId = (deviceInfo != null) ? (deviceInfo.deviceId ?? "") : Global.deviceId;
    return "$appName:$appVersion:$platform:$platformVersion:$deviceId";
  }

  Future<DeviceInfoSchema?> getMe({String? clientAddress, bool canAdd = false, bool fetchDeviceToken = false}) async {
    clientAddress = clientAddress ?? clientCommon.address;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    String appName = Settings.appName;
    String appVersion = Global.build;
    String platform = PlatformName.get();
    String platformVersion = Global.deviceVersion;
    DeviceInfoSchema? deviceInfo = await queryByDeviceId(clientAddress, Global.deviceId);
    if (deviceInfo == null) {
      if (canAdd) {
        deviceInfo = await set(DeviceInfoSchema(contactAddress: clientAddress, deviceId: Global.deviceId, data: {
          'appName': appName,
          'appVersion': appVersion,
          'platform': platform,
          'platformVersion': platformVersion,
        }));
      } else {
        return null;
      }
    } else {
      bool sameProfile = (appName == deviceInfo.appName) && (appVersion == deviceInfo.appVersion.toString()) && (platform == deviceInfo.platform) && (platformVersion == deviceInfo.platformVersion.toString());
      if (!sameProfile) {
        deviceInfo = await set(DeviceInfoSchema(contactAddress: deviceInfo.contactAddress, deviceId: deviceInfo.deviceId, data: {
          'appName': appName,
          'appVersion': appVersion,
          'platform': platform,
          'platformVersion': platformVersion,
          'deviceToken': deviceInfo.deviceToken,
        }));
      }
    }
    if (deviceInfo == null) return null;
    if (fetchDeviceToken) {
      // SUPPORT:START
      String? deviceToken = (await DeviceToken.get()) ?? ((await contactCommon.getMe())?.deviceToken);
      // SUPPORT:END
      if ((deviceToken?.isNotEmpty == true) && (deviceInfo.deviceToken != deviceToken)) {
        bool success = await setDeviceToken(deviceInfo.contactAddress, deviceInfo.deviceId, deviceToken);
        if (success) deviceInfo.data?["deviceToken"] = deviceToken;
      }
    }
    return deviceInfo;
  }

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

  Future<List<String>> getDeviceTokenList(String? contactAddress, {int max = 3, int days = 3}) async {
    if (contactAddress == null || contactAddress.isEmpty) return [];
    List<String> tokens = [];
    int minUpdateAt = DateTime.now().subtract(Duration(days: days)).millisecond;
    List<DeviceInfoSchema> schemaList = await queryLatestList(contactAddress, limit: max);
    for (int i = 0; i < schemaList.length; i++) {
      DeviceInfoSchema schema = schemaList[i];
      if (tokens.isNotEmpty) {
        if ((schema.updateAt ?? 0) < minUpdateAt) continue;
      }
      String deviceToken = schema.deviceToken ?? "";
      if (deviceToken.isNotEmpty) {
        tokens.add(deviceToken);
      }
    }
    // SUPPORT:START
    if (tokens.isEmpty) {
      ContactSchema? contact = await contactCommon.queryByClientAddress(contactAddress);
      String deviceToken = contact?.deviceToken ?? "";
      if (deviceToken.isNotEmpty) {
        tokens.add(deviceToken);
      }
    }
    // SUPPORT:END
    return tokens;
  }

  Future<bool> setDeviceToken(String? contactAddress, String? deviceId, String? deviceToken) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return false;
    DeviceInfoSchema? schema = await queryByDeviceId(contactAddress, deviceId);
    if (schema == null) {
      schema = await set(DeviceInfoSchema(
        contactAddress: contactAddress,
        deviceId: deviceId,
        data: {'deviceToken': deviceToken},
      ));
      return schema != null;
    }
    if (schema.data?["deviceToken"]?.toString() == deviceToken) return true;
    if (schema.data == null) schema.data = new Map<String, dynamic>();
    schema.data?["deviceToken"] = deviceToken;
    return (await set(schema)) != null;
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    return await DeviceInfoStorage.instance.queryLatest(contactAddress);
  }

  Future<List<DeviceInfoSchema>> queryLatestList(String? contactAddress, {int offset = 0, int limit = 20}) async {
    if (contactAddress == null || contactAddress.isEmpty) return [];
    return await DeviceInfoStorage.instance.queryLatestList(contactAddress, offset: offset, limit: limit);
  }

  /*Future<List<DeviceInfoSchema>> queryListLatest(List<String>? contactAddressList) async {
    if (contactAddressList == null || contactAddressList.isEmpty) return [];
    return await DeviceInfoStorage.instance.queryListLatest(contactAddressList);
  }*/

  Future<bool> updateLatest(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return false;
    return await DeviceInfoStorage.instance.setUpdate(contactAddress, deviceId, updateAt: DateTime.now().millisecondsSinceEpoch);
  }

  Future<DeviceInfoSchema?> queryByDeviceId(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return null;
    return await DeviceInfoStorage.instance.queryByDeviceId(contactAddress, deviceId);
  }

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

}
