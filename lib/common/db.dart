import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DB {
  static const String CHAT_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 3;
  static Database currentDatabase;

  String publicKey;

  DB({this.publicKey});

  static Future<Database> _openDB(String path, String password) async {
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      onCreate: (Database db, int version) async {
        await MessageStorage.create(db, version);

        // await ContactSchema.create(db);
        // await TopicRepo.create(db, version);
        // await SubscriberRepo.create(db, version);
        //
        // var now = DateTime.now();
        // var publicKey = _publicKey.replaceFirst(_CHAT_DATABASE_NAME + '_', '');
        // var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(publicKey);
        // await db.insert(
        //     ContactSchema.tableName,
        //     ContactSchema(
        //       type: ContactType.me,
        //       clientAddress: publicKey,
        //       nknWalletAddress: walletAddress,
        //       createdTime: now,
        //       updatedTime: now,
        //       profileVersion: uuid.v4(),
        //     ).toEntity(publicKey));
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
    if (currentDatabase != null) {}
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${CHAT_DATABASE_NAME}_$publicKey.db');
    currentDatabase = await _openDB(path, password);
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
