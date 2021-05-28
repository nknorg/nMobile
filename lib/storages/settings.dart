import 'dart:collection';

import '../helpers/local_storage.dart';

class SettingsStorage {
  static const String SETTINGS_KEY = 'SETTINGS';
  static const String LOCALE_KEY = 'locale';
  static const String NOTIFICATION_TYPE_KEY = 'notification_type';
  static const String BIOMETRICS_AUTHENTICATION = 'biometrics_authentication';
  static const String SEED_RPC_SERVERS_KEY = 'seed_rpc_servers';

  static const String CHAT_TIP_STATUS = 'CHAT_TIP_STATUS';
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
}
