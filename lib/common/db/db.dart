import 'dart:async';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db/upgrade1to2.dart';
import 'package:nmobile/common/db/upgrade2to3.dart';
import 'package:nmobile/common/db/upgrade3to4.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 5;

  // ignore: close_sinks
  StreamController<bool> _openedController = StreamController<bool>.broadcast();
  StreamSink<bool> get _openedSink => _openedController.sink;
  Stream<bool> get openedStream => _openedController.stream;

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
        await ContactStorage.create(db, version);
        await DeviceInfoStorage.create(db, version);
        await TopicStorage.create(db, version);
        await SubscriberStorage.create(db, version);
        await MessageStorage.create(db, version);
        await SessionStorage.create(db, version);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - upgrade - old:$oldVersion - new:$newVersion");
        Loading.show(text: "数据库升级中,请勿离开此页面!"); // TODO:GG locale dbUpgrade
        // TODO:GG delete message(receipt) + read message(piece + contactOptions)
        // TODO:GG take care old version any upgrade
        if (oldVersion <= 1 && newVersion >= 2) {
          await Upgrade1to2.upgradeTopicTable2V3(db);
          await Upgrade1to2.upgradeContactSchema2V3(db);
        }
        if (oldVersion == 2 && newVersion >= 3) {
          await Upgrade2to3.updateTopicTableToV3ByTopic(db);
          await Upgrade2to3.updateTopicTableToV3BySubscriber(db);
        }
        if (oldVersion == 3 && newVersion >= 4) {
          await Upgrade3to4.updateSubscriberV3ToV4(db);
        }
        if (oldVersion == 4 && newVersion >= 5) {
          // TODO:GG deviceInfo create
          // TODO:GG session data move
          await SessionStorage.create(db, newVersion);
          await DeviceInfoStorage.create(db, newVersion);
        }
        Loading.dismiss();
      },
      onOpen: (Database db) async {
        logger.i("DB - opened");
        // await addTestData(
        //   db,
        //   selfAddress: clientCommon.address,
        //   sideAddress: "98796e46eef1dbdb72678433cdb78c989d12cde487f15f854b4d870a7045b525",
        //   topicName: "98.0916.001",
        // );
      },
    );
    // TODO:GG 这里要加吗
    // await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
    // await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
    // await NKNDataManager.updateSubscriberV3ToV4(db);
    return db;
  }

  Future<bool> openByDefault() async {
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

  // delete() async {
  //   var databasesPath = await getDatabasesPath();
  //   String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
  //   try {
  //     await deleteDatabase(path);
  //   } catch (e) {
  //     logger.e('DB - Close db error', e);
  //   }
  // }

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
