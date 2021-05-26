import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
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
    String pubkey = hexEncode(chat.publicKey);
    if (options != null) {
      map['options'] = jsonEncode(options);
    }
    if (contentType == ContentType.nknImage || contentType == ContentType.media) {
      // map['content'] = Path.getLocalFilePath(pubkey, SubDirName.data, (content as File).path);
    } else if (contentType == ContentType.audio) {
      // map['content'] = Path.getLocalFilePath(pubkey, SubDirName.data, (content as File).path);
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = DateTime.now().millisecondsSinceEpoch;
      }
    } else if (contentType == ContentType.nknOnePiece) {
      // map['content'] = Path.getLocalFilePath(pubkey, SubDirName.data, (content as File).path);
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
