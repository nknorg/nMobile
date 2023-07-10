import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceInfoCommon with Tag {
  DeviceInfoCommon();

  String getDeviceProfile({DeviceInfoSchema? deviceInfo}) {
    String appName = ((deviceInfo != null) && deviceInfo.appName.isNotEmpty) ? deviceInfo.appName : Settings.appName;
    String appVersion = ((deviceInfo != null) && deviceInfo.appVersion.toString().isNotEmpty) ? deviceInfo.appVersion.toString() : Settings.build;
    String platform = ((deviceInfo != null) && deviceInfo.platform.isNotEmpty) ? deviceInfo.platform : DevicePlatformName.get();
    String platformVersion = ((deviceInfo != null) && deviceInfo.platformVersion.toString().isNotEmpty) ? deviceInfo.platformVersion.toString() : Settings.deviceVersion;
    String deviceId = ((deviceInfo != null) && deviceInfo.deviceId.isNotEmpty) ? deviceInfo.deviceId : Settings.deviceId;
    return "$appName:$appVersion:$platform:$platformVersion:$deviceId";
  }

  Future<DeviceInfoSchema?> getMe({
    String? selfAddress,
    bool canAdd = false,
    bool fetchDeviceToken = false,
    bool refreshOnlineAt = false,
  }) async {
    selfAddress = selfAddress ?? clientCommon.address;
    if (selfAddress == null || selfAddress.isEmpty) return null;
    String appName = Settings.appName;
    String appVersion = Settings.build;
    String platform = DevicePlatformName.get();
    String platformVersion = Settings.deviceVersion;
    Map<String, dynamic> newData = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
    DeviceInfoSchema? deviceInfo = await query(selfAddress, Settings.deviceId);
    if (deviceInfo == null) {
      if (!canAdd) return null;
      deviceInfo = await add(DeviceInfoSchema(
        contactAddress: selfAddress,
        deviceId: Settings.deviceId,
        onlineAt: 0,
        data: newData,
      ));
    } else {
      bool sameProfile = (appName == deviceInfo.appName) && (appVersion == deviceInfo.appVersion.toString()) && (platform == deviceInfo.platform) && (platformVersion == deviceInfo.platformVersion.toString());
      if (!sameProfile) {
        logger.i("$TAG - getMe - setData - newData:$newData - oldData:${deviceInfo.data}");
        bool success = await setProfile(deviceInfo.contactAddress, deviceInfo.deviceId, newData);
        if (success) deviceInfo.data = newData;
      }
    }
    if (deviceInfo == null) return null;
    if (fetchDeviceToken) {
      String? deviceToken = await DeviceToken.get();
      if ((deviceToken?.isNotEmpty == true) && (deviceInfo.deviceToken != deviceToken)) {
        logger.i("$TAG - getMe - deviceToken diff - new:$deviceToken - old:${deviceInfo.deviceToken}");
        bool success = await setDeviceToken(deviceInfo.contactAddress, deviceInfo.deviceId, deviceToken);
        if (success) deviceInfo.deviceToken = deviceToken ?? "";
      }
    }
    if (refreshOnlineAt) {
      int nowAt = DateTime.now().millisecondsSinceEpoch;
      logger.i("$TAG - getMe - online refresh - new:$nowAt - old:${deviceInfo.onlineAt}");
      bool success = await setOnlineAt(deviceInfo.contactAddress, deviceInfo.deviceId, onlineAt: nowAt);
      if (success) deviceInfo.onlineAt = nowAt;
    }
    logger.d("$TAG - getMe - fetchDeviceToken:$fetchDeviceToken - deviceInfo:$deviceInfo");
    return deviceInfo;
  }

  Future<DeviceInfoSchema?> add(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactAddress.isEmpty) return null;
    if (schema.deviceId.isEmpty) return null;
    return await DeviceInfoStorage.instance.insert(schema);
  }

  Future<DeviceInfoSchema?> query(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    return await DeviceInfoStorage.instance.query(contactAddress, deviceId);
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    return await DeviceInfoStorage.instance.queryLatest(contactAddress);
  }

  Future<List<DeviceInfoSchema>> queryListLatest(String? contactAddress, {int offset = 0, final limit = 20}) async {
    if (contactAddress == null || contactAddress.isEmpty) return [];
    return await DeviceInfoStorage.instance.queryListLatest(contactAddress, offset: offset, limit: limit);
  }

  Future<List<DeviceInfoSchema>> queryListByContactAddress(List<String>? contactAddressList) async {
    if (contactAddressList == null || contactAddressList.isEmpty) return [];
    return await DeviceInfoStorage.instance.queryListByContactAddress(contactAddressList);
  }

  Future<List<String>> queryDeviceTokenList(
    String? contactAddress, {
    int max = Settings.maxCountPushDevices,
    int days = Settings.timeoutDeviceTokensDay,
  }) async {
    if (contactAddress == null || contactAddress.isEmpty) return [];
    List<String> tokens = [];
    List<DeviceInfoSchema> devices = await queryListLatest(contactAddress, limit: max);
    int minOnlineAt = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    for (int i = 0; i < devices.length; i++) {
      DeviceInfoSchema schema = devices[i];
      String deviceToken = schema.deviceToken.trim();
      if (deviceToken.isEmpty) continue;
      if (tokens.isNotEmpty) {
        if (schema.onlineAt < minOnlineAt) continue;
      }
      if (!tokens.contains(deviceToken)) {
        tokens.add(deviceToken);
      }
    }
    logger.d("$TAG - queryDeviceTokenList - count:${tokens.length}/${devices.length} - tokens:$tokens - contactAddress:$contactAddress");
    return tokens;
  }

  Future<bool> setDeviceToken(String? contactAddress, String? deviceId, String? deviceToken) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    return await DeviceInfoStorage.instance.setDeviceToken(contactAddress, deviceId, deviceToken ?? "");
  }

  Future<bool> setOnlineAt(String? contactAddress, String? deviceId, {int? onlineAt}) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    return await DeviceInfoStorage.instance.setOnlineAt(contactAddress, deviceId, onlineAt: onlineAt);
  }

  Future<bool> setProfile(String? contactAddress, String? deviceId, Map<String, dynamic>? added) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, added);
    logger.d("$TAG - setProfile - success:${data != null} - add:$added - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setPingAt(String? contactAddress, String? deviceId, {int? pingAt}) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "pingAt": pingAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setPingAt - success:${data != null} - pingAt:$pingAt - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setPongAt(String? contactAddress, String? deviceId, {int? pongAt}) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "pongAt": pongAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setPongAt - success:${data != null} - pongAt:$pongAt - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setContactProfileResponseInfo(String? contactAddress, String? deviceId, String? version, {int? timeAt}) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "contactProfileResponseVersion": version,
      "contactProfileResponseAt": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setContactProfileResponseInfo - success:${data != null} - version:$version - timeAt:$timeAt - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setDeviceInfoResponseAt(String? contactAddress, String? deviceId, {int? timeAt}) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "deviceInfoResponseAt": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setDeviceInfoResponseAt - success:${data != null} - timeAt:$timeAt - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<String?> joinQueueIdsByAddressDeviceId(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    DeviceInfoSchema? device = await query(contactAddress, deviceId);
    return joinQueueIdsByDevice(device);
  }

  String? joinQueueIdsByDevice(DeviceInfoSchema? device) {
    if (device == null) return null;
    int latestSendMessageQueueId = device.latestSendMessageQueueId;
    int latestReceivedMessageQueueId = device.latestReceivedMessageQueueId;
    List<int> lostReceiveMessageQueueIds = device.lostReceiveMessageQueueIds;
    return joinQueueIds(latestSendMessageQueueId, latestReceivedMessageQueueId, lostReceiveMessageQueueIds, device.deviceId);
  }

  String? joinQueueIds(int latestSendMessageQueueId, int latestReceivedMessageQueueId, List<int> lostReceiveMessageQueueIds, String deviceId) {
    if (deviceId.isEmpty) return null;
    return "${latestSendMessageQueueId}_::_${latestReceivedMessageQueueId}_::_${lostReceiveMessageQueueIds.join(".")}_::_$deviceId";
  }

  List<dynamic> splitQueueIds(String? queueIds) {
    if (queueIds == null || queueIds.isEmpty) return [0, 0, [], ""];
    List<String> splits = queueIds.split("_::_");
    if (splits.length < 4) return [0, 0, [], ""];
    int latestSendMessageQueueId = int.tryParse(splits[0].toString()) ?? 0;
    int latestReceivedMessageQueueId = int.tryParse(splits[1].toString()) ?? 0;
    List<int> lostReceiveMessageQueueIds = splits[2].split(".").map((e) => int.tryParse(e.toString()) ?? 0).toList()..removeWhere((element) => element == 0);
    String deviceId = splits[3].toString();
    return [latestSendMessageQueueId, latestReceivedMessageQueueId, lostReceiveMessageQueueIds, deviceId];
  }

  Future<bool> setLatestSendMessageQueueId(String? contactAddress, String? deviceId, int queueId) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "latestSendMessageQueueId": queueId,
    });
    logger.d("$TAG - setLatestSendMessageQueueId - success:${data != null} - queueId:$queueId - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setSendingMessageQueueIds(String? contactAddress, String? deviceId, Map adds, List<int> dels) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setDataItemMapChange(contactAddress, deviceId, "sendingMessageQueueIds", adds, dels);
    logger.d("$TAG - setSendingMessageQueueIds - success:${data != null} - adds:$adds - dels:$dels - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setLatestReceivedMessageQueueId(String? contactAddress, String? deviceId, int queueId) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setData(contactAddress, deviceId, {
      "latestReceivedMessageQueueId": queueId,
    });
    logger.d("$TAG - setLatestReceivedMessageQueueId - success:${data != null} - queueId:$queueId - data:$data - contactAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

  Future<bool> setLostReceiveMessageQueueIds(String? contactAddress, String? deviceId, List<int> adds, List<int> dels) async {
    if (contactAddress == null || contactAddress.isEmpty) return false;
    var data = await DeviceInfoStorage.instance.setDataItemListChange(contactAddress, deviceId, "lostReceiveMessageQueueIds", adds, dels);
    logger.d("$TAG - setLostReceiveMessageQueueIds - success:${data != null} - adds:$adds - dels:$dels - data:$data - clientAddress:$contactAddress - deviceId:$deviceId");
    return data != null;
  }

//  SUPPORT:START
  static bool isMessageQueueEnable(String? platform, int? appVersion) {
    if (platform == null || platform.isEmpty || appVersion == null || appVersion == 0) return false;
    bool platformOK = false, versionOk = false;
    platformOK = (platform == DevicePlatformName.android) || (platform == DevicePlatformName.ios);
    versionOk = appVersion >= 282;
    return platformOK && versionOk;
  }
//  SUPPORT:END

//  SUPPORT:START
  static bool isIOSDeviceVersionLess152({String deviceVersion = ""}) {
    deviceVersion = deviceVersion.isEmpty ? Settings.deviceVersionName : deviceVersion;
    List<String> vList = deviceVersion.split(".");
    String vStr0 = vList.length > 0 ? vList[0] : "";
    String vStr1 = vList.length > 1 ? vList[1] : "";
    int? v0 = int.tryParse(vStr0);
    int? v1 = int.tryParse(vStr1);
    if ((v0 == null) || (v0 >= 16)) return false;
    if ((v0 == 15) && ((v1 == null) || (v1 >= 2))) return false;
    return true;
  }
//  SUPPORT:END
}
