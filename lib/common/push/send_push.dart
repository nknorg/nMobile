import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';

class SendPush {
  static Future<bool> sendAPNS(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber, // TODO:GG firebase badgeNumber
  }) async {
    try {
      String body = jsonEncode({
        'title': title,
        'body': content,
      }); // TODO:GG test
      await Common.sendPushAPNS(deviceToken, body);
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<bool> sendFCM(
    String deviceToken,
    String title,
    String content, {
    int? badgeNumber, // TODO:GG firebase badgeNumber
  }) async {
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
}
