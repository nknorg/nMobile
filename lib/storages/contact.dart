import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ContactStorage with Tag {
  // static String get tableName => 'Contact';
  static String get tableName => 'Contact_2'; // v5

  Database? get db => dbCommon.database;

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `address` VARCHAR(200),
        `type` INT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `avatar` TEXT,
        `first_name` VARCHAR(50),
        `last_name` VARCHAR(50),
        `profile_version` VARCHAR(300),
        `profile_expires_at` BIGINT,
        `is_top` BOOLEAN DEFAULT 0,
        `device_token` TEXT,
        `options` TEXT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_contact_address` ON `$tableName` (`address`)');
    await db.execute('CREATE INDEX `index_contact_first_name` ON `$tableName` (`first_name`)');
    await db.execute('CREATE INDEX `index_contact_last_name` ON `$tableName` (`last_name`)');
    await db.execute('CREATE INDEX `index_contact_create_at` ON `$tableName` (`create_at`)');
    await db.execute('CREATE INDEX `index_contact_update_at` ON `$tableName` (`update_at`)');
    await db.execute('CREATE INDEX `index_contact_type_create_at` ON `$tableName` (`type`, `create_at`)');
    await db.execute('CREATE INDEX `index_contact_type_update_at` ON `$tableName` (`type`, `update_at`)');
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
            logger.w("$TAG - insert - duplicated - schema:$schema");
          } else {
            id = await txn.insert(tableName, entity);
          }
        });
      }
      if (id != null && id != 0) {
        ContactSchema schema = await ContactSchema.fromMap(entity);
        schema.id = id;
        logger.v("$TAG - insert - success - schema:$schema");
        return schema;
      } else {
        ContactSchema? exists = await queryByClientAddress(schema.clientAddress);
        if (exists != null) {
          logger.i("$TAG - insert - exists - schema:$exists");
        } else {
          logger.w("$TAG - insert - fail - schema:$schema");
        }
      }
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  // Future<bool> delete(int? contactId) async {
  //   if (contactId == null || contactId == 0) return false;
  //   try {
  //     int? count = await db?.delete(
  //       tableName,
  //       where: 'id = ?',
  //       whereArgs: [contactId],
  //     );
  //     if (count != null && count > 0) {
  //       logger.v("$TAG - delete - success - contactId:$contactId");
  //       return true;
  //     }
  //     logger.w("$TAG - delete - fail - contactId:$contactId");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }

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
        logger.v("$TAG - query - success - contactId:$contactId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - query - empty - contactId:$contactId");
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
        logger.v("$TAG - queryByClientAddress - success - address:$clientAddress - schema:$schema");
        return schema;
      }
      logger.v("$TAG - queryByClientAddress - empty - address:$clientAddress");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<ContactSchema>> queryList({int? contactType, String? orderBy, int? limit, int? offset}) async {
    orderBy = orderBy ?? (contactType == ContactType.friend ? 'create_at DESC' : 'update_at DESC');
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: (contactType != null) ? 'type = ?' : null,
        whereArgs: (contactType != null) ? [contactType] : null,
        offset: offset ?? null,
        limit: limit ?? null,
        orderBy: orderBy,
      );
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryList - empty - contactType:$contactType");
        return [];
      }
      List<Future<ContactSchema>> futures = <Future<ContactSchema>>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n      $map";
        futures.add(ContactSchema.fromMap(map));
      });
      List<ContactSchema> results = await Future.wait(futures);
      logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  // Future<int> queryCountByClientAddress(String? clientAddress) async {
  //   if (clientAddress == null || clientAddress.isEmpty) return 0;
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['COUNT(id)'],
  //       where: 'address = ?',
  //       whereArgs: [clientAddress],
  //     );
  //     int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
  //     logger.v("$TAG - queryCountByClientAddress - address:$clientAddress - count:$count");
  //     return count ?? 0;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return 0;
  // }

  Future<bool> setType(int? contactId, int? contactType) async {
    if (contactId == null || contactId == 0 || contactType == null) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'type': contactType,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setType - success - contactId:$contactId - type:$contactType");
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
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setProfile - success - contactId:$contactId - profileInfo:$profileInfo");
        return true;
      }
      logger.w("$TAG - setProfile - fail - contactId:$contactId - profileInfo:$profileInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setProfileOnly(int? contactId, String? profileVersion, int? profileExpiresAt) async {
    if (contactId == null || contactId == 0) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'profile_version': profileVersion ?? Uuid().v4(),
          'profile_expires_at': profileExpiresAt ?? DateTime.now().millisecondsSinceEpoch,
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setProfileOnly - success - contactId:$contactId - profileVersion:$profileVersion - profileExpiresAt:$profileExpiresAt");
        return true;
      }
      logger.w("$TAG - setProfileOnly - fail - contactId:$contactId - profileVersion:$profileVersion - profileExpiresAt:$profileExpiresAt");
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
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setTop - success - clientAddress:$clientAddress - top:$top");
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
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setDeviceToken - success - contactId:$contactId - deviceToken:$deviceToken");
        return true;
      }
      logger.w("$TAG - setDeviceToken - fail - contactId:$contactId - deviceToken:$deviceToken");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setNotificationOpen(int? contactId, bool open, {OptionsSchema? old}) async {
    if (contactId == null || contactId == 0) return false;
    OptionsSchema options = old ?? OptionsSchema();
    options.notificationOpen = open;
    try {
      int? count = await db?.update(
        tableName,
        {
          'options': jsonEncode(options.toMap()),
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setNotificationOpen - success - contactId:$contactId - open:$open");
        return true;
      }
      logger.w("$TAG - setNotificationOpen - fail - contactId:$contactId - open:$open");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setBurning(int? contactId, int? burningSeconds, int? updateAt, {OptionsSchema? old}) async {
    if (contactId == null || contactId == 0) return false;
    OptionsSchema options = old ?? OptionsSchema();
    options.deleteAfterSeconds = burningSeconds ?? 0;
    options.updateBurnAfterAt = updateAt ?? DateTime.now().millisecondsSinceEpoch;
    try {
      int? count = await db?.update(
        tableName,
        {
          'options': jsonEncode(options.toMap()),
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setOptionsBurn - success - contactId:$contactId - options:$options");
        return true;
      }
      logger.w("$TAG - setOptionsBurn - fail - contactId:$contactId - options:$options");
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
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setRemarkProfile - success - contactId:$contactId - extraInfo:$extraInfo");
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
          'update_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count != null && count > 0) {
        logger.v("$TAG - setNotes - success - contactId:$contactId - update:$data - new:$notes - old:$oldExtraInfo");
        return true;
      }
      logger.w("$TAG - setNotes - fail - contactId:$contactId - update:$data - new:$notes - old:$oldExtraInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
