import 'dart:convert';

import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

class ContactStorage with Tag {
  static String get tableName => 'Contact';

  Database? get db => DB.currentDatabase;

  static create(Database db, int version) async {
    final createSql = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        address TEXT,
        avatar TEXT,
        first_name TEXT,
        last_name TEXT,
        options TEXT,
        data TEXT,
        created_time INTEGER,
        updated_time INTEGER,
        profile_version TEXT,
        profile_expires_at INTEGER,
        is_top BOOLEAN DEFAULT 0,
        device_token TEXT,
        notification_open BOOLEAN DEFAULT 0
      )''';
    // create table
    db.execute(createSql);

    // index
    await db.execute('CREATE INDEX index_contact_type ON $tableName (type)');
    await db.execute('CREATE UNIQUE INDEX unique_index_contact_address ON $tableName (address)');
    await db.execute('CREATE INDEX index_contact_first_name ON $tableName (first_name)');
    await db.execute('CREATE INDEX index_contact_last_name ON $tableName (last_name)');
    await db.execute('CREATE INDEX index_contact_created_time ON $tableName (created_time)');
    await db.execute('CREATE INDEX index_contact_updated_time ON $tableName (updated_time)');
    await db.execute('CREATE INDEX index_contact_type_created_time ON $tableName (type, created_time)');
  }

  Future<ContactSchema?> insert(ContactSchema? schema, {bool checkDuplicated = true}) async {
    if (schema == null || schema.clientAddress.isEmpty) return null;
    try {
      Map<String, dynamic> entity = await schema.toMap();
      int? id;
      if (!checkDuplicated) {
        id = await db?.insert(tableName, entity);
      } else {
        await db?.transaction((txn) async {
          List<Map<String, dynamic>>? res = await txn.query(
            tableName,
            columns: ['*'],
            where: 'address = ?',
            whereArgs: [schema.clientAddress],
          );
          if (res != null && res.length > 0) {
            throw Exception(["contact duplicated!"]);
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        ContactSchema schema = await ContactSchema.fromMap(entity);
        schema.id = id;
        logger.d("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - fail - schema:$schema");
    } catch (e) {
      if (e.toString() != "contact duplicated!") {
        handleError(e);
      }
    }
    return null;
  }

  Future<bool> delete(int? contactId) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - delete - success - contactId:$contactId");
        return true;
      }
      logger.w("$TAG - delete - fail - contactId:$contactId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<List<ContactSchema>> queryList({String? contactType, String? orderBy, int? limit, int? offset}) async {
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: contactType != null ? 'type = ?' : null,
        whereArgs: contactType != null ? [contactType] : null,
        offset: offset ?? null,
        limit: limit ?? null,
        orderBy: orderBy ?? 'created_time desc',
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryList - empty - contactType:$contactType");
        return [];
      }
      List<Future<ContactSchema>> futures = <Future<ContactSchema>>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n$map";
        futures.add(ContactSchema.fromMap(map));
      });
      List<ContactSchema> results = await Future.wait(futures);
      logger.d("$TAG - queryList - items:$logText");
      return results;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<ContactSchema?> query(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (res != null && res.length > 0) {
        ContactSchema schema = await ContactSchema.fromMap(res.first);
        logger.d("$TAG - query - success - contactId:$contactId - schema:$schema");
        return schema;
      }
      logger.d("$TAG - query - empty - contactId:$contactId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<ContactSchema?> queryByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (res != null && res.length > 0) {
        ContactSchema schema = await ContactSchema.fromMap(res.first);
        logger.d("$TAG - queryByClientAddress - success - address:$clientAddress - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryByClientAddress - empty - address:$clientAddress");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<int> queryCountByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("$TAG - queryCountByClientAddress - address:$clientAddress - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<bool> setType(int? contactId, String? contactType) async {
    if (contactId == null || contactId == 0 || contactType == null || contactType == ContactType.me) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'type': contactType,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setType - success - contactId:$contactId - type:$contactType");
        return true;
      }
      logger.w("$TAG - setType - fail - contactId:$contactId - type:$contactType");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setProfile(int? contactId, Map<String, dynamic> profileInfo) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'avatar': profileInfo['avatar'],
          'first_name': profileInfo['first_name'],
          'last_name': profileInfo['last_name'],
          'profile_version': profileInfo['profile_version'] ?? Uuid().v4(),
          'profile_expires_at': profileInfo['profile_expires_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setProfile - success - contactId:$contactId - profileInfo:$profileInfo");
        return true;
      }
      logger.w("$TAG - setProfile - fail - contactId:$contactId - profileInfo:$profileInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setRemarkProfile(int? contactId, Map<String, dynamic>? extraInfo) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'data': (extraInfo?.isNotEmpty == true) ? jsonEncode(extraInfo) : null,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setRemarkProfile - success - contactId:$contactId - extraInfo:$extraInfo");
        return true;
      }
      logger.w("$TAG - setRemarkProfile - fail - contactId:$contactId - extraInfo:$extraInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setNotes(int? contactId, String? notes, {Map<String, dynamic>? oldExtraInfo}) async {
    if (contactId == null || contactId == 0) return false;
    try {
      Map<String, dynamic> data = oldExtraInfo ?? Map<String, dynamic>();
      data['notes'] = notes;
      int? count = await db?.update(
        tableName,
        {
          'data': jsonEncode(data),
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setNotes - success - contactId:$contactId - update:$data - new:$notes - old:$oldExtraInfo");
        return true;
      }
      logger.w("$TAG - setNotes - fail - contactId:$contactId - update:$data - new:$notes - old:$oldExtraInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setOptionsBurn(int? contactId, int? burningSeconds, int? updateTime, {OptionsSchema? old}) async {
    if (contactId == null || contactId == 0) return false;
    OptionsSchema options = old ?? OptionsSchema();

    options.deleteAfterSeconds = burningSeconds ?? 0;
    options.updateBurnAfterTime = updateTime ?? DateTime.now().millisecondsSinceEpoch;

    try {
      int? count = await db?.update(
        tableName,
        {
          'options': jsonEncode(options.toMap()),
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setOptionsBurn - success - contactId:$contactId - options:$options");
        return true;
      }
      logger.w("$TAG - setOptionsBurn - fail - contactId:$contactId - options:$options");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setTop(String? clientAddress, bool top) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'is_top': top ? 1 : 0,
        },
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setTop - success - clientAddress:$clientAddress - top:$top");
        return true;
      }
      logger.w("$TAG - setTop - fail - clientAddress:$clientAddress - top:$top");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setDeviceToken(int? contactId, String? deviceToken) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'device_token': deviceToken,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setDeviceToken - success - contactId:$contactId - deviceToken:$deviceToken");
        return true;
      }
      logger.w("$TAG - setDeviceToken - fail - contactId:$contactId - deviceToken:$deviceToken");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setNotificationOpen(int? contactId, bool open) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'notification_open': open ? 1 : 0,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.d("$TAG - setNotificationOpen - success - contactId:$contactId - open:$open");
        return true;
      }
      logger.w("$TAG - setNotificationOpen - fail - contactId:$contactId - open:$open");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
