import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
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
  static int currentDatabaseVersion = 4;

  // ignore: close_sinks
  StreamController<bool> _openedController = StreamController<bool>.broadcast();
  StreamSink<bool> get _openedSink => _openedController.sink;
  Stream<bool> get openedStream => _openedController.stream;

  Database? database;

  DB();

  Future<Database> _openDB(String publicKey, String password) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    logger.i("DB - path:$path - pwd:$password");
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      singleInstance: true,
      onCreate: (Database db, int version) async {
        logger.i("DB - create - version:$version");
        await ContactStorage.create(db, version);
        await DeviceInfoStorage.create(db, version);
        await TopicStorage.create(db, version);
        await SubscriberStorage.create(db, version);
        await SessionStorage.create(db, version);
        await MessageStorage.create(db, version);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - upgrade - old:$oldVersion - new:$newVersion");
        // Loading.show(); // TODO:GG loading(tip)
        // TODO:GG index sync
        // TODO:GG deviceInfo create
        // TODO:GG session data move
        // TODO:GG topic fields change
        // TODO:GG delete message(receipt) + read message(piece + contactOptions)
        // TODO:GG take care old version any upgrade
        // if (newVersion >= dataBaseVersionV2) {
        //   await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
        //   await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
        // }
        // if (newVersion >= dataBaseVersionV3 && oldVersion == 2){
        //   await TopicRepo.updateTopicTableToV3(db);
        //   await SubscriberRepo.updateTopicTableToV3(db);
        // }
        if (oldVersion < 4 && newVersion >= 4) {
          await SessionStorage.create(db, newVersion);
        }
        // Loading.dismiss(); // TODO:GG loading(tip)
      },
      onOpen: (Database db) async {
        logger.i("DB - open");
      },
    );
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
    String databasePwd = hexEncode(Uint8List.fromList(sha256(hexDecode(seed))));
    await open(publicKey, databasePwd);

    ContactSchema? me = await contactCommon.getMe(clientAddress: publicKey, canAdd: true);
    contactCommon.meUpdateSink.add(me);
    return true;
  }

  Future open(String publicKey, String password) async {
    //if (database != null) return; // bug!
    database = await _openDB(publicKey, password);
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
}
