import 'dart:io';

import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';

class DeviceToken {
  static const PREFIX_APNS = "[APNS]:";
  static const PREFIX_FCM = "[FCM]:";

  static Future<String?> get() async {
    String? token;
    if (Platform.isIOS) {
      token = await getAPNS();
    } else if (Platform.isAndroid) {
      token = await getFCM();
    }
    if (token?.isNotEmpty == true) {
      logger.i("DeviceToken - getToken - $token");
    } else {
      logger.w("DeviceToken - getToken null");
    }
    return token;
  }

  static Future<String?> getAPNS() async {
    String? token = await Common.getAPNSToken();
    if (token?.isNotEmpty == true) {
      return PREFIX_APNS + token!;
    }
    return null;
  }

  static Future<String?> getFCM() async {
    String? token = await Common.getFCMToken();
    if (token?.isNotEmpty == true) {
      return PREFIX_FCM + token!;
    }
    return null;
  }

  static String splitAPNS(String? token) {
    if (token == null || token.isEmpty) return "";
    if (token.startsWith(PREFIX_APNS)) {
      return token.replaceAll(PREFIX_APNS, "");
    }
    return "";
  }

  static String splitFCM(String? token) {
    if (token == null || token.isEmpty) return "";
    if (token.startsWith(PREFIX_FCM)) {
      return token.replaceAll(PREFIX_FCM, "");
    }
    return "";
  }
}
