import 'dart:convert';

import 'package:nmobile/utils/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String LENGTH_SUFFIX = 'length';

  set(String key, val) async {
    if (val is String) {
      await _storage.write(key: key, value: val);
    } else if (val is Map) {
      await _storage.write(key: key, value: jsonEncode(val));
    } else {
      logger.e("SecureStorage - set ---> val type fail:$val");
    }
  }

  get(String key) async {
    return await _storage.read(key: key);
  }

  delete(String key) async {
    await _storage.delete(key: key);
  }

  deleteAll() async {
    await _storage.deleteAll();
  }

  Future<Map<String, String>> getAll() async {
    return await _storage.readAll();
  }

  Future<int> getArrayLength(String key) async {
    var val = await _storage.read(key: '$key:$LENGTH_SUFFIX');
    if (val == null) {
      return 0;
    }
    return int.tryParse(val) ?? 0;
  }

  Future<Map<String, dynamic>?> getItem(String key, int n) async {
    String? item = await _storage.read(key: '$key:$n');
    if (item == null) return null;
    return jsonDecode(item);
  }

  Future<List<Map<String, dynamic>>> getArray(String key) async {
    int length = await getArrayLength(key);

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
    futures.add(_storage.write(key: '$key:$LENGTH_SUFFIX', value: val.length.toString()));
    for (var i = 0; i < val.length; i++) {
      futures.add(_storage.write(key: '$key:$i', value: val[i]));
    }
    await Future.wait(futures);
  }

  addItem(String key, val) async {
    List<Future> futures = <Future>[];
    int length = await getArrayLength(key);

    futures.add(set('$key:$LENGTH_SUFFIX', length + 1));
    futures.add(set('$key:$length', val));
    await Future.wait(futures);
  }
}
