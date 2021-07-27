import 'dart:convert';

import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DeviceInfoStorage with Tag {
  static String get tableName => 'DeviceInfo';

  Database? get db => DB.currentDatabase;

  static create(Database db, int version) async {
    final createSql = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_address TEXT,
        create_at INTEGER,
        update_at INTEGER,
        device_id TEXT,
        data TEXT
      )''';
    // create table
    db.execute(createSql);

    // index
    await db.execute('CREATE UNIQUE INDEX unique_index_contact_address ON $tableName (contact_address)');
    await db.execute('CREATE INDEX index_device_id ON $tableName (device_id)');
    await db.execute('CREATE INDEX index_contact_address_update_at ON $tableName (contact_address, update_at)');
    await db.execute('CREATE INDEX index_contact_address_device_id_update_at ON $tableName (contact_address, device_id, update_at)');
  }

  Future<DeviceInfoSchema?> insert(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactAddress.isEmpty) return null;
    try {
      Map<String, dynamic> entity = schema.toMap();
      int? id = await db?.insert(tableName, entity);
      if (id != null && id != 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(entity);
        schema.id = id;
        logger.d("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - fail - schema:$schema");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<DeviceInfoSchema?> queryLatest(String? contactAddress) async {
    if (contactAddress == null || contactAddress.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'contact_address = ?',
        whereArgs: [contactAddress],
        offset: 0,
        limit: 1,
        orderBy: 'update_at DESC',
      );
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        logger.d("$TAG - queryLatest - success - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryLatest - empty - contactAddress:$contactAddress");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<DeviceInfoSchema?> queryByDeviceId(String? contactAddress, String? deviceId) async {
    if (contactAddress == null || contactAddress.isEmpty || deviceId == null || deviceId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'contact_address = ? AND device_id = ?',
        whereArgs: [contactAddress, deviceId],
        offset: 0,
        limit: 1,
        orderBy: 'update_at DESC',
      );
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        logger.d("$TAG - queryByDeviceId - success - contactAddress:$contactAddress - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryByDeviceId - empty - contactAddress:$contactAddress");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<bool> update(int? deviceInfoId, Map<String, dynamic>? newData) async {
    if (deviceInfoId == null || deviceInfoId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'data': newData != null ? jsonEncode(newData) : null,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [deviceInfoId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setData - success - deviceInfoId:$deviceInfoId - data:$newData");
        return true;
      }
      logger.w("$TAG - setData - fail - deviceInfoId:$deviceInfoId - data:$newData");
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
