import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'contact.dart';

var uuid = Uuid();

class ContentType {
  static const String system = 'system'; // TODO:GG wait data
  static const String receipt = 'receipt';
  static const String piece = 'nknOnePiece'; // TODO:GG wait handle

  static const String text = 'text';
  static const String textExtension = 'textExtension'; // TODO:GG wait handle
  static const String media = 'media'; // TODO:GG remove?
  static const String image = 'nknImage'; // TODO:GG remove?
  static const String audio = 'audio'; // TODO:GG wait handle
  // static const String video = 'video';

  static const String contact = 'contact'; // TODO:GG wait handle
  static const String eventContactOptions = 'event:contactOptions'; // TODO:GG wait handle
  static const String eventSubscribe = 'event:subscribe'; // TODO:GG wait handle
  static const String eventUnsubscribe = 'event:unsubscribe'; // TODO:GG wait handle
  static const String eventChannelInvitation = 'event:channelInvitation'; // TODO:GG wait data
}

class MessageOptions {
  static const KEY_AUDIO_DURATION = "audioDuration";
  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";
  static const KEY_DEVICE_TOKEN = "deviceToken";

  static const KEY_PARENT_TYPE = "parentType";
  static const KEY_PARITY = "parity";
  static const KEY_TOTAL = "total";
  static const KEY_INDEX = "index";
  static const KEY_BYTES_LENGTH = "bytesLength";

  static Map<String, dynamic> createAudio(int duration) {
    return {KEY_AUDIO_DURATION: duration};
  }

  static Map<String, dynamic> createBurn(int deleteAfterSeconds) {
    return {KEY_DELETE_AFTER_SECONDS: deleteAfterSeconds};
  }

  static Map<String, dynamic> createPiece(MessageSchema schema) {
    return {
      KEY_PARENT_TYPE: schema.parentType,
      KEY_PARITY: schema.parity,
      KEY_TOTAL: schema.total,
      KEY_INDEX: schema.index,
      KEY_BYTES_LENGTH: schema.bytesLength,
    };
  }

  static int? getDeleteAfterSeconds(MessageSchema? schema) {
    if (schema == null || schema.options == null || schema.options!.keys.length == 0) return null;
    var seconds = schema.options![MessageOptions.KEY_DELETE_AFTER_SECONDS];
    if (seconds == null) return null;
    return int.parse(seconds);
  }

  static String? getDeviceToken(MessageSchema? schema) {
    if (schema == null || schema.options == null || schema.options!.keys.length == 0) return null;
    var deviceToken = schema.options![MessageOptions.KEY_DEVICE_TOKEN];
    return deviceToken;
  }
}

class MessageStatus {
  static const int Sending = 100;
  static const int SendFail = 110;
  static const int SendSuccess = 120;
  static const int SendByReplyReceipt = 130;
  static const int Received = 200;
  static const int ReceivedRead = 210;

  static MessageSchema set(MessageSchema schema, int status) {
    if (status == Sending) {
      schema.isOutbound = true;
      schema.isSendError = false;
      schema.isSuccess = false;
      schema.isRead = false;
    } else if (status == SendFail) {
      schema.isOutbound = true;
      schema.isSendError = true;
      schema.isSuccess = false;
      schema.isRead = false;
    } else if (status == SendSuccess) {
      schema.isOutbound = true;
      schema.isSendError = false;
      schema.isSuccess = true;
      schema.isRead = false;
    } else if (status == SendByReplyReceipt) {
      schema.isOutbound = true;
      schema.isSendError = false;
      schema.isSuccess = true;
      schema.isRead = true;
    }
    if (status == Received) {
      schema.isOutbound = false;
      schema.isSendError = false;
      schema.isSuccess = true;
      schema.isRead = false;
    } else if (status == ReceivedRead) {
      schema.isOutbound = false;
      schema.isSendError = false;
      schema.isSuccess = true;
      schema.isRead = true;
    }
    return schema;
  }

  static int get(MessageSchema schema) {
    if (schema.isOutbound) {
      if (schema.isSendError) {
        // || schema.pid == null
        return SendFail;
      } else if (schema.isSuccess && schema.isRead) {
        return SendByReplyReceipt;
      } else if (schema.isSuccess) {
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
  static String getReceipt(String msgId) {
    Map map = {
      'id': uuid.v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  static String getPiece(MessageSchema schema) {
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.piece,
      'content': schema.content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'parentType': schema.parentType,
      'parity': schema.parity,
      'total': schema.total,
      'index': schema.index,
      'bytesLength': schema.bytesLength,
    };
    if (schema.options != null && schema.options!.keys.length > 0) {
      data['options'] = schema.options;
    }
    if (schema.topic != null) {
      data['topic'] = schema.topic;
    }
    return jsonEncode(data);
  }

  static String getText(MessageSchema schema) {
    Map map = {
      'id': schema.msgId,
      'contentType': ContentType.text,
      'content': schema.content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (schema.options != null && schema.options!.keys.length > 0) {
      map['options'] = schema.options;
    }
    if (schema.topic != null) {
      map['topic'] = schema.topic;
    }
    return jsonEncode(map);
  }

  static Future<String> getDChatMedia(MessageSchema schema) async {
    File file = schema.content as File;
    String content = '![media](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.media,
      'content': content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (schema.options != null && schema.options!.keys.length > 0) {
      data['options'] = schema.options;
    }
    if (schema.topic != null) {
      data['topic'] = schema.topic;
    }
    return jsonEncode(data);
  }

  static Future<String> getImage(MessageSchema schema) async {
    File file = schema.content as File;
    String content = '![image](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.image,
      'content': content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (schema.options != null && schema.options!.keys.length > 0) {
      data['options'] = schema.options;
    }
    if (schema.topic != null) {
      data['topic'] = schema.topic;
    }
    return jsonEncode(data);
  }

  static Future<String> getAudio(MessageSchema schema) async {
    File file = schema.content as File;
    // var mimeType = mime(file.path) ?? "";
    // if (mimeType.split('aac').length > 1) {
    String content = '![audio](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    // }
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.audio,
      'content': content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (schema.options != null && schema.options!.keys.length > 0) {
      data['options'] = schema.options;
    }
    if (schema.topic != null) {
      data['topic'] = schema.topic;
    }
    return jsonEncode(data);
  }

  static String getContact(MessageSchema schema, ContactSchema other, String requestType) {
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.contact,
      'requestType': requestType,
      'version': other.profileVersion,
      'expiresAt': 0, // TODO:GG expiresAt
    };
    return jsonEncode(data);
  }

  static String getEventContactOptionsBurn(MessageSchema schema, {int? seconds}) {
    int? deleteAfterSeconds = seconds ?? MessageOptions.getDeleteAfterSeconds(schema);
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deleteAfterSeconds': deleteAfterSeconds},
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    data['optionType'] = '0';
    return jsonEncode(data);
  }

  static String getEventContactOptionsNotice(MessageSchema schema, {String? token}) {
    String? deviceToken = token ?? MessageOptions.getDeviceToken(schema);
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deviceToken': deviceToken},
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    data['optionType'] = '1';
    return jsonEncode(data);
  }

  String getEventSubscribe(MessageSchema schema) {
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.eventSubscribe,
      'content': schema.content,
      'topic': schema.topic,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  String getEventUnSubscribe(MessageSchema schema) {
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.eventUnsubscribe,
      'content': schema.content,
      'topic': schema.topic,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }
}

class MessageSchema extends Equatable {
  Uint8List? pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String from; // (required) <-> sender / -> target_id(session_id)
  String? to; // <-> receiver / -> target_id(session_id)
  String? topic; // <-> topic / -> target_id(session_id)

  String contentType; // (required) <-> type
  dynamic content; // <-> content
  Map<String, dynamic>? options; // <-> options

  DateTime? sendTime; // <-> send_time
  DateTime? receiveTime; // <-> receive_time
  DateTime? deleteTime; // <-> delete_time

  bool isOutbound = false; // <-> is_outbound
  bool isSendError = false; // <-> is_send_error
  bool isSuccess = false; // <-> is_success
  bool isRead = false; // <-> is_read

  String? parentType;
  int? parity;
  int? total;
  int? index;
  int? bytesLength;

  MessageSchema(
    this.msgId,
    this.from,
    this.contentType, {
    this.pid,
    this.to,
    this.topic,
    this.content,
    this.options,
    this.sendTime,
  }) {
    if (msgId == null || msgId.isEmpty) msgId = uuid.v4();
    if (sendTime == null) sendTime = DateTime.now();
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null || raw.data == null) return null;
    Map<String, dynamic>? data = jsonFormat(raw.data);
    if (data != null) {
      MessageSchema schema = MessageSchema(
        data['id'],
        raw.src,
        data['contentType'],
        pid: raw.messageId,
        to: chatCommon.id,
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

      // set in messages screen
      // int? deleteTime = MessageOptions.getDeleteAfterSeconds(schema);
      // schema.deleteTime = deleteTime != null ? DateTime.fromMillisecondsSinceEpoch(deleteTime) : null;

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

  /// to send
  MessageSchema.fromSend(
    this.msgId,
    this.from,
    this.contentType, {
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
    if (msgId.isEmpty) msgId = uuid.v4();

    sendTime = DateTime.now();
    receiveTime = null;
    deleteTime = null;

    // set in messages screen
    // int? dt = MessageOptions.getDeleteAfterSeconds(this);
    // deleteTime = dt != null ? DateTime.fromMillisecondsSinceEpoch(dt) : null;

    MessageStatus.set(this, MessageStatus.Sending);
  }

  /// from sqlite
  static MessageSchema fromMap(Map<String, dynamic> e) {
    MessageSchema schema = MessageSchema(
      e['msg_id'],
      e['sender'],
      e['type'],
      pid: e['pid'] != null ? hexDecode(e['pid']) : null,
      to: e['receiver'],
      topic: e['topic'],
      options: e['options'] != null ? jsonFormat(e['options']) : null,
    );

    if (schema.contentType == ContentType.image || schema.contentType == ContentType.media) {
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      schema.content = File(filePath);
    } else if (schema.contentType == ContentType.audio) {
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      schema.content = File(filePath);
    } else if (schema.contentType == ContentType.piece) {
      String filePath = join(Global.applicationRootDirectory.path, e['content']);
      schema.content = File(filePath);
    } else {
      schema.content = e['content'];
    }

    schema.sendTime = e['send_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['send_time']) : null;
    schema.receiveTime = e['receive_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['receive_time']) : null;
    schema.deleteTime = e['delete_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['delete_time']) : null;

    schema.isOutbound = (e['is_outbound'] != null && e['is_outbound'] == 1) ? true : false;
    schema.isSendError = (e['is_send_error'] != null && e['is_send_error'] == 1) ? true : false;
    schema.isSuccess = (e['is_success'] != null && e['is_success'] == 1) ? true : false;
    schema.isRead = (e['is_read'] != null && e['is_read'] == 1) ? true : false;

    Map<String, dynamic> options = schema.options ?? Map<String, dynamic>();
    schema.parentType = options[MessageOptions.KEY_PARENT_TYPE];
    schema.parity = options[MessageOptions.KEY_PARITY];
    schema.total = options[MessageOptions.KEY_TOTAL];
    schema.index = options[MessageOptions.KEY_INDEX];
    schema.bytesLength = options[MessageOptions.KEY_BYTES_LENGTH];

    return schema;
  }

  /// to sqlite
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid) : null,
      'msg_id': msgId,
      'sender': from,
      'receiver': to,
      'topic': topic,
      'target_id': getTargetId,
      'type': contentType,
      'send_time': sendTime?.millisecondsSinceEpoch,
      'receive_time': receiveTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
      'is_read': isRead ? 1 : 0,
      'is_outbound': isOutbound ? 1 : 0,
      'is_success': isSuccess ? 1 : 0,
      'is_send_error': isSendError ? 1 : 0,
    };
    String pubKey = hexEncode(chatCommon.publicKey);
    if (contentType == ContentType.image || contentType == ContentType.media) {
      map['content'] = Path.getLocalChat(pubKey, Path.getFileName((content as File).path));
    } else if (contentType == ContentType.audio) {
      map['content'] = Path.getLocalChat(pubKey, Path.getFileName((content as File).path));
    } else if (contentType == ContentType.piece) {
      map['content'] = Path.getLocalChat(pubKey, Path.getFileName((content as File).path));
    } else {
      map['content'] = content;
    }

    if (contentType == ContentType.piece) {
      if (options == null) {
        options = Map<String, dynamic>();
      }
      Map<String, dynamic> piece = MessageOptions.createPiece(this);
      options?.addAll(piece);
    }
    map['options'] = options != null ? jsonEncode(options) : null;

    return map;
  }

  Future<File?> getMediaFile() async {
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
    String name = hexEncode(Uint8List.fromList(md5.convert(bytes).bytes));
    String path = Path.getLocalChat(hexEncode(chatCommon.publicKey), '$name.$extension');
    File file = File(join(Global.applicationRootDirectory.path, path));

    logger.d('getMediaFile - path:${file.absolute}');

    if (!await file.exists()) {
      logger.d('getMediaFile - write:${file.absolute}');
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  String? get getTargetId {
    return topic != null
        ? topic
        : isOutbound
            ? to
            : from;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, contentType: $contentType, content: $content, options: $options, sendTime: $sendTime, receiveTime: $receiveTime, deleteTime: $deleteTime, isOutbound: $isOutbound, isSendError: $isSendError, isSuccess: $isSuccess, isRead: $isRead, parentType: $parentType, parity: $parity, total: $total, index: $index, bytesLength: $bytesLength}';
  }

  @override
  List<Object?> get props => [pid];
}
