import 'dart:async';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db/upgrade1to2.dart';
import 'package:nmobile/common/db/upgrade2to3.dart';
import 'package:nmobile/common/db/upgrade3to4.dart';
import 'package:nmobile/common/db/upgrade4to5.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
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
import 'package:sqflite/utils/utils.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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

  Database? database;

  DB();

  Future<Database> _openDB(String publicKey, String seed) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    String password = hexEncode(sha256(seed));
    logger.i("DB - ready - path:$path - pwd:$password"); //  - exists:${await databaseExists(path)}

    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      singleInstance: true,
      onCreate: (Database db, int version) async {
        logger.i("DB - create - version:$version - path:${db.path}");
        await ContactStorage.create(db);
        await DeviceInfoStorage.create(db);
        await TopicStorage.create(db);
        await SubscriberStorage.create(db);
        await MessageStorage.create(db);
        await SessionStorage.create(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - upgrade - old:$oldVersion - new:$newVersion");

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
          _upgradeTipSink.add(null);
        }
      },
      onOpen: (Database db) async {
        int version = await db.getVersion();
        logger.i("DB - opened - version:$version - path:${db.path}");
        SettingsStorage.setSettings(SettingsStorage.DATABASE_VERSION, version);
      },
    );
    return db;
  }

  Future<bool> openByDefault() async {
    if (await needUpgrade()) return false;
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.address.isEmpty) {
      logger.i("DB - openByDefault - wallet default is empty");
      return false;
    }
    String publicKey = wallet.publicKey;
    String? seed = await walletCommon.getSeed(wallet.address);
    if (publicKey.isEmpty || seed == null || seed.isEmpty) {
      logger.w("DB - openByDefault - publicKey/seed error");
      return false;
    }
    await open(publicKey, seed);

    ContactSchema? me = await contactCommon.getMe(clientAddress: publicKey, canAdd: true);
    contactCommon.meUpdateSink.add(me);
    return true;
  }

  Future open(String publicKey, String seed) async {
    //if (database != null) return; // bug!
    database = await _openDB(publicKey, seed);
    _openedSink.add(true);
  }

  Future close() async {
    await database?.close();
    database = null;
    _openedSink.add(false);
  }

  bool isOpen() {
    return database != null && database!.isOpen;
  }

  Future<bool> needUpgrade() async {
    int? savedVersion = await SettingsStorage.getSettings(SettingsStorage.DATABASE_VERSION);
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
    var count = firstIntValue(await db.query('sqlite_master', columns: ['COUNT(*)'], where: 'type = ? AND name = ?', whereArgs: ['table', table]));
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
}
