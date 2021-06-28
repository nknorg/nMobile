import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceToken {
  static const PREFIX_APNS = "[APNS]:";
  static const PREFIX_FCM = "[FCM]:";
  static const PREFIX_HUAWEI = "[HUAWEI]:";
  static const PREFIX_XIAOMI = "[XIAOMI]:";
  static const PREFIX_OPPO = "[OPPO]:";
  static const PREFIX_VIVO = "[VIVO]:";

  static Future<String?> getAPNSToken() async {
    String? token = await FirebaseMessaging.instance.getAPNSToken();
    logger.i("$DeviceToken - getAPNSToken - $token");
    return token;
  }

  static Future<String?> getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    logger.i("$DeviceToken - getFCMToken - $token");
    return token;
  }

  static Future<String?> getHuaWeiToken() async {
    return null;
  }

  static Future<String?> getXiaoMiToken() async {
    return null;
  }

  static Future<String?> getOPPOToken() async {
    return null;
  }

  static Future<String?> getVIVOToken() async {
    return null;
  }

  static String splitAPNSToken(String? token) {
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

  static String splitFCMToken(String? token) {
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

  static String splitHuaWeiToken(String? token) {
    return "";
  }

  static String splitXiaoMiToken(String? token) {
    return "";
  }

  static String splitOPPOToken(String? token) {
    return "";
  }

  static String splitVIVOToken(String? token) {
    return "";
  }
}
