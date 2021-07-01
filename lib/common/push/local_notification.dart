import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';

import '../global.dart';

class LocalNotification {
  static const String channel_id = "nmobile_d_chat";
  static const String channel_name = "D-Chat";
  static const String channel_desc = "D-Chat notification";

  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  LocalNotification();

  init() async {
    var initializationSettingsAndroid = new AndroidInitializationSettings(
      '@mipmap/ic_launcher_round',
    );
    var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: false,
      defaultPresentBadge: true,
      onDidReceiveLocalNotification: null,
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (String? payload) async {
      _flutterLocalNotificationsPlugin.cancelAll();
    });
  }

  Future show(
    String uuid,
    String title,
    String content, {
    String? targetId,
    int? badgeNumber,
    String? payload,
  }) async {
    if (targetId != null && application.appLifecycleState == AppLifecycleState.resumed) {
      if (chatCommon.currentTalkId == targetId) return;
    }

    int notificationId = uuid.hashCode;

    var androidNotificationDetails = AndroidNotificationDetails(
      channel_id,
      channel_name,
      channel_desc,
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
      enableLights: true,
      groupKey: targetId,
    );
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
      badgeNumber: badgeNumber,
      threadIdentifier: targetId,
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
