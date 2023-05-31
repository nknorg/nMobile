import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessagePieceStorage with Tag {
  static String get tableName => 'Message_piece';

  static MessagePieceStorage instance = MessagePieceStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_message_piece", onLog: (log, error) => error ? logger.w(log) : null);

  // same with table_messages
  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `pid` VARCHAR(100),
        `msg_id` VARCHAR(100),
        `device_id` VARCHAR(200),
        `queue_id` BIGINT,
        `sender` VARCHAR(100),
        `target_id` VARCHAR(200),
        `target_type` INT,
        `is_outbound` BOOLEAN DEFAULT 0,
        `status` INT,
        `send_at` BIGINT,
        `receive_at` BIGINT,
        `is_delete` BOOLEAN DEFAULT 0,
        `delete_at` BIGINT,
        `type` VARCHAR(30),
        `content` TEXT,
        `options` TEXT,
        `data` TEXT
      )''';

  MessagePieceStorage();

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    await db.execute('CREATE INDEX `index_message_piece_msg_id` ON `$tableName` (`msg_id`)'); // no unique
    await db.execute('CREATE INDEX `index_message_piece_target_id_target_type` ON `$tableName` (`target_id`, `target_type`)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (db?.isOpen != true) return null;
    if (schema == null) return null;
    Map<String, dynamic> map = schema.toMap();
    return await _queue.add(() async {
      try {
        int? id = await db?.transaction((txn) {
          return txn.insert(tableName, map);
        });
        if (id != null && id > 0) {
          schema = MessageSchema.fromMap(map);
          // logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        }
        logger.w("$TAG - insert - empty - schema:$schema");
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<int> delete(String? msgId) async {
    if (db?.isOpen != true) return 0;
    if (msgId == null || msgId.isEmpty) return 0;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - delete - success - msgId:$msgId");
              return count;
            }
            // logger.v("$TAG - delete - empty - msgId:$msgId");
          } catch (e, st) {
            handleError(e, st);
          }
          return 0;
        }) ??
        0;
  }

  Future<int> deleteByTarget(String? targetId, int targetType) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty) return 0;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'target_id = ? AND target_type = ?',
                whereArgs: [targetId, targetType],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - deleteByTarget - success - targetId:$targetId - targetType:$targetType");
              return count;
            }
            // logger.v("$TAG - deleteByTarget - empty - targetId:$targetId - targetType:$targetType");
          } catch (e, st) {
            handleError(e, st);
          }
          return 0;
        }) ??
        0;
  }

  Future<List<MessageSchema>> queryList(String? msgId, {int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (msgId == null || msgId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'msg_id = ?',
          whereArgs: [msgId],
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryList - empty - msgId:$msgId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      // String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        // logText += "\n$item";
        result.add(item);
      });
      // logger.v("$TAG - queryList - success - msgId:$msgId - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }
}
