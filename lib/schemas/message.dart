import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class ContentType {
  static const String system = 'system';
  static const String text = 'text';
  static const String receipt = 'receipt';
  static const String textExtension = 'textExtension';
  static const String media = 'media';
  static const String contact = 'contact';
  static const String eventContactOptions = 'event:contactOptions';
  static const String dchatSubscribe = 'dchat/subscribe';
  static const String eventSubscribe = 'event:subscribe';
  static const String ChannelInvitation = 'event:channelInvitation';
}

class MessageSchema extends Equatable {
  final String from;
  final String to;
  dynamic data;
  dynamic content;
  String contentType;
  String topic;
  bool encrypted;
  Uint8List pid;
  String msgId;
  DateTime timestamp;
  DateTime receiveTime;
  DateTime deleteTime;
  Map<String, dynamic> options;
  bool isRead = false;
  bool isSuccess = false;
  bool isOutbound = false;
  bool isSendError = false;
  int burnAfterSeconds;

  MessageSchema({this.from, this.to, this.pid, this.data}) {
    if (data != null) {
      try {
        var msg = jsonDecode(data);
        contentType = msg['contentType'];
        topic = msg['topic'];
        msgId = msg['id'];
        if (msg['timestamp'] != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(msg['timestamp']);
        }
        options = msg['options'];
        switch (contentType) {
          case ContentType.text:
            content = msg['content'];
            break;
          case ContentType.receipt:
            content = msg['targetID'];
            break;
          case ContentType.textExtension:
            content = msg['content'];
            break;
          case ContentType.ChannelInvitation:
            content = msg['content'];
            break;
          case ContentType.eventSubscribe:
            content = msg['content'];
            break;
          case ContentType.media:
            break;
          default:
            content = data;
            break;
        }
      } on FormatException catch (e) {
        content = data;
        debugPrint(e.message);
        debugPrintStack();
      }
    }
  }

  MessageSchema.fromSendData({
    this.from,
    this.to,
    this.topic,
    this.content,
    this.contentType,
    Duration deleteAfterSeconds,
  }) {
    timestamp = DateTime.now();
    msgId = uuid.v4();
    if (options == null) {
      options = {};
    }
    if (deleteAfterSeconds != null) {
      options['deleteAfterSeconds'] = deleteAfterSeconds.inSeconds;
    }
    if (options.keys.length == 0) options = null;
  }

  loadMedia(String currPubkey) async {
    var msg = jsonDecode(data);
    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(msg['content']);
    var mimeType = match?.group(1);
    var fileBase64 = match?.group(2);
    var extension;
    if (mimeType.indexOf('image/jpg') > -1) {
      extension = 'jpg';
    } else if (mimeType.indexOf('image/png') > -1) {
      extension = 'png';
    } else if (mimeType.indexOf('image/gif') > -1) {
      extension = 'gif';
    } else if (mimeType.indexOf('image/webp') > -1) {
      extension = 'webp';
    } else if (mimeType.indexOf('image/') > -1) {
      extension = mimeType.split('/').last;
    }
    if (fileBase64.isNotEmpty) {
      var bytes = base64Decode(fileBase64);
      String name = hexEncode(md5.convert(bytes).bytes);
      String path = getCachePath(currPubkey);
      File file = File(join(path, name + '.$extension'));
      file.writeAsBytesSync(bytes);

      content = file;
    }
  }

  toTextData() {
    Map data = {
      'id': msgId,
      'contentType': contentType ?? ContentType.text,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    return jsonEncode(data);
  }

  toMediaData() {
    File file = this.content as File;
    var mimeType = mime(file.path);
    String content;
    if (mimeType.indexOf('image') > -1) {
      content = '![image](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    }

    Map data = {
      'id': msgId,
      'contentType': contentType ?? ContentType.text,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    return jsonEncode(data);
  }

  toActionContentOptionsData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deleteAfterSeconds': burnAfterSeconds},
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(data);
  }

  toDchatSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.dchatSubscribe,
      'content': 'Joined channel.',
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(data);
  }

  toEventSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventSubscribe,
      'content': content,
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  receipt(DChatAccount account) async {
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    this.isSuccess = true;

    try {
      await account.client.sendText([from], jsonEncode(data));
      // todo debug
      LocalNotification.debugNotification('[debug] send receipt', msgId);
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      // todo debug
      LocalNotification.debugNotification('[debug] send receipt error', e);
      Timer(Duration(seconds: 1), () {
        receipt(account);
      });
    }
  }

  receiptTopic(Database db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var countQuery = await db.query(
        MessageSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'msg_id = ? AND topic = ? AND is_outbound = 1',
        whereArgs: [msgId, topic],
      );
      var count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;
      if (count > 0) {
        await db.update(
          MessageSchema.tableName,
          {
            'is_read': 1,
            'is_success': 1,
          },
          where: 'msg_id = ? AND is_outbound = 1',
          whereArgs: [msgId],
        );
      }
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  @override
  List<Object> get props => [pid];

  @override
  String toString() => 'MessageSchema { pid: $pid }';

  static generateContent(String type, String content) {
    Map data = {
      'id': uuid.v4(),
      'contentType': type,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String get tableName => 'Messages';

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE Messages (
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
        is_read BOOLEAN,
        is_success BOOLEAN,
        is_outbound BOOLEAN,
        is_send_error BOOLEAN,
        receive_time INTEGER,
        send_time INTEGER,
        delete_time INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX index_pid ON Messages (pid)');
    await db.execute('CREATE INDEX index_msg_id ON Messages (msg_id)');
    await db.execute('CREATE INDEX index_sender ON Messages (sender)');
    await db.execute('CREATE INDEX index_receiver ON Messages (receiver)');
    await db.execute('CREATE INDEX index_target_id ON Messages (target_id)');
    await db.execute('CREATE INDEX index_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_send_time ON Messages (send_time)');
    await db.execute('CREATE INDEX index_delete_time ON Messages (delete_time)');
  }

  toEntity(String accountPubkey) {
    DateTime now = DateTime.now();
    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid) : null,
      'msg_id': msgId,
      'sender': from,
      'receiver': to,
      'target_id': topic != null ? topic : isOutbound ? to : from,
      'type': contentType,
      'topic': topic,
      'options': options != null ? jsonEncode(options) : null,
      'is_read': isRead ? 1 : 0,
      'is_outbound': isOutbound ? 1 : 0,
      'is_success': isSuccess ? 1 : 0,
      'is_send_error': isSendError ? 1 : 0,
      'receive_time': now.millisecondsSinceEpoch,
      'send_time': timestamp.millisecondsSinceEpoch,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
    };
    if (contentType == ContentType.media) {
      map['content'] = getLocalPath(accountPubkey, (content as File).path);
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = now.millisecondsSinceEpoch;
      }
    } else {
      map['content'] = content;
    }

    return map;
  }

  static MessageSchema parseEntity(Map e) {
    var message = MessageSchema(
      from: e['sender'],
      to: e['receiver'],
    );
    message.pid = e['pid'] != null ? hexDecode(e['pid']) : e['pid'];
    message.msgId = e['msg_id'];
    message.isOutbound = e['is_outbound'] != 0 ? true : false;
    message.contentType = e['type'];

    message.topic = e['topic'];
    message.options = e['options'] != null ? jsonDecode(e['options']) : null;
    message.isRead = e['is_read'] != 0 ? true : false;
    message.isSendError = e['is_send_error'] != 0 ? true : false;
    message.isSuccess = e['is_success'] != 0 ? true : false;
    message.timestamp = DateTime.fromMillisecondsSinceEpoch(e['send_time']);
    message.receiveTime = DateTime.fromMillisecondsSinceEpoch(e['receive_time']);
    message.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    if (message.contentType == ContentType.media) {
      message.content = File(join(Global.applicationRootDirectory.path, e['content']));
    } else {
      message.content = e['content'];
    }

    return message;
  }

  Future<bool> insert(Future<Database> db, String accountPubkey) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      int n = await (await db).insert(MessageSchema.tableName, toEntity(accountPubkey));
      return n > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      return false;
    }
  }

  Future<bool> isExist(Future<Database> db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        MessageSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'msg_id = ? AND is_outbound = 0',
        whereArgs: [msgId],
      );
      return Sqflite.firstIntValue(res) > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      return false;
    }
  }

  static Future<List<MessageSchema>> getAndReadTargetMessages(Future<Database> db, String targetId, {int limit = 20, int skip = 0}) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      await (await db).update(
        MessageSchema.tableName,
        {
          'is_read': 1,
        },
        where: 'target_id = ? AND is_outbound = 0 AND is_read = 0',
        whereArgs: [targetId],
      );
      var res = await (await db).query(
        MessageSchema.tableName,
        columns: ['*'],
        orderBy: 'send_time desc',
        where: 'target_id = ?',
        whereArgs: [targetId],
        limit: limit,
        offset: skip,
      );

      List<MessageSchema> messages = <MessageSchema>[];
      for (var i = 0; i < res.length; i++) {
        var messageItem = MessageSchema.parseEntity(res[i]);
        if (!messageItem.isOutbound && messageItem.options != null) {
          if (messageItem.deleteTime == null && messageItem.options['deleteAfterSeconds'] != null) {
            messageItem.deleteTime = DateTime.now().add(Duration(seconds: messageItem.options['deleteAfterSeconds']));
            (await db).update(
              MessageSchema.tableName,
              {
                'delete_time': messageItem.deleteTime.millisecondsSinceEpoch,
              },
              where: 'msg_id = ?',
              whereArgs: [messageItem.msgId],
            );
          }
        }
        messages.add(messageItem);
      }

      return messages;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static Future<int> readTargetMessages(Future<Database> db, String targetId) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var count = await (await db).update(
        MessageSchema.tableName,
        {
          'is_read': 1,
        },
        where: 'sender = ? AND is_read = 0',
        whereArgs: [targetId],
      );
      return count;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static Future<int> unReadMessages(Future<Database> db, String myChatId) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        MessageSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'sender != ? AND is_read = 0',
        whereArgs: [myChatId],
      );
      return Sqflite.firstIntValue(res);
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<int> receiptMessage(Future<Database> db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        MessageSchema.tableName,
        columns: ['*'],
        where: 'msg_id = ?',
        whereArgs: [contentType == ContentType.receipt ? content : msgId],
      );
      var record = res?.first;

      Map<String, dynamic> data = {
        'is_success': 1,
      };

      try {
        if (record['options'] != null) {
          var options = jsonDecode(record['options']);
          if (options['deleteAfterSeconds'] != null && record['delete_time'] == null) {
            deleteTime = DateTime.now().add(Duration(seconds: options['deleteAfterSeconds']));
            data['delete_time'] = deleteTime.millisecondsSinceEpoch;
          }
        }
      } on FormatException catch (e) {
        debugPrint(e.message);
      } catch (e) {
        debugPrint(e);
      }

      var count = await (await db).update(
        MessageSchema.tableName,
        data,
        where: 'msg_id = ?',
        whereArgs: [contentType == ContentType.receipt ? content : msgId],
      );

      return count;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<int> readMessage(Future<Database> db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var count = await (await db).update(
        MessageSchema.tableName,
        {
          'is_read': 1,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      return count;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<int> deleteMessage(Future<Database> db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).delete(
        MessageSchema.tableName,
        where: 'msg_id = ?',
        whereArgs: [contentType == ContentType.receipt ? content : msgId],
      );
      return res;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  int get deleteAfterSeconds {
    if (options != null && options.containsKey('deleteAfterSeconds')) {
      return options['deleteAfterSeconds'];
    } else {
      return null;
    }
  }
}
