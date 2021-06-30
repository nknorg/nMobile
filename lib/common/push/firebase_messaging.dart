// import 'dart:typed_data';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/utils/logger.dart';

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   print('FireBaseMessaging - _firebaseMessagingBackgroundHandler - messageId:${message.messageId} - from:${message.from}');
//   await Firebase.initializeApp();
// }

class FireBaseMessaging with Tag {
  static const String channel_id = "nmobile_d_chat";
  static const String channel_name = "D-Chat";
  static const String channel_desc = "D-Chat notification";

  // late AndroidNotificationChannel channel;
  // late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  init() async {
    // await Firebase.initializeApp();
    //
    // // background
    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    //
    // // android channel
    // channel = AndroidNotificationChannel(
    //   channel_id,
    //   channel_name,
    //   channel_desc,
    //   importance: Importance.max,
    //   showBadge: true,
    //   playSound: true,
    //   enableLights: true,
    //   enableVibration: true,
    //   vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
    // );
    //
    // // local notification
    // flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    //
    // /// Create an Android Notification Channel.
    // /// We use this channel in the `AndroidManifest.xml` file to override the default FCM channel to enable heads up notifications.
    // await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  startListen() async {
    // // token refresh
    // FirebaseMessaging.instance.onTokenRefresh.listen((String event) async {
    //   logger.i("$TAG - onTokenRefresh - :$event");
    //   // TODO:GG update deviceInfo profileVersion
    // });
    //
    // // background click
    // FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    //   if (message == null) return;
    //   logger.i("$TAG - getInitialMessage - messageId:${message.messageId} - from:${message.from}");
    // });
    //
    // // foreground pop TODO:GG maybe use local notification
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   logger.d("$TAG - onMessage - messageId:${message.messageId} - from:${message.from}");
    //   // if (application.appLifecycleState == AppLifecycleState.resumed) return; // TODO:GG test // handle in chatIn with localNotification
    //   // String? targetId = message.from; // cant check contactNotificationOpen and messagesScreen because payload no contactInfo and msgInfo
    //   RemoteNotification? notification = message.notification;
    //   if (notification == null) return;
    //   // AndroidNotification? android = message.notification?.android;
    //   // AppleNotification? apple = message.notification?.apple;
    //   flutterLocalNotificationsPlugin.show(
    //     notification.hashCode,
    //     notification.title,
    //     notification.body,
    //     NotificationDetails(
    //       android: AndroidNotificationDetails(
    //         channel_id,
    //         channel_name,
    //         channel_desc,
    //         // groupKey: targetId,
    //         importance: Importance.max,
    //         priority: Priority.high,
    //         autoCancel: true,
    //         enableLights: true,
    //         enableVibration: true,
    //         vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
    //         // icon: , // set in manifest
    //       ),
    //       iOS: IOSNotificationDetails(
    //         // threadIdentifier: targetId,
    //         // badgeNumber: apple?.badge, // TODO:GG firebase badgeNumber
    //         presentBadge: true,
    //         presentSound: true,
    //         presentAlert: true,
    //       ),
    //     ),
    //   );
    // });
    //
    // // foreground click
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   logger.d("$TAG - onMessageOpenedApp - messageId:${message.messageId} - from:${message.from}");
    // });
  }
}
