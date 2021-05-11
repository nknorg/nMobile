import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class MessageSchema {
  Uint8List pid;
  String msgId;
  String from;
  String to;
  dynamic content;
  String contentType;
  String topic;
  DateTime timestamp;
  DateTime receiveTime;
  DateTime deleteTime;
  Map<String, dynamic> options;

  bool isRead = false;
  bool isSuccess = false;
  bool isOutbound = false;
  bool isSendError = false;

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

  Map toEntity() {
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
      map['content'] = getLocalPath(pubkey, (content as File).path);
    } else if (contentType == ContentType.audio) {
      map['content'] = getLocalPath(pubkey, (content as File).path);
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = DateTime.now().millisecondsSinceEpoch;
      }
    } else if (contentType == ContentType.nknOnePiece) {
      map['content'] = getLocalPath(pubkey, (content as File).path);
    } else {
      map['content'] = content;
    }
    return map;
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
