
import 'dart:convert';

import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/entity/subscriber_repo.dart';
import 'package:nmobile/model/entity/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../entity/contact.dart';

class NKNDataManager {
  factory NKNDataManager() => _getInstance();

  static NKNDataManager get instance => _getInstance();
  static NKNDataManager _instance;

  NKNDataManager._internal();

  static NKNDataManager _getInstance() {
    if (_instance == null) {
      _instance = new NKNDataManager._internal();
    }
    return _instance;
  }

  static const String _CHAT_DATABASE_NAME = 'nkn';

  static String _publicKey;
  static String _password;

  static int dataBaseVersionV2 = 2;
  static int dataBaseVersionV3 = 3;
  static int dataBaseVersionV4 = 4;

  static int currentDatabaseVersion = dataBaseVersionV3;

  static Database _currentDatabase;

  Future<Database> open() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '$_publicKey.db');
    var db = await openDatabase(
      path,
      password: _password,
      version: currentDatabaseVersion,
      onCreate: (Database db, int version) async {
        await MessageSchema.create(db, version);

        await ContactSchema.create(db);
        await TopicRepo.create(db, version);
        await SubscriberRepo.create(db, version);

        var now = DateTime.now();
        var publicKey = _publicKey.replaceFirst(_CHAT_DATABASE_NAME + '_', '');
        var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(publicKey);
        await db.insert(
            ContactSchema.tableName,
            ContactSchema(
              type: ContactType.me,
              clientAddress: publicKey,
              nknWalletAddress: walletAddress,
              createdTime: now,
              updatedTime: now,
              profileVersion: uuid.v4(),
            ).toEntity(publicKey));
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        NLog.w('OldVersion is___'+oldVersion.toString());
        NLog.w('NewVersion is___'+newVersion.toString());
        if (newVersion >= dataBaseVersionV2) {
          await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
          await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
        }
        if (newVersion >= dataBaseVersionV4){
          await TopicRepo.updateTopicTableToV4(db);
          await SubscriberRepo.updateTopicTableToV4(db);
        }
      },
    );
    await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
    await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
    await NKNDataManager.updateSubsriberV3ToV4(db);
    return db;
  }

  initDataBase(String pubKey, String password) async {
    if (_currentDatabase == null) {
      _publicKey = publicKey2DbName(pubKey);
      _password = password;
      _currentDatabase = await NKNDataManager.instance.open();
    }
  }

  changeDatabase(String pubKey, String password) async {
    if (_currentDatabase != null) {
      await _currentDatabase.close();
    }

    /// changeDataBase
    _publicKey = publicKey2DbName(pubKey);
    _password = password;

    if (_publicKey != null && _password != null) {
      NLog.w('Change database__' + _publicKey);
      _currentDatabase = await NKNDataManager.instance.open();
    } else {
      NLog.w('Wrong!!! change database no _publicKey');
    }
  }

  Future<Database> currentDatabase() async {
    if (_publicKey == null || _password == null) {
      return null;
    }
    if (_publicKey.isEmpty || _password.isEmpty) {
      return null;
    }
    if (_currentDatabase == null) {
      _currentDatabase = await NKNDataManager.instance.open();
    }
    return _currentDatabase;
  }

  close() async {
    await _currentDatabase.close();
    _currentDatabase = null;
  }

  delete() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '$_publicKey.db');
    try {
      await deleteDatabase(path);
    } catch (e) {
      NLog.w('Close database E:' + e.toString());
    }
  }

  static String publicKey2DbName(String publicKey) {
    return '${_CHAT_DATABASE_NAME}_$publicKey';
  }

  static final deleteTopicSql = '''DROP TABLE IF EXISTS Topic;''';
  static final createTopicSql = '''
      CREATE TABLE IF NOT EXISTS topic (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        count INTEGER,
        avatar TEXT,
        theme_id INTEGER,
        time_update INTEGER,
        expire_at INTEGER,
        is_top BOOLEAN DEFAULT 0,
        options TEXT
      )''';

  static upgradeTopicTable2V3(Database db, int dbVersion) async {
    String topicTable = 'topic';
    var sql =
        "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$topicTable'";
    var res = await db.rawQuery(sql);
    if (res == null) {
      await db.execute(createTopicSql);
    } else {
      bool isTopExists =
          await NKNDataManager.checkColumnExists(db, topicTable, 'is_top');
      bool themeIdExists =
          await NKNDataManager.checkColumnExists(db, topicTable, 'theme_id');
      bool timeUpdateExists =
          await NKNDataManager.checkColumnExists(db, topicTable, 'time_update');
      bool isExpireAtExists =
          await NKNDataManager.checkColumnExists(db, topicTable, 'expire_at');
      if (isTopExists == false) {
        await db.execute(
            'ALTER TABLE $topicTable ADD COLUMN is_top BOOLEAN DEFAULT 0');
      }
      if (themeIdExists == false) {
        await db.execute(
            'ALTER TABLE $topicTable ADD COLUMN theme_id INTEGER DEFAULT 0');
      }
      if (timeUpdateExists == false) {
        await db.execute(
            'ALTER TABLE $topicTable ADD COLUMN time_update INTEGER DEFAULT 0');
      }
      if (isExpireAtExists == false) {
        await db.execute(
            'ALTER TABLE $topicTable ADD COLUMN expire_at INTEGER DEFAULT 0');
      }
    }
  }

  static updateSubsriberV3ToV4(Database db) async{
    String subsriberTable = 'subscriber';
    var sql =
        "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$subsriberTable'";
    var res = await db.rawQuery(sql);
    if (res == null) {
      await db.execute(SubscriberRepo.createSqlV5);
    } else {
      bool memberStatusReady =
      await NKNDataManager.checkColumnExists(db, subsriberTable, 'member_status');
      if (memberStatusReady == false) {
        await db.execute(
            'ALTER TABLE $subsriberTable ADD COLUMN member_status BOOLEAN DEFAULT 0');
      }
    }
  }

  static upgradeContactSchema2V3(Database db, int dbVersion) async {
    String tableName = ContactSchema.tableName;
    var sql =
        "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$tableName'";
    var res = await db.rawQuery(sql);
    var returnRes = res != null && res.length > 0;

    final createSqlV3 = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        address TEXT,
        first_name TEXT,
        last_name TEXT,
        data TEXT,
        options TEXT,
        avatar TEXT,
        created_time INTEGER,
        updated_time INTEGER,
        profile_version TEXT,
        profile_expires_at INTEGER,
        is_top BOOLEAN DEFAULT 0,
        device_token TEXT,
        notification_open BOOLEAN DEFAULT 0
      )''';
    if (returnRes == false) {
      // create contact Table
      await db.execute(createSqlV3);
    } else {
      var batch = db.batch();
      bool deviceTokenExists =
          await NKNDataManager.checkColumnExists(db, tableName, 'device_token');
      bool notificationOpenExists = await NKNDataManager.checkColumnExists(
          db, tableName, 'notification_open');
      bool isTopExists =
          await NKNDataManager.checkColumnExists(db, tableName, 'is_top');
      if (deviceTokenExists == false) {
        batch.execute(
            'ALTER TABLE $tableName ADD COLUMN device_token TEXT DEFAULT ""');
      }
      if (notificationOpenExists == false) {
        NLog.w('notificationOpenExists runtTime Type ==='+notificationOpenExists.toString());
        batch.execute(
            'ALTER TABLE $tableName ADD COLUMN notification_open BOOLEAN DEFAULT 0');
      }
      if (isTopExists == false) {
        batch.execute(
            'ALTER TABLE $tableName ADD COLUMN is_top BOOLEAN DEFAULT 0');
      }
      await batch.commit();
    }

    var contactResult = await db.query(
        tableName,
    );
    if (contactResult.isNotEmpty){
      Map contact0 = contactResult[0];
      var notificationOpen = contact0['notification_open'];
      String modifyType = 'String';
      if (notificationOpen.runtimeType.toString() == modifyType){
        String contactTemp = 'contact_temp';
        final createContactTempSql = '''
          CREATE TABLE IF NOT EXISTS $contactTemp (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT,
          address TEXT,
          first_name TEXT,
          last_name TEXT,
          data TEXT,
          options TEXT,
          avatar TEXT,
          created_time INTEGER,
          updated_time INTEGER,
          profile_version TEXT,
          profile_expires_at INTEGER,
          is_top BOOLEAN DEFAULT 0,
          device_token TEXT,
          notification_open BOOLEAN DEFAULT 0
        )''';
        await db.execute(createContactTempSql);

        for (Map contact in contactResult){
          int notificationValue = 0;
          if (contact['notification_open'] == '1'){
            notificationValue = 1;
          }
          String firstName = '';
          if (contact['first_name'] != null){
            firstName = contact['first_name'];
          }
          String avatar;
          if (contact['avatar'] != null){
            avatar = contact['avatar'];
          }
          Map<String,dynamic> insertMap = {
            'type': contact['type'],
            'address': contact['address'],
            'notification_open': notificationValue,
            'first_name': firstName,
            'avatar': avatar,
          };
          if (contact['options'] != null){
            insertMap['options'] = contact['options'];
          }
          if (contact['profile_version'] != null){
            insertMap['profile_version'] = contact['profile_version'];
          }
          if (contact['data'] != null){
            insertMap['data'] = contact['data'];
          }

          try{
            await db.insert(
                contactTemp, insertMap);
          }
          catch(e){
            NLog.w('await db.insert is+____'+e.toString());
          }
        }
        String dropContact = '''DROP TABLE IF EXISTS $tableName;''';
        await db.execute(dropContact);
        await db.execute(createSqlV3);

        var contactTempResult = await db.query(
          contactTemp,
        );
        for (Map contact in contactTempResult){
          Map<String,dynamic> insertMap = {
            'type': contact['type'],
            'address': contact['address'],
            'notification_open': contact['notification_open'],
            'first_name': contact['first_name'],
            'avatar': contact['avatar'],
            'created_time': DateTime.now().millisecondsSinceEpoch,
            'updated_time': DateTime.now().millisecondsSinceEpoch,
          };

          if (contact['options'] != null){
            insertMap['options'] = contact['options'];
          }
          if (contact['profile_version'] != null){
            insertMap['profile_version'] = contact['profile_version'];
          }
          if (contact['data'] != null){
            insertMap['data'] = contact['data'];
          }
          NLog.w('insertMap is_____'+contact.toString());
          try{
            await db.insert(
                tableName, insertMap);
          }
          catch(e){
            NLog.w('insertMap is_____ db.insert is+____'+e.toString());
          }
        }
        String deleteContactTemp = '''DROP TABLE IF EXISTS $contactTemp;''';
        await db.execute(deleteContactTemp);
      }
    }
  }

  static Future<bool> checkColumnExists(
      Database db, String tableName, String columnName) async {
    bool result = false;
    List resultList = await db.rawQuery("PRAGMA table_info($tableName)");
    for (Map columnMap in resultList) {
      String name = columnMap['name'];
      if (name == columnName) {
        return true;
      }
    }
    return result;
  }
}
