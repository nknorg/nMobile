import 'dart:async';
import 'dart:io';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/db/upgrade1to2.dart';
import 'package:nmobile/common/db/upgrade2to3.dart';
import 'package:nmobile/common/db/upgrade3to4.dart';
import 'package:nmobile/common/db/upgrade4to5.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 5;

  // ignore: close_sinks
  StreamController<bool> _openedController = StreamController<bool>.broadcast();
  StreamSink<bool> get _openedSink => _openedController.sink;
  Stream<bool> get openedStream => _openedController.stream;

  // ignore: close_sinks
  StreamController<String?> _upgradeTipController = StreamController<String?>.broadcast();
  StreamSink<String?> get _upgradeTipSink => _upgradeTipController.sink;
  Stream<String?> get upgradeTipStream => _upgradeTipController.stream;

  Lock _lock = new Lock();

  Database? database;

  DB();

  Future<Database?> _tryOpenDB(String path, String password, {String publicKey = ""}) async {
    try {
      return await _openDB(path, password, publicKey: publicKey);
    } catch (e) {
      handleError(e);
      _upgradeTipSink.add(null);
      // Toast.show("database open error");
    }
    return null;
  }

  Future<Database> _openDB(String path, String password, {String publicKey = ""}) async {
    return _lock.synchronized(() async {
      return await _openDBWithNoLick(path, password, publicKey: publicKey);
    });
  }

  Future<Database> _openDBWithNoLick(String path, String password, {String publicKey = ""}) async {
    if (await needUpgrade(publicKey)) {
      _upgradeTipSink.add(".");
    } else {
      _upgradeTipSink.add(null);
    }

    // test
    // int i = 0;
    // while (i < 100) {
    //   _upgradeTipSink.add("test_$i");
    //   await Future.delayed(Duration(milliseconds: 100));
    //   i++;
    // }

    // var db = await openDatabase(":memory:");
    // var db = await sqflite.openDatabase(path);
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      singleInstance: true,
      onConfigure: (Database db) {
        logger.i("DB - onConfigure - version:${db.getVersion()} - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - config - cipher_version:$value'));
      },
      onCreate: (Database db, int version) async {
        logger.i("DB - onCreate - version:$version - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - create - cipher_version:$value'));
        _upgradeTipSink.add("..");
        await ContactStorage.create(db);
        await DeviceInfoStorage.create(db);
        await TopicStorage.create(db);
        await SubscriberStorage.create(db);
        await MessageStorage.create(db);
        await SessionStorage.create(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - onUpgrade - old:$oldVersion - new:$newVersion");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - upgrade - cipher_version:$value'));
        _upgradeTipSink.add("...");

        // 1 -> 2
        bool v1to2 = false;
        if (oldVersion <= 1 && newVersion >= 2) {
          v1to2 = true;
          await Upgrade1to2.upgradeTopicTable2V3(db);
          await Upgrade1to2.upgradeContactSchema2V3(db);
        }

        // 2 -> 3
        bool v2to3 = false;
        if ((v1to2 || oldVersion == 2) && newVersion >= 3) {
          v2to3 = true;
          await Upgrade2to3.updateTopicTableToV3ByTopic(db);
          await Upgrade2to3.updateTopicTableToV3BySubscriber(db);
        }

        // 3 -> 4
        bool v3to4 = false;
        if ((v2to3 || oldVersion == 3) && newVersion >= 4) {
          v3to4 = true;
          await Upgrade3to4.updateSubscriberV3ToV4(db);
        }

        // 4-> 5
        if ((v3to4 || oldVersion == 4) && newVersion >= 5) {
          await Upgrade4to5.upgradeContact(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.createDeviceInfo(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.upgradeTopic(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.upgradeSubscriber(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.upgradeMessages(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.createSession(db, upgradeTipStream: _upgradeTipSink);
          await Upgrade4to5.deletesOldTables(db, upgradeTipStream: _upgradeTipSink);
        }

        // dismiss tip dialog
        _upgradeTipSink.add(null);
      },
      onOpen: (Database db) async {
        _upgradeTipSink.add(null);
        int version = await db.getVersion();
        logger.i("DB - onOpen - version:$version - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - opened - cipher_version:$value'));
        if (publicKey.isNotEmpty) SettingsStorage.setSettings("${SettingsStorage.DATABASE_VERSION}:$publicKey", version); // await
      },
    );
    return db;
  }

  Future open(String publicKey, String seed) async {
    //if (database != null) return; // bug!
    String path = await getDBFilePath(publicKey);
    bool exists = await databaseExists(path);
    String password = seed.isEmpty ? "" : hexEncode(sha256(seed));
    logger.i("DB - open - exists:$exists - publicKey:$publicKey - seed:$seed - password:$password - path:$path");

    if (!Platform.isIOS) {
      // TODO:GG test??? android
      database = await _tryOpenDB(path, password, publicKey: publicKey);
    } else {
      if (!exists) {
        // 1.new_14_v1，create-pwd=empty，tag(clean) -> [7/8] TODO:GG test 15.1
        // 2.new_16_v1，create-pwd=empty，tag(clean) -> [8]
        database = await _tryOpenDB(path, "", publicKey: publicKey);
        if (database != null) {
          SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        } else {
          Toast.show("database create failed");
        }
        // 3.new_14_v2，create-pwd=seed，tag(clean+reset) TODO:GG test 14.4 15.1
        // 4.new_16_v2，create-pwd=seed，tag(clean+reset) TODO:GG test
        // database = await _tryOpenDB(path, password, publicKey: publicKey);
        // if (database != null) {
        //   SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //   SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        // } else {
        //   Toast.show("database create fail");
        // }
      } else {
        // 5.old_14_v1，database_copy，tag(clean) -> [7/8] TODO:GG test 14.4 15.1
        // 6.old_16_v1，default-pwd=empty，tag(clean) -> [8] TODO:GG test
        bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false;
        if (!clean) {
          if (DeviceInfoCommon.isIOSDeviceVersionLess152()) {
            database = await _tryOpenDB(path, password, publicKey: publicKey);
            if (database == null) {
              database = await _tryOpenDB(path, "", publicKey: publicKey);
              if (database != null) {
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
              } else {
                Toast.show("database open failed");
              }
            } else {
              String copyPath = await getDBFilePath("${publicKey}_copy");
              bool copyTemp = await _copyDB(path, copyPath, sourcePwd: password, targetPwd: "");
              if (copyTemp) {
                bool copyBack = await _copyDB(copyPath, path, sourcePwd: "", targetPwd: "");
                if (copyBack) {
                  database = await _tryOpenDB(path, "", publicKey: publicKey);
                  if (database != null) {
                    await databaseExists(copyPath);
                    SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
                  } else {
                    logger.e("DB - open - open copy fail");
                  }
                } else {
                  logger.e("DB - open - copy_2 fail");
                }
              } else {
                logger.e("DB - open - copy_1 fail");
              }
            }
          } else {
            database = await _tryOpenDB(path, "", publicKey: publicKey);
            if (database == null) {
              database = await _tryOpenDB(path, password, publicKey: publicKey);
              if (database != null) {
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
              } else {
                Toast.show("database open failed");
              }
            } else {
              SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
            }
          }
        } else {
          database = await _tryOpenDB(path, "", publicKey: publicKey);
          if (database == null) {
            await SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", false);
            await Future.delayed(Duration(milliseconds: 500));
            return await open(publicKey, seed);
          } else {
            // success
            logger.i("DB - open - success");
          }
        }
        // 7.old_14_v2，[5/(1)] -> reset-pwd=seed，tag(reset) TODO:GG test 14.4 15.1
        // 8.old_16_v2，[5/6/(1/2)] -> reset-pwd=seed，tag(reset) TODO:GG test 14.4 15.1
        // bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false;
        // bool reset = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey")) ?? false;
        // if (!clean) {
        //   database = await _tryOpenDB(path, password, publicKey: publicKey);
        //   if (database == null) {
        //     database = await _tryOpenDB(path, "", publicKey: publicKey);
        //     if (database != null) {
        //       SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //     } else {
        //       Toast.show("database open failed");
        //     }
        //   } else {
        //     bool success = (await Common.resetSQLitePasswordInIos(path, "")) ?? false; // TODO:GG 能返回true吗?
        //     if (success) SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //   }
        // } else {
        //   if (!reset) {
        //     database = await _tryOpenDB(path, "", publicKey: publicKey);
        //     if (database == null) {
        //       await SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", false);
        //       await Future.delayed(Duration(milliseconds: 500));
        //       return await open(publicKey, seed);
        //     } else {
        //       bool success = (await Common.resetSQLitePasswordInIos(path, password)) ?? false; // TODO:GG empty能设置密码吗
        //       if (success) SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        //     }
        //   } else {
        //     database = await _tryOpenDB(path, password, publicKey: publicKey);
        //     if (database == null) {
        //       database = await _tryOpenDB(path, "", publicKey: publicKey);
        //       if (database != null) {
        //         SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
        //       } else {
        //         Toast.show("database open failed..");
        //       }
        //     } else {
        //       // success
        //     }
        //   }
        // }
      }
    }
    if (database != null) _openedSink.add(true);
  }

  Future close() async {
    await _lock.synchronized(() async {
      await database?.close();
      database = null;
      _openedSink.add(false);
    });
  }

  bool isOpen() {
    return database != null && database!.isOpen;
  }

  Future<String> getDBDirPath() async {
    return getDatabasesPath();
  }

  Future<String> getDBFilePath(String publicKey) async {
    var databasesPath = await getDBDirPath();
    return join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
  }

  Future<bool> needUpgrade(String publicKey) async {
    if (publicKey.isEmpty) return false;
    int? savedVersion = await SettingsStorage.getSettings("${SettingsStorage.DATABASE_VERSION}:$publicKey");
    return savedVersion != currentDatabaseVersion;
  }

  // delete() async {
  //   var databasesPath = await getDatabasesPath();
  //   String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
  //   try {
  //     await deleteDatabase(path);
  //   } catch (e) {
  //     logger.e('DB - Close db error', e);
  //   }
  // }

  // static Future<void> checkTable(Database db, String table) async {
  //   await db.execute('DROP TABLE IF EXISTS $table;');
  // }

  static Future<bool> checkTableExists(Database db, String table) async {
    var count = Sqflite.firstIntValue(await db.query('sqlite_master', columns: ['COUNT(*)'], where: 'type = ? AND name = ?', whereArgs: ['table', table]));
    return (count ?? 0) > 0;
  }

  static Future<bool> checkColumnExists(Database db, String tableName, String columnName) async {
    bool result = false;
    List resultList = await db.rawQuery("PRAGMA table_info($tableName)");
    for (Map columnMap in resultList) {
      String? name = columnMap['name'];
      if ((name?.isNotEmpty == true) && (name == columnName)) {
        return true;
      }
    }
    return result;
  }

  Future<bool> _copyDB(String sourcePath, String targetPath, {String sourcePwd = "", String targetPwd = ""}) async {
    Database? sourceDB = await _tryOpenDB(sourcePath, sourcePwd);
    if (sourceDB == null) {
      logger.e("DB - _copyDB - sourceDB == nil");
      return false;
    }
    bool targetExists = await databaseExists(targetPath);
    if (targetExists) await deleteDatabase(targetPath);
    Database? targetDB = await _tryOpenDB(targetPath, targetPwd);
    if (targetDB == null) {
      logger.e("DB - _copyDB - targetDB == nil");
      return false;
    }
    try {
      if (sourcePwd.isNotEmpty) await sourceDB.execute("PRAGMA key = \'$sourcePwd\'"); // TODO:GG 这个密码对了吗？
      await sourceDB.execute("Attach DATABASE $targetPath AS copy_1 KEY \'\'");
      await sourceDB.execute("SELECT sqlcipher_export(\'$targetPath\')");
      await sourceDB.execute("DETACH DATABASE $targetPath");

      // // create table
      // await ContactStorage.create(targetDB);
      // await DeviceInfoStorage.create(targetDB);
      // await TopicStorage.create(targetDB);
      // await SubscriberStorage.create(targetDB);
      // await MessageStorage.create(targetDB);
      // await SessionStorage.create(targetDB);
      // // copy tables
      // List<String> tables = [
      //   ContactStorage.tableName,
      //   DeviceInfoStorage.tableName,
      //   TopicStorage.tableName,
      //   SubscriberStorage.tableName,
      //   MessageStorage.tableName,
      //   SessionStorage.tableName,
      // ];
      // for (var i = 0; i < tables.length; i++) {
      //   targetDB.rawInsert(sql)
      // }
      // await targetDB.execute("Attach DATABASE $sourcePath AS copy_1 KEY \'$sourcePwd\'"); // TODO:GG 有密码怎么进去复制？
      //
      // await targetDB.execute("CREATE TABLE ${ContactStorage.tableName} AS SELECT * FROM copy_1.${ContactStorage.tableName}");
      // await targetDB.execute("CREATE TABLE ${DeviceInfoStorage.tableName} AS SELECT * FROM copy_1.${DeviceInfoStorage.tableName}");
      // await targetDB.execute("CREATE TABLE ${TopicStorage.tableName} AS SELECT * FROM copy_1.${TopicStorage.tableName}");
      // await targetDB.execute("CREATE TABLE ${SubscriberStorage.tableName} AS SELECT * FROM copy_1.${SubscriberStorage.tableName}");
      // await targetDB.execute("CREATE TABLE ${MessageStorage.tableName} AS SELECT * FROM copy_1.${MessageStorage.tableName}");
      // await targetDB.execute("CREATE TABLE ${SessionStorage.tableName} AS SELECT * FROM copy_1.${SessionStorage.tableName}");
      // await targetDB.execute("DETACH copy_1");
    } catch (e) {
      handleError(e);
    }
    return true;
  }
}
