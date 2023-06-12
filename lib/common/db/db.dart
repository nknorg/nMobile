import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db/upgrade1to2.dart';
import 'package:nmobile/common/db/upgrade2to3.dart';
import 'package:nmobile/common/db/upgrade3to4.dart';
import 'package:nmobile/common/db/upgrade4to5.dart';
import 'package:nmobile/common/db/upgrade5to6.dart';
import 'package:nmobile/common/db/upgrade6to7.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/message_piece.dart';
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
// import 'package:sqflite/sqflite.dart';

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static const int VERSION_DB_NOW = 7;

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

  Map<int, int> _upgradeAt = {};

  DB();

  Future open(String publicKey, String seed) {
    return _lock.synchronized(() async {
      // FUTURE:GG IOS_152_V3 (remove _openWithFix())
      // database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
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
        // FUTURE:GG IOS_152_V2
        database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
        if (database != null) {
          SettingsStorage.setSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey", true); // await
          SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
        } else {
          Toast.show("database create fail");
        }
      } else {
        // FUTURE:GG IOS_152_V2
        bool clean = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_CLEAN_PWD_ON_IOS_14}:$publicKey")) ?? false;
        bool reset = (await SettingsStorage.getSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey")) ?? false;
        if (reset) {
          database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
          if (database == null) {
            Toast.show("database open failed.");
            await SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false);
            await Future.delayed(Duration(milliseconds: 500));
            return await _openWithFix(publicKey, seed);
          }
        } else {
          try {
            database = await _openDB(path, "", publicKey: publicKey);
          } catch (e, st) {
            if (clean) handleError(e, st);
          }
          if (database != null) {
            _upgradeTipSink.add("~ ~ ~ ~ ~");
            await database?.close();
            database = null;
            await Future.delayed(Duration(milliseconds: 200));
            String copyPath = await getDBFilePath("${publicKey}_copy");
            bool copyTemp = await _copyDB2Plaintext(path, copyPath, sourcePwd: "");
            if (copyTemp) {
              bool copyBack = await _copyDB2Encrypted(copyPath, path, password);
              _deleteDBFile(copyPath); // await
              if (copyBack) {
                database = await _tryOpenDB(path, password, publicKey: publicKey, upgradeTip: true);
                if (database != null) {
                  SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", true); // await
                } else {
                  logger.e("DB - open - open copy fail");
                  SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
                }
              } else {
                logger.e("DB - open - copy_2 fail");
                SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
              }
            } else {
              logger.e("DB - open - copy_1 fail");
              SettingsStorage.setSettings("${SettingsStorage.DATABASE_RESET_PWD_ON_IOS_16}:$publicKey", false); // await
            }
            _upgradeTipSink.add(null);
          } else {
            Toast.show("database open failed.");
          }
        }
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

    var db = await openDatabase(
      path,
      password: password,
      version: VERSION_DB_NOW,
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
        await PrivateGroupStorage.create(db);
        await PrivateGroupItemStorage.create(db);
        await MessageStorage.create(db);
        await MessagePieceStorage.create(db);
        await SessionStorage.create(db);
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
        bool v5to6 = false;
        if ((v4to5 || (oldVersion == 5)) && (newVersion >= 6)) {
          v5to6 = true;
          await Upgrade5to6.createPrivateGroup(db);
          await Upgrade5to6.createPrivateGroupItem(db);
          await Upgrade5to6.upgradeMessages(db);
        }

        // 6-> 7
        if ((v5to6 || (oldVersion == 6)) && (newVersion >= 7)) {
          await Upgrade6to7.upgradeDeviceInfo(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeContact(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeTopic(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeSubscriber(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradePrivateGroup(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradePrivateGroupItem(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeMessage(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeMessagePiece(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.upgradeSession(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
          await Upgrade6to7.deletesOldTables(db, upgradeTipSink: upgradeTip ? _upgradeTipSink : null);
        }

        // dismiss tip dialog
        if (upgradeTip) _upgradeTipSink.add(null);
      },
      onOpen: (Database db) async {
        int version = await db.getVersion();
        logger.i("DB - onOpen - version:$version - path:${db.path}");
        // db.rawQuery('PRAGMA cipher_version').then((value) => logger.i('DB - opened - cipher_version:$value'));
        if (upgradeTip) _upgradeTipSink.add(null);
        if (publicKey.isNotEmpty) {
          // version_now
          await SettingsStorage.setSettings("${SettingsStorage.DATABASE_VERSION}:$publicKey", version); // await
          // upgrade_at
          for (var i = 1; i <= VERSION_DB_NOW; i++) {
            int? value = await SettingsStorage.getSettings("${SettingsStorage.DATABASE_VERSION_TIME}:$publicKey:$i");
            int dbUpgradeAt = int.tryParse(value?.toString() ?? "0") ?? 0;
            if (dbUpgradeAt <= 0) {
              dbUpgradeAt = DateTime.now().millisecondsSinceEpoch;
              SettingsStorage.setSettings("${SettingsStorage.DATABASE_VERSION_TIME}:$publicKey:$i", dbUpgradeAt); // await
            }
            _upgradeAt[i] = dbUpgradeAt;
          }
          logger.d("DB - onOpen - upgrade_at:$_upgradeAt");
        }
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
    return savedVersion != VERSION_DB_NOW;
  }

  int upgradeAt(int i) {
    return _upgradeAt[i] ?? 0;
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
    // source+target
    Database sourceDB;
    Database targetDB;
    try {
      sourceDB = await _openDB(sourcePath, sourcePwd);
      bool targetExists = await databaseExists(targetPath);
      if (targetExists) {
        await _deleteDBFile(targetPath);
        await Future.delayed(Duration(milliseconds: 100));
      }
      targetDB = await _openDB(targetPath, "");
    } catch (e, st) {
      handleError(e, st);
      return false;
    }
    // copy
    try {
      await sourceDB.execute("Attach DATABASE `$targetPath` AS `plaintext` KEY ``");
      await sourceDB.execute("INSERT INTO `plaintext`.`${ContactStorage.tableName}` SELECT * FROM `${ContactStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${DeviceInfoStorage.tableName}` SELECT * FROM `${DeviceInfoStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${TopicStorage.tableName}` SELECT * FROM `${TopicStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${SubscriberStorage.tableName}` SELECT * FROM `${SubscriberStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${PrivateGroupStorage.tableName}` SELECT * FROM `${PrivateGroupStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${PrivateGroupItemStorage.tableName}` SELECT * FROM `${PrivateGroupItemStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${MessageStorage.tableName}` SELECT * FROM `${MessageStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${MessagePieceStorage.tableName}` SELECT * FROM `${MessagePieceStorage.tableName}`");
      await sourceDB.execute("INSERT INTO `plaintext`.`${SessionStorage.tableName}` SELECT * FROM `${SessionStorage.tableName}`");
      await sourceDB.execute("DETACH `plaintext`");
    } catch (e) {}
    // close
    try {
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
    // source+target
    Database sourceDB;
    Database targetDB;
    try {
      sourceDB = await _openDB(sourcePath, "");
      bool targetExists = await databaseExists(targetPath);
      if (targetExists) {
        await _deleteDBFile(targetPath);
        await Future.delayed(Duration(milliseconds: 100));
      }
      targetDB = await _openDB(targetPath, targetPwd);
    } catch (e, st) {
      handleError(e, st);
      return false;
    }
    // copy
    try {
      await targetDB.execute("Attach DATABASE `$sourcePath` AS `plaintext` KEY ``");
      await targetDB.execute("INSERT INTO `${ContactStorage.tableName}` SELECT * FROM `plaintext`.`${ContactStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${DeviceInfoStorage.tableName}` SELECT * FROM `plaintext`.`${DeviceInfoStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${TopicStorage.tableName}` SELECT * FROM `plaintext`.`${TopicStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${SubscriberStorage.tableName}` SELECT * FROM `plaintext`.`${SubscriberStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${PrivateGroupStorage.tableName}` SELECT * FROM `plaintext`.`${PrivateGroupStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${PrivateGroupItemStorage.tableName}` SELECT * FROM `plaintext`.`${PrivateGroupItemStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${MessageStorage.tableName}` SELECT * FROM `plaintext`.`${MessageStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${MessagePieceStorage.tableName}` SELECT * FROM `plaintext`.`${MessagePieceStorage.tableName}`");
      await targetDB.execute("INSERT INTO `${SessionStorage.tableName}` SELECT * FROM `plaintext`.`${SessionStorage.tableName}`");
      await targetDB.execute("DETACH `plaintext`");
    } catch (e) {}
    // close
    try {
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
}
