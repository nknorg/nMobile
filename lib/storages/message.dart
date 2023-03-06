import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage with Tag {
  // static String get tableName => 'Messages';
  static String get tableName => 'Messages_2';

  static MessageStorage instance = MessageStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_message", onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `pid` VARCHAR(300),
        `msg_id` VARCHAR(300),
        `sender` VARCHAR(200),
        `receiver` VARCHAR(200),
        `topic` VARCHAR(200),
        `group_id` VARCHAR(200),
        `target_id` VARCHAR(200),
        `status` INT,
        `is_outbound` BOOLEAN DEFAULT 0,
        `send_at` BIGINT,
        `receive_at` BIGINT,
        `is_delete` BOOLEAN DEFAULT 0,
        `delete_at` BIGINT,
        `type` VARCHAR(30),
        `content` TEXT,
        `options` TEXT
      )''';

  MessageStorage();

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE INDEX `index_messages_pid` ON `$tableName` (`pid`)');
    await db.execute('CREATE INDEX `index_messages_msg_id_type` ON `$tableName` (`msg_id`, `type`)');
    await db.execute('CREATE INDEX `index_messages_target_id_topic_group_type` ON `$tableName` (`target_id`, `topic`, `group_id`, `type`)');
    await db.execute('CREATE INDEX `index_messages_status_target_id_topic_group` ON `$tableName` (`status`, `target_id`, `topic`, `group_id`)');
    await db.execute('CREATE INDEX `index_messages_status_is_delete_target_id_topic_group` ON `$tableName` (`status`, `is_delete`, `target_id`, `topic`, `group_id`)');
    await db.execute('CREATE INDEX `index_messages_target_id_topic_group_is_delete_type_send_at` ON `$tableName` (`target_id`, `topic`, `group_id`, `is_delete`, `type`, `send_at`)');
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
          logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        }
        logger.w("$TAG - insert - empty - schema:$schema");
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<int> deleteByIdContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return 0;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'msg_id = ? AND type = ?',
                whereArgs: [msgId, contentType],
              );
            });
            if (count != null && count > 0) {
              logger.v("$TAG - deleteByIdContentType - success - msgId:$msgId - contentType:$contentType");
              return count;
            }
            logger.w("$TAG - deleteByIdContentType - empty - msgId:$msgId - contentType:$contentType");
          } catch (e, st) {
            handleError(e, st);
          }
          return 0;
        }) ??
        0;
  }

  Future<int> deleteByTargetIdContentType(String? targetId, String? topic, String? groupId, String? contentType) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'target_id = ? AND topic = ? AND group_id = ? AND type = ?',
                whereArgs: [targetId, topic ?? "", groupId ?? "", contentType],
              );
            });
            if (count != null && count > 0) {
              logger.v("$TAG - deleteByTargetIdContentType - success - targetId:$targetId - contentType:$contentType");
              return count;
            }
            logger.w("$TAG - deleteByTargetIdContentType - empty - targetId:$targetId - contentType:$contentType");
          } catch (e, st) {
            handleError(e, st);
          }
          return 0;
        }) ??
        0;
  }

  Future<MessageSchema?> query(String? msgId) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'msg_id = ?',
          whereArgs: [msgId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        MessageSchema schema = MessageSchema.fromMap(res.first);
        logger.v("$TAG - query - success - msgId:$msgId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - query - success - msgId:$msgId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<MessageSchema?> queryByIdNoContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'msg_id = ? AND NOT type = ?',
          whereArgs: [msgId, contentType],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        MessageSchema schema = MessageSchema.fromMap(res.first);
        logger.v("$TAG - queryByIdNoContentType - success - msgId:$msgId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - queryByIdNoContentType - empty - msgId:$msgId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<MessageSchema>> queryListByIds(List<String>? msgIds) async {
    if (db?.isOpen != true) return [];
    if (msgIds == null || msgIds.isEmpty) return [];
    try {
      List? res = await db?.transaction((txn) {
        Batch batch = txn.batch();
        msgIds.forEach((msgId) {
          if (msgId.isNotEmpty) {
            batch.query(
              tableName,
              columns: ['*'],
              where: 'msg_id = ?',
              whereArgs: [msgId],
              offset: 0,
              limit: 1,
            );
          }
        });
        return batch.commit();
      });
      if (res != null && res.length > 0) {
        List<MessageSchema> schemaList = [];
        for (var i = 0; i < res.length; i++) {
          if (res[i] == null || res[i].isEmpty || res[i][0].isEmpty) continue;
          Map<String, dynamic> map = res[i][0];
          MessageSchema schema = MessageSchema.fromMap(map);
          schemaList.add(schema);
        }
        logger.v("$TAG - queryListByIds - success - msgIds:$msgIds - schemaList:$schemaList");
        return schemaList;
      }
      logger.v("$TAG - queryListByIds - empty - msgIds:$msgIds");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByIdsNoContentType(List<String>? msgIds, String? contentType) async {
    if (db?.isOpen != true) return [];
    if (msgIds == null || msgIds.isEmpty || contentType == null || contentType.isEmpty) return [];
    try {
      List? res = await db?.transaction((txn) {
        Batch batch = txn.batch();
        msgIds.forEach((msgId) {
          if (msgId.isNotEmpty) {
            batch.query(
              tableName,
              columns: ['*'],
              where: 'msg_id = ? AND NOT type = ?',
              whereArgs: [msgId, contentType],
              offset: 0,
              limit: 1,
            );
          }
        });
        return batch.commit();
      });
      if (res != null && res.length > 0) {
        List<MessageSchema> schemaList = [];
        for (var i = 0; i < res.length; i++) {
          if (res[i] == null || res[i].isEmpty || res[i][0].isEmpty) continue;
          Map<String, dynamic> map = res[i][0];
          MessageSchema schema = MessageSchema.fromMap(map);
          schemaList.add(schema);
        }
        logger.v("$TAG - queryListByIdsNoContentType - success - msgIds:$msgIds - schemaList:$schemaList");
        return schemaList;
      }
      logger.v("$TAG - queryListByIdsNoContentType - empty - msgIds:$msgIds");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByIdContentType(String? msgId, String? contentType, int limit) async {
    if (db?.isOpen != true) return [];
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'msg_id = ? AND type = ?',
          whereArgs: [msgId, contentType],
          offset: 0,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListByIdContentType - empty - msgId:$msgId - contentType:$contentType");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.v("$TAG - queryListByIdContentType - success - msgId:$msgId - contentType:$contentType - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByTargetIdWithUnRead(String? targetId, String? topic, String? groupId, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'status = ? AND is_delete = ? AND target_id = ? AND topic = ? AND group_id = ?',
          whereArgs: [MessageStatus.Received, 0, targetId, topic ?? "", groupId ?? ""],
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListByTargetIdWithUnRead - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "    \n$item";
        result.add(item);
      });
      logger.v("$TAG - queryListByTargetIdWithUnRead - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<int> unReadCountByTargetId(String? targetId, String? topic, String? groupId) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty) return 0;
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: 'status = ? AND is_delete = ? AND target_id = ? AND topic = ? AND group_id = ?',
          whereArgs: [MessageStatus.Received, 0, targetId, topic ?? "", groupId ?? ""],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - unReadCountByTargetId - targetId:$targetId - count:$count");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListByTargetIdWithNotDeleteAndPiece(String? targetId, String? topic, String? groupId, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND topic = ? AND group_id = ? AND is_delete = ? AND NOT type = ?',
          whereArgs: [targetId, topic ?? "", groupId ?? "", 0, MessageContentType.piece],
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListByTargetIdWithNotDeleteAndPiece - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "    \n$item";
        result.add(item);
      });
      logger.v("$TAG - queryListByTargetIdWithNotDeleteAndPiece - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByTargetIdWithTypeNotDelete(String? targetId, String? topic, String? groupId, List<String>? types, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    if (types == null || types.isEmpty) return [];

    String whereTypes = "type = ?";
    if (types.length <= 1) {
      whereTypes = " AND " + whereTypes;
    } else {
      for (var i = 1; i < types.length; i++) {
        whereTypes = whereTypes + " OR type = ?";
      }
      whereTypes = "AND ( " + whereTypes + " )";
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND topic = ? AND group_id = ? AND is_delete = ? $whereTypes',
          whereArgs: [targetId, topic ?? "", groupId ?? "", 0]..addAll(types),
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListByTargetIdWithNotDeleteAndPiece - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "    \n$item";
        result.add(item);
      });
      logger.v("$TAG - queryListByTargetIdWithNotDeleteAndPiece - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByStatus(int? status, {String? targetId, String? topic, String? groupId, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (status == null) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (targetId?.isNotEmpty == true) ? 'status = ? AND target_id = ? AND topic = ? AND group_id = ?' : 'status = ?',
          whereArgs: (targetId?.isNotEmpty == true) ? [status, targetId, topic ?? "", groupId ?? ""] : [status],
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryListByStatus - empty - status:$status - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "    \n$item";
        result.add(item);
      });
      logger.v("$TAG - queryListByStatus - success - status:$status - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'pid': pid != null ? hexEncode(pid) : null,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            logger.v("$TAG - updatePid - count:$count - msgId:$msgId - pid:$pid");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateStatus(String? msgId, int status, {int? receiveAt, String? noType}) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                receiveAt == null
                    ? {
                        'status': status,
                      }
                    : {
                        'status': status,
                        'receive_at': receiveAt,
                      },
                where: (noType?.isNotEmpty == true) ? 'msg_id = ? AND NOT type = ?' : 'msg_id = ?',
                whereArgs: (noType?.isNotEmpty == true) ? [msgId, noType] : [msgId],
              );
            });
            logger.v("$TAG - updateStatus - count:$count - msgId:$msgId - status:$status");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateIsDelete(String? msgId, bool isDelete, {bool clearContent = false}) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                clearContent ? {'is_delete': isDelete ? 1 : 0, 'content': null} : {'is_delete': isDelete ? 1 : 0},
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            logger.v("$TAG - updateIsDelete - count:$count - msgId:$msgId - isDelete:$isDelete");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateIsDeleteByTargetId(String? targetId, String? topic, String? groupId, bool isDelete, {bool clearContent = false}) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                clearContent ? {'is_delete': isDelete ? 1 : 0, 'content': null} : {'is_delete': isDelete ? 1 : 0},
                where: 'target_id = ? AND topic = ? AND group_id = ?',
                whereArgs: [targetId, topic ?? "", groupId ?? ""],
              );
            });
            logger.v("$TAG - updateIsDeleteByTargetId - count:$count - targetId:$targetId - isDelete:$isDelete");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateSendAt(String? msgId, int? sendAt) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'send_at': sendAt ?? DateTime.now().millisecondsSinceEpoch,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            logger.v("$TAG - updateSendAt - count:$count - msgId:$msgId - sendAt:$sendAt");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateDeleteAt(String? msgId, int? deleteAt) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'delete_at': deleteAt ?? DateTime.now().millisecondsSinceEpoch,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            logger.v("$TAG - updateDeleteAt - count:$count - msgId:$msgId - deleteAt:$deleteAt");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateOptions(String? msgId, Map<String, dynamic>? options) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'options': options != null ? jsonEncode(options) : null,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            logger.v("$TAG - updateOptions - count:$count - msgId:$msgId - options:$options");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }
}
