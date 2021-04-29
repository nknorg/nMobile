import 'dart:convert';
import 'dart:typed_data';

import 'package:nmobile/common/chat.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class MessageSchema {
  Uint8List pid;
  String msgId;
  String from;
  String to;
  String content;
  String contentType;
  String topic;
  DateTime timestamp;
  DateTime receiveTime;
  DateTime deleteTime;
  Map<String, dynamic> options;

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
