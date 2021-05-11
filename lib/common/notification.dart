import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';

import 'global.dart';

class Notification {
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;

  init() async {
    var initializationSettingsAndroid = new AndroidInitializationSettings('@drawable/ic_launcher_round');

    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (payload) async {
      _flutterLocalNotificationsPlugin.cancelAll();
    });
  }

  showDChatNotification(String title, String content, {int badgeNumber}) async {
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: badgeNumber);
    var androidNotificationDetails = AndroidNotificationDetails(
      'nmobile_d_chat',
      'D-Chat',
      'D-Chat notification',
      vibrationPattern: Int64List.fromList([0, 30, 100, 30]),
      autoCancel: true,
    );
    var platformChannelSpecifics = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSPlatformChannelSpecifics,
    );
    S localizations = S.of(Global.appContext);
    switch (Settings.notificationType) {
      case NotificationType.only_name:
        await _flutterLocalNotificationsPlugin.show(++_notificationId, title, localizations.you_have_new_message, platformChannelSpecifics);
        break;
      case NotificationType.name_and_message:
        await _flutterLocalNotificationsPlugin.show(++_notificationId, title, content, platformChannelSpecifics);
        break;
      case NotificationType.none:
        await _flutterLocalNotificationsPlugin.show(++_notificationId, localizations.new_message, localizations.you_have_new_message, platformChannelSpecifics);
        break;
    }
  }

  Future cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
