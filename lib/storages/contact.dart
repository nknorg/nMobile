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

  ParallelQueue _queue = ParallelQueue("storage_contact", onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `create_at` BIGINT,
        `update_at` BIGINT,
        `address` VARCHAR(100),
        `wallet_address` VARCHAR(100),
        `avatar` TEXT,
        `first_name` VARCHAR(50),
        `last_name` VARCHAR(50),
        `remark_name` VARCHAR(50),
        `type` INT,
        `is_top` BOOLEAN DEFAULT 0,
        `options` TEXT,
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_contact_address` ON `$tableName` (`address`)');
    await db.execute('CREATE INDEX `index_contact_is_top_create_at` ON `$tableName` (`is_top`, `create_at`)');
    await db.execute('CREATE INDEX `index_contact_type_is_top_create_at` ON `$tableName` (`type`, `is_top`, `create_at`)');
  }

  Future<ContactSchema?> insert(ContactSchema? schema, {bool unique = true}) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.address.isEmpty) return null;
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
              where: 'address = ?',
              whereArgs: [schema.address],
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
        ContactSchema added = ContactSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<ContactSchema?> query(String? address) async {
    if (db?.isOpen != true) return null;
    if (address == null || address.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'address = ?',
          whereArgs: [address],
        );
      });
      if (res != null && res.length > 0) {
        ContactSchema schema = ContactSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - address:$address - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - address:$address");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<ContactSchema>> queryList({int? type, bool orderDesc = true, int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (type != null) ? 'type = ?' : null,
          whereArgs: (type != null) ? [type] : null,
          offset: offset,
          limit: limit,
          orderBy: "is_top DESC, create_at ${orderDesc ? 'DESC' : 'ASC'}",
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - type:$type");
        return [];
      }
      List<ContactSchema> results = <ContactSchema>[];
      // String logText = '';
      res.forEach((map) {
        // logText += "\n      $map";
        results.add(ContactSchema.fromMap(map));
      });
      // logger.v("$TAG - queryList - type:$type - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<ContactSchema>> queryListByAddress(List<String>? addressList) async {
    if (db?.isOpen != true) return [];
    if (addressList == null || addressList.isEmpty) return [];
    try {
      List? res = await db?.transaction((txn) {
        Batch batch = txn.batch();
        addressList.forEach((clientAddress) {
          if (clientAddress.isNotEmpty) {
            batch.query(
              tableName,
              columns: ['*'],
              where: 'address = ?',
              whereArgs: [clientAddress],
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
        // logger.v("$TAG - queryListByAddress - success - addressList:$addressList - schemaList:$schemaList");
        return schemaList;
      }
      // logger.v("$TAG - queryListByAddress - empty - addressList:$addressList");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> setWalletAddress(String? address, String walletAddress) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'wallet_address': walletAddress,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setWalletAddress - success - address:$address - walletAddress:$walletAddress");
              return true;
            }
            logger.w("$TAG - setWalletAddress - fail - address:$address - walletAddress:$walletAddress");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setAvatar(String? address, String? avatarLocalPath) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'avatar': avatarLocalPath,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setAvatar - success - address:$address - avatarLocalPath:$avatarLocalPath");
              return true;
            }
            logger.w("$TAG - setAvatar - fail - address:$address - avatarLocalPath:$avatarLocalPath");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setFullName(String? address, String firstName, String lastName) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'first_name': firstName,
                  'last_name': lastName,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setFullName - success - address:$address - firstName:$firstName - lastName:$lastName");
              return true;
            }
            logger.w("$TAG - setFullName - fail - address:$address - firstName:$firstName - lastName:$lastName");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setRemarkName(String? address, String remarkName) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'remark_name': remarkName,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setRemarkName - success - address:$address - remarkName:$remarkName");
              return true;
            }
            logger.w("$TAG - setRemarkName - fail - address:$address - remarkName:$remarkName");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setType(String? address, int type) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'type': type,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setType - success - address:$address - type:$type");
              return true;
            }
            logger.w("$TAG - setType - fail - address:$address - type:$type");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setTop(String? address, bool top) async {
    if (db?.isOpen != true) return false;
    if (address == null || address.isEmpty) return false;
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
                whereArgs: [address],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setTop - success - address:$address - top:$top");
              return true;
            }
            logger.w("$TAG - setTop - fail - address:$address - top:$top");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<OptionsSchema?> setNotificationOpen(String? address, bool open) async {
    if (db?.isOpen != true) return null;
    if (address == null || address.isEmpty) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'address = ?',
                whereArgs: [address],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setNotificationOpen - no exists - address:$address");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              OptionsSchema options = schema.options;
              options.notificationOpen = open;
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options.toMap()),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
              if (count <= 0) logger.w("$TAG - setNotificationOpen - fail - address:$address - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<OptionsSchema?> setBurning(String? address, int? burningSeconds, int? updateAt) async {
    if (db?.isOpen != true) return null;
    if (address == null || address.isEmpty) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'address = ?',
                whereArgs: [address],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setBurning - no exists - address:$address");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              OptionsSchema options = schema.options;
              options.deleteAfterSeconds = burningSeconds ?? 0;
              options.updateBurnAfterAt = updateAt ?? DateTime.now().millisecondsSinceEpoch;
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options.toMap()),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
              if (count <= 0) logger.w("$TAG - setBurning - fail - address:$address - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setData(String? address, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (address == null || address.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'address = ?',
                whereArgs: [address],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setData - no exists - address:$address");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data;
              if ((removeKeys != null) && removeKeys.isNotEmpty) {
                removeKeys.forEach((element) => data.remove(element));
              }
              data.addAll(added ?? Map());
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
              if (count <= 0) logger.w("$TAG - setData - fail - address:$address - newData:$data");
              return (count > 0) ? data : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }

  Future<Map<String, dynamic>?> setDataItemMapChange(String? address, String key, Map addPairs, List delKeys) async {
    if (db?.isOpen != true) return null;
    if (address == null || address.isEmpty) return null;
    if (addPairs.isEmpty && delKeys.isEmpty) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'address = ?',
                whereArgs: [address],
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - setDataItemMapChange - no exists - address:$address");
                return null;
              }
              ContactSchema schema = ContactSchema.fromMap(res.first);
              Map<String, dynamic> data = schema.data;
              Map<String, dynamic> values = data[key] ?? Map();
              if (delKeys.isNotEmpty) values.removeWhere((key, _) => delKeys.indexWhere((item) => key.toString() == item.toString()) >= 0);
              if (addPairs.isNotEmpty) values.addAll(addPairs.map((key, value) => MapEntry(key.toString(), value)));
              data[key] = values;
              int count = await txn.update(
                tableName,
                {
                  'data': jsonEncode(data),
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'address = ?',
                whereArgs: [address],
              );
              if (count <= 0) logger.w("$TAG - setDataItemMapChange - fail - address:$address - newData:$data");
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
