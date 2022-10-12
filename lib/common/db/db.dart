import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/db/upgrade1to2.dart';
import 'package:nmobile/common/db/upgrade2to3.dart';
import 'package:nmobile/common/db/upgrade3to4.dart';
import 'package:nmobile/common/db/upgrade4to5.dart';
import 'package:nmobile/common/db/upgrade5to6.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:synchronized/synchronized.dart';
// import 'package:sqflite/sqflite.dart' as sqflite;

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 6;

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

  Future open(String publicKey, String seed) {
    // publicKey = "e2113a5e3000f6be24ddf2e2ff6911e506173e77d75abfd27871479993bb67b0";
    // seed = "e3e642b70824315486a566dc90decff5585a9b9059c964cc8e622570048fa9e5";
    return _lock.synchronized(() async {
      return await _openWithFix(publicKey, seed);
    });
  }

  Future _openWithFix(String publicKey, String seed) async {
    String path = await getDBFilePath(publicKey);
    bool exists = await databaseExists(path);
    String password = seed.isEmpty ? "" : hexEncode(Uint8List.fromList(Hash.sha256(seed)));
    logger.i("DB - open - exists:$exists - publicKey:$publicKey - seed:$seed - password:$password - path:$path");

    if (!Platform.isIOS) {
      database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
    } else {
      if (!exists) {
        // 1.new_14_v1，create-pwd=empty，tag(clean) -> [7/8]
        // 2.new_16_v1，create-pwd=empty，tag(clean) -> [8]
        database = await _tryOpenDB(path, "", publicKey: publicKey);
        if (database != null) {
          SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        } else {
          Toast.show("database create failed");
        }
        // 3.new_14_v2，create-pwd=seed，tag(clean+reset)
        // 4.new_16_v2，create-pwd=seed，tag(clean+reset)
        // FUTURE:GG IOS_152_V2
        // database = await _tryOpenDB(path, password, publicKey: publicKey);
        // if (database != null) {
        //   SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //   SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        // } else {
        //   Toast.show("database create fail");
        // }
      } else {
        // 5.old_14_v1，database_copy，tag(clean) -> [7/8]
        // 6.old_16_v1，default-pwd=empty，tag(clean) -> [8]
        try {
          database = await _openDB(path, "", publicKey: publicKey, upgradeTip: true);
        } catch (e) {
          // nothing
        }
        bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false;
        if (!clean) {
          if (database == null) {
            database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
            if (database != null) {
              if (DeviceInfoCommon.isIOSDeviceVersionLess152()) {
                _upgradeTipSink.add("~ ~ ~ ~ ~");
                await database?.close();
                database = null;
                await Future.delayed(Duration(milliseconds: 200));
                String copyPath = await getDBFilePath("${publicKey}_copy");
                bool copyTemp = await _copyDB2Plaintext(path, copyPath, sourcePwd: password);
                if (copyTemp) {
                  bool copyBack = await _copyDB2Plaintext(copyPath, path, sourcePwd: "");
                  _deleteDBFile(copyPath); // await
                  if (copyBack) {
                    database = await _tryOpenDB(path, "", publicKey: publicKey);
                    if (database != null) {
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
                _upgradeTipSink.add(null);
              } else {
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
              }
            } else {
              Toast.show("database open failed.");
            }
          } else {
            SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
          }
        } else {
          if (database == null) {
            await SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", false);
            await Future.delayed(Duration(milliseconds: 200));
            return await _openWithFix(publicKey, seed);
          } else {
            // success
          }
        }
        // 7.old_14_v2，[5/(1)] -> database_copy，tag(reset)
        // 8.old_16_v2，[5/6/(1/2)] -> database_copy，tag(reset)
        // FUTURE:GG IOS_152_V2
        // try {
        //   database = await _openDB(path, "", publicKey: publicKey, upgradeTip: true);
        // } catch (e) {}
        // bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false;
        // bool reset = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey")) ?? false;
        // if (!clean) {
        //   if (database == null) {
        //     database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
        //     if (database != null) {
        //       SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //       SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        //     } else {
        //       Toast.show("database open failed.");
        //     }
        //   } else {
        //     SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //     SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
        //   }
        // } else {
        //   if (!reset) {
        //     if (database == null) {
        //       database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
        //       if (database != null) {
        //         SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //         SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        //       } else {
        //         Toast.show("database open failed.");
        //       }
        //     } else {
        //       _upgradeTipSink.add("~ ~ ~ ~ ~");
        //       await database?.close();
        //       database = null;
        //       await Future.delayed(Duration(milliseconds: 200));
        //       String copyPath = await getDBFilePath("${publicKey}_copy");
        //       bool copyTemp = await _copyDB2Plaintext(path, copyPath, sourcePwd: "");
        //       if (copyTemp) {
        //         bool copyBack = await _copyDB2Encrypted(copyPath, path, password);
        //         _deleteDBFile(copyPath); // await
        //         if (copyBack) {
        //           try {
        //             database = await _openDB(path, "", publicKey: publicKey);
        //           } catch (e) {}
        //           if (database == null) {
        //             database = await _tryOpenDB(path, password, publicKey: publicKey);
        //             if (database != null) {
        //               SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //               SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        //             } else {
        //               logger.e("DB - open - open copy fail");
        //             }
        //           } else {
        //             SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //             SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
        //           }
        //         } else {
        //           logger.e("DB - open - copy_2 fail");
        //         }
        //       } else {
        //         logger.e("DB - open - copy_1 fail");
        //       }
        //       _upgradeTipSink.add(null);
        //     }
        //   } else {
        //     if (database != null) {
        //       SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
        //       SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
        //     } else {
        //       database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
        //       if (database == null) {
        //         Toast.show("database open failed...");
        //       } else {
        //         // success
        //       }
        //     }
        //   }
        // }
      }
    }
    if (database != null) _openedSink.add(true);
  }

  Future<Database?> _tryOpenDB(String path, String password, {String publicKey = "", bool upgradeTip = false}) async {
    try {
      return await _openDB(path, password, publicKey: publicKey, upgradeTip: upgradeTip);
    } catch (e, st) {
      handleError(e, st);
      _upgradeTipSink.add(null);
      // Toast.show("database open error");
    }
    return null;
  }

  Future<Database> _openDB(String path, String password, {String publicKey = "", bool upgradeTip = false}) async {
    if (upgradeTip) {
      if (await needUpgrade(publicKey)) {
        _upgradeTipSink.add(".");
      } else {
        _upgradeTipSink.add(null);
      }
    }

    // test
    // int i = 0;
    // while (i < 100) {
    //   if (upgradeTip) _upgradeTipSink.add("test_$i");
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
        logger.i("DB - onConfigure - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - config - cipher_version:$value'));
      },
      onCreate: (Database db, int version) async {
        logger.i("DB - onCreate - version:$version - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - create - cipher_version:$value'));
        if (upgradeTip) _upgradeTipSink.add("..");

        await ContactStorage.create(db);
        await DeviceInfoStorage.create(db);
        await TopicStorage.create(db);
        await SubscriberStorage.create(db);
        await MessageStorage.create(db);
        await SessionStorage.create(db);
        await PrivateGroupStorage.create(db);
        await PrivateGroupItemStorage.create(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - onUpgrade - old:$oldVersion - new:$newVersion");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - upgrade - cipher_version:$value'));
        if (upgradeTip) _upgradeTipSink.add("...");

        // 1 -> 2
        bool v1to2 = false;
        if ((oldVersion <= 1) && (newVersion >= 2)) {
          v1to2 = true;
          await Upgrade1to2.upgradeTopicTable2V3(db);
          await Upgrade1to2.upgradeContactSchema2V3(db);
        }

        // 2 -> 3
        bool v2to3 = false;
        if ((v1to2 || (oldVersion == 2)) && (newVersion >= 3)) {
          v2to3 = true;
          await Upgrade2to3.updateTopicTableToV3ByTopic(db);
          await Upgrade2to3.updateTopicTableToV3BySubscriber(db);
        }

        // 3 -> 4
        bool v3to4 = false;
        if ((v2to3 || (oldVersion == 3)) && (newVersion >= 4)) {
          v3to4 = true;
          await Upgrade3to4.updateSubscriberV3ToV4(db);
        }

        // 4 -> 5
        bool v4to5 = false;
        if ((v3to4 || (oldVersion == 4)) && (newVersion >= 5)) {
          v4to5 = true;
          await Upgrade4to5.upgradeContact(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.createDeviceInfo(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.upgradeTopic(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.upgradeSubscriber(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.upgradeMessages(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.createSession(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade4to5.deletesOldTables(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
        }

        // 5 -> 6
        if ((v4to5 || (oldVersion == 5)) && (newVersion >= 6)) {
          await Upgrade5to6.createPrivateGroup(db);
          await Upgrade5to6.createPrivateGroupItem(db);
          await Upgrade5to6.upgradeMessages(db);
        }

        // dismiss tip dialog
        if (upgradeTip) _upgradeTipSink.add(null);
      },
      onOpen: (Database db) async {
        int version = await db.getVersion();
        logger.i("DB - onOpen - version:$version - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - opened - cipher_version:$value'));
        if (upgradeTip) _upgradeTipSink.add(null);

        if (publicKey.isNotEmpty) SettingsStorage.setSettings("${SettingsStorage.DATABASE_VERSION}:$publicKey", version); // await
      },
    );
    return db;
  }

  Future close() async {
    await _lock.synchronized(() async {
      await database?.close();
      database = null;
      _openedSink.add(false);
    });
  }

  bool isOpen() {
    return database?.isOpen == true;
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

  Future<bool> _deleteDBFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    await deleteDatabase(filePath);
    File file = File(filePath);
    if (!(await file.exists())) return true;
    if (file.existsSync()) {
      file.deleteSync(recursive: true);
      return true;
    }
    return false;
  }

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

  Future<bool> _copyDB2Plaintext(String sourcePath, String targetPath, {String sourcePwd = ""}) async {
    try {
      // source
      Database sourceDB = await _openDB(sourcePath, sourcePwd);
      // target
      bool targetExists = await databaseExists(targetPath);
      if (targetExists) {
        await _deleteDBFile(targetPath);
        await Future.delayed(Duration(milliseconds: 100));
      }
      Database targetDB = await _openDB(targetPath, "");
      // copy
      await sourceDB.execute("Attach DATABASE `$targetPath` AS `plaintext` KEY ``");
      await sourceDB.execute("INSERT INTO `plaintext`.`${ContactStorage.tableName}` SELECT * FROM `${ContactStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${DeviceInfoStorage.tableName}` SELECT * FROM `${DeviceInfoStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${TopicStorage.tableName}` SELECT * FROM `${TopicStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${SubscriberStorage.tableName}` SELECT * FROM `${SubscriberStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${PrivateGroupStorage.tableName}` SELECT * FROM `${PrivateGroupStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${PrivateGroupItemStorage.tableName}` SELECT * FROM `${PrivateGroupItemStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${MessageStorage.tableName}` SELECT * FROM `${MessageStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${SessionStorage.tableName}` SELECT * FROM `${SessionStorage.tableName}`");
      await sourceDB.execute("DETACH `plaintext`");
      // close
      await sourceDB.close();
      await targetDB.close();
      // if (sourcePwd.isNotEmpty) await sourceDB.execute("PRAGMA key = $sourcePwd"); // key error
      // await sourceDB.execute("Attach DATABASE `$targetPath` AS copy_1 KEY ''");
      // await sourceDB.execute("SELECT sqlcipher_export(`copy_1`)"); //  no sqlcipher import
      // await sourceDB.execute("DETACH DATABASE `copy_1`");
    } catch (e, st) {
      handleError(e, st);
      return false;
    }
    return true;
  }

  Future<bool> _copyDB2Encrypted(String sourcePath, String targetPath, String targetPwd) async {
    try {
      // source
      Database sourceDB = await _openDB(sourcePath, "");
      // target
      bool targetExists = await databaseExists(targetPath);
      if (targetExists) {
        await _deleteDBFile(targetPath);
        await Future.delayed(Duration(milliseconds: 100));
      }
      Database targetDB = await _openDB(targetPath, targetPwd);
      // copy
      await targetDB.execute("Attach DATABASE `$sourcePath` AS `plaintext` KEY ``");
      await targetDB.execute("INSERT INTO `${ContactStorage.tableName}` SELECT * FROM `plaintext`.`${ContactStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${DeviceInfoStorage.tableName}` SELECT * FROM `plaintext`.`${DeviceInfoStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${TopicStorage.tableName}` SELECT * FROM `plaintext`.`${TopicStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${SubscriberStorage.tableName}` SELECT * FROM `plaintext`.`${SubscriberStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${PrivateGroupStorage.tableName}` SELECT * FROM `plaintext`.`${PrivateGroupStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${PrivateGroupItemStorage.tableName}` SELECT * FROM `plaintext`.`${PrivateGroupItemStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${MessageStorage.tableName}` SELECT * FROM `plaintext`.`${MessageStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${SessionStorage.tableName}` SELECT * FROM `plaintext`.`${SessionStorage.tableName}`");
      await targetDB.execute("DETACH `plaintext`");
      // close
      await sourceDB.close();
      await targetDB.close();
      // if (sourcePwd.isNotEmpty) await sourceDB.execute("PRAGMA key = $sourcePwd"); // key error
      // await sourceDB.execute("Attach DATABASE `$targetPath` AS copy_1 KEY ''");
      // await sourceDB.execute("SELECT sqlcipher_export(`copy_1`)"); //  no sqlcipher import
      // await sourceDB.execute("DETACH DATABASE `copy_1`");
    } catch (e, st) {
      handleError(e, st);
      return false;
    }
    return true;
  }

  Future fixIOS_152() async {
    if (!Platform.isIOS) return;
    if (!DeviceInfoCommon.isIOSDeviceVersionLess152()) return;
    bool fixed = (await SettingsStorage.getSettings(SettingsStorage.DATABASE_FIXED_IOS_152)) ?? false;
    if (fixed) return;
    _upgradeTipSink.add("...");
    List<WalletSchema> wallets = await walletCommon.getWallets();
    for (var i = 0; i < wallets.length; i++) {
      WalletSchema wallet = wallets[i];
      String publicKey = wallet.publicKey;
      String path = await getDBFilePath(publicKey);
      bool exists = await databaseExists(path);
      bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false; // FUTURE:GG IOS_152_V2
      if (exists && !clean) {
        String seed = await walletCommon.getSeed(wallet.address);
        await _openWithFix(publicKey, seed);
        await database?.close();
        database = null;
        await SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // FUTURE:GG IOS_152_V2
      }
    }
    await SettingsStorage.setSettings(SettingsStorage.DATABASE_FIXED_IOS_152, true); // FUTURE:GG IOS_152_V2
    _upgradeTipSink.add(null);
  }
}
