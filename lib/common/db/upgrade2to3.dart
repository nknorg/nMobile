import 'package:sqflite/sqflite.dart';

class Upgrade2to3 {
  static Future<void> updateTopicTableToV3ByTopic(Database db) async {
    await db.execute('ALTER TABLE topic ADD COLUMN type INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE topic ADD COLUMN accept_all BOOLEAN DEFAULT 0');
    await db.execute('ALTER TABLE topic ADD COLUMN joined BOOLEAN DEFAULT 0');
  }

  static Future<void> updateTopicTableToV3BySubscriber(Database db) async {
    await db.execute('ALTER TABLE subscriber ADD COLUMN member_status INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE subscriber DROP COLUMN uploaded');
    await db.execute('ALTER TABLE subscriber DROP COLUMN upload_done');
  }
}
