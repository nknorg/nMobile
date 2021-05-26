import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class MessageOptions {
  // audio
  static const KEY_AUDIO_DURATION = "audioDuration";

  // burn
  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";

  static const KEY_ONE_PIECE_PARENT_TYPE = "parentType";
  static const KEY_ONE_PIECE_PARITY = "parity";
  static const KEY_ONE_PIECE_TOTAL = "total";
  static const KEY_ONE_PIECE_INDEX = "index";
  static const KEY_ONE_PIECE_BYTES_LENGTH = "bytesLength";

  static Map<String, dynamic> createAudio(int duration) {
    return {KEY_AUDIO_DURATION: duration};
  }

  static Map<String, dynamic> createBurn(int deleteAfterSeconds) {
    return {KEY_DELETE_AFTER_SECONDS: deleteAfterSeconds};
  }

  static Map<String, dynamic> createOnePiece(String parentType, int parity, int total, int index, int bytesLength) {
    return {
      KEY_ONE_PIECE_PARENT_TYPE: parentType,
      KEY_ONE_PIECE_PARITY: parity,
      KEY_ONE_PIECE_TOTAL: total,
      KEY_ONE_PIECE_INDEX: index,
      KEY_ONE_PIECE_BYTES_LENGTH: bytesLength,
    };
  }
}

class MessageStatus {
  static const int Sending = 100;
  static const int SendSuccess = 110;
  static const int SendFail = 120;
  static const int SendReceipt = 130;
  static const int Received = 200;
  static const int ReceivedRead = 210;

  static MessageSchema set(MessageSchema schema, int status) {
    if (status == null) return schema;
    if (status == Sending) {
      schema?.isOutbound = true;
      schema?.isSendError = false;
      schema?.isSuccess = false;
      schema?.isRead = false;
    } else if (status == SendSuccess) {
      schema?.isOutbound = true;
      schema?.isSendError = false;
      schema?.isSuccess = false;
      schema?.isRead = true;
    } else if (status == SendFail) {
      schema?.isOutbound = true;
      schema?.isSendError = true;
      schema?.isSuccess = false;
      schema?.isRead = true;
    } else if (status == SendReceipt) {
      schema?.isOutbound = true;
      schema?.isSendError = false;
      schema?.isSuccess = true;
      schema?.isRead = true;
    }
    if (status == Received) {
      schema?.isOutbound = false;
      schema?.isSendError = false;
      schema?.isSuccess = true;
      schema?.isRead = false;
    } else if (status == ReceivedRead) {
      schema?.isOutbound = false;
      schema?.isSendError = false;
      schema?.isSuccess = true;
      schema?.isRead = true;
    }
    return schema;
  }

  static int get(MessageSchema schema) {
    if (schema == null || schema.isOutbound == null) return 0;
    if (schema.isOutbound) {
      if (schema.isSuccess) {
        return SendReceipt;
      } else if (schema.isSendError || schema.pid == null) {
        return SendFail;
      } else if (schema.isSendError) {
        return SendFail;
      } else if (schema.isRead) {
        return SendSuccess;
      } else {
        return Sending;
      }
    } else {
      if (schema.isRead) {
        return ReceivedRead;
      } else {
        return Received;
      }
    }
  }
}

class MessageSchema {
  Uint8List pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String from; // (required) <-> sender / -> target_id
  String to; // (required) <-> receiver / -> target_id
  String topic; // <-> topic / -> target_id

  String contentType; // (required) <-> type
  dynamic content; // <-> content
  Map<String, dynamic> options; // <-> options

  DateTime sendTime; // <-> send_time
  DateTime receiveTime; // <-> receive_time
  DateTime deleteTime; // <-> delete_time

  bool isOutbound = false; // <-> is_outbound
  bool isSendError = false; // <-> is_send_error
  bool isSuccess = false; // <-> is_success
  bool isRead = false; // <-> is_read

  MessageSchema(
    this.msgId,
    this.from,
    this.to,
    this.contentType, {
    this.pid,
    this.topic,
    this.content,
    this.options,
    this.sendTime,
  }) {
    if (msgId == null) msgId = uuid.v4();
    if (sendTime == null) sendTime = DateTime.now();
  }

  static MessageSchema fromReceive(OnMessage raw) {
    if (raw == null && raw.data != null) return null;
    Map data = jsonFormat(raw.data);
    if (data != null) {
      MessageSchema schema = MessageSchema(
        data['id'],
        raw.src,
        chat.id,
        data['contentType'],
        pid: raw.messageId,
        // topic:  // TODO:GG
        content: data['content'],
        options: data['options'],
      );

      if (data['timestamp'] != null) {
        schema.sendTime = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      }
      schema.receiveTime = DateTime.now();
      schema.deleteTime = null; // TODO:GG set when looked

      schema = MessageStatus.set(schema, MessageStatus.Received);

      return schema;
    }
    return null;
  }

  MessageSchema.fromSend(
    this.from,
    this.contentType, {
    this.msgId,
    this.to,
    this.topic,
    this.content,
    this.options,
  }) {
    // pid (SDK create)
    if (msgId == null) msgId = uuid.v4();

    if (options.keys.length == 0) options = null;

    sendTime = DateTime.now();
    receiveTime = null;
    deleteTime = null;

    MessageStatus.set(this, MessageStatus.Sending);
  }

  MessageSchema.fromMap(Map e) {
    this.pid = e['pid'] != null ? hexDecode(e['pid']) : e['pid'];
    this.msgId = e['msg_id'];
    this.from = e['sender'];
    this.to = e['receiver'];
    this.topic = e['topic'];

    this.contentType = e['type'];
    if (this.contentType == ContentType.nknImage || this.contentType == ContentType.media || this.contentType == ContentType.audio || this.contentType == ContentType.nknOnePiece) {
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      this.content = File(filePath);
    } else {
      this.content = e['content'];
    }
    this.options = e['options'] != null ? jsonDecode(e['options']) : null;

    this.sendTime = e['send_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['send_time']) : null;
    this.receiveTime = e['receive_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['receive_time']) : null;
    this.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    this.isOutbound = (e['is_outbound'] != null && e['is_outbound'] == 1) ? true : false;
    this.isSendError = (e['is_send_error'] != null && e['is_send_error'] == 1) ? true : false;
    this.isSuccess = (e['is_success'] != null && e['is_success'] == 1) ? true : false;
    this.isRead = (e['is_read'] != null && e['is_read'] == 1) ? true : false;
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
      'topic': topic,
      'target_id': topic != null
          ? topic
          : isOutbound
              ? to
              : from,
      'type': contentType,
      'options': options != null ? jsonEncode(options) : null,
      'send_time': sendTime?.millisecondsSinceEpoch,
      'receive_time': rTime,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
      'is_read': (isRead != null && isRead) ? 1 : 0,
      'is_outbound': (isOutbound != null && isOutbound) ? 1 : 0,
      'is_success': (isSuccess != null && isSuccess) ? 1 : 0,
      'is_send_error': (isSendError != null && isSendError) ? 1 : 0,
    };
    String pubKey = hexEncode(chat.publicKey);
    if (contentType == ContentType.nknImage || contentType == ContentType.media) {
      map['content'] = Path.getLocalChatMedia(pubKey, Path.getFileName((content as File)?.path));
    } else if (contentType == ContentType.audio) {
      map['content'] = Path.getLocalChatAudio(pubKey, Path.getFileName((content as File)?.path));
    } else if (contentType == ContentType.eventContactOptions) {
      map['content'] = content;
      if (map['send_time'] == null) {
        map['send_time'] = DateTime.now().millisecondsSinceEpoch;
      }
    } else if (contentType == ContentType.nknOnePiece) {
      map['content'] = Path.getLocalChatPiece(pubKey, Path.getFileName((content as File)?.path));
    } else {
      map['content'] = content;
    }
    return map;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, contentType: $contentType, content: $content, options: $options, sendTime: $sendTime, receiveTime: $receiveTime, deleteTime: $deleteTime, isOutbound: $isOutbound, isSendError: $isSendError, isSuccess: $isSuccess, isRead: $isRead}';
  }

  String toSendTextData() {
    Map data = {
      'id': msgId,
      'contentType': contentType ?? ContentType.text,
      'content': content,
      'timestamp': sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
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
