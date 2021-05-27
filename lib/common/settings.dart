import 'package:nmobile/storages/settings.dart';

class NotificationType {
  static const int only_name = 0;
  static const int name_and_message = 1;
  static const int none = 2;
}

class Settings {
  static late String locale;
  static late int notificationType;
  static late bool biometricsAuthentication;
  static bool debug = true;

  static init() async {
    SettingsStorage settingsStorage = SettingsStorage();
    // load language
    Settings.locale = (await settingsStorage.getSettings(SettingsStorage.LOCALE_KEY)) ?? 'auto';
    // load notification type
    Settings.notificationType = (await settingsStorage.getSettings(SettingsStorage.NOTIFICATION_TYPE_KEY)) ?? NotificationType.only_name;
    // load biometrics authentication
    Settings.biometricsAuthentication = (await settingsStorage.getSettings(SettingsStorage.BIOMETRICS_AUTHENTICATION)) ?? false;
  }
}
