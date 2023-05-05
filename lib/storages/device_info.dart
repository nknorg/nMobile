import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DeviceInfoStorage with Tag {
  static String get tableName => 'DeviceInfo'; // v5

  static DeviceInfoStorage instance = DeviceInfoStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_deviceInfo", timeout: Duration(seconds: 10), onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `contact_address` VARCHAR(200),
        `device_id` TEXT,
        `device_token` TEXT,
        `online_at` BIGINT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    // TODO:GG 升级(device_token("") + online_at(updateAt))?
    await db.execute(createSQL);

    // index
    // TODO:GG 升级 (几乎都有改，有个旧的uq不影响)?
    await db.execute('CREATE UNIQUE INDEX `index_unique_device_info_contact_address_device_id` ON `$tableName` (`contact_address`, `device_id`)');
    await db.execute('CREATE INDEX `index_device_info_device_id` ON `$tableName` (`device_id`)');
    await db.execute('CREATE INDEX `index_device_info_contact_address_online_at` ON `$tableName` (`contact_address`, `online_at`)');
    await db.execute('CREATE INDEX `index_device_info_contact_address_device_id_online_at` ON `$tableName` (`contact_address`, `device_id`, `online_at`)');
  }

  Future<DeviceInfoSchema?> insert(DeviceInfoSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.contactAddress.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
    return await _queue.add(() async {
      try {
        int? id;
        if (!unique) {
          id = await db?.transaction((txn) {
            return txn.insert(tableName, entity);
          });
        } else {
          id = await db?.transaction((txn) async {
            List<Map<String, dynamic>> res = await txn.query(
              tableName,
              columns: ['*'],
              where: 'contact_address = ? AND device_id = ?',
              whereArgs: [schema.contactAddress, schema.deviceId],
              offset: 0,
              limit: 1,
            );
            if (res != null && res.length > 0) {
              logger.w("$TAG - insert - duplicated - db_exist:${res.first} - insert_new:$schema");
              entity = res.first;
              return null;
            } else {
              return await txn.insert(tableName, entity);
            }
          });
        }
        DeviceInfoSchema added = DeviceInfoSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (db?.isOpen != true) return null;
    if (contactAddress == null || contactAddress.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'contact_address = ?',
          whereArgs: [contactAddress],
          offset: 0,
          limit: 1,
          orderBy: 'online_at DESC',
        );
      });
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        // logger.v("$TAG - queryLatest - success - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - queryLatest - empty - contactAddress:$contactAddress");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<DeviceInfoSchema>> queryLatestList(String? contactAddress, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (contactAddress == null || contactAddress.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'contact_address = ?',
          whereArgs: [contactAddress],
          offset: offset,
          limit: limit,
          orderBy: 'online_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryLatestList - empty - contactAddress:$contactAddress");
        return [];
      }
      List<DeviceInfoSchema> results = <DeviceInfoSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        results.add(DeviceInfoSchema.fromMap(map));
      });
      // logger.v("$TAG - queryLatestList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<DeviceInfoSchema>> queryListLatest(List<String>? contactAddressList) async {
    if (db?.isOpen != true) return [];
    if (contactAddressList == null || contactAddressList.isEmpty) return [];
    try {
      List? res = await db?.transaction((txn) {
        Batch batch = txn.batch();
        contactAddressList.forEach((contactAddress) {
          if (contactAddress.isNotEmpty) {
            batch.query(
              tableName,
              columns: ['*'],
              where: 'contact_address = ?',
              whereArgs: [contactAddress],
              offset: 0,
              limit: 1,
              orderBy: 'online_at DESC',
            );
          }
        });
        return batch.commit();
      });
      if (res != null && res.length > 0) {
        List<DeviceInfoSchema> schemaList = [];
        for (var i = 0; i < res.length; i++) {
          if (res[i] == null || res[i].isEmpty || res[i][0].isEmpty) continue;
          Map<String, dynamic> map = res[i][0];
          DeviceInfoSchema schema = DeviceInfoSchema.fromMap(map);
          schemaList.add(schema);
        }
        // logger.v("$TAG - queryListLatest - success - contactAddressList:$contactAddressList - schemaList:$schemaList");
        return schemaList;
      }
      // logger.v("$TAG - queryListLatest - empty - contactAddressList:$contactAddressList");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<DeviceInfoSchema?> queryByDeviceId(String? contactAddress, String? deviceId) async {
    if (db?.isOpen != true) return null;
    if (contactAddress == null || contactAddress.isEmpty) return null;
    deviceId = deviceId ?? "";
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'contact_address = ? AND device_id = ?',
          whereArgs: [contactAddress, deviceId],
          offset: 0,
          limit: 1,
          orderBy: 'online_at DESC',
        );
      });
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        // logger.v("$TAG - queryByDeviceId - success - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - queryByDeviceId - empty - contactAddress:$contactAddress");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<bool> setDeviceToken(String? contactAddress, String? deviceId, String? deviceToken) async {
    if (db?.isOpen != true) return false;
    if (contactAddress == null || contactAddress.isEmpty) return false;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'device_token': deviceToken,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setDeviceToken - success - contactAddress:$contactAddress - deviceId:$deviceId - deviceToken:$deviceToken");
              return true;
            }
            logger.w("$TAG - setDeviceToken - fail - contactAddress:$contactAddress - deviceId:$deviceId - deviceToken:$deviceToken");
            return false;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setOnlineAt(String? contactAddress, String? deviceId, {int? onlineAt}) async {
    if (db?.isOpen != true) return false;
    if (contactAddress == null || contactAddress.isEmpty) return false;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'online_at': onlineAt ?? DateTime.now().millisecondsSinceEpoch,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setOnlineAt - success - contactAddress:$contactAddress - deviceId:$deviceId - onlineAt:$onlineAt");
              return true;
            }
            logger.w("$TAG - setOnlineAt - fail - contactAddress:$contactAddress - deviceId:$deviceId - onlineAt:$onlineAt");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<Map<String, dynamic>?> setData(String? contactAddress, String? deviceId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (contactAddress == null || contactAddress.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
                offset: 0,
                limit: 1,
                orderBy: 'online_at DESC',
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - contactAddress:$contactAddress - deviceId:$deviceId");
                return null;
              }
              DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data ?? Map<String, dynamic>();
              data.addAll(added ?? Map());
              if ((removeKeys != null) && removeKeys.isNotEmpty) {
                removeKeys.forEach((element) => data.remove(element));
              }
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - contactAddress:$contactAddress - deviceId:$deviceId - newData:$data");
              return (count > 0) ? data : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setDataItemListChange(String? contactAddress, String? deviceId, String key, List adds, List dels) async {
    if (db?.isOpen != true) return null;
    if (contactAddress == null || contactAddress.isEmpty || key.isEmpty) return null;
    if (adds.isEmpty && dels.isEmpty) return null;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setDataItemListChange - no exists - contactAddress:$contactAddress - deviceId:$deviceId");
                return null;
              }
              DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data ?? Map<String, dynamic>();
              List values = data[key] ?? [];
              if (dels.isNotEmpty) values.removeWhere((value) => dels.indexWhere((item) => value == item) >= 0);
              if (adds.isNotEmpty) values.addAll(adds);
              data[key] = values;
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
              );
              if (count <= 0) logger.w("$TAG - setDataItemListChange - fail - contactAddress:$contactAddress - deviceId:$deviceId - newData:$data");
              return (count > 0) ? data : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setDataItemMapChange(String? contactAddress, String? deviceId, String key, Map addPairs, List delKeys) async {
    if (db?.isOpen != true) return null;
    if (contactAddress == null || contactAddress.isEmpty || key.isEmpty) return null;
    if (addPairs.isEmpty && delKeys.isEmpty) return null;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setDataItemMapChange - no exists - contactAddress:$contactAddress - deviceId:$deviceId");
                return null;
              }
              DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data ?? Map<String, dynamic>();
              Map<String, dynamic> values = data[key] ?? Map();
              if (delKeys.isNotEmpty) {
                values.removeWhere((key, _) => delKeys.indexWhere((item) => key.toString() == item.toString()) >= 0);
              }
              if (addPairs.isNotEmpty) {
                Map<String, dynamic> convert = addPairs.map((key, value) => MapEntry(key.toString(), value));
                values.addAll(convert);
              }
              data[key] = values;
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'contact_address = ? AND device_id = ?',
                whereArgs: [contactAddress, deviceId],
              );
              if (count <= 0) logger.w("$TAG - setDataItemMapChange - fail - contactAddress:$contactAddress - deviceId:$deviceId - newData:$data");
              return (count > 0) ? data : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }
}
