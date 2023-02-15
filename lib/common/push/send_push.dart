import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SendPush {
  static Future<String?> send(String uuid, String deviceToken, String title, String content) async {
    String apns = DeviceToken.splitAPNS(deviceToken);
    if (apns.isNotEmpty) {
      return sendAPNS(uuid, apns, Settings.apnsTopic, title, content);
    }
    String fcm = DeviceToken.splitFCM(deviceToken);
    if (fcm.isNotEmpty) {
      return sendFCM(Settings.getGooglePushToken(), uuid, fcm, title, content);
    }
    return null;
  }

  static Future<String?> sendAPNS(String uuid, String deviceToken, String topic, String title, String content) async {
    String payload = jsonEncode({
      'aps': {
        'alert': {
          'title': title,
          'body': content,
        },
        'badge': 1,
        'sound': "default",
      },
    });
    int tryTimes = 0;
    while (tryTimes < 3) {
      Map<String, dynamic>? result = await Common.sendPushAPNS(uuid, deviceToken, topic, payload);
      if (result == null) {
        tryTimes++;
      } else if ((result["code"] != null) && (result["code"]?.toString() != "200")) {
        logger.e("SendPush - sendAPNS - fail - code:${result["code"]} - error:${result["error"]}");
        if (tryTimes >= 2) Sentry.captureMessage("APNS ERROR ${result["code"]}\n${result["error"]}");
        tryTimes++;
      } else {
        logger.i("SendPush - sendAPNS - success - uuid:$uuid - deviceToken:$deviceToken - payload:$payload");
        break;
      }
    }
    return (tryTimes < 3) ? uuid : null;
  }

  static Future<String?> sendFCM(String authorization, String uuid, String deviceToken, String title, String content) async {
    String body = jsonEncode({
      "to": deviceToken,
      "priority": "high",
      "notification": {
        'title': title,
        'body': content,
      },
      "android": {
        "priority": "HIGH",
        "ttl": "0s",
        // "collapse_key": targetId,
        // "restricted_package_name": packageName,
        "notification": {
          "tag": uuid,
        }
        // "data": {extra},
      },
    });
    String? notificationId;
    int tryTimes = 0;
    while (tryTimes < 3) {
      try {
        // http
        http.Response response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          // Uri.parse('https://fcm.googleapis.com/v1/projects/nmobile/messages:send'), // need auth 2.0
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'key=$authorization',
          },
          body: body,
        );
        // response
        if (response.statusCode == 200) {
          logger.i("SendPush - sendFCM - success - body:${response.body}");
          Map<String, dynamic>? result = jsonDecode(response.body);
          if ((result != null) && (result["results"] is List) && (result["results"].length > 0)) {
            notificationId = result["results"][0]["message_id"]?.toString();
          } else {
            notificationId = "";
          }
          break;
        } else {
          logger.e("SendPush - sendFCM - fail - code:${response.statusCode} - body:${response.reasonPhrase}");
          if (tryTimes >= 2) Sentry.captureMessage("FCM ERROR - ${response.statusCode}\n${response.reasonPhrase}");
          tryTimes++;
        }
      } catch (e, st) {
        handleError(e, st);
        tryTimes++;
      }
    }
    return (tryTimes < 3) ? notificationId : null;
  }
}
