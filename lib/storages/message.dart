import 'dart:io';

import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage {
  static String get tableName => 'Messages';

  Database get db => DB.currentDatabase;

  MessageStorage();

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pid TEXT,
        msg_id TEXT,
        sender TEXT,
        receiver TEXT,
        target_id TEXT,
        type TEXT,
        topic TEXT,
        content TEXT,
        options TEXT,
        is_read BOOLEAN DEFAULT 0,
        is_success BOOLEAN DEFAULT 0,
        is_outbound BOOLEAN DEFAULT 0,
        is_send_error BOOLEAN DEFAULT 0,
        receive_time INTEGER,
        send_time INTEGER,
        delete_time INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX index_messages_pid ON Messages (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id ON Messages (msg_id)');
    await db.execute('CREATE INDEX index_messages_sender ON Messages (sender)');
    await db.execute('CREATE INDEX index_messages_receiver ON Messages (receiver)');
    await db.execute('CREATE INDEX index_messages_target_id ON Messages (target_id)');
    await db.execute('CREATE INDEX index_messages_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_messages_send_time ON Messages (send_time)');
    await db.execute('CREATE INDEX index_messages_delete_time ON Messages (delete_time)');
    // query message
    await db.execute('CREATE INDEX index_messages_target_id_is_outbound ON Messages (target_id, is_outbound)');
    await db.execute('CREATE INDEX index_messages_target_id_type ON Messages (target_id, type)');
  }

  Future<bool> insertReceivedMessage(MessageSchema schema) async {
    Map insertMessageInfo = schema.toMap();
    int n = await db.insert(tableName, insertMessageInfo);
    if (n > 0) {
      return true;
    }

    return false;
  }

  Future<int> queryCount(String msgId) async {
    var query = await db.query(
      tableName,
      columns: ['COUNT(id)'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return Sqflite.firstIntValue(query);
  }

  Future<List<Map>> queryByMsgId(String msgId) async {
    var list = await db.query(
      tableName,
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return list;
  }

  Future<bool> receiveSuccess(String msgId) async {
    int result = await db.update(tableName, {'is_success': 1});
    return result > 0;
  }

  Future<int> updateDeleteTime(String msgId, DateTime deleteTime) async {
    var count = await db.update(
      tableName,
      {
        'delete_time': deleteTime?.millisecondsSinceEpoch,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return count;
  }

  Future<List<MessageSchema>> getAndReadTargetMessages(String targetId, {int skip = 0, int limit = 20}) async {
    await db.update(
      tableName,
      {
        'is_read': 1,
      },
      where: 'target_id = ? AND is_outbound = 0',
      whereArgs: [targetId],
    );
    var res = await db.query(
      tableName,
      columns: ['*'],
      orderBy: 'send_time desc',
      where: 'target_id = ? AND NOT type = ?',
      whereArgs: [targetId, ContentType.nknOnePiece],
      limit: limit,
      offset: skip,
    );

    List<MessageSchema> messages = <MessageSchema>[];

    for (var i = 0; i < res.length; i++) {
      MessageSchema messageItem = MessageSchema.fromMap(res[i]);
      if (!messageItem.isOutbound && messageItem.options != null) {
        if (messageItem.deleteTime == null && messageItem.burnAfterSeconds != null) {
          messageItem.deleteTime = DateTime.now().add(Duration(seconds: messageItem.burnAfterSeconds));
          await updateDeleteTime(messageItem.msgId, messageItem.deleteTime);
        }
      }
      messages.add(messageItem);
    }
    return messages;
  }

  Future<int> markMessageRead(String msgId) async {
    var count = await db.update(
      tableName,
      {
        'is_read': 1,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return count;
  }

  /// ContentType is text, textExtension, media, audio counted to not read
  Future<List<SessionSchema>> getLastSession(int skip, int limit) async {
    var res = await db.query(
      '$tableName as m',
      columns: [
        'm.*',
        '(SELECT COUNT(id) from $tableName WHERE target_id = m.target_id AND is_outbound = 0 AND is_read = 0 '
            'AND (type = "text" '
            'or type = "textExtension" '
            'or type = "media" '
            'or type = "audio")) as not_read',
        'MAX(send_time)'
      ],
      where: "type = ? or type = ? or type = ? or type = ? or type = ?",
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.nknImage,
        ContentType.audio,
      ],
      groupBy: 'm.target_id',
      orderBy: 'm.send_time desc',
      limit: limit,
      offset: skip,
    );

    List<SessionSchema> list = <SessionSchema>[];
    for (var i = 0, length = res.length; i < length; i++) {
      var item = res[i];
      SessionSchema model = await SessionSchema.fromMap(item);
      if (model != null) {
        list.add(model);
      }
    }
    if (list.length > 0) {
      return list;
    }
    return null;
  }

  Future<SessionSchema> getUpdateSession(String targetId) async {
    var res = await db.query(
      '$tableName',
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0 AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
      whereArgs: [
        targetId,
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.audio,
        ContentType.nknImage,
      ],
      orderBy: 'send_time desc',
    );

    if (res != null && res.length > 0) {
      Map info = res[0];
      SessionSchema model = await SessionSchema.fromMap(info);
      model.notReadCount = res.length;
      return model;
    } else {
      var countResult = await db.query(
        '$tableName',
        where: 'target_id = ? AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
        whereArgs: [
          targetId,
          ContentType.text,
          ContentType.textExtension,
          ContentType.media,
          ContentType.audio,
          ContentType.nknImage,
        ],
        orderBy: 'send_time desc',
      );
      if (countResult != null && countResult.length > 0) {
        Map info = countResult[0];
        SessionSchema model = await SessionSchema.fromMap(info);
        model.notReadCount = 0;
        return model;
      }
    }
    return null;
  }
}
