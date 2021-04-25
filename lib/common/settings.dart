class LocalNotificationType {
  static const int only_name = 0;
  static const int name_and_message = 1;
  static const int none = 2;
}

class Settings {
  static String locale;
  static int localNotificationType = LocalNotificationType.only_name;
  static bool debug = false;
}
