import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

enum MessageStatus {
  MessageSending,
  MessageSendSuccess,
  MessageSendFail,
  MessageSendReceipt,
  MessageReceived,
  MessageReceivedRead,
}

class MessageSchema {
  Uint8List pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String from; // (required) <-> sender / -> target_id
  String to; // (required) <-> receiver / -> target_id
  dynamic content; // <-> content
  String contentType; // (required) <-> type
  String topic; // <-> topic / -> target_id
  DateTime timestamp;
  DateTime receiveTime; // <-> receive_time
  DateTime deleteTime; // <-> delete_time
  Map<String, dynamic> options; // <-> options

  bool isRead = false; // <-> is_read
  bool isSuccess = false; // <-> is_success
  bool isOutbound = false; // <-> is_outbound
  bool isSendError = false; // <-> is_send_error

  MessageStatus messageStatus;

  /// for burnAfterReading
  int burnAfterSeconds;
  int showBurnAfterSeconds;

  /// for bell notification
  String deviceToken;

  /// for audio chat
  double audioFileDuration;

  /// for nknOnePiece
  String parentType;
  int parity;
  int total;
  int index;
  int bytesLength;

  MessageSchema(
    this.msgId,
    this.from,
    this.to,
    this.contentType, {
    this.content,
    this.topic,
    this.timestamp,
  }) {
    if (msgId == null) msgId = uuid.v4();
    if (timestamp == null) timestamp = DateTime.now();
  }

  MessageSchema.fromMap(Map e) {
    this.msgId = e['msg_id'];
    this.from = e['sender'];
    this.to = e['receiver'];
    this.contentType = e['type'];

    this.pid = e['pid'] != null ? hexDecode(e['pid']) : e['pid'];

    this.topic = e['topic'];
    this.options = e['options'] != null ? jsonDecode(e['options']) : null;

    bool isRead = e['is_read'] == 1 ? true : false;
    bool isSuccess = e['is_success'] == 1 ? true : false;
    bool isOutbound = e['is_outbound'] != 0 ? true : false;
    bool isSendError = e['is_send_error'] != 0 ? true : false;

    if (isOutbound) {
      this.messageStatus = MessageStatus.MessageSending;
      if (isSuccess) {
        this.messageStatus = MessageStatus.MessageSendReceipt;
      }
      if (isSendError) {
        this.messageStatus = MessageStatus.MessageSendFail;
      }
      if (isRead) {
        this.messageStatus = MessageStatus.MessageSendReceipt;
      }
    } else {
      this.messageStatus = MessageStatus.MessageReceived;
    }

    if (e['pid'] == null) {
      this.messageStatus = MessageStatus.MessageSendFail;
    }

    this.timestamp = DateTime.fromMillisecondsSinceEpoch(e['send_time']);
    this.receiveTime = DateTime.fromMillisecondsSinceEpoch(e['receive_time']);
    this.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    // TODO: remove
    // if (this.contentType == ContentType.textExtension ||
    //     this.contentType == ContentType.nknImage ||
    //     this.contentType == ContentType.media ||
    //     this.contentType == ContentType.audio) {
    //   if (this.options != null) {
    //     if (this.options['deleteAfterSeconds'] != null) {
    //       this.burnAfterSeconds = int.parse(this.options['deleteAfterSeconds'].toString());
    //     }
    //   }
    // }

    if (this.contentType == ContentType.nknImage || this.contentType == ContentType.media) {
      File mediaFile = File(join(Global.applicationRootDirectory.path, e['content']));
      this.content = mediaFile;
    } else if (this.contentType == ContentType.audio) {
      if (this.options != null) {
        if (this.options['audioDuration'] != null) {
          String audioDS = this.options['audioDuration'];
          if (audioDS == null || audioDS.toString() == 'null') {
          } else {
            this.audioFileDuration = double.parse(audioDS);
          }
        }
      }
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      this.content = File(filePath);
    } else if (this.contentType == ContentType.nknOnePiece) {
      if (this.options != null) {
        this.parity = this.options['parity'];
        this.total = this.options['total'];
        this.index = this.options['index'];
        this.parentType = this.options['parentType'];
        this.bytesLength = this.options['bytesLength'];
      }
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      this.content = File(filePath);
    } else {
      this.content = e['content'];
    }

    // TODO:GG other_contentType + burn + deviceToken + MessageReceivedRead
  }

  Map<String, dynamic> toMap() {
    int rTime = DateTime.now().millisecondsSinceEpoch;
    if (receiveTime != null) {
      rTime = receiveTime.millisecondsSinceEpoch;
    }
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
      'receive_time': rTime,
      'send_time': timestamp?.millisecondsSinceEpoch,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
    };
    if (options != null) {
      map['options'] = jsonEncode(options);
    }
    String pubKey = hexEncode(chat.publicKey);
    if (contentType == ContentType.nknImage || contentType == ContentType.media) {
      // map['content'] = Path.getLocalFile(pubKey, SubDirName.data, (content as File).path); // TODO:GG path
    } else if (contentType == ContentType.audio) {
      // map['content'] = Path.getLocalFile(pubKey, SubDirName.data, (content as File).path); // TODO:GG path
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = DateTime.now().millisecondsSinceEpoch;
      }
    } else if (contentType == ContentType.nknOnePiece) {
      // map['content'] = Path.getLocalFile(pubKey, SubDirName.data, (content as File).path); // TODO:GG path
    } else {
      map['content'] = content;
    }
    return map;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, content: $content, contentType: $contentType, topic: $topic, timestamp: $timestamp, receiveTime: $receiveTime, deleteTime: $deleteTime, options: $options, isRead: $isRead, isSuccess: $isSuccess, isOutbound: $isOutbound, isSendError: $isSendError, messageStatus: $messageStatus, burnAfterSeconds: $burnAfterSeconds, showBurnAfterSeconds: $showBurnAfterSeconds, deviceToken: $deviceToken, audioFileDuration: $audioFileDuration, parentType: $parentType, parity: $parity, total: $total, index: $index, bytesLength: $bytesLength}';
  }

  String toSendTextData() {
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
}
