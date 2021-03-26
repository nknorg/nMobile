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
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/utils/nlog_util.dart';
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
  static const String nknImage = 'nknImage';

  /// in order to suit old version
  static const String media = 'media';

  /// in order to tear message into pieces
  static const String nknOnePiece = 'nknOnePiece';

  static const String nknAudio = 'audio';
  static const String receipt = 'receipt';
  // static const String batchReceipt = 'batchReceipt';

  static const String system = 'system';
  static const String contact = 'contact';

  static const String eventContactOptions = 'event:contactOptions';
  static const String eventSubscribe = 'event:subscribe';
  static const String eventUnsubscribe = 'event:unsubscribe';
  static const String channelInvitation = 'event:channelInvitation';
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

  String parentType;
  int parity;
  int total;
  int index;
  int bytesLength;

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
          case ContentType.channelInvitation:
          case ContentType.eventSubscribe:
            content = msg['content'];
            break;
          case ContentType.nknImage:
          case ContentType.media:
          case ContentType.nknAudio:
            break;
          case ContentType.receipt:
            content = msg['targetID'];
            break;
          case ContentType.nknOnePiece:
            content = msg['content'];
            parity = msg['parity'];
            total = msg['total'];
            index = msg['index'];
            parentType = msg['parentType'];
            bytesLength = msg['bytesLength'];

            if (msg['options'] != null &&
                msg['options']['audioDuration'] != null) {
              audioFileDuration =
                  double.parse(msg['options']['audioDuration'].toString());
            }
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

    /// for nknOnePiece
    this.parity,
    this.total,
    this.index,
    this.bytesLength,
    this.msgId,
    this.parentType,
    this.topic,
    this.content,
    this.contentType,
    this.deviceToken,
    this.audioFileDuration,
    Duration deleteAfterSeconds,
  }) {
    timestamp = DateTime.now();

    if (msgId == null) {
      msgId = uuid.v4();
    }
    if (options == null) {
      options = {};
    }
    if (audioFileDuration != null) {
      options['audioDuration'] = audioFileDuration.toString();
    }
    if (deleteAfterSeconds != null) {
      options['deleteAfterSeconds'] = deleteAfterSeconds.inSeconds;
    }
    if (options.keys.length == 0) options = null;

    isOutbound = true;
    messageStatus = MessageStatus.MessageSending;
  }

  MessageSchema.formReceivedMessage({
    this.msgId,
    this.pid,
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

    if (options == null) {
      options = {};
    }
    if (audioFileDuration != null) {
      options['audioDuration'] = audioFileDuration.toString();
    }
    if (deleteAfterSeconds != null) {
      options['deleteAfterSeconds'] = deleteAfterSeconds.inSeconds;
    }
    if (options.keys.length == 0) options = null;

    setMessageStatus(MessageStatus.MessageReceived);
  }

  loadMedia(ChatBloc cBloc) async {
    String publicKey = NKNClientCaller.currentChatId;
    var msg = jsonDecode(data);

    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(msg['content']);
    var mimeType = match?.group(1);
    var fileBase64 = match?.group(2);

    var extension;
    if (mimeType.indexOf('image/jpg') > -1 ||
        mimeType.indexOf('image/jpeg') > -1) {
      extension = 'jpg';
    } else if (mimeType.indexOf('image/png') > -1) {
      extension = 'png';
    } else if (mimeType.indexOf('image/gif') > -1) {
      extension = 'gif';
    } else if (mimeType.indexOf('image/webp') > -1) {
      extension = 'webp';
    } else if (mimeType.indexOf('image/') > -1) {
      extension = mimeType.split('/').last;
    } else if (mimeType.indexOf('aac') > -1) {
      extension = 'aac';
      NLog.w('Will Load AudioFile');
    } else {
      if (extension != null) {
        NLog.w('got other extension' + extension);
      }
    }
    if (fileBase64.isNotEmpty) {
      var bytes = base64Decode(fileBase64);
      String name = hexEncode(md5.convert(bytes).bytes);
      String path = getCachePath(publicKey);

      File file = File(join(path, name + '.$extension'));

      NLog.w('loadMedia __File Length is____'+file.length().toString());

      file.writeAsBytesSync(bytes, flush: true);
      this.content = file;
    }

    if (msg['options'] != null) {
      if (msg['options']['audioDuration'] != null) {
        audioFileDuration =
            double.parse(msg['options']['audioDuration'].toString());
        options['audioDuration'] = msg['options']['audioDuration'].toString();
      }
    }
    if (topic != null){
      cBloc.add(RefreshMessageChatEvent(this));
    }
  }

  String toTextData() {
    Map data = {
      'id': msgId,
      'contentType': contentType ?? ContentType.text,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    return jsonEncode(data);
  }

  String toNknPieceMessageData() {
    Map data = {
      'id': msgId,
      'topic': topic,
      'contentType': ContentType.nknOnePiece,
      'parentType': parentType,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'parity': parity,
      'total': total,
      'index': index,
      'bytesLength': bytesLength,
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
      transContent =
          '![audio](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    } else {
      if (mimeType != null) {
        NLog.w('Wrong audio Extension!!!' + mimeType);
      }
    }

    Map data = {
      'id': msgId,
      'contentType': ContentType.nknAudio,
      'content': transContent,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    return jsonEncode(data);
  }

  String toSuitVersionImageData(String contentType) {
    File file = this.content as File;
    var mimeType = mime(file.path);

    String content;
    if (mimeType.indexOf('image') > -1) {
      content =
      '![image](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    }

    Map data = {
      'id': msgId,
      'contentType': contentType,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    NLog.w('toSuitVersionImageData is___'+data.toString());
    return jsonEncode(data);
  }

  String toImageData() {
    File file = this.content as File;
    var mimeType = mime(file.path);

    String content;
    if (mimeType.indexOf('image') > -1) {
      content =
          '![image](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    }

    Map data = {
      'id': msgId,
      'contentType': ContentType.nknImage,
      'content': content,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    if (options != null && options.keys.length > 0) {
      data['options'] = options;
    }
    if (topic != null) {
      data['topic'] = topic;
    }
    NLog.w('toImageData is___'+data.toString());
    return jsonEncode(data);
  }

  String toContactBurnOptionData() {
    data = {
      'id': msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deleteAfterSeconds': burnAfterSeconds},
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    data['optionType'] = '0';
    return jsonEncode(data);
  }

  String toContactNoticeOptionData() {
    data = {
      'id': msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deviceToken': deviceToken},
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    data['optionType'] = '1';
    return jsonEncode(data);
  }

  String toEventSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventSubscribe,
      'content': content,
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  String toEventUnSubscribeData() {
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventUnsubscribe,
      'content': content,
      'topic': topic,
      'timestamp': timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  sendReceiptMessage() async {
    if (msgId == null) {
      NLog.w('sendReceiptMessage Wrong!!! no msgId');
    }
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    isSuccess = true;

    try {
      NKNClientCaller.sendText([from], jsonEncode(data), msgId);
      NLog.w('SendMessage Receipt Success__' + msgId.toString());
    } catch (e) {
      NLog.w('Wrong!!!sendReceiptMessage E:' + e.toString());
      Timer(Duration(seconds: 1), () {
        sendReceiptMessage();
      });
    }
  }

  Future<bool> receiptTopic() async {
    Database cdb = await NKNDataManager().currentDatabase();
    Map<String, dynamic> data = {
      'is_success': 1,
      'is_send_error': 0,
    };
    try{
      var count = await cdb.update(
        MessageSchema.tableName,
        data,
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (count > 0){
        NLog.w('receiptTopic success!');
        return true;
      }
    }
    catch(e){
      NLog.w('Wrong!!!__receiptTopic');
    }
    NLog.w('receiptTopic failed!');
    return false;
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
    await db
        .execute('CREATE INDEX index_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_send_time ON Messages (send_time)');
    await db
        .execute('CREATE INDEX index_delete_time ON Messages (delete_time)');
  }

  Map toEntity(String accountPubkey) {
    DateTime now = DateTime.now();

    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid) : null,
      'msg_id': msgId,
      'sender': from,
      'receiver': to,
      'target_id': topic != null
          ? topic
          : isOutbound
              ? to
              : from,
      'type': contentType,
      'topic': topic,
      'options': options != null ? jsonEncode(options) : null,
      'is_read': isRead ? 1 : 0,
      'is_outbound': isOutbound ? 1 : 0,
      'is_success': isSuccess ? 1 : 0,
      'is_send_error': isSendError ? 1 : 0,
      'receive_time': now.millisecondsSinceEpoch,
      'send_time': timestamp?.millisecondsSinceEpoch,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
    };
    if (contentType == ContentType.nknImage ||
        contentType == ContentType.media) {
      map['content'] = getLocalPath(accountPubkey, (content as File).path);
    } else if (contentType == ContentType.nknAudio) {
      NLog.w('Message options is1____' + options.toString());
      options['audioDuration'] = audioFileDuration.toString();
      NLog.w('Message options is2____' + options.toString());
      map['options'] = jsonEncode(options);
      NLog.w('Message options is3____' + options.toString());
      map['content'] = getLocalPath(accountPubkey, (content as File).path);

      if (content == null) {
        NLog.w('FetchAudioMessageInfo Wrong!!! no content');
      }
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = now.millisecondsSinceEpoch;
      }
    } else if (contentType == ContentType.nknOnePiece) {
      map['content'] = getLocalPath(accountPubkey, (content as File).path);
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
    message.contentType = e['type'];

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
    message.receiveTime =
        DateTime.fromMillisecondsSinceEpoch(e['receive_time']);
    message.deleteTime = e['delete_time'] != null
        ? DateTime.fromMillisecondsSinceEpoch(e['delete_time'])
        : null;

    if (message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.media) {
      File mediaFile =
          File(join(Global.applicationRootDirectory.path, e['content']));
      message.content = mediaFile;
    } else if (message.contentType == ContentType.nknAudio) {
      if (message.options != null) {
        if (message.options['audioDuration'] != null) {
          String audioDS = message.options['audioDuration'];
          if (audioDS == null || audioDS.toString() == 'null') {
            NLog.w('Audio Duration is Null_' + message.options.toString());
          } else {
            NLog.w('Get Audio Duration__' + audioDS.toString());
            message.audioFileDuration = double.parse(audioDS);
          }
        } else {
          NLog.w('Wrong!!! Audio Duration is null');
        }
      }
      String filePath =
          join(Global.applicationRootDirectory.path, e['content']);

      message.content = File(filePath);
    } else if (message.contentType == ContentType.nknOnePiece) {
      if (message.options != null) {
        message.parity = message.options['parity'];
        message.total = message.options['total'];
        message.index = message.options['index'];
        message.parentType = message.options['parentType'];
        message.bytesLength = message.options['bytesLength'];
      }
      String filePath =
          join(Global.applicationRootDirectory.path, e['content']);
      message.content = File(filePath);
    } else {
      message.content = e['content'];
    }
    return message;
  }

  Future<bool> insertSendMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String pubKey = NKNClientCaller.currentChatId;

    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (res == null) {
      return false;
    }
    if (res.length > 0) {
      return false;
    } else {
      /// stupid database deleteTime
      if (contentType == ContentType.text ||
          contentType == ContentType.textExtension ||
          contentType == ContentType.nknAudio ||
          contentType == ContentType.media ||
          contentType == ContentType.nknImage) {
        if (options != null && options['deleteAfterSeconds'] != null) {
          deleteTime = DateTime.now()
              .add(Duration(seconds: options['deleteAfterSeconds']));
        }
      }
      int n = await cdb.insert(MessageSchema.tableName, toEntity(pubKey));

      var updateReceipt = await cdb.query(
        MessageSchema.tableName,
        where: 'target_id = ? AND type = ?',
        whereArgs: [msgId, ContentType.receipt],
      );
      if (updateReceipt.length > 0) {
        await setMessageStatus(MessageStatus.MessageSendReceipt);
      }
      if (n > 0) {
        return true;
      }
    }
    return false;
  }

  Future<bool> insertOnePieceMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String pubKey = NKNClientCaller.currentChatId;
    try {
      Map onePieceInfo = toEntity(pubKey);
      NLog.w('OnePiece info is__' + onePieceInfo.toString());
      int n = await cdb.insert(MessageSchema.tableName, onePieceInfo);
      if (n > 0) {
        return true;
      }
    } catch (e) {
      NLog.w('insertOnePieceMessage E:' + e.toString());
    }
    return false;
  }

  Future<bool> insertReceivedMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String pubKey = NKNClientCaller.currentChatId;

    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ? AND is_outbound = 0 AND type = ?',
      whereArgs: [msgId, contentType],
    );
    if (res.length > 0) {
      return false;
    } else {
      Map insertMessageInfo = toEntity(pubKey);
      int n = await cdb.insert(MessageSchema.tableName, insertMessageInfo);
      if (n > 0) {
        return true;
      } else {
        NLog.w('insertReceivedMessage Failed!!!' + msgId.toString());
      }
    }
    return false;
  }

  Future<bool> isReceivedMessageExist() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['COUNT(id) as count'],
      where: 'msg_id = ? AND is_outbound = 0 AND NOT type = ?',
      whereArgs: [msgId, ContentType.nknOnePiece],
    );
    return Sqflite.firstIntValue(res) > 0;
  }

  Future<bool> isOnePieceExist() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ? AND type = ?',
      orderBy: 'send_time desc',
      whereArgs: [msgId, ContentType.nknOnePiece],
    );

    List<MessageSchema> allPieceM = new List<MessageSchema>();
    if (res.length > 0) {
      for (int i = 0; i < res.length; i++) {
        MessageSchema onePiece = MessageSchema.parseEntity(res[i]);
        if (onePiece.index == index) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<List<MessageSchema>> getAndReadTargetMessages(String targetId,
      {int limit = 20, int skip = 0}) async {
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
      where: 'target_id = ? AND NOT type = ?',
      whereArgs: [targetId, ContentType.nknOnePiece],
      limit: limit,
      offset: skip,
    );

    List<MessageSchema> messages = <MessageSchema>[];

    for (var i = 0; i < res.length; i++) {
      var messageItem = MessageSchema.parseEntity(res[i]);
      if (!messageItem.isSendMessage() && messageItem.options != null) {
        NLog.w('messageItem.options is__'+messageItem.options.toString());
        if (messageItem.deleteTime == null &&
            messageItem.options['deleteAfterSeconds'] != null) {
          messageItem.deleteTime = DateTime.now().add(
              Duration(seconds: messageItem.options['deleteAfterSeconds']));
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
    if (messages.length > 0) {
      return messages;
    }
    return null;
  }

  static Future<int> unReadMessages() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String myChatId = NKNClientCaller.currentChatId;
    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'sender != ? AND is_read = 0 AND NOT type = ? AND NOT type = ?',
      whereArgs: [myChatId, ContentType.nknOnePiece,ContentType.receipt],
    );

    if (res != null){
      return res.length;
    }
    return 0;
  }

  static Future<List> findAllUnreadMessages() async {
    Database cdb = await NKNDataManager().currentDatabase();
    String myChatId = NKNClientCaller.currentChatId;
    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'sender != ? AND is_read = 0 AND NOT type = ? AND NOT type = ? AND NOT type = ?',
      whereArgs: [myChatId, ContentType.nknOnePiece, ContentType.eventSubscribe, ContentType.receipt],
    );

    if (res != null){
      List unreadList = new List();
      for (Map unreadMessage in res){
        unreadList.add(parseEntity(unreadMessage));
      }
      return unreadList;
    }
    return null;
  }

  Future<int> receiptMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    if (contentType == null) {
      return -1;
    }
    String queryID = '';
    if (contentType == ContentType.receipt) {
      if (content != null) {
        queryID = content;
      }
    }
    if (queryID.length == 0) {
      NLog.w('Wrong!!!queryID.length == 0');
      return -1;
    }
    Map<String, dynamic> data = {
      'is_success': 1,
      'is_send_error': 0,
    };

    try {
      var count = await cdb.update(
        MessageSchema.tableName,
        data,
        where: 'msg_id = ?',
        whereArgs: [queryID],
      );
      return count;
    } catch (e) {
      NLog.w('Wrong!!!__receiptMessage');
    }
    return 0;
  }

  updateMessageOptions() async {
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

  setMessageStatus(int status) async {
    messageStatus = status;
    if (status == MessageStatus.MessageSendSuccess ||
        status == MessageStatus.MessageSending) {
      isOutbound = true;
      isSendError = false;
      isSuccess = false;
    }
    if (status == MessageStatus.MessageSendFail) {
      isOutbound = true;
      isSendError = true;
    }
    if (status == MessageStatus.MessageReceived) {
      isOutbound = false;
      isRead = false;
    }
    if (status == MessageStatus.MessageReceivedRead) {
      isOutbound = false;
      isRead = true;
    }
    if (status == MessageStatus.MessageSendReceipt) {
      isOutbound = true;
      isSuccess = true;
      isSendError = false;
    }

    Database cdb = await NKNDataManager().currentDatabase();
    int result = await cdb.update(
      MessageSchema.tableName,
      {
        'is_read': isRead ? 1 : 0,
        'is_outbound': isOutbound ? 1 : 0,
        'is_success': isSuccess ? 1 : 0,
        'is_send_error': isSendError ? 1 : 0,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (result > 0) {
      NLog.w('updateMessageStatus success!__' + status.toString());
    }
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

  Future<List> allPieces() async {
    Database cdb = await NKNDataManager().currentDatabase();

    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ? AND type = ?',
      orderBy: 'send_time desc',
      whereArgs: [msgId, ContentType.nknOnePiece],
    );

    List<MessageSchema> allPieceM = new List<MessageSchema>();
    if (res.length > 0) {
      for (int i = 0; i < res.length; i++) {
        MessageSchema onePiece = MessageSchema.parseEntity(res[i]);
        allPieceM.add(onePiece);
      }
      return allPieceM;
    }
    return null;
  }

  Future<bool> existFullPiece() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var existFull = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ? AND type = ?',
      whereArgs: [msgId, parentType],
    );
    if (existFull.isNotEmpty) {
      NLog.w('Exist Full Message');
      return true;
    }
    return false;
  }

  Future<bool> existOnePieceIndex() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ? AND type = ?',
      whereArgs: [msgId, ContentType.nknOnePiece],
    );

    // for (int i = 0; i < res.length; i++){
    //   MessageSchema existOnePieces = MessageSchema.parseEntity(res[i]);
    //   if (existOnePieces.parity == parity){
    //     return true;
    //   }
    // }
    return false;
  }

  Future<int> deleteMessage() async {
    Database cdb = await NKNDataManager().currentDatabase();
    int result = await cdb.update(
      MessageSchema.tableName,
      {
        'pid': null,
        'msg_id': msgId,
        'sender': null,
        'receiver': null,
        'target_id': null,
        'type': null,
        'topic': null,
        'options': null,
        'is_read': null,
        'is_outbound': null,
        'is_success': null,
        'is_send_error': null,
        'receive_time': null,
        'send_time': null,
        'delete_time': null,
        'content': null,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (result > 0) {
      NLog.w('Message set to only Id' + msgId.toString());
    }
    return result;
  }

  Future<int> updateDeleteTime() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      MessageSchema.tableName,
      {
        'delete_time': deleteTime?.millisecondsSinceEpoch,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return count;
  }

  int get deleteAfterSeconds {
    if (options != null && options.containsKey('deleteAfterSeconds')) {
      return options['deleteAfterSeconds'];
    } else {
      return null;
    }
  }
}
