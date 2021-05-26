import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class MessageOptions {
  static const KEY_AUDIO_DURATION = "audioDuration";
  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";

  static Map<String, dynamic> createAudio(int duration) {
    return {KEY_AUDIO_DURATION: duration};
  }

  static Map<String, dynamic> createBurn(int deleteAfterSeconds) {
    return {KEY_DELETE_AFTER_SECONDS: deleteAfterSeconds};
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

class MessageData {
  static String getSendReceipt(String msgId) {
    Map map = {
      'id': uuid.v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  static String getSendText(MessageSchema schema) {
    if (schema == null) return null;
    Map map = {
      'id': schema.msgId,
      'contentType': schema.contentType ?? ContentType.text,
      'content': schema.content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (schema.options != null && schema.options.keys.length > 0) {
      map['options'] = schema.options;
    }
    if (schema.topic != null) {
      map['topic'] = schema.topic;
    }
    return jsonEncode(map);
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
        chatCommon.id,
        data['contentType'],
        pid: raw.messageId,
        topic: data['topic'],
        content: data['content'],
        options: data['options'],
      );

      if (schema.contentType == ContentType.receipt) {
        schema.content = data['targetID'];
      }

      if (data['timestamp'] != null) {
        schema.sendTime = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      }
      schema.receiveTime = DateTime.now();
      schema.deleteTime = null;

      schema = MessageStatus.set(schema, MessageStatus.Received);

      schema.parentType = data['parentType'];
      schema.parity = data['parity'];
      schema.total = data['total'];
      schema.index = data['index'];
      schema.bytesLength = data['bytesLength'];

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
    this.parentType,
    this.parity,
    this.total,
    this.index,
    this.bytesLength,
  }) {
    // pid (SDK create)
    if (msgId == null) msgId = uuid.v4();

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
    String pubKey = hexEncode(chatCommon.publicKey);
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

  Future<File> getMediaFile() async {
    if (content == null) return null;
    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(content);
    var mimeType = match?.group(1) ?? "";
    var fileBase64 = match?.group(2);
    if (fileBase64 == null || fileBase64.isEmpty) return null;

    var extension;
    if (mimeType.indexOf('image/jpg') > -1 || mimeType.indexOf('image/jpeg') > -1) {
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
    } else {
      logger.w('getMediaFile - no_extension');
    }

    var bytes = base64Decode(fileBase64);
    String name = hexEncode(md5.convert(bytes).bytes);
    String path = Path.getLocalChatMedia(hexEncode(chatCommon.publicKey), '$name.$extension');
    File file = File(join(Global.applicationRootDirectory.path, path));

    logger.d('getMediaFile - path:${file.absolute}');

    if (!await file.exists()) {
      logger.d('getMediaFile - write:${file.absolute}');
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, contentType: $contentType, content: $content, options: $options, sendTime: $sendTime, receiveTime: $receiveTime, deleteTime: $deleteTime, isOutbound: $isOutbound, isSendError: $isSendError, isSuccess: $isSuccess, isRead: $isRead, parentType: $parentType, parity: $parity, total: $total, index: $index, bytesLength: $bytesLength}';
  }
}
