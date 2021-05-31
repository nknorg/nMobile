import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 3;
  static Database? currentDatabase;

  String publicKey;

  DB({required this.publicKey});

  static Future<Database> _openDB(String publicKey, String password) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      onCreate: (Database db, int version) async {
        logger.i("DB - database tables create");
        await MessageStorage.create(db, version);
        await ContactStorage.create(db, version);
        await TopicStorage.create(db, version);
        // await SubscriberRepo.create(db, version);

        // create contact me
        try {
          ContactSchema? me = await ContactSchema.createByType(publicKey, ContactType.me);
          if (me == null) return;
          Map<String, dynamic> add = await me.toMap();
          var count = await db.insert(ContactStorage.tableName, add);
          logger.i("DB - contact me insert scheme:${count > 0 ? me : null}");
        } catch (e) {
          handleError(e);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - database tables upgrade");
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
    if (currentDatabase != null) return;
    currentDatabase = await _openDB(publicKey, password);
  }

  close() async {
    await currentDatabase?.close();
    currentDatabase = null;
  }

  delete() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    try {
      await deleteDatabase(path);
    } catch (e) {
      logger.e('DB - Close db error', e);
    }
  }
}
