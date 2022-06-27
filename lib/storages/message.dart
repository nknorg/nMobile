import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class MessageStorage with Tag {
  // static String get tableName => 'Messages';
  static String get tableName => 'Messages_2';

  static MessageStorage instance = MessageStorage();

  Database? get db => dbCommon.database;

  Lock _lock = new Lock();

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `pid` VARCHAR(300),
        `msg_id` VARCHAR(300),
        `sender` VARCHAR(200),
        `receiver` VARCHAR(200),
        `topic` VARCHAR(200),
        `target_id` VARCHAR(200),
        `status` INT,
        `is_outbound` BOOLEAN DEFAULT 0,
        `is_delete` BOOLEAN DEFAULT 0,
        `send_at` BIGINT,
        `receive_at` BIGINT,
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
    await db.execute('CREATE INDEX `index_messages_target_id_topic_type` ON `$tableName` (`target_id`, `topic`, `type`)');
    await db.execute('CREATE INDEX `index_messages_status_target_id_topic` ON `$tableName` (`status`, `target_id`, `topic`)');
    await db.execute('CREATE INDEX `index_messages_status_is_delete_target_id_topic` ON `$tableName` (`status`, `is_delete`, `target_id`, `topic`)');
    await db.execute('CREATE INDEX `index_messages_target_id_topic_is_delete_type_send_at` ON `$tableName` (`target_id`, `topic`, `is_delete`, `type`, `send_at`)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (db?.isOpen != true) return null;
    if (schema == null) return null;
    Map<String, dynamic> map = schema.toMap();
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return null;
    });
  }

  /*Future<bool> delete(String msgId) async {
    if (db?.isOpen != true) return false;
    if (msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
      try {
        int? result = await db?.transaction((txn) {
          return txn.delete(
            tableName,
            where: 'msg_id = ?',
            whereArgs: [msgId],
          );
        });
        if (result != null && result > 0) {
          logger.v("$TAG - delete - success - msgId:$msgId");
          return true;
        }
        logger.w("$TAG - delete - empty - msgId:$msgId");
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }*/

  /*Future<bool> deleteByPid(String? pid) async {
    if (db?.isOpen != true) return false;
    if (pid == null || pid.isEmpty) return false;
    return await _lock.synchronized(() async {
      try {
        int? result = await db?.transaction((txn) {
          return txn.delete(
            tableName,
            where: 'pid = ?',
            whereArgs: [pid],
          );
        });
        if (result != null && result > 0) {
          logger.v("$TAG - deleteByPid - success - pid:$pid");
          return true;
        }
        logger.w("$TAG - deleteByPid - empty - pid:$pid");
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }*/

  Future<int> deleteByIdContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return 0;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return 0;
    });
  }

  Future<int> deleteByTargetIdContentType(String? targetId, String? topic, String? contentType) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.delete(
            tableName,
            where: 'target_id = ? AND topic = ? AND type = ?',
            whereArgs: [targetId, topic ?? "", contentType],
          );
        });
        if (count != null && count > 0) {
          logger.v("$TAG - deleteByTargetIdContentType - success - targetId:$targetId - contentType:$contentType");
          return count;
        }
        logger.w("$TAG - deleteByTargetIdContentType - empty - targetId:$targetId - contentType:$contentType");
      } catch (e) {
        handleError(e);
      }
      return 0;
    });
  }

  /*Future<int> deleteList(List<MessageSchema>? list) async {
    if (db?.isOpen != true) return 0;
    if (list == null || list.isEmpty) return 0;
    return await _lock.synchronized(() async {
      try {
        Batch? batch = db?.batch();
        for (MessageSchema schema in list) {
          batch?.delete(
            tableName,
            where: 'msg_id = ?',
            whereArgs: [schema.msgId],
          );
        }
        List<Object?>? results = await batch?.commit();
        int count = 0;
        if (results != null && results.isNotEmpty) {
          for (Object? result in results) {
            if (result != null && (result as int) > 0) {
              count += result;
            }
          }
        }
        if (count >= list.length) {
          logger.v("$TAG - deleteList - success - count:$count");
          return count;
        } else if (count > 0) {
          logger.w("$TAG - deleteList - lost - lost:${list.length - count}");
          return count;
        }
        logger.w("$TAG - deleteList - empty - list:$list");
      } catch (e) {
        handleError(e);
      }
      return 0;
    });
  }*/

  Future<MessageSchema?> query(String? msgId) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty) return null;
    // return await _lock.synchronized(() async {
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
    } catch (e) {
      handleError(e);
    }
    return null;
    // });
  }

  /*Future<MessageSchema?> queryByPid(Uint8List? pid) async {
    if (db?.isOpen != true) return null;
    if (pid == null || pid.isEmpty) return null;
    return await _lock.synchronized(() async {
      try {
        List<Map<String, dynamic>>? res = await db?.transaction((txn) {
          return txn.query(
            tableName,
            columns: ['*'],
            where: 'pid = ?',
            whereArgs: [pid],
          );
        });
        if (res != null && res.length > 0) {
          MessageSchema schema = MessageSchema.fromMap(res.first);
          logger.v("$TAG - queryByPid - success - pid:$pid - schema:$schema");
          return schema;
        }
        logger.v("$TAG - queryByPid - empty - pid:$pid");
      } catch (e) {
        handleError(e);
      }
      return null;
    });
  }*/

  Future<MessageSchema?> queryByIdNoContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return null;
    // return await _lock.synchronized(() async {
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
    } catch (e) {
      handleError(e);
    }
    return null;
    // });
  }

  Future<List<MessageSchema>> queryListByIds(List<String>? msgIds) async {
    if (db?.isOpen != true) return [];
    if (msgIds == null || msgIds.isEmpty) return [];
    // return await _lock.synchronized(() async {
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
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<List<MessageSchema>> queryListByIdsNoContentType(List<String>? msgIds, String? contentType) async {
    if (db?.isOpen != true) return [];
    if (msgIds == null || msgIds.isEmpty || contentType == null || contentType.isEmpty) return [];
    // return await _lock.synchronized(() async {
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
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  /*Future<MessageSchema?> queryByIdContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return null;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return null;
    return await _lock.synchronized(() async {
      try {
        List<Map<String, dynamic>>? res = await db?.transaction((txn) {
          return txn.query(
            tableName,
            columns: ['*'],
            where: 'msg_id = ? AND type = ?',
            whereArgs: [msgId, contentType],
          );
        });
        if (res != null && res.length > 0) {
          MessageSchema schema = MessageSchema.fromMap(res.first);
          logger.v("$TAG - queryByContentType - success - msgId:$msgId - schema:$schema");
          return schema;
        }
        logger.v("$TAG - queryByIdContentType - empty - msgId:$msgId");
      } catch (e) {
        handleError(e);
      }
      return null;
    });
  }*/

  /*Future<List<MessageSchema>> queryListById(String? msgId) async {
    if (db?.isOpen != true) return [];
    if (msgId == null || msgId.isEmpty) return [];
    return await _lock.synchronized(() async {
      try {
        List<Map<String, dynamic>>? res = await db?.transaction((txn) {
          return txn.query(
            tableName,
            columns: ['*'],
            where: 'msg_id = ?',
            whereArgs: [msgId],
          );
        });
        if (res == null || res.isEmpty) {
          logger.v("$TAG - queryListById - empty - msgId:$msgId");
          return [];
        }
        List<MessageSchema> result = <MessageSchema>[];
        String logText = '';
        res.forEach((map) {
          MessageSchema item = MessageSchema.fromMap(map);
          logText += "    \n$item";
          result.add(item);
        });
        logger.v("$TAG - queryListById - success - msgId:$msgId - length:${result.length} - items:$logText");
        return result;
      } catch (e) {
        handleError(e);
      }
      return [];
    });
  }*/

  Future<List<MessageSchema>> queryListByIdContentType(String? msgId, String? contentType, int limit) async {
    if (db?.isOpen != true) return [];
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return [];
    // return await _lock.synchronized(() async {
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
        logger.d("$TAG - queryListByIdContentType - empty - msgId:$msgId - contentType:$contentType");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListByIdContentType - success - msgId:$msgId - contentType:$contentType - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  /*Future<int> queryCountByIdContentType(String? msgId, String? contentType) async {
    if (db?.isOpen != true) return 0;
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    return await _lock.synchronized(() async {
      try {
        final res = await db?.transaction((txn) {
          return txn.query(
            tableName,
            columns: ['COUNT(id)'],
            where: 'msg_id = ? AND type = ?',
            whereArgs: [msgId, contentType],
          );
        });
        int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
        logger.v("$TAG - queryCountByIdContentType - msgId:$msgId - count:$count");
        return count ?? 0;
      } catch (e) {
        handleError(e);
      }
      return 0;
    });
  }*/

  /*Future<List<MessageSchema>> queryListUnRead() async {
    if (db?.isOpen != true) return [];
    return await _lock.synchronized(() async {
      try {
        List<Map<String, dynamic>>? res = await db?.transaction((txn) {
          return txn.query(
            tableName,
            columns: ['*'],
            where: 'status = ? AND is_delete = ?',
            whereArgs: [MessageStatus.Received, 0],
          );
        });
        if (res == null || res.isEmpty) {
          logger.v("$TAG - queryListUnRead - empty");
          return [];
        }
        List<MessageSchema> result = <MessageSchema>[];
        String logText = '';
        res.forEach((map) {
          MessageSchema item = MessageSchema.fromMap(map);
          logText += "    \n$item";
          result.add(item);
        });
        logger.v("$TAG - queryListUnRead- length:${result.length} - items:$logText");
        return result;
      } catch (e) {
        handleError(e);
      }
      return [];
    });
  }*/

  Future<int> unReadCount() async {
    if (db?.isOpen != true) return 0;
    // return await _lock.synchronized(() async {
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: 'status = ? AND is_delete = ?',
          whereArgs: [MessageStatus.Received, 0],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - unReadCount - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
    // });
  }

  Future<List<MessageSchema>> queryListByTargetIdWithUnRead(String? targetId, String? topic, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    // return await _lock.synchronized(() async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'status = ? AND is_delete = ? AND target_id = ? AND topic = ?',
          whereArgs: [MessageStatus.Received, 0, targetId, topic ?? ""],
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
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<int> unReadCountByTargetId(String? targetId, String? topic) async {
    if (db?.isOpen != true) return 0;
    if (targetId == null || targetId.isEmpty) return 0;
    // return await _lock.synchronized(() async {
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['COUNT(id)'],
          where: 'status = ? AND is_delete = ? AND target_id = ? AND topic = ?',
          whereArgs: [MessageStatus.Received, 0, targetId, topic ?? ""],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - unReadCountByTargetId - targetId:$targetId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
    // });
  }

  Future<List<MessageSchema>> queryListByTargetIdWithNotDeleteAndPiece(String? targetId, String? topic, {int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (targetId == null || targetId.isEmpty) return [];
    // return await _lock.synchronized(() async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND topic = ? AND is_delete = ? AND NOT type = ?',
          whereArgs: [targetId, topic ?? "", 0, MessageContentType.piece],
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
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<List<MessageSchema>> queryListByStatus(int? status, {String? targetId, String? topic, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (status == null) return [];
    // return await _lock.synchronized(() async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: (targetId?.isNotEmpty == true) ? 'status = ? AND target_id = ? AND topic = ?' : 'status = ?',
          whereArgs: (targetId?.isNotEmpty == true) ? [status, targetId, topic ?? ""] : [status],
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
    } catch (e) {
      handleError(e);
    }
    return [];
    // });
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> updateStatus(String? msgId, int status, {int? receiveAt, String? noType}) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  /*Future<bool> updateListStatus(List<String>? msgIdList, int status, {int? receiveAt, String? noType}) async {
    if (db?.isOpen != true) return false;
    if (msgIdList == null || msgIdList.isEmpty) return false;
    return await _lock.synchronized(() async {
      try {
        await db?.transaction((txn) {
          Batch batch = txn.batch();
          msgIdList.forEach((msgId) {
            batch.update(
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
          return batch.commit();
        });
        logger.v("$TAG - updateListStatus - status:$status - msgIdList:$msgIdList");
        return true;
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }*/

  Future<bool> updateIsDelete(String? msgId, bool isDelete, {bool clearContent = false}) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> updateIsDeleteByTargetId(String? targetId, String? topic, bool isDelete, {bool clearContent = false}) async {
    if (db?.isOpen != true) return false;
    if (targetId == null || targetId.isEmpty) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            clearContent ? {'is_delete': isDelete ? 1 : 0, 'content': null} : {'is_delete': isDelete ? 1 : 0},
            where: 'target_id = ? AND topic = ?',
            whereArgs: [targetId, topic ?? ""],
          );
        });
        logger.v("$TAG - updateIsDeleteByTargetId - count:$count - targetId:$targetId - isDelete:$isDelete");
        return (count ?? 0) > 0;
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> updateSendAt(String? msgId, int? sendAt) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  /*Future<bool> updateReceiveAt(String? msgId, int? receiveAt) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            {
              'receive_at': receiveAt ?? DateTime.now().millisecondsSinceEpoch,
            },
            where: 'msg_id = ?',
            whereArgs: [msgId],
          );
        });
        logger.v("$TAG - updateReceiveAt - count:$count - msgId:$msgId - receiveAt:$receiveAt");
        return (count ?? 0) > 0;
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }*/

  Future<bool> updateDeleteAt(String? msgId, int? deleteAt) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }

  Future<bool> updateOptions(String? msgId, Map<String, dynamic>? options) async {
    if (db?.isOpen != true) return false;
    if (msgId == null || msgId.isEmpty) return false;
    return await _lock.synchronized(() async {
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
      } catch (e) {
        handleError(e);
      }
      return false;
    });
  }
}
