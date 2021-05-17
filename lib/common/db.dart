import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'contact/contact.dart';

class DB {
  static const String CHAT_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 3;
  static Database currentDatabase;

  String publicKey;

  DB({this.publicKey});

  static Future<Database> _openDB(String publicKey, String password) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${CHAT_DATABASE_NAME}_$publicKey.db');
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      onCreate: (Database db, int version) async {
        await MessageStorage.create(db, version);
        await ContactStorage.create(db, version);
        // await TopicRepo.create(db, version);
        // await SubscriberRepo.create(db, version);

        // create me
        var now = DateTime.now();
        var walletAddress = await Wallet.pubKeyToWalletAddr(publicKey);
        await db.insert(
            ContactStorage.tableName,
            ContactSchema(
              type: ContactType.me,
              clientAddress: publicKey,
              nknWalletAddress: walletAddress,
              createdTime: now,
              updatedTime: now,
              profileVersion: uuid.v4(),
            ).toEntity());
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // if (newVersion >= dataBaseVersionV2) {
        //   await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
        //   await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
        // }
        // if (newVersion >= dataBaseVersionV3 && oldVersion == 2){
        //   await TopicRepo.updateTopicTableToV3(db);
        //   await SubscriberRepo.updateTopicTableToV3(db);
        // }
      },
    );
    // await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
    // await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
    // await NKNDataManager.updateSubscriberV3ToV4(db);

    return db;
  }

  static open(String publicKey, String password) async {
    if (currentDatabase != null) {
      return;
    }
    currentDatabase = await _openDB(publicKey, password);
  }

  close() async {
    await currentDatabase.close();
    currentDatabase = null;
  }

  delete() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${CHAT_DATABASE_NAME}_$publicKey.db');
    try {
      await deleteDatabase(path);
    } catch (e) {
      logger.e('Close db error', e);
    }
  }
}
