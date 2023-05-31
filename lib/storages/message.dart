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

  MessageStorage();

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    await db.execute('CREATE UNIQUE INDEX `index_message_msg_id` ON `$tableName` (`msg_id`)');
    // queryListByTarget
    await db.execute('CREATE INDEX `index_message_target_id_target_type_send_at` ON `$tableName` (`target_id`, `target_type`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_status_send_at` ON `$tableName` (`target_id`, `target_type`, `status`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_delete_send_at` ON `$tableName` (`target_id`, `target_type`, `is_delete`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_outbound_send_at` ON `$tableName` (`target_id`, `target_type`, `is_outbound`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_status_is_delete_send_at` ON `$tableName` (`target_id`, `target_type`, `status`, `is_delete`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_outbound_status_send_at` ON `$tableName` (`target_id`, `target_type`, `is_outbound`, `status`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_outbound_is_delete_send_at` ON `$tableName` (`target_id`, `target_type`, `is_outbound`, `is_delete`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_outbound_status_is_delete_send_at` ON `$tableName` (`target_id`, `target_type`, `is_outbound`, `status`, `is_delete`, `send_at`)');
    // queryListByOutboundStatus
    await db.execute('CREATE INDEX `index_message_is_outbound_status_send_at` ON `$tableName` (`is_outbound`, `status`, `send_at`)');
    await db.execute('CREATE INDEX `index_message_is_outbound_status_is_delete_send_at` ON `$tableName` (`is_outbound`, `status`, `is_delete`, `send_at`)');
    // queryListByTargetTypesWithNoDelete
    await db.execute('CREATE INDEX `index_message_target_id_target_type_is_delete_type_send_at` ON `$tableName` (`target_id`, `target_type`, `is_delete`, `type`, `send_at`)');
    // queryListByTargetDeviceQueueId
    await db.execute('CREATE INDEX `index_message_target_id_target_type_device_id_queue_id_send_at` ON `$tableName` (`target_id`, `target_type`, `device_id`, `queue_id`, `send_at`)');
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
        // logger.v("$TAG - query - success - msgId:$msgId - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - success - msgId:$msgId");
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
        // logger.v("$TAG - queryListByIds - success - msgIds:$msgIds - schemaList:$schemaList");
        return schemaList;
      }
      // logger.v("$TAG - queryListByIds - empty - msgIds:$msgIds");
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByTarget(String? targetId, int targetType, {bool? isOutbound, int? status, bool? isDelete, int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    String whereOutbound = isOutbound == null ? "" : "AND is_outbound = ?";
    List valueOutbound = isOutbound == null ? [] : [isOutbound ? 1 : 0];
    String whereStatus = status == null ? "" : "AND status = ?";
    List valueStatus = status == null ? [] : [status];
    String whereIsDelete = isDelete == null ? "" : "AND is_delete = ?";
    List valueIsDelete = isDelete == null ? [] : [isDelete ? 1 : 0];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND target_type = ? $whereOutbound $whereStatus $whereIsDelete',
          whereArgs: [targetId, targetType]
            ..addAll(valueOutbound)
            ..addAll(valueStatus)
            ..addAll(valueIsDelete),
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTarget - empty - targetId:$targetId - targetType:$targetType - isOutbound:$isOutbound - status:$status - isDelete:$isDelete");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      // String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        // logText += "    \n$item";
        result.add(item);
      });
      // logger.v("$TAG - queryListByTarget - success - targetId:$targetId - targetType:$targetType - isOutbound:$isOutbound - status:$status - isDelete:$isDelete - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByOutboundStatus(bool isOutbound, int status, {bool? isDelete, int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    String whereIsDelete = (isDelete == null) ? "" : "AND is_delete = ?";
    List valueIsDelete = (isDelete == null) ? [] : [isDelete ? 1 : 0];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'is_outbound = ? AND status = ? $whereIsDelete',
          whereArgs: [isOutbound ? 1 : 0, status]..addAll(valueIsDelete),
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByOutboundStatus - empty - isOutbound:$isOutbound - status:$status - isDelete:$isDelete");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      // String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        // logText += "    \n$item";
        result.add(item);
      });
      // logger.v("$TAG - queryListByOutboundStatus - success - isOutbound:$isOutbound - status:$status - isDelete:$isDelete - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  /*Future<int> queryCountByTargetStatus(String? targetId, int targetType, int status, {bool? isDelete}) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty) return 0;
    String whereIsDelete = isDelete == null ? "" : "AND is_delete = ?";
    List valueIsDelete = isDelete == null ? [] : [isDelete ? 1 : 0];
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: 'target_id = ? AND target_type = ? AND status = ? $whereIsDelete',
          whereArgs: [targetId, targetType, status]..addAll(valueIsDelete),
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - queryCountByTargetStatus - targetId:$targetId - targetType:$targetType - status:$status - count:$count");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }*/

  Future<List<MessageSchema>> queryListByTargetTypesWithNoDelete(String? targetId, int targetType, List<String> types, {int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    if (types.isEmpty) return [];
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
          where: 'target_id = ? AND target_type = ? AND is_delete = ? $whereTypes',
          whereArgs: [targetId, targetType, 0]..addAll(types),
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTargetTypes - empty - targetId:$targetId - targetType:$targetType - types:types");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      // String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        // logText += "    \n$item";
        result.add(item);
      });
      // logger.v("$TAG - queryListByTargetTypes - success - targetId:$targetId - targetType:$targetType - types:types - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByTargetDeviceQueueId(String? targetId, int targetType, String? deviceId, int queueId, {int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    deviceId = deviceId ?? "";
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND target_type = ? AND device_id = ? AND queue_id = ?',
          whereArgs: [targetId, targetType, deviceId, queueId],
          orderBy: 'send_at DESC',
          offset: offset,
          limit: limit,
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListByTargetDeviceQueueId - empty - targetId:$targetId - deviceId:$deviceId - queueId:$queueId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      // String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        // logText += "    \n$item";
        result.add(item);
      });
      // logger.v("$TAG - queryListByTargetDeviceQueueId - success - targetId:$targetId - deviceId:$deviceId - queueId:$queueId - length:${result.length} - items:$logText");
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
            // logger.v("$TAG - updatePid - count:$count - msgId:$msgId - pid:$pid");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateDeviceQueueId(String? msgId, String? deviceId, int queueId) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    deviceId = deviceId ?? "";
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'device_id': deviceId,
                  'queue_id': queueId,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            // logger.v("$TAG - updateDeviceQueueId - count:$count - msgId:$msgId - deviceId:$deviceId - queueId:$queueId");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateStatus(String? msgId, int status, {int? receiveAt}) async {
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
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            // logger.v("$TAG - updateStatus - count:$count - msgId:$msgId - status:$status");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> updateIsDelete(String? msgId, bool isDelete) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_delete': isDelete ? 1 : 0,
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
            });
            // logger.v("$TAG - updateIsDelete - count:$count - msgId:$msgId - isDelete:$isDelete");
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
            // logger.v("$TAG - updateSendAt - count:$count - msgId:$msgId - sendAt:$sendAt");
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
            // logger.v("$TAG - updateDeleteAt - count:$count - msgId:$msgId - deleteAt:$deleteAt");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<Map<String, dynamic>?> updateOptions(String? msgId, Map<String, dynamic>? added, {List<String>? removeKeys}) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty) return null;
    if ((added == null || added.isEmpty) && (removeKeys == null || removeKeys.isEmpty)) return null;
    return await _queue.add(() async {
          try {
            return await db?.transaction((txn) async {
              List<Map<String, dynamic>> res = await txn.query(
                tableName,
                columns: ['*'],
                where: 'msg_id = ?',
                whereArgs: [msgId],
                offset: 0,
                limit: 1,
              );
              if (res == null || res.length <= 0) {
                logger.w("$TAG - updateOptions - no exists - msgId:$msgId");
                return null;
              }
              MessageSchema schema = MessageSchema.fromMap(res.first);
              Map<String, dynamic>? options = schema.options ?? Map<String, dynamic>();
              if ((removeKeys != null) && removeKeys.isNotEmpty) {
                removeKeys.forEach((element) => options.remove(element));
              }
              options.addAll(added ?? Map());
              int count = await txn.update(
                tableName,
                {
                  'options': jsonEncode(options),
                },
                where: 'msg_id = ?',
                whereArgs: [msgId],
              );
              if (count <= 0) logger.w("$TAG - updateOptions - fail - count:$count - msgId:$msgId - options:$options");
              return (count > 0) ? options : null;
            });
          } catch (e, st) {
            handleError(e, st);
          }
          return null;
        }) ??
        null;
  }
}
