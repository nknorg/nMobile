import 'dart:io';

import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceToken {
  static const PREFIX_APNS = "[APNS]:";
  static const PREFIX_FCM = "[FCM]:";
  static const PREFIX_HUAWEI = "[HUAWEI]:";
  static const PREFIX_XIAOMI = "[XIAOMI]:";
  static const PREFIX_OPPO = "[OPPO]:";
  static const PREFIX_VIVO = "[VIVO]:";

  static Future<String?> get({String? platform, int? appVersion}) async {
    String? token;
    if (Platform.isIOS) {
      token = await getAPNS(platform: platform, appVersion: appVersion);
    } else if (Platform.isAndroid) {
      if (await Common.isGoogleServiceAvailable()) {
        // chinese mobile phone maybe support google service, but token is null
        token = await getFCM(platform: platform, appVersion: appVersion);
      } else {
        // other
      }
    }
    logger.i("DeviceToken - getToken - $token");
    return token;
  }

  static Future<String> getAPNS({String? platform, int? appVersion}) async {
    String? token = await Common.getAPNSToken();
    if (DeviceInfoCommon.isDeviceTokenNoCombineEnable(platform, appVersion)) {
      if (token?.isNotEmpty == true) {
        token = PREFIX_APNS + token!;
      }
    }
    return token ?? "";
  }

  static Future<String> getFCM({String? platform, int? appVersion}) async {
    String? token = await Common.getFCMToken();
    if (DeviceInfoCommon.isDeviceTokenNoCombineEnable(platform, appVersion)) {
      if (token?.isNotEmpty == true) {
        token = PREFIX_FCM + token!;
      }
    }
    return token ?? "";
  }

  static Future<String?> getHuaWei() async {
    return null;
  }

  static Future<String?> getXiaoMi() async {
    return null;
  }

  static Future<String?> getOPPO() async {
    return null;
  }

  static Future<String?> getVIVO() async {
    return null;
  }

  static String splitAPNS(String? token) {
    if (token == null || token.isEmpty) return "";
    if (token.startsWith(PREFIX_APNS)) {
      return token.replaceAll(PREFIX_APNS, "");
    } else if (token.startsWith(PREFIX_FCM) || token.startsWith(PREFIX_HUAWEI) || token.startsWith(PREFIX_XIAOMI) || token.startsWith(PREFIX_OPPO) || token.startsWith(PREFIX_VIVO)) {
      return "";
    }
    // SUPPORT:START
    if (token.contains('__FCMToken__:')) {
      List<String> sList = token.split('__FCMToken__:');
      if (sList.length >= 2) {
        return sList[0].toString();
      }
    } else if (token.length == 64) {
      return token; // apns
    }
    // SUPPORT:END
    return "";
  }

  static String splitFCM(String? token) {
    if (token == null || token.isEmpty) return "";
    if (token.startsWith(PREFIX_FCM)) {
      return token.replaceAll(PREFIX_FCM, "");
    } else if (token.startsWith(PREFIX_APNS) || token.startsWith(PREFIX_HUAWEI) || token.startsWith(PREFIX_XIAOMI) || token.startsWith(PREFIX_OPPO) || token.startsWith(PREFIX_VIVO)) {
      return "";
    }
    // SUPPORT:START
    if (token.contains('__FCMToken__:')) {
      List<String> sList = token.split('__FCMToken__:');
      if (sList.length >= 2) {
        return sList[1].toString();
      }
    } else if (token.length == 163) {
      return token; // fcm
    }
    // SUPPORT:END
    return "";
  }

  static String splitHuaWei(String? token) {
    return "";
  }

  static String splitXiaoMi(String? token) {
    return "";
  }

  static String splitOPPO(String? token) {
    return "";
  }

  static String splitVIVO(String? token) {
    return "";
  }
}
