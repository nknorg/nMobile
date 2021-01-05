import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/helpers/settings.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/news.dart';
import 'package:nmobile/utils/log_tag.dart';

import 'global.dart';

Future _onDidReceiveLocalNotification(int id, String title, String body, String payload) async {
// display a dialog with the notification details, tap ok to go to another page
  showDialog(
    context: Global.appContext,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text('Ok'),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewsScreen(),
              ),
            );
          },
        )
      ],
    ),
  );
}

class LocalNotification {
  static FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static int _notificationId = 0;
  static int _notificationIdDebug = 1000;
  static final _log = LOG('LocalNotification'.tag());

  static init() async {
    var initializationSettingsAndroid = new AndroidInitializationSettings('@drawable/icon_logo');

    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );
    var initializationSettings = InitializationSettings(initializationSettingsAndroid, initializationSettingsIOS);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (payload) async {
      _flutterLocalNotificationsPlugin.cancelAll();
    });
  }

  static messageNotification(String title, String content, {int badgeNumber, MessageSchema message}) async {
    if (message != null && Global.state == AppLifecycleState.resumed) {
      if (message.topic != null) {
        if (Global.currentOtherChatId == message.topic) {
          return;
        }
      } else if (Global.currentOtherChatId == message.from) {
        return;
      }
    }

    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: badgeNumber);
    var androidNotificationDetails = AndroidNotificationDetails('d_chat_notify_sound_vibration', 'Sound Vibration', 'channel description',
        vibrationPattern: Int64List.fromList([0, 30, 100, 30]));
    var platformChannelSpecifics = NotificationDetails(androidNotificationDetails, iOSPlatformChannelSpecifics);
    try {
      _log.d('messageNotification | Global.appContext: ${Global.appContext == null ? null : 'instance'}');
      final nl10ns = Global.appContext != null ? NL10ns.of(Global.appContext) : null;
      switch (Settings.localNotificationType) {
        case LocalNotificationType.only_name:
          await _flutterLocalNotificationsPlugin.show(_genNotificationId, title, nl10ns?.you_have_new_message ?? ' ', platformChannelSpecifics);
          break;
        case LocalNotificationType.name_and_message:
          await _flutterLocalNotificationsPlugin.show(_genNotificationId, title, content, platformChannelSpecifics);
          break;
        case LocalNotificationType.none:
          await _flutterLocalNotificationsPlugin.show(
              _genNotificationId, nl10ns?.new_message ?? ' ', nl10ns?.you_have_new_message ?? ' ', platformChannelSpecifics);
          break;
      }
    } catch (e) {
      _log.e('messageNotification', e);
    }
  }

  static Future cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  static get _genNotificationId {
    _notificationId++;
    if (_notificationId > 9) _notificationId = 1;
    return _notificationId;
  }
}
