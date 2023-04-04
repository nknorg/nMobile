import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactStorage with Tag {
  // static String get tableName => 'Contact';
  static String get tableName => 'Contact_2'; // v5

  static ContactStorage instance = ContactStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_contact", timeout: Duration(seconds: 10), onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `address` VARCHAR(200),
        `type` INT,
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
    await db.execute('CREATE INDEX `index_contact_create_at` ON `$tableName` (`create_at`)');
    await db.execute('CREATE INDEX `index_contact_update_at` ON `$tableName` (`update_at`)');
    await db.execute('CREATE INDEX `index_contact_first_name` ON `$tableName` (`first_name`)');
    await db.execute('CREATE INDEX `index_contact_last_name` ON `$tableName` (`last_name`)');
    await db.execute('CREATE INDEX `index_contact_type_create_at` ON `$tableName` (`type`, `create_at`)');
    await db.execute('CREATE INDEX `index_contact_type_update_at` ON `$tableName` (`type`, `update_at`)');
  }

  Future<ContactSchema?> insert(ContactSchema? schema, {bool checkDuplicated = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.clientAddress.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
    return await _queue.add(() async {
      try {
        int? id;
        if (!checkDuplicated) {
          id = await db?.transaction((txn) {
            return txn.insert(tableName, entity);
          });
        } else {
          id = await db?.transaction((txn) async {
            List<Map<String, dynamic>> res = await txn.query(
              tableName,
              columns: ['*'],
              where: 'address = ?',
              whereArgs: [schema.clientAddress],
              offset: 0,
              limit: 1,
            );
            if (res != null && res.length > 0) {
              logger.w("$TAG - insert - duplicated - schema:$schema");
              return null;
            } else {
              return await txn.insert(tableName, entity);
            }
          });
        }
        if (id != null) {
          ContactSchema schema = ContactSchema.fromMap(entity);
          schema.id = id;
          // logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        } else {
          logger.i("$TAG - insert - exists - schema:$schema");
        }
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<ContactSchema?> query(int? contactId) async {
    if (db?.isOpen != true) return null;
    if (contactId == null || contactId == 0) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'id = ?',
          whereArgs: [contactId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        ContactSchema schema = ContactSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - contactId:$contactId - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - contactId:$contactId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<ContactSchema?> queryByClientAddress(String? clientAddress) async {
    if (db?.isOpen != true) return null;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'address = ?',
          whereArgs: [clientAddress],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        ContactSchema schema = ContactSchema.fromMap(res.first);
        // logger.v("$TAG - queryByClientAddress - success - address:$clientAddress - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - queryByClientAddress - empty - address:$clientAddress");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<ContactSchema>> queryListByClientAddress(List<String>? clientAddressList) async {
    if (db?.isOpen != true) return [];
    if (clientAddressList == null || clientAddressList.isEmpty) return [];
    try {
      List? res = await db?.transaction((txn) {
        Batch batch = txn.batch();
        clientAddressList.forEach((clientAddress) {
          if (clientAddress.isNotEmpty) {
            batch.query(
              tableName,
              columns: ['*'],
              where: 'address = ?',
              whereArgs: [clientAddress],
              offset: 0,
              limit: 1,
            );
          }
        });
        return batch.commit();
      });
      if (res != null && res.length > 0) {
        List<ContactSchema> schemaList = [];
        for (var i = 0; i < res.length; i++) {
          if (res[i] == null || res[i].isEmpty || res[i][0].isEmpty) continue;
          Map<String, dynamic> map = res[i][0];
          ContactSchema schema = ContactSchema.fromMap(map);
          schemaList.add(schema);
        }
        // logger.v("$TAG - queryListByClientAddress - success - clientAddressList:$clientAddressList - schemaList:$schemaList");
        return schemaList;
      }
      // logger.v("$TAG - queryListByClientAddress - empty - clientAddressList:$clientAddressList");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<ContactSchema>> queryList({int? contactType, String? orderBy, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    orderBy = orderBy ?? (contactType == ContactType.friend ? 'create_at DESC' : 'update_at DESC');
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (contactType != null) ? 'type = ?' : null,
          whereArgs: (contactType != null) ? [contactType] : null,
          offset: offset,
          limit: limit,
          orderBy: orderBy,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - contactType:$contactType");
        return [];
      }
      List<ContactSchema> results = <ContactSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        results.add(ContactSchema.fromMap(map));
      });
      // logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> setType(int? contactId, int? contactType) async {
    if (db?.isOpen != true) return false;
    if (contactId == null || contactId == 0 || contactType == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'type': contactType,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [contactId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setType - success - contactId:$contactId - type:$contactType");
              return true;
            }
            logger.w("$TAG - setType - fail - contactId:$contactId - type:$contactType");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setProfile(int? contactId, String? profileVersion, String? avatarLocalPath, String? firstName, String? lastName) async {
    if (db?.isOpen != true) return false;
    if (contactId == null || contactId == 0) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'avatar': avatarLocalPath,
                  'first_name': firstName,
                  'last_name': lastName,
                  'profile_version': profileVersion,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [contactId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setProfileInfo - success - contactId:$contactId - profileVersion:$profileVersion - avatarLocalPath:$avatarLocalPath - firstName:$firstName - lastName:$lastName");
              return true;
            }
            logger.w("$TAG - setProfileInfo - fail - contactId:$contactId - profileVersion:$profileVersion - avatarLocalPath:$avatarLocalPath - firstName:$firstName - lastName:$lastName");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setProfileVersion(int? contactId, String? profileVersion) async {
    if (db?.isOpen != true) return false;
    if (contactId == null || contactId == 0) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'profile_version': profileVersion,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [contactId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setProfileVersion - success - contactId:$contactId - profileVersion:$profileVersion");
              return true;
            }
            logger.w("$TAG - setProfileVersion - fail - contactId:$contactId - profileVersion:$profileVersion");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setTop(String? clientAddress, bool top) async {
    if (db?.isOpen != true) return false;
    if (clientAddress == null || clientAddress.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_top': top ? 1 : 0,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [clientAddress],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setTop - success - clientAddress:$clientAddress - top:$top");
              return true;
            }
            logger.w("$TAG - setTop - fail - clientAddress:$clientAddress - top:$top");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<OptionsSchema?> setNotificationOpen(int? contactId, bool open) async {
    if (db?.isOpen != true) return null;
    if (contactId == null || contactId == 0) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'id = ?',
                whereArgs: [contactId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setNotificationOpen - no exists - contactId:$contactId");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              OptionsSchema options = schema.options ?? OptionsSchema();
              options.notificationOpen = open;
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options.toMap()),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [contactId],
              );
              if (count <= 0) logger.v("$TAG - setNotificationOpen - fail - contactId:$contactId - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<OptionsSchema?> setBurning(int? contactId, int? burningSeconds, int? updateAt) async {
    if (db?.isOpen != true) return null;
    if (contactId == null || contactId == 0) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'id = ?',
                whereArgs: [contactId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setBurning - no exists - contactId:$contactId");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              OptionsSchema options = schema.options ?? OptionsSchema();
              options.deleteAfterSeconds = burningSeconds ?? 0;
              options.updateBurnAfterAt = updateAt ?? DateTime.now().millisecondsSinceEpoch;
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options.toMap()),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [contactId],
              );
              if (count <= 0) logger.w("$TAG - setBurning - fail - contactId:$contactId - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setData(int? contactId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (contactId == null || contactId == 0) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'id = ?',
                whereArgs: [contactId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - contactId:$contactId");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
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
                where: 'id = ?',
                whereArgs: [contactId],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - contactId:$contactId - newData:$data");
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
