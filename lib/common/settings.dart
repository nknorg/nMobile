import 'dart:convert';
import 'dart:io';

import 'package:nmobile/storages/settings.dart';

class NotificationType {
  static const only_name = 0;
  static const name_and_message = 1;
  static const none = 2;
}

class PlatformName {
  static const web = "web";
  static const android = "android";
  static const ios = "ios";

  static String get() {
    return Platform.isAndroid ? android : (Platform.isIOS ? ios : "");
  }
}

class Settings {
  static const bool debug = true;
  static const String appName = "nMobile";
  static const String sentryDSN = 'https://c4d9d78cefc7457db9ade3f8026e9a34@o466976.ingest.sentry.io/5483254';

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
    final isAuth = await SettingsStorage.getSettings(SettingsStorage.BIOMETRICS_AUTHENTICATION);
    Settings.biometricsAuthentication = (isAuth == null) ? true : ((isAuth is bool) ? isAuth : true);
  }

  // return Your push(F_?_i_?_r_?_e_?_b_?_a_?_s_?_e) server token
  static String getGooglePushToken() {
    return "";
  }
}
