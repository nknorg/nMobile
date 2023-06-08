import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nmobile/utils/logger.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String LENGTH_SUFFIX = 'length';

  static SecureStorage instance = SecureStorage();

  set(String key, val) async {
    try {
      if (val is String) {
        await _storage.write(key: key, value: val);
      } else if (val is Map) {
        await _storage.write(key: key, value: jsonEncode(val));
      } else {
        logger.e("SecureStorage - set ---> val type fail:$val");
      }
    } catch (e) {
      logger.e("SecureStorage - set - key:$key - val:$val - error:$e");
    }
  }

  get(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      logger.e("SecureStorage - get - key:$key - error:$e");
    }
  }

  delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      logger.e("SecureStorage - delete - key:$key - error:$e");
    }
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
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<Map<String, dynamic>?> getItem(String key, int n) async {
    String? item = await _storage.read(key: '$key:$n');
    if (item == null) return null;
    try {
      return jsonDecode(item);
    } catch (e) {
      return null;
    }
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
