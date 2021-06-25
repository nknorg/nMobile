import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FireBaseMessaging - _firebaseMessagingBackgroundHandler - messageId:${message.messageId} - from:${message.from}');
  await Firebase.initializeApp();
}

class FireBaseMessaging with Tag {
  static const String channel_id = "nmobile_d_chat";
  static const String channel_name = "D-Chat";
  static const String channel_desc = "D-Chat notification";

  late AndroidNotificationChannel channel;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  String? _token;

  init() async {
    await Firebase.initializeApp();

    // background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // android channel
    channel = AndroidNotificationChannel(
      channel_id,
      channel_name,
      channel_desc,
      importance: Importance.max,
      showBadge: true,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
    );

    // local notification
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    /// Create an Android Notification Channel.
    /// We use this channel in the `AndroidManifest.xml` file to override the default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow heads up notifications.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    ); // await
  }

  startListen() async {
    // token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((String event) {
      logger.i("$TAG - onTokenRefresh - old:$_token - new:$event");
      // TODO:GG firebase should notify all contact who notificationOpen?
      // TODO:GG ios wrong?
      _token = event;
    });

    // background click
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message == null) return;
      logger.i("$TAG - getInitialMessage - messageId:${message.messageId} - from:${message.from}");
    });

    // foreground pop
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.d("$TAG - onMessage - messageId:${message.messageId} - from:${message.from}");
      // if (application.appLifecycleState == AppLifecycleState.resumed) return; // TODO:GG test // handle in chatIn with localNotification
      // String? targetId = message.from; // cant check contactNotificationOpen and messagesScreen because payload no contactInfo and msgInfo
      RemoteNotification? notification = message.notification;
      if (notification == null) return;
      // AndroidNotification? android = message.notification?.android;
      // AppleNotification? apple = message.notification?.apple;
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel_id,
            channel_name,
            channel_desc,
            // groupKey: targetId,
            importance: Importance.max,
            priority: Priority.high,
            autoCancel: true,
            enableLights: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
            // icon: , // set in manifest
          ),
          iOS: IOSNotificationDetails(
            // threadIdentifier: targetId,
            // badgeNumber: apple?.badge, // TODO:GG firebase badgeNumber
            presentBadge: true,
            presentSound: true,
            presentAlert: true,
          ),
        ),
      );
    });

    // foreground click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logger.d("$TAG - onMessageOpenedApp - messageId:${message.messageId} - from:${message.from}");
    });

    // ios permission
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      logger.d('$TAG - requestPermission - OK');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      logger.w('$TAG - requestPermission - temp');
    } else {
      logger.w('$TAG - requestPermission - NONE');
    }
  }

  Future<String?> getToken() async {
    if (_token == null) {
      if (Platform.isAndroid) {
        _token = await FirebaseMessaging.instance.getToken();
      } else {
        // TODO:GG ios wrong?
        _token = await FirebaseMessaging.instance.getAPNSToken();
      }
    }
    return _token;
  }

  Future deleteToken() async {
    await FirebaseMessaging.instance.deleteToken();
    _token = null;
  }

  sendPushMessage(
    String token,
    String uuid,
    String title,
    String content, {
    String? targetId,
    int? badgeNumber, // TODO:GG firebase badgeNumber
    String? payload,
  }) async {
    try {
      String body = createFCMPayload(token, title, content);
      http.Response response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=${Settings.fcmServerToken}',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        logger.d("$TAG - sendPushMessage - success - body:$body");
      } else {
        logger.w("$TAG - sendPushMessage - fail - code:${response.statusCode} - body:$body");
      }
    } catch (e) {
      handleError(e);
    }
  }

  String createFCMPayload(
    String token,
    String title,
    String content,
    // String? targetId,
    // int expireS,
  ) {
    token = "064cd3060e55ce3806d99284f318d5305930f4b1defb1805be70494196eb7469__FCMToken__:cpS5pduEJE-xj5tFfTyRcC:APA91bGPIWCBhDjXiZwxSXnTpyVvTAJq-Hg2439DbV7DrLMIaBWM067YXU1jevv48knUDN_xqEkbbu94sJU6JQbEECwLdCH4nfRL5e5UtTN5iqb0vmsKqUbjsvKJqyoUNdU_5sLll8QA";
    // SUPPORT:START
    String fcmGapString = "__FCMToken__:";
    List<String> sList = token.split(fcmGapString);
    if (sList.length > 1) {
      token = sList[1].toString();
    }
    // SUPPORT:END

    return jsonEncode({
      'to': token,
      // 'data': {
      //   'via': 'FlutterFire Cloud Messaging!!!',
      //   'count': "_messageCount.toString()",
      // },
      'notification': {
        'title': title,
        'body': content,
      },
      "android": {
        // "collapseKey": targetId,
        "priority": "normal",
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
  }
}
