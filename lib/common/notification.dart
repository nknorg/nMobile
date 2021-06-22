import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/message.dart';

import 'global.dart';

class Notification {
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Notification();

  init() async {
    var initializationSettingsAndroid = new AndroidInitializationSettings(
      '@mipmap/ic_launcher_round',
    );
    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (String? payload) async {
      _flutterLocalNotificationsPlugin.cancelAll();
    });
  }

  Future showLocalNotification(
    String uuid,
    String title,
    String content, {
    MessageSchema? message,
    int? badgeNumber,
    String? payload,
  }) async {
    if (message != null && application.appLifecycleState == AppLifecycleState.resumed) {
      if (chatCommon.currentTalkId == message.targetId) return;
    }

    int notificationId = uuid.hashCode;
    String? userId = message?.targetId;

    var androidNotificationDetails = AndroidNotificationDetails(
      'nmobile_d_chat',
      'D-Chat',
      'D-Chat notification',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
      enableLights: true,
      groupKey: userId,
    );
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
      badgeNumber: badgeNumber,
      threadIdentifier: userId,
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSPlatformChannelSpecifics,
    );

    S localizations = S.of(Global.appContext);
    switch (Settings.notificationType) {
      case NotificationType.only_name:
        await _flutterLocalNotificationsPlugin.show(notificationId, title, localizations.you_have_new_message, platformChannelSpecifics, payload: payload);
        break;
      case NotificationType.name_and_message:
        await _flutterLocalNotificationsPlugin.show(notificationId, title, content, platformChannelSpecifics, payload: payload);
        break;
      case NotificationType.none:
        await _flutterLocalNotificationsPlugin.show(notificationId, localizations.new_message, localizations.you_have_new_message, platformChannelSpecifics, payload: payload);
        break;
    }
  }
}
