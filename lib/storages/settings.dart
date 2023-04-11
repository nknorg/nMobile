import 'package:nmobile/helpers/local_storage.dart';

class SettingsStorage {
  static const String SETTINGS_KEY = 'SETTINGS';
  static const String LOCALE_KEY = 'locale';
  static const String SEED_RPC_SERVERS_KEY = 'seed_rpc_servers'; // not support 'NKN_RPC_NODE_LIST'
  static const String NOTIFICATION_TYPE_KEY = 'notification_type'; // not support 'local_notification_type'
  static const String BIOMETRICS_AUTHENTICATION = 'auth';

  static const String DATABASE_VERSION = "database_version";
  static const String DATABASE_VERSION_TIME = "database_version_time";

  static const String CHAT_TIP_STATUS = 'chat_tip_status'; // not support 'WALLET_TIP_STATUS'

  static const String DEFAULT_TOPIC_SUBSCRIBE_SPEED_ENABLE = "default_topic_subscribe_speed_enable";
  static const String DEFAULT_TOPIC_RESUBSCRIBE_SPEED_ENABLE = "default_topic_resubscribe_speed_enable";
  static const String DEFAULT_FEE = "default_fee";

  static const String CLOSE_BUG_UPLOAD_API = 'close_bug_upload_api';
  static const String CLOSE_NOTIFICATION_PUSH_API = 'close_notification_push_api';

  // FIXED:GG ios_db_error
  static const String DATABASE_FIXED_IOS_152 = "database_fixed_ios_152";
  static const String DATABASE_CLEAN_PWD_ON_IOS_14 = "database_clean_pwd_on_ios_14";
  static const String DATABASE_RESET_PWD_ON_IOS_16 = "database_reset_pwd_on_ios_16";

  static Future getSettings(String key) async {
    return await LocalStorage.instance.get('$SETTINGS_KEY:$key');
  }

  static Future setSettings(String key, val) async {
    return await LocalStorage.instance.set('$SETTINGS_KEY:$key', val);
  }
}
