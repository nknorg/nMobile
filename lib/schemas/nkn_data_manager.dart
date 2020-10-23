
import 'package:flutter/cupertino.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'contact.dart';

class NKNDataManager{
  static final deleteTopicSql = '''DROP TABLE IF EXISTS Topic;''';
  static final createTopicSql = '''
      CREATE TABLE IF NOT EXISTS $tableName (
        $id INTEGER PRIMARY KEY AUTOINCREMENT,
        $topic TEXT,
        $count INTEGER,
        $avatar TEXT,
        $theme_id INTEGER,
        $time_update INTEGER,
        $expire_at INTEGER,
        $is_top BOOLEAN DEFAULT 0,
        $options TEXT
      )''';

  static upgradeTopicTable2V3(Database db, int dbVersion) async {
    print('Still update topic');
    // await db.execute(deleteTopicSql);
    await db.execute(createTopicSql);
  }

  static upgradeContactSchema2V3(Database db, int dbVersion) async {
    String tableName = ContactSchema.tableName;
    var sql = "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$tableName'";
    var res = await db.rawQuery(sql);
    var returnRes = res!=null && res.length > 0;

    if (returnRes == false){
      /// 需要创建表
      print('需要创建表');
      final createSqlV4 = '''
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
      // index
      await db.execute(createSqlV4);
    }
    else{
      var batch = db.batch();
      await batch.execute('ALTER TABLE $tableName ADD COLUMN device_token TEXT DEFAULT "0"');
      await batch.execute('ALTER TABLE $tableName ADD COLUMN notification_open TEXT DEFAULT "0"');
      await batch.execute('ALTER TABLE $tableName ADD COLUMN is_top BOOLEAN DEFAULT 0');
      await batch.commit();
      print('update isTop');
    }
    // bool deviceTokenExists = await NKNDataManager.checkColumnExists(db, tableName, 'device_token');
    // bool notificationOpenExists = await NKNDataManager.checkColumnExists(db, tableName, 'notification_open');
    // bool isTopExists = await NKNDataManager.checkColumnExists(db, tableName, 'is_top');
    // if (deviceTokenExists == false){
    //   await db.execute('ALTER TABLE $tableName ADD COLUMN device_token TEXT DEFAULT "0"');
    // }
    // else if (notificationOpenExists == false){
    //   await db.execute('ALTER TABLE $tableName ADD COLUMN notification_open TEXT DEFAULT "0"');
    // }
    // else if (isTopExists == false){
    //   await db.execute('ALTER TABLE $tableName ADD COLUMN is_top BOOLEAN DEFAULT 0');
    // }
  }

  static Future <bool> checkColumnExists(Database db, String tableName, String columnName) async{
    bool result = false;
    List resultList = await db.rawQuery("PRAGMA table_info($tableName)");
    for (Map columnMap in resultList){
      String name = columnMap['name'];
      if (name == columnName){
        return true;
      }
    }
    return result;
  }
}