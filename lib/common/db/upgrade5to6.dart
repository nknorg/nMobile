import 'dart:async';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// TODO:GG PG check
class Upgrade5to6 {
  static Future createPrivateGroup(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    upgradeTipSink?.add("... (1/3)");
    // create table
    if (!(await DB.checkTableExists(db, PrivateGroupStorage.tableName))) {
      await PrivateGroupStorage.create(db);
    } else {
      logger.w("Upgrade5to6 - ${PrivateGroupStorage.tableName} exist");
    }
  }

  static Future createPrivateGroupList(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    upgradeTipSink?.add("... (2/3)");

    // create table
    if (!(await DB.checkTableExists(db, PrivateGroupItemStorage.tableName))) {
      await PrivateGroupItemStorage.create(db);
    } else {
      logger.w("Upgrade5to6 - ${PrivateGroupItemStorage.tableName} exist");
    }
  }

  static Future upgradeMessages(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    upgradeTipSink?.add("... (3/3)");

    // alter table
    if ((await DB.checkTableExists(db, MessageStorage.tableName))) {
      await db.execute('ALTER TABLE ${MessageStorage.tableName} ADD COLUMN group_id VARCHAR(200) DEFAULT ""');
      await db.execute('CREATE INDEX `index_messages_target_id_group_id_type` ON `${MessageStorage.tableName}` (`target_id`, `group_id`, `type`)');
    }
  }
}
