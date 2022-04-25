import 'dart:convert';

import 'package:nmobile/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String LENGTH_SUFFIX = 'length';

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
    } else if (val is List<String>) {
      await prefs.setStringList(key, val);
    }
  }

  Future<dynamic> get(key) async {
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
    int? val = prefs.getInt('$key:$LENGTH_SUFFIX');
    return val ?? 0;
  }

  Future<Map<String, dynamic>?> getItem(String key, int n) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var result = prefs.get('$key:$n');
    if (result == null) return null;
    String? item = prefs.getString('$key:$n');
    if (item != null && item.isNotEmpty) {
      try {
        return jsonDecode(item);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getArray(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? length = prefs.getInt('$key:$LENGTH_SUFFIX');
    if (length == null) return <Map<String, dynamic>>[];

    List<Map<String, dynamic>> res = [];
    for (var i = 0; i < length; i++) {
      Map<String, dynamic>? item = await getItem(key, i);
      if (item != null) {
        res.add(item);
      }
    }
    return res;
  }

  setArray(String key, List<String> val) async {
    List<Future> futures = <Future>[];
    futures.add(set('$key:$LENGTH_SUFFIX', val.length.toString()));
    for (var i = 0; i < val.length; i++) {
      futures.add(set('$key:$i', val[i]));
    }
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
      futures.add(set('$key:$i', item));
    }
    futures.add(remove('$key:${length - 1}'));
    await Future.wait(futures);
  }

  debugInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String log = "";
    Set<String> keys = prefs.getKeys();
    keys.forEach((key) {
      log += "K:::$key --- V:::${prefs.get(key)}\n";
    });
    logger.wtf("LocalStorage - debugInfo ---> $log");
  }
}
