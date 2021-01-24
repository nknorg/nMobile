import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class MessageStatus {
  static const int MessageSending = 1;
  static const int MessageSendSuccess = 2;
  static const int MessageSendFail = 3;
  static const int MessageSendReceipt = 4;

  static const int MessageReceived = 5;
  static const int MessageReceivedRead = 6;
}

class ContentType {
  static const String text = 'text';
  static const String textExtension = 'textExtension';
  static const String nknImage = 'image';
  static const String nknAudio = 'audio';
  static const String receipt = 'receipt';
  static const String batchReceipt = 'batchReceipt';

  static const String system = 'system';
  static const String contact = 'contact';

  static const String eventContactOptions = 'event:contactOptions';
  static const String eventSubscribe = 'event:subscribe';
  static const String eventUnsubscribe = 'event:unsubscribe';
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

  int messageStatus;

  bool isRead = false;
  bool isSuccess = false;
  bool isOutbound = false;
  bool isSendError = false;

  int burnAfterSeconds;

  String deviceToken;
  int contactOptionsType;

  double audioFileDuration;

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
          case ContentType.textExtension:
          case ContentType.ChannelInvitation:
          case ContentType.eventSubscribe:
            content = msg['content'];
            break;
          case ContentType.nknImage:
          case ContentType.nknAudio:
            break;
          case ContentType.receipt:
            content = msg['targetID'];
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

  isSendMessage() {
    if (messageStatus == MessageStatus.MessageReceived ||
        messageStatus == MessageStatus.MessageReceivedRead) {
      return false;
    }
    return true;
  }

  MessageSchema.fromSendData({
    this.from,
    this.to,
    this.topic,
    this.content,
    this.contentType,
    this.deviceToken,
    this.audioFileDuration,
    Duration deleteAfterSeconds,
  }) {
    timestamp = DateTime.now();

    msgId = uuid.v4();
    if (options == null) {
      options = {};
    }
    if (audioFileDuration != null){
      options['audioDuration'] = audioFileDuration.toString();
    }
    if (deleteAfterSeconds != null) {
      options['deleteAfterSeconds'] = deleteAfterSeconds.inSeconds;
    }
    if (options.keys.length == 0) options = null;

    messageStatus = MessageStatus.MessageSending;
  }

  loadMedia(ChatBloc cBloc) async {
    String currentPubkey = NKNClientCaller.pubKey;
    var msg = jsonDecode(data);

    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(msg['content']);
    var mimeType = match?.group(1);
    var fileBase64 = match?.group(2);
    print('message content is______'+msg['content']);
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
      extension = mimeType
          .split('/')
          .last;
    }
    else if (mimeType.indexOf('aac') > -1) {
      extension = 'aac';
      print('got index aac');
    }
    else{
      print('got other extension'+extension);
    }
    if (fileBase64.isNotEmpty) {
      var bytes = base64Decode(fileBase64);
      String name = hexEncode(md5
          .convert(bytes)
          .bytes);
      String path = getCachePath(currentPubkey);

      File file = File(join(path, name + '.$extension'));
      file.writeAsBytesSync(bytes,flush: true);
      this.content = file;
    }

    if (msg['options'] != null) {
      if (msg['options']['audioDuration'] != null) {
        audioFileDuration = double.parse(msg['options']['audioDuration'].toString());
        options['audioDuration'] = msg['options']['audioDuration'].toString();
      }
    }
    print('loadMedia Finished)');
    cBloc.add(UpdateMessageEvent(this));
  }

  String toTextData() {
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

  String toAudioData() {
    File file = this.content as File;
    var mimeType = mime(file.path);

    String transContent;
    if (mimeType.split('aac').length > 1) {
       transContent = '![audio](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    }
    else{
      print('mimeType is____'+mimeType);
    }

    Map data = {
      'id': msgId,
      'contentType': ContentType.nknAudio,
      'content': transContent,
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

  String toImageData() {
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

  String toContentOptionData(){
    // this.contactOptionsType = contentOptionType;
    Map data = Map();
    /// 接受/取消远程消息推送 后面可继续扩展
    if (contactOptionsType == 0){
      data = {
        'id': msgId,
        'contentType': ContentType.eventContactOptions,
        'content': {'deleteAfterSeconds': burnAfterSeconds},
        'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      };
    }
    else if (contactOptionsType == 1){
      data = {
        'id': msgId,
        'contentType': ContentType.eventContactOptions,
        'content': {'deviceToken': deviceToken},
        'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      };
    }
    data['optionType'] = contactOptionsType.toString();
    return jsonEncode(data);
  }

  String toEventSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventSubscribe,
      'content': content,
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  String toEventUnSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventUnsubscribe,
      'content': content,
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  sendReceiptMessage() async {
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    isSuccess = true;

    try {
      NKNClientCaller.sendText([from], jsonEncode(data));
      print('Send Receipt____'+from+'-----'+data.toString());
    } catch (e) {
      Global.debugLog('Message receipt() E:'+e.toString());
      Timer(Duration(seconds: 1), () {
        sendReceiptMessage();
      });
    }
  }

  receiptTopic() async {
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      setMessageStatus(MessageStatus.MessageSendReceipt);

      var countQuery = await cdb.query(
        MessageSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'msg_id = ? AND topic = ? AND is_outbound = 1',
        whereArgs: [msgId, topic],
      );
      var count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;

      if (count > 0) {
        await cdb.update(
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

  setMessageStatus(int status){
    messageStatus = status;
    if (status == MessageStatus.MessageSendSuccess ||
        status == MessageStatus.MessageSending){
      isOutbound = true;
      isSendError = false;
      print('message Set to Succresss');
    }
    if (status == MessageStatus.MessageSendFail){
      isOutbound = true;
      isSendError = true;
    }
    if (status == MessageStatus.MessageReceived){
      isOutbound = false;
    }
    if (status == MessageStatus.MessageReceivedRead){
      isRead = true;
    }
    if (status == MessageStatus.MessageSendReceipt){
      // isOutbound = true;
      // isSendError = false;
      isSuccess = true;
      isSendError = false;
    }
    // if (messageStatus == MessageStatus.MessageSending ||
    //     messageStatus == MessageStatus.MessageSendSuccess ||
    //     messageStatus == MessageStatus.MessageSendFail ||
    //     messageStatus == MessageStatus.MessageSendReceipt){
    //   isOutbound = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendSuccess){
    //   isSuccess = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendReceipt){
    //   isRead = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendFail){
    //   isSendError = true;
    // }
  }

  Map toEntity(String accountPubkey) {
    DateTime now = DateTime.now();
    // if (messageStatus == MessageStatus.MessageSending ||
    //     messageStatus == MessageStatus.MessageSendSuccess ||
    //     messageStatus == MessageStatus.MessageSendFail ||
    //     messageStatus == MessageStatus.MessageSendReceipt){
    //   isOutbound = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendSuccess){
    //   isSuccess = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendReceipt){
    //   isRead = true;
    // }
    // if (messageStatus == MessageStatus.MessageSendFail){
    //   isSendError = true;
    // }

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
    if (contentType == ContentType.nknImage) {
      map['content'] = getLocalPath(accountPubkey, (content as File).path);
    }
    else if (contentType == ContentType.nknAudio) {
      options['audioDuration'] = audioFileDuration.toString();
      map['options'] = jsonEncode(options);
      map['content'] = getLocalPath(accountPubkey, (content as File).path);
      print('FetchAudioMessageInfo'+map.toString());
    }
    else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = now.millisecondsSinceEpoch;
      }
    }
    else {
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
    message.contentType = e['type'];

    message.topic = e['topic'];
    message.options = e['options'] != null ? jsonDecode(e['options']) : null;

    bool isRead = e['is_read'] != 0 ? true : false;
    bool isSuccess = e['is_success'] != 0 ? true : false;
    bool isOutbound = e['is_outbound'] != 0 ? true : false;
    bool isSendError = e['is_send_error'] != 0 ? true : false;

    if (isOutbound){
      print('content is__'+e.toString()+'isRead__'+isRead.toString()+'\n'+'isSuccess__'+isSuccess.toString()+'\n'+'isSendError__'+isSendError.toString()+'\n');
      message.messageStatus =  MessageStatus.MessageSending;
      // if (isSuccess){
      //   message.messageStatus = MessageStatus.MessageSendSuccess;
      // }
      if (isSuccess){
        message.messageStatus = MessageStatus.MessageSendReceipt;
      }
      if (isSendError){
        message.messageStatus =  MessageStatus.MessageSendFail;
      }
    }
    else{
      message.messageStatus =  MessageStatus.MessageReceived;
    }

    message.timestamp = DateTime.fromMillisecondsSinceEpoch(e['send_time']);
    message.receiveTime = DateTime.fromMillisecondsSinceEpoch(e['receive_time']);
    message.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    if (message.contentType == ContentType.nknImage) {
      message.content = File(join(Global.applicationRootDirectory.path, e['content']));
    }
    else if (message.contentType == ContentType.nknAudio){
      if (message.options != null){
        if (message.options['audioDuration'] != null){
          String audioDS = message.options['audioDuration'];
          if (audioDS == null || audioDS.toString() == 'null'){
            print('Audio Duration is Null__'+message.options.toString());
          }
          else{
            print('get Duration __'+audioDS);
            message.audioFileDuration = double.parse(audioDS);
          }
        }
        else{
          print('Audio Duration is Null'+message.options['audioDuration']);
        }
      }
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      message.content = File(filePath);

      print('InsertAudioMessage'+message.options.toString());
    }
    else {
      message.content = e['content'];
    }
    return message;
  }

  Future<bool> insertMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String pubKey = NKNClientCaller.pubKey;

    int n = await cdb.insert(MessageSchema.tableName, toEntity(pubKey));
    return n > 0;
  }

  Future<bool> isExist() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['COUNT(id) as count'],
      where: 'msg_id = ? AND is_outbound = 0',
      whereArgs: [msgId],
    );
    return Sqflite.firstIntValue(res) > 0;
  }

  static Future<List<MessageSchema>> getAndReadTargetMessages(String targetId, {int limit = 20, int skip = 0}) async {
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      MessageSchema.tableName,
      {
        'is_read': 1,
      },
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0',
      whereArgs: [targetId],
    );
    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['*'],
      orderBy: 'send_time desc',
      where: 'target_id = ?',
      whereArgs: [targetId],
      limit: limit,
      offset: skip,
    );

    List<MessageSchema> messages = <MessageSchema>[];

    print('Message count is____'+res.length.toString());

    for (var i = 0; i < res.length; i++) {
      var messageItem = MessageSchema.parseEntity(res[i]);
      if (!messageItem.isSendMessage() && messageItem.options != null) {
        if (messageItem.deleteTime == null && messageItem.options['deleteAfterSeconds'] != null) {
          messageItem.deleteTime = DateTime.now().add(Duration(seconds: messageItem.options['deleteAfterSeconds']));
          cdb.update(
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
    if (messages.length > 0){
      return messages;
    }
    return null;
  }

  static Future<int> unReadMessages() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String myChatId = NKNClientCaller.currentChatId;
    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['COUNT(id) as count'],
      where: 'sender != ? AND is_read = 0',
      whereArgs: [myChatId],
    );
    return Sqflite.firstIntValue(res);
  }

  Future<int> receiptMessage() async {
    Database cdb = await NKNDataManager.instance.currentDatabase();

    if (msgId == null){
      print('--------------------------msgId == null');
    }
    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['*'],
      where: 'msg_id = ?',
      whereArgs: [contentType == ContentType.receipt ? content : msgId],
    );
    var record = res?.first;

    Map<String, dynamic> data = {
      'is_success': 1,
    };

    // if (record['options'] != null) {
    //   var options = jsonDecode(record['options']);
    //   if (options['deleteAfterSeconds'] != null && record['delete_time'] == null) {
    //     deleteTime = DateTime.now().add(Duration(seconds: options['deleteAfterSeconds']));
    //     data['delete_time'] = deleteTime.millisecondsSinceEpoch;
    //   }
    // }
    var count = await cdb.update(
      MessageSchema.tableName,
      data,
      where: 'msg_id = ?',
      whereArgs: [contentType == ContentType.receipt ? content : msgId],
    );
    setMessageStatus(MessageStatus.MessageSendReceipt);
    print('--------------------------Map receiptMessage to Success'+msgId);
    return count;
  }

  updateMessageOptions() async{
    Database cdb = await NKNDataManager().currentDatabase();
    await cdb.update(
      MessageSchema.tableName,
      {
        'options': options,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
  }

  Future<int> markMessageRead() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      MessageSchema.tableName,
      {
        'is_read': 1,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return count;
  }

  Future<int> deleteMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.delete(
      MessageSchema.tableName,
      where: 'msg_id = ?',
      whereArgs: [contentType == ContentType.receipt ? content : msgId],
    );
    return res;
  }

  int get deleteAfterSeconds {
    if (options != null && options.containsKey('deleteAfterSeconds')) {
      return options['deleteAfterSeconds'];
    } else {
      return null;
    }
  }
}
