import 'dart:async';
import 'dart:convert';

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

  static Future upgradeSession(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    if ((await DB.checkTableExists(db, SessionStorage.tableName))) {
      try {
        // Get current timestamp in milliseconds
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        // Update sessions where last_message_at is greater than current time
        int updatedCount = await db.rawUpdate('UPDATE ${SessionStorage.tableName} SET last_message_at = ? WHERE last_message_at > ?', [currentTime, currentTime]);
        // Update last_message_options field to fix future timestamps in message options
        try {
          List<Map<String, dynamic>> sessions = await db.query(
            SessionStorage.tableName,
            columns: ['id', 'last_message_options'],
            where: 'last_message_options IS NOT NULL AND last_message_options != ""',
          );
          
          int optionsUpdatedCount = 0;
          
          for (var session in sessions) {
            String? optionsStr = session['last_message_options'] as String?;
            if (optionsStr != null && optionsStr.isNotEmpty) {
              try {
                Map<String, dynamic> options = Map<String, dynamic>.from(jsonDecode(optionsStr));
                if (options.containsKey('send_at') && options['send_at'] is int) {
                  int sendAt = options['send_at'];
                  if (sendAt > currentTime) {
                    options['send_at'] = currentTime;
                    await db.update(
                      SessionStorage.tableName,
                      {'last_message_options': jsonEncode(options)},
                      where: 'id = ?',
                      whereArgs: [session['id']],
                    );
                    optionsUpdatedCount++;
                  }
                }
              } catch (e) {
                logger.w("Upgrade7to8 - Error parsing last_message_options for session ${session['id']}: ${e.toString()}");
              }
            }
          }
          
          logger.i("Upgrade7to8 - Updated $optionsUpdatedCount sessions with future timestamps in last_message_options");
        } catch (e) {
          logger.e("Upgrade7to8 - Error updating last_message_options with future timestamps: ${e.toString()}");
        }

        logger.i("Upgrade7to8 - Updated $updatedCount sessions with future timestamps to current time");
      } catch (e) {
        logger.e("Upgrade7to8 - Error updating sessions with future timestamps: ${e.toString()}");
      }
    }
  }
}
