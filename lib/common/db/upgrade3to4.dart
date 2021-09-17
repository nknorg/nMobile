import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class Upgrade3to4 {
  static final createSqlV5 = '''
      CREATE TABLE IF NOT EXISTS ${SubscriberStorage.tableName}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        chat_id TEXT,
        prm_p_i INTEGER,
        time_create INTEGER,
        expire_at INTEGER,
        uploaded BOOLEAN,
        subscribed BOOLEAN,
        upload_done BOOLEAN,
        member_status BOOLEAN
      )''';

  static updateSubscriberV3ToV4(Database db) async {
    String subsriberTable = 'subscriber';
    var sql = "SELECT * FROM sqlite_master WHERE TYPE = 'table' AND NAME = '$subsriberTable'";
    var res = await db.rawQuery(sql);
    if (res == null) {
      await db.execute(createSqlV5);
    } else {
      bool memberStatusReady = await DB.checkColumnExists(db, subsriberTable, 'member_status');
      if (memberStatusReady == false) {
        await db.execute('ALTER TABLE $subsriberTable ADD COLUMN member_status BOOLEAN DEFAULT 0');
      }
    }
  }
}
