import 'dart:collection';

import '../helpers/local_storage.dart';

class SettingsStorage {
  static const String SETTINGS_KEY = 'SETTINGS';
  static const String LOCALE_KEY = 'locale';
  static const String SEED_RPC_SERVERS_KEY = 'seed_rpc_servers'; // not support 'NKN_RPC_NODE_LIST'
  static const String NOTIFICATION_TYPE_KEY = 'notification_type'; // not support 'local_notification_type'
  static const String BIOMETRICS_AUTHENTICATION = 'biometrics_authentication'; // not support 'auth'

  static const String CHAT_TIP_STATUS = 'chat_tip_status'; // not support 'WALLET_TIP_STATUS'
  static const String CHAT_TIP_NOTIFICATION = 'chat_tip_notification'; // not support 'NKN_MESSAGE_NOTIFICATION_ALERT'

  final LocalStorage _localStorage = LocalStorage();

  Future getSettings(String key) async {
    return await _localStorage.get('$SETTINGS_KEY:$key');
  }

  Future setSettings(String key, val) async {
    return await _localStorage.set('$SETTINGS_KEY:$key', val);
  }

  Future setSeedRpcServers(List<String> val) async {
    List<String> list = val;
    list = LinkedHashSet<String>.from(list).toList();
    if (list.length > 10) {
      list = list.skip(list.length - 10).take(10).toList();
    }
    return await _localStorage.set('$SETTINGS_KEY:$SEED_RPC_SERVERS_KEY', list);
  }

  Future addSeedRpcServers(List<String> val) async {
    List<String> list = await getSeedRpcServers();
    list.addAll(val);
    list = LinkedHashSet<String>.from(list).toList();
    if (list.length > 10) {
      list = list.skip(list.length - 10).take(10).toList();
    }
    return await _localStorage.set('$SETTINGS_KEY:$SEED_RPC_SERVERS_KEY', list);
  }

  Future<List<String>> getSeedRpcServers() async {
    List<String> results = [];
    List? list = (await _localStorage.get('$SETTINGS_KEY:$SEED_RPC_SERVERS_KEY'));
    if (list?.isNotEmpty == true) {
      for (var i in list!) {
        results.add(i.toString());
      }
    }
    results = LinkedHashSet<String>.from(results).toList();
    return results;
  }

  Future<bool> isNeedTipNotificationOpen(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return false;
    var result = await _localStorage.get('$CHAT_TIP_NOTIFICATION:$targetId');
    return result?.toString() != "1";
  }

  Future setNeedTipNotificationOpen(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return;
    await _localStorage.set('$CHAT_TIP_NOTIFICATION:$targetId', "1");
  }
}
