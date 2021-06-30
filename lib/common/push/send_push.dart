import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';

class SendPush {
  static Future<bool> send(String deviceToken, String title, String content) async {
    String apns = DeviceToken.splitAPNS(deviceToken);
    if (apns.isNotEmpty) {
      return sendAPNS(apns, title, content);
    }
    String fcm = DeviceToken.splitFCM(deviceToken);
    if (fcm.isNotEmpty) {
      return sendFCM(fcm, title, content);
    }
    String huawei = DeviceToken.splitHuaWei(deviceToken);
    if (huawei.isNotEmpty) {
      return sendHuaWei(huawei, title, content);
    }
    String xiaomi = DeviceToken.splitXiaoMi(deviceToken);
    if (xiaomi.isNotEmpty) {
      return sendXiaoMi(xiaomi, title, content);
    }
    String oppo = DeviceToken.splitOPPO(deviceToken);
    if (oppo.isNotEmpty) {
      return sendOPPO(oppo, title, content);
    }
    String vivo = DeviceToken.splitVIVO(deviceToken);
    if (vivo.isNotEmpty) {
      return sendVIVO(vivo, title, content);
    }
    return false;
  }

  static Future<bool> sendAPNS(String deviceToken, String title, String content) async {
    try {
      String payload = jsonEncode({
        'aps': {
          'alert': {
            'title': title,
            'body': content,
          },
          // 'badge': 1, // dont set
          'sound': "default",
        },
      });
      await Common.sendPushAPNS(deviceToken, payload);
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<bool> sendFCM(String deviceToken, String title, String content) async {
    try {
      // body
      String body = jsonEncode({
        'to': deviceToken,
        // 'token': token,
        // 'data': {
        //   'via': 'FlutterFire Cloud Messaging!!!',
        //   'count': "_messageCount.toString()",
        // },
        'notification': {
          'title': title,
          'body': content,
        },
        "priority": "high",
        "android": {
          // "collapseKey": targetId,
          "priority": "high",
          // "ttl": "${expireS}s",
        },
        "apns": {
          // "apns-collapse-id": targetId,
          "headers": {
            "apns-priority": "5",
            // "apns-expiration": "${DateTime.now().add(Duration(seconds: expireS)).millisecondsSinceEpoch / 1000}",
          },
        },
        "webpush": {
          // "Topic": targetId,
          "headers": {
            "Urgency": "high",
            // "TTL": "$expireS",
          }
        },
      });
      // http
      http.Response response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=${Settings.fcmServerToken}',
        },
        body: body,
      );
      // response
      if (response.statusCode == 200) {
        logger.d("SendPush - sendPushMessage - success - body:$body");
        return true;
      } else {
        logger.w("SendPush - sendPushMessage - fail - code:${response.statusCode} - body:$body");
        return false;
      }
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<bool> sendHuaWei(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber,
  }) async {
    return false;
  }

  static Future<bool> sendXiaoMi(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber,
  }) async {
    return false;
  }

  static Future<bool> sendOPPO(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber,
  }) async {
    return false;
  }

  static Future<bool> sendVIVO(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber,
  }) async {
    return false;
  }
}
