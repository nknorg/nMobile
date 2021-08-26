import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage with Tag {
  static String get tableName => 'Messages';

  Database? get db => DB.currentDatabase;

  MessageStorage();

  // is_read BOOLEAN // TODO:GG delete
  // is_success BOOLEAN // TODO:GG delete
  // is_send_error BOOLEAN // TODO:GG delete
  // send_at // TODO:GG rename field
  // receive_at // TODO:GG rename field
  // delete_at // TODO:GG rename field
  // status // TODO:GG new field
  // is_delete // TODO:GG new field
  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pid TEXT,
        msg_id TEXT,
        sender TEXT,
        receiver TEXT,
        topic TEXT,
        target_id TEXT,
        status INTEGER,
        is_outbound BOOLEAN DEFAULT 0,
        is_delete BOOLEAN DEFAULT 0,
        send_at INTEGER,
        receive_at INTEGER,
        delete_at INTEGER,
        type TEXT,
        content TEXT,
        options TEXT
      )''');
    // index
    await db.execute('CREATE INDEX index_messages_pid ON $tableName (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id_type ON $tableName (msg_id, type)');
    await db.execute('CREATE INDEX index_messages_status_is_delete_target_id ON $tableName (status, is_delete, target_id)');
    await db.execute('CREATE INDEX index_messages_target_id_is_delete_type_send_at ON $tableName (target_id, is_delete, type, send_at)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (schema == null) return null;
    try {
      Map<String, dynamic> map = schema.toMap();
      int? id = await db?.insert(tableName, map);
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
  }

  // Future<bool> delete(String msgId) async {
  //   if (msgId.isEmpty) return false;
  //   try {
  //     int? result = await db?.delete(
  //       tableName,
  //       where: 'msg_id = ?',
  //       whereArgs: [msgId],
  //     );
  //     if (result != null && result > 0) {
  //       logger.v("$TAG - delete - success - msgId:$msgId");
  //       return true;
  //     }
  //     logger.w("$TAG - delete - empty - msgId:$msgId");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }

  Future<bool> deleteByContentType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return false;
    try {
      int? result = await db?.delete(
        tableName,
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      if (result != null && result > 0) {
        logger.v("$TAG - deleteByContentType - success - msgId:$msgId - contentType:$contentType");
        return true;
      }
      logger.w("$TAG - deleteByContentType - empty - msgId:$msgId - contentType:$contentType");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<int> deleteList(List<MessageSchema>? list) async {
  //   if (list == null || list.isEmpty) return 0;
  //   try {
  //     Batch? batch = db?.batch();
  //     for (MessageSchema schema in list) {
  //       batch?.delete(
  //         tableName,
  //         where: 'msg_id = ?',
  //         whereArgs: [schema.msgId],
  //       );
  //     }
  //     List<Object?>? results = await batch?.commit();
  //     int count = 0;
  //     if (results != null && results.isNotEmpty) {
  //       for (Object? result in results) {
  //         if (result != null && (result as int) > 0) {
  //           count += result;
  //         }
  //       }
  //     }
  //     if (count >= list.length) {
  //       logger.v("$TAG - deleteList - success - count:$count");
  //       return count;
  //     } else if (count > 0) {
  //       logger.w("$TAG - deleteList - lost - lost:${list.length - count}");
  //       return count;
  //     }
  //     logger.w("$TAG - deleteList - empty - list:$list");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return 0;
  // }

  Future<MessageSchema?> query(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (res != null && res.length > 0) {
        MessageSchema schema = MessageSchema.fromMap(res.first);
        logger.v("$TAG - queryList - success - msgId:$msgId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - queryList - success - msgId:$msgId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<MessageSchema?> queryByPid(Uint8List? pid) async {
    if (pid == null || pid.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'pid = ?',
        whereArgs: [pid],
      );
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
  }

  Future<MessageSchema?> queryByNoContentType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ? AND NOT type = ?',
        whereArgs: [msgId, contentType],
      );
      if (res != null && res.length > 0) {
        MessageSchema schema = MessageSchema.fromMap(res.first);
        logger.v("$TAG - queryByNoContentType - success - msgId:$msgId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - queryByNoContentType - empty - msgId:$msgId");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  // Future<MessageSchema?> queryByContentType(String? msgId, String? contentType) async {
  //   if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return null;
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'msg_id = ? AND type = ?',
  //       whereArgs: [msgId, contentType],
  //     );
  //     if (res != null && res.length > 0) {
  //       MessageSchema schema = MessageSchema.fromMap(res.first);
  //       logger.v("$TAG - queryByContentType - success - msgId:$msgId - schema:$schema");
  //       return schema;
  //     }
  //     logger.v("$TAG - queryByContentType - empty - msgId:$msgId");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return null;
  // }

  // Future<List<MessageSchema>> queryList(String? msgId) async {
  //   if (msgId == null || msgId.isEmpty) return [];
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'msg_id = ?',
  //       whereArgs: [msgId],
  //     );
  //     if (res == null || res.isEmpty) {
  //       logger.v("$TAG - queryList - empty - msgId:$msgId");
  //       return [];
  //     }
  //     List<MessageSchema> result = <MessageSchema>[];
  //     String logText = '';
  //     res.forEach((map) {
  //       MessageSchema item = MessageSchema.fromMap(map);
  //       logText += "    \n$item";
  //       result.add(item);
  //     });
  //     logger.v("$TAG - queryList - success - msgId:$msgId - length:${result.length} - items:$logText");
  //     return result;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return [];
  // }

  Future<List<MessageSchema>> queryListByContentType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListByContentType - empty - msgId:$msgId - contentType:$contentType");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListByContentType - success - msgId:$msgId - contentType:$contentType - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<int> queryCountByContentType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - queryCountByContentType - msgId:$msgId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  // Future<List<MessageSchema>> queryListUnRead() async {
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'status = ? AND is_delete = ?',
  //       whereArgs: [MessageStatus.Received, 0],
  //     );
  //     if (res == null || res.isEmpty) {
  //       logger.v("$TAG - queryListUnRead - empty");
  //       return [];
  //     }
  //     List<MessageSchema> result = <MessageSchema>[];
  //     String logText = '';
  //     res.forEach((map) {
  //       MessageSchema item = MessageSchema.fromMap(map);
  //       logText += "    \n$item";
  //       result.add(item);
  //     });
  //     logger.v("$TAG - queryListUnRead- length:${result.length} - items:$logText");
  //     return result;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return [];
  // }

  Future<int> unReadCount() async {
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'status = ? AND is_delete = ?',
        whereArgs: [MessageStatus.Received, 0],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - unReadCount - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListByTargetIdWithUnRead(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'status = ? AND is_delete = ? AND target_id = ?',
        whereArgs: [MessageStatus.Received, 0, targetId],
      );
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
  }

  Future<int> unReadCountByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return 0;
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'status = ? AND is_delete = ? AND target_id = ?',
        whereArgs: [MessageStatus.Received, 0, targetId],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.v("$TAG - unReadCountByTargetId - targetId:$targetId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListByTargetIdWithNotDeleteAndPiece(String? targetId, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'target_id = ? AND is_delete = ? AND NOT type = ?',
        whereArgs: [targetId, 0, MessageContentType.piece],
        offset: offset,
        limit: limit,
        orderBy: 'send_at DESC',
      );
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
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'pid': pid != null ? hexEncode(pid) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.v("$TAG - updatePid - count:$count - msgId:$msgId - pid:$pid");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateStatus(String? msgId, int status, {int? receiveAt}) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
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
      logger.v("$TAG - updateStatus - count:$count - msgId:$msgId - status:$status");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateIsDelete(String? msgId, bool isDelete, {bool clearContent = false}) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        clearContent
            ? {
                'is_delete': isDelete ? 1 : 0,
                'content': null,
              }
            : {
                'is_delete': isDelete ? 1 : 0,
              },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.v("$TAG - updateIsDelete - count:$count - msgId:$msgId - isDelete:$isDelete");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateSendAt(String? msgId, int? sendAt) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'send_at': sendAt ?? DateTime.now().millisecondsSinceEpoch,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.v("$TAG - updateSendAt - count:$count - msgId:$msgId - sendAt:$sendAt");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<bool> updateReceiveAt(String? msgId, int? receiveAt) async {
  //   if (msgId == null || msgId.isEmpty) return false;
  //   try {
  //     int? count = await db?.update(
  //       tableName,
  //       {
  //         'receive_at': receiveAt ?? DateTime.now().millisecondsSinceEpoch,
  //       },
  //       where: 'msg_id = ?',
  //       whereArgs: [msgId],
  //     );
  //     logger.v("$TAG - updateReceiveAt - count:$count - msgId:$msgId - receiveAt:$receiveAt");
  //     return (count ?? 0) > 0;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return false;
  // }

  Future<bool> updateDeleteAt(String? msgId, int? deleteAt) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'delete_at': deleteAt ?? DateTime.now().millisecondsSinceEpoch,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.v("$TAG - updateDeleteAt - count:$count - msgId:$msgId - deleteAt:$deleteAt");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateOptions(String? msgId, Map<String, dynamic>? options) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'options': options != null ? jsonEncode(options) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.v("$TAG - updateOptions - count:$count - msgId:$msgId - options:$options");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
