import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

class RemoteNotification {
  static Future<String?> send(String? deviceToken, {String? uuid, String? title, String? content}) async {
    bool? close = await SettingsStorage.getSettings(SettingsStorage.CLOSE_NOTIFICATION_PUSH_API);
    if (close == true) return null;

    if (deviceToken == null || deviceToken.isEmpty == true) return "";

    uuid = uuid ?? Uuid().v4();

    title = title ?? Settings.locale((s) => s.new_message);
    // if (topic != null) {
    //   title = '[${topic.topicShort}] ${contact?.displayName}';
    // } else if (contact != null) {
    //   title = contact.displayName;
    // }

    content = content ?? Settings.locale((s) => s.you_have_new_message);
    // switch (message.contentType) {
    //   case MessageContentType.text:
    //   case MessageContentType.textExtension:
    //     content = message.content;
    //     break;
    //   case MessageContentType.ipfs:
    //   case MessageContentType.media:
    //   case MessageContentType.image:
    //     content = '[${localizations.image}]';
    //     break;
    //   case MessageContentType.audio:
    //     content = '[${localizations.audio}]';
    //     break;
    //   case MessageContentType.topicSubscribe:
    //   case MessageContentType.topicUnsubscribe:
    //   case MessageContentType.topicInvitation:
    //   case MessageContentType.topicKickOut:
    //     break;
    // }

    String apns = DeviceToken.splitAPNS(deviceToken);
    if (apns.isNotEmpty) {
      return sendAPNS(uuid, apns, Settings.apnsTopic, title, content);
    }
    String fcm = DeviceToken.splitFCM(deviceToken);
    if (fcm.isNotEmpty) {
      return sendFCM(Settings.getGooglePushToken(), uuid, fcm, title, content);
    }
    logger.w("RemoteNotification - send - no platform find");
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
    while (tryTimes < Settings.tryTimesNotificationPush) {
      Map<String, dynamic>? result = await Common.sendPushAPNS(uuid, deviceToken, topic, payload);
      if (result == null) {
        tryTimes++;
      } else if ((result["code"] != null) && (result["code"]?.toString() != "200")) {
        logger.e("RemoteNotification - sendAPNS - fail - code:${result["code"]} - error:${result["error"]}");
        if (tryTimes >= (Settings.tryTimesNotificationPush - 1)) Sentry.captureMessage("APNS ERROR ${result["code"]}\n${result["error"]}");
        tryTimes++;
      } else {
        logger.i("RemoteNotification - sendAPNS - success - uuid:$uuid - deviceToken:$deviceToken - payload:$payload");
        break;
      }
    }
    return (tryTimes < Settings.tryTimesNotificationPush) ? uuid : null;
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
    while (tryTimes < Settings.tryTimesNotificationPush) {
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
          logger.i("RemoteNotification - sendFCM - success - body:${response.body}");
          Map<String, dynamic>? result = jsonDecode(response.body);
          if ((result != null) && (result["results"] is List) && (result["results"].length > 0)) {
            notificationId = result["results"][0]["message_id"]?.toString();
          } else {
            notificationId = "";
          }
          break;
        } else {
          logger.e("RemoteNotification - sendFCM - fail - code:${response.statusCode} - body:${response.reasonPhrase}");
          if (tryTimes >= (Settings.tryTimesNotificationPush - 1)) Sentry.captureMessage("FCM ERROR - ${response.statusCode}\n${response.reasonPhrase}");
          tryTimes++;
        }
      } catch (e, st) {
        handleError(e, st);
        tryTimes++;
      }
    }
    return (tryTimes < Settings.tryTimesNotificationPush) ? notificationId : null;
  }
}
