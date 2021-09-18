import 'package:nmobile/storages/contact.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';

class Upgrade1to2 {
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

  static upgradeTopicTable2V3(Database db) async {
    String topicTable = 'topic';
    var sql = "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$topicTable'";
    var res = await db.rawQuery(sql);
    if (res == null) {
      await db.execute(createTopicSql);
    } else {
      bool isTopExists = await DB.checkColumnExists(db, topicTable, 'is_top');
      bool themeIdExists = await DB.checkColumnExists(db, topicTable, 'theme_id');
      bool timeUpdateExists = await DB.checkColumnExists(db, topicTable, 'time_update');
      bool isExpireAtExists = await DB.checkColumnExists(db, topicTable, 'expire_at');
      if (isTopExists == false) {
        await db.execute('ALTER TABLE $topicTable ADD COLUMN is_top BOOLEAN DEFAULT 0');
      }
      if (themeIdExists == false) {
        await db.execute('ALTER TABLE $topicTable ADD COLUMN theme_id INTEGER DEFAULT 0');
      }
      if (timeUpdateExists == false) {
        await db.execute('ALTER TABLE $topicTable ADD COLUMN time_update INTEGER DEFAULT 0');
      }
      if (isExpireAtExists == false) {
        await db.execute('ALTER TABLE $topicTable ADD COLUMN expire_at INTEGER DEFAULT 0');
      }
    }
  }

  static upgradeContactSchema2V3(Database db) async {
    String tableName = ContactStorage.tableName;
    var sql = "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$tableName'";
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
      bool deviceTokenExists = await DB.checkColumnExists(db, tableName, 'device_token');
      bool notificationOpenExists = await DB.checkColumnExists(db, tableName, 'notification_open');
      bool isTopExists = await DB.checkColumnExists(db, tableName, 'is_top');
      if (deviceTokenExists == false) {
        batch.execute('ALTER TABLE $tableName ADD COLUMN device_token TEXT DEFAULT ""');
      }
      if (notificationOpenExists == false) {
        // NLog.w('notificationOpenExists runtTime Type ===' + notificationOpenExists.toString());
        batch.execute('ALTER TABLE $tableName ADD COLUMN notification_open BOOLEAN DEFAULT 0');
      }
      if (isTopExists == false) {
        batch.execute('ALTER TABLE $tableName ADD COLUMN is_top BOOLEAN DEFAULT 0');
      }
      await batch.commit();
    }

    var contactResult = await db.query(
      tableName,
    );
    if (contactResult.isNotEmpty) {
      Map contact0 = contactResult[0];
      var notificationOpen = contact0['notification_open'];
      String modifyType = 'String';
      if (notificationOpen.runtimeType.toString() == modifyType) {
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

        for (Map contact in contactResult) {
          int notificationValue = 0;
          if (contact['notification_open'] == '1') {
            notificationValue = 1;
          }
          String firstName = '';
          if (contact['first_name'] != null) {
            firstName = contact['first_name'];
          }
          String? avatar;
          if (contact['avatar'] != null) {
            avatar = contact['avatar'];
          }
          Map<String, dynamic> insertMap = {
            'type': contact['type'],
            'address': contact['address'],
            'notification_open': notificationValue,
            'first_name': firstName,
            'avatar': avatar,
          };
          if (contact['options'] != null) {
            insertMap['options'] = contact['options'];
          }
          if (contact['profile_version'] != null) {
            insertMap['profile_version'] = contact['profile_version'];
          }
          if (contact['data'] != null) {
            insertMap['data'] = contact['data'];
          }

          try {
            await db.insert(contactTemp, insertMap);
          } catch (e) {
            // NLog.w('await db.insert is+____' + e.toString());
          }
        }
        String dropContact = '''DROP TABLE IF EXISTS $tableName;''';
        await db.execute(dropContact);
        await db.execute(createSqlV3);

        var contactTempResult = await db.query(
          contactTemp,
        );
        for (Map contact in contactTempResult) {
          Map<String, dynamic> insertMap = {
            'type': contact['type'],
            'address': contact['address'],
            'notification_open': contact['notification_open'],
            'first_name': contact['first_name'],
            'avatar': contact['avatar'],
            'created_time': DateTime.now().millisecondsSinceEpoch,
            'updated_time': DateTime.now().millisecondsSinceEpoch,
          };

          if (contact['options'] != null) {
            insertMap['options'] = contact['options'];
          }
          if (contact['profile_version'] != null) {
            insertMap['profile_version'] = contact['profile_version'];
          }
          if (contact['data'] != null) {
            insertMap['data'] = contact['data'];
          }
          // NLog.w('insertMap is_____' + contact.toString());
          try {
            await db.insert(tableName, insertMap);
          } catch (e) {
            // NLog.w('insertMap is_____ db.insert is+____' + e.toString());
          }
        }
        String deleteContactTemp = '''DROP TABLE IF EXISTS $contactTemp;''';
        await db.execute(deleteContactTemp);
      }
    }
  }
}
