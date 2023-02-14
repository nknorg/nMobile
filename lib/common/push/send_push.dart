import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SendPush {
  static Future<bool> send(String uuid, String deviceToken, String title, String content) async {
    String apns = DeviceToken.splitAPNS(deviceToken);
    if (apns.isNotEmpty) {
      return sendAPNS(uuid, apns, title, content);
    }
    String fcm = DeviceToken.splitFCM(deviceToken);
    if (fcm.isNotEmpty) {
      return sendFCM(fcm, title, content);
    }
    return false;
  }

  static Future<bool> sendAPNS(String uuid, String deviceToken, String title, String content) async {
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
      Map<String, dynamic>? result = await Common.sendPushAPNS(uuid, deviceToken, Settings.apnsTopic, payload);
      if (result == null) {
        tryTimes++;
      } else if ((result["code"] != null) && (result["code"]?.toString() != "200")) {
        logger.e("SendPush - sendAPNS - fail - code:${result["code"]} - error:${result["error"]}");
        if (tryTimes >= 2) Sentry.captureMessage("${result["code"]}\n${result["error"]}");
        tryTimes++;
      } else {
        logger.i("SendPush - sendAPNS - success - uuid:$uuid - deviceToken:$deviceToken - payload:$payload");
        break;
      }
    }
    return tryTimes < 3;
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
        // Uri.parse('https://fcm.googleapis.com/v1/projects/nmobile/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=${Settings.getGooglePushToken()}',
        },
        body: body,
      );
      // response
      if (response.statusCode == 200) {
        logger.i("SendPush - sendFCM - success - body:$body");
        return true;
      } else {
        logger.e("SendPush - sendFCM - fail - code:${response.statusCode} - body:$body");
        return false;
      }
    } catch (e, st) {
      handleError(e, st);
    }
    return false;
  }
}
