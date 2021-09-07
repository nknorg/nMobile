import 'dart:io';

import 'package:nmobile/storages/settings.dart';

class NotificationType {
  static const int only_name = 0;
  static const int name_and_message = 1;
  static const int none = 2;
}

class PlatformName {
  static const String web = "web";
  static const String android = "android";
  static const String ios = "ios";

  static String get() {
    return Platform.isAndroid ? android : (Platform.isIOS ? ios : "");
  }
}

class Settings {
  static const bool debug = true;
  static const String appName = "nMobile";
  static const String sentryDSN = 'https://c4d9d78cefc7457db9ade3f8026e9a34@o466976.ingest.sentry.io/5483254';
  static const String fcmServerToken = "Add Your Firebase server token";

  // notification
  static late String locale;
  static late int notificationType;
  static late bool biometricsAuthentication;

  static init() async {
    // load language
    Settings.locale = (await SettingsStorage.getSettings(SettingsStorage.LOCALE_KEY)) ?? 'auto';
    // load notification type
    Settings.notificationType = (await SettingsStorage.getSettings(SettingsStorage.NOTIFICATION_TYPE_KEY)) ?? NotificationType.only_name;
    // load biometrics authentication
    Settings.biometricsAuthentication = (await SettingsStorage.getSettings(SettingsStorage.BIOMETRICS_AUTHENTICATION)) ?? false;
  }
}
