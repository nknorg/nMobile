import 'dart:convert';

import 'package:flustars/flustars.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String NKN_WALLET_KEY = 'WALLETS';
  static const String SETTINGS_KEY = 'SETTINGS';
  static const String LENGTH_SUFFIX = 'length';

  static const String LOCALE_KEY = 'locale';
  static const String LOCAL_NOTIFICATION_TYPE_KEY = 'local_notification_type';
  static const String AUTH_KEY = 'auth';
  static const String DEBUG_KEY = 'debug';

  static const String NEWS_BANNER = 'NEWS_BANNER';
  static const String NEWS_LIST = 'NEWS_LIST';

  static const String WALLET_TIP_STATUS = 'WALLET_TIP_STATUS';
  static const String CHAT_UNSEND_CONTENT = 'CHAT_UNSEND_CONTENT';
  static const String RN_WALLET_UPGRADED = 'RN_WALLET_UPGRADED';

  static const String UN_SUBSCRIBE_LIST = 'UN_SUBSCRIBE_LIST';

  set(String key, val) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (val == null) {
      await prefs.setString(key, val);
    } else if (val is String) {
      await prefs.setString(key, val);
    } else if (val is int) {
      await prefs.setInt(key, val);
    } else if (val is bool) {
      await prefs.setBool(key, val);
    } else if (val is Map) {
      await prefs.setString(key, jsonEncode(val));
    }
  }

  get(key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.get(key);
  }

  remove(key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  clear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  getKeys() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getKeys();
  }

  Future<int> getArrayLength(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var val = prefs.get('$key:$LENGTH_SUFFIX');
    if (val == null) {
      return 0;
    }
    return val;
  }

  Future<Map<String, dynamic>> getItem(String key, int n) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var result = prefs.get('$key:$n');
    if (result == null) return null;
    return jsonDecode(prefs.get('$key:$n'));
  }

  Future<List<Map<String, dynamic>>> getArray(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var length = prefs.get('$key:$LENGTH_SUFFIX');
    if (length == null) return null;

    List<Map<String, dynamic>> res = [];
    for (var i = 0; i < length; i++) {
      res.add(await getItem(key, i));
    }
    return res;
  }

  setArray(String key, List<String> val) async {
    List<Future> futures = <Future>[];
    futures.add(set('$key:$LENGTH_SUFFIX', val.length.toString()));
    val.map((v) {
      futures.add(set('$key:$v', v));
    });
    await Future.wait(futures);
  }

  setItem(String key, int n, val) async {
    int length = await getArrayLength(key);
    if (n >= length) {
      throw RangeError('n is out index: ${length - 1}');
    }
    await set('$key:$n', val);
  }

  addItem(String key, val) async {
    List<Future> futures = <Future>[];
    int length = await getArrayLength(key);
    futures.add(set('$key:$LENGTH_SUFFIX', length + 1));
    futures.add(set('$key:$length', val));
    await Future.wait(futures);
  }

  removeItem(String key, int n) async {
    List<Future> futures = <Future>[];
    int length = await getArrayLength(key);
    futures.add(set('$key:$LENGTH_SUFFIX', length - 1));

    for (var i = n; i < length - 1; i++) {
      var item = await getItem('$key', i + 1);
      futures.add(set('$key:$n', item));
    }
    futures.add(remove('$key:${length - 1}'));

    await Future.wait(futures);
  }

  static String getChatUnSendContentFromId(String to) {
    return SpUtil.getString(to + Global.currentClient.address);
  }

  static saveChatUnSendContentFromId(String to, {String content}) async {
    if (to.length == 0) return;
    if (content == null || content.length == 0) {
      SpUtil.remove(to + Global.currentClient.address);
    }
    SpUtil.putString(to + Global.currentClient.address, content);
  }

  static saveUnsubscribeTopic(String topic) {
    List<String> list = SpUtil.getStringList(UN_SUBSCRIBE_LIST + Global.currentClient.publicKey, defValue: <String>[]);
    if (!list.contains(topic)) {
      list.add(topic);
      SpUtil.putStringList(UN_SUBSCRIBE_LIST, list);
    }
  }

  static removeTopicFromUnsubscribeList(String topic) {
    List<String> list = getUnsubscribeTopicList();
    if (list.contains(topic)) {
      list.remove(topic);
      SpUtil.putStringList(UN_SUBSCRIBE_LIST + Global.currentClient.publicKey, list);
    }
  }

  static List<String> getUnsubscribeTopicList() {
    return SpUtil.getStringList(UN_SUBSCRIBE_LIST + Global.currentClient.publicKey, defValue: <String>[]);
  }

  //leave group list cache
  static bool isBlank(String topic) {
    List<String> list = getUnsubscribeTopicList();
    if (list == null || list.length == 0) return false;

    if (list.contains(topic)) {
      return true;
    } else {
      return false;
    }
  }
}
