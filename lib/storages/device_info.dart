import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoStorage with Tag {
  static String get tableName => 'DeviceInfo';

  Database? get db => DB.currentDatabase;

  static create(Database db, int version) async {
    final createSql = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        create_at INTEGER,
        update_at INTEGER,
        contact_id INTEGER,
        device_id TEXT,
        data TEXT,
        data_version TEXT,
      )''';
    // create table
    db.execute(createSql);

    // index
    await db.execute('CREATE INDEX index_contact_id ON $tableName (contact_id)');
    await db.execute('CREATE INDEX index_device_id ON $tableName (device_id)');
    await db.execute('CREATE INDEX index_contact_id_update_at ON $tableName (contact_id, update_at)');
    await db.execute('CREATE INDEX index_contact_id_device_id_update_at ON $tableName (contact_id, device_id, update_at)');
  }

  Future<DeviceInfoSchema?> insert(DeviceInfoSchema? schema) async {
    if (schema == null || schema.contactId == 0) return null;
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

  Future<DeviceInfoSchema?> queryLatest(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'contact_id = ?',
        whereArgs: [contactId],
        offset: 0,
        limit: 1,
        orderBy: 'update_at desc',
      );
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        logger.d("$TAG - queryLatest - success - contactId:$contactId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryLatest - empty - contactId:$contactId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<DeviceInfoSchema?> queryByDeviceId(int? contactId, String? deviceId) async {
    if (contactId == null || contactId == 0 || deviceId == null || deviceId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'contact_id = ? AND device_id = ?',
        whereArgs: [contactId, deviceId],
        offset: 0,
        limit: 1,
        orderBy: 'update_at desc',
      );
      if (res != null && res.length > 0) {
        DeviceInfoSchema schema = DeviceInfoSchema.fromMap(res.first);
        logger.d("$TAG - queryByDeviceId - success - contactId:$contactId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryByDeviceId - empty - contactId:$contactId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<bool> update(int? contactId, Map<String, dynamic> newData, String? dataVersion) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'data': newData,
          'data_version': dataVersion ?? Uuid().v4(),
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        ,
        where: 'contact_id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setData - success - contactId:$contactId - data:$newData");
        return true;
      }
      logger.w("$TAG - setData - fail - contactId:$contactId - data:$newData");
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
