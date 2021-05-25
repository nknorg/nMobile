import 'dart:convert';
import 'dart:io';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage {
  static String get tableName => 'Messages';

  Database get db => DB.currentDatabase;

  MessageStorage();

  ContactStorage _contactStorage = ContactStorage();

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
    Map insertMessageInfo = schema.toEntity();
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
      MessageSchema messageItem = parseMessageSchema(res[i]);
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

  MessageSchema parseMessageSchema(Map e) {
    var message = MessageSchema(
      e['msg_id'],
      e['sender'],
      e['receiver'],
      e['type'],
    );
    message.pid = e['pid'] != null ? hexDecode(e['pid']) : e['pid'];

    message.topic = e['topic'];
    message.options = e['options'] != null ? jsonDecode(e['options']) : null;

    bool isRead = e['is_read'] != 0 ? true : false;
    bool isSuccess = e['is_success'] != 0 ? true : false;
    bool isOutbound = e['is_outbound'] != 0 ? true : false;
    bool isSendError = e['is_send_error'] != 0 ? true : false;

    if (isOutbound) {
      message.messageStatus = MessageStatus.MessageSending;
      if (isSuccess) {
        message.messageStatus = MessageStatus.MessageSendReceipt;
      }
      if (isSendError) {
        message.messageStatus = MessageStatus.MessageSendFail;
      }
      if (isRead) {
        message.messageStatus = MessageStatus.MessageSendReceipt;
      }
    } else {
      message.messageStatus = MessageStatus.MessageReceived;
    }

    if (e['pid'] == null) {
      message.messageStatus = MessageStatus.MessageSendFail;
    }

    message.timestamp = DateTime.fromMillisecondsSinceEpoch(e['send_time']);
    message.receiveTime = DateTime.fromMillisecondsSinceEpoch(e['receive_time']);
    message.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    // TODO: remove
    // if (message.contentType == ContentType.textExtension ||
    //     message.contentType == ContentType.nknImage ||
    //     message.contentType == ContentType.media ||
    //     message.contentType == ContentType.audio) {
    //   if (message.options != null) {
    //     if (message.options['deleteAfterSeconds'] != null) {
    //       message.burnAfterSeconds = int.parse(message.options['deleteAfterSeconds'].toString());
    //     }
    //   }
    // }

    if (message.contentType == ContentType.nknImage || message.contentType == ContentType.media) {
      File mediaFile = File(join(Global.applicationRootDirectory.path, e['content']));
      message.content = mediaFile;
    } else if (message.contentType == ContentType.audio) {
      if (message.options != null) {
        if (message.options['audioDuration'] != null) {
          String audioDS = message.options['audioDuration'];
          if (audioDS == null || audioDS.toString() == 'null') {
          } else {
            message.audioFileDuration = double.parse(audioDS);
          }
        }
      }
      String filePath = join(Global.applicationRootDirectory.path, e['content']);

      message.content = File(filePath);
    } else if (message.contentType == ContentType.nknOnePiece) {
      if (message.options != null) {
        message.parity = message.options['parity'];
        message.total = message.options['total'];
        message.index = message.options['index'];
        message.parentType = message.options['parentType'];
        message.bytesLength = message.options['bytesLength'];
      }
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      message.content = File(filePath);
    } else {
      message.content = e['content'];
    }
    return message;
  }

  /// message list
  Future<SessionSchema> parseSession(Map e) async {
    var res = SessionSchema(
      targetId: e['target_id'],
      sender: e['sender'],
      content: e['content'],
      contentType: e['type'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] as int,
    );

    // todo
    if (e['topic'] != null) {
      // final repoTopic = TopicRepo();
      // res.topic = await repoTopic.getTopicByName(e['topic']);
      // res.contact = await ContactSchema.fetchContactByAddress(res.sender);
      // res.isTop = res.topic?.isTop ?? false;
      //
      // if (res.topic == null){
      //   res.isTop = await ContactSchema.getIsTop(res.targetId);
      //   res.contact = await ContactSchema.fetchContactByAddress(res.targetId);
      // }
    } else {
      if (res.targetId == null) {
        return null;
      }

      res.contact = await _contactStorage.queryContactByClientAddress(res.targetId);
      res.isTop = res.contact?.isTop ?? false;
    }
    return res;
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
      SessionSchema model = await parseSession(item);
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
      SessionSchema model = await parseSession(info);
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
        SessionSchema model = await parseSession(info);
        model.notReadCount = 0;
        return model;
      }
    }
    return null;
  }
}
