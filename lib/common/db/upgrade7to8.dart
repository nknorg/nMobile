import 'dart:async';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../storages/session.dart';

class Upgrade7to8 {
  static Future upgradeMessages(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    if ((await DB.checkTableExists(db, MessageStorage.tableName))) {
      upgradeTipSink?.add("Updating messages with future timestamps...");

      try {
        // Get current timestamp in milliseconds
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        // Update messages where send_at is greater than current time
        int updatedCount = await db.rawUpdate('UPDATE ${MessageStorage.tableName} SET send_at = ? WHERE send_at > ?', [currentTime, currentTime]);

        logger.i("Upgrade7to8 - Updated $updatedCount messages with future timestamps to current time");
      } catch (e) {
        logger.e("Upgrade7to8 - Error updating messages with future timestamps: ${e.toString()}");
      }
    }
  }

  static Future upgradeSessionList(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    if ((await DB.checkTableExists(db, SessionStorage.tableName))) {
      try {
        // Get current timestamp in milliseconds
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        // Update sessions where last_message_at is greater than current time
        int updatedCount = await db.rawUpdate('UPDATE ${SessionStorage.tableName} SET last_message_at = ? WHERE last_message_at > ?', [currentTime, currentTime]);

        logger.i("Upgrade7to8 - Updated $updatedCount sessions with future timestamps to current time");
      } catch (e) {
        logger.e("Upgrade7to8 - Error updating sessions with future timestamps: ${e.toString()}");
      }
    }
  }
}
