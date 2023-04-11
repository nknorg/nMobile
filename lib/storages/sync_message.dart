import 'dart:async';
import 'dart:convert';

import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/utils/logger.dart';

class SyncMessageStorage with Tag {
  static const String KEY_INSTANCE_ID = 'INSTANCE_ID';
  static const String KEY_SYNC_DEVICES = 'SYNC_DEVICES';
  static const String KEY_SYNC_DEVICES_VERSION = 'SYNC_DEVICES:VERSION';

  final String key;

  SyncMessageStorage({required this.key});

  Future<String?> getInstanceId() async {
    return await LocalStorage.instance.get('$key:$KEY_INSTANCE_ID');
  }

  Future setInstanceId(String id) async {
    await LocalStorage.instance.set('$key:$KEY_INSTANCE_ID', id);
  }

  Future setVersion() async {
    await LocalStorage.instance.set('$key:$KEY_SYNC_DEVICES_VERSION', DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<String> getVersion() async {
    return await LocalStorage.instance.get('$key:$KEY_SYNC_DEVICES_VERSION');
  }

  Future put(String id, String name) async {
    Map? data = await get();

    if (data == null) {
      data = {};
    }
    if (data[id] == null) {
      await setVersion();
    }
    data[id] = {'name': name};
    await LocalStorage.instance.set('$key:$KEY_SYNC_DEVICES', data);
  }

  Future<Map?> get() async {
    var data = await LocalStorage.instance.get('$key:$KEY_SYNC_DEVICES');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  Future getDevicesArray() async {
    Map? map = await get();
    if (map != null) {
      List<Map> list = [];
      map.forEach((id, d) {
        d['id'] = id;
        list.add(d);
      });
      return list;
    }
    return null;
  }
}
