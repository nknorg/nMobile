import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceToken {
  static const PREFIX_APNS = "[APNS]:";
  static const PREFIX_FCM = "[FCM]:";
  static const PREFIX_HUAWEI = "[HUAWEI]:";
  static const PREFIX_XIAOMI = "[XIAOMI]:";
  static const PREFIX_OPPO = "[OPPO]:";
  static const PREFIX_VIVO = "[VIVO]:";

  static Future<String?> get() async {
    String token = "";
    if (Platform.isIOS) {
      token = await getAPNS();
    } else if (Platform.isAndroid) {
      // TODO:GG googleServiceEnable ???
      token = await getFCM();
    }
    logger.i("DeviceToken - getToken - $token");
    return token;
  }

  static Future<String> getAPNS() async {
    String? token = await FirebaseMessaging.instance.getAPNSToken();
    // TODO:GG 根据deviceInfo协议来判断是否要拼接
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    token = "$token'__FCMToken__:' $fcmToken";
    logger.i("$DeviceToken - getAPNSToken - $token");
    return token;
  }

  static Future<String> getFCM() async {
    String? token = await FirebaseMessaging.instance.getToken();
    logger.i("$DeviceToken - getFCMToken - $token");
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
    }
    // SUPPORT:START
    if (token.length == 64) {
      return token; // apns
    } else if (token.length > 163) {
      List<String> sList = token.split('__FCMToken__:');
      if (sList.length >= 2) {
        return sList[0].toString();
      }
    }
    // SUPPORT:END
    return "";
  }

  static String splitFCM(String? token) {
    if (token == null || token.isEmpty) return "";
    if (token.startsWith(PREFIX_FCM)) {
      return token.replaceAll(PREFIX_FCM, "");
    }
    // SUPPORT:START
    if (token.length == 163) {
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
