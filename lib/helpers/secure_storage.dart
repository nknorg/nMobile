import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String PASSWORDS_KEY = 'PASSWORDS';
  static const String LENGTH_SUFFIX = 'length';

  set(String key, val) async {
    if (val is String) {
      await _storage.write(key: key, value: val);
    } else if (val is Map) {
      await _storage.write(key: key, value: jsonEncode(val));
    } else {
      throw ArgumentError('val type fail');
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
    return int.parse(val);
  }

  Future<Map<String, dynamic>> getItem(String key, int n) async {
    return jsonDecode(await _storage.read(key: '$key:$n'));
  }

  Future<List<Map<String, dynamic>>> getArray(String key) async {
    int length = await getArrayLength(key);

    List<Map<String, dynamic>> res = [];
    for (var i = 0; i < length; i++) {
      res.add(await getItem(key, i));
    }
    return res;
  }

  setArray(String key, List<String> val) async {
    List<Future> futures = <Future>[];
    futures.add(_storage.write(key: '$key:$LENGTH_SUFFIX', value: val.length.toString()));
    val.map((v) {
      futures.add(_storage.write(key: '$key:$v', value: v));
    });
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
