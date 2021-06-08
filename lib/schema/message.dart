import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class ContentType {
  static const String system = 'system'; // TODO:GG wait data
  static const String receipt = 'receipt';
  static const String contact = 'contact';

  static const String piece = 'nknOnePiece';

  static const String text = 'text';
  static const String textExtension = 'textExtension'; // TODO:GG wait handle
  static const String media = 'media';
  // static const String image = 'image';
  static const String audio = 'audio'; // TODO:GG wait handle
  // static const String video = 'video';

  static const String eventContactOptions = 'event:contactOptions'; // TODO:GG wait handle
  static const String eventSubscribe = 'event:subscribe'; // TODO:GG wait handle
  static const String eventUnsubscribe = 'event:unsubscribe'; // TODO:GG wait handle
  static const String eventChannelInvitation = 'event:channelInvitation'; // TODO:GG wait data

  // SUPPORT:START
  static const String nknImage = 'nknImage';
  // SUPPORT:END
}

class MessageOptions {
  static const KEY_AUDIO_DURATION = "audioDuration"; // TODO:GG wait handle
  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds"; // TODO:GG wait handle
  static const KEY_DEVICE_TOKEN = "deviceToken"; // TODO:GG wait handle

  static const KEY_PARENT_TYPE = "parentType";
  static const KEY_BYTES_LENGTH = "bytesLength";
  static const KEY_PARITY = "parity";
  static const KEY_TOTAL = "total";
  static const KEY_INDEX = "index";

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

  static Map<String, dynamic> createPiece(MessageSchema schema) {
    return {
      KEY_PARENT_TYPE: schema.parentType,
      KEY_BYTES_LENGTH: schema.bytesLength,
      KEY_TOTAL: schema.total,
      KEY_PARITY: schema.parity,
      KEY_INDEX: schema.index,
    };
  }

  static Map<String, dynamic>? clearPiece(Map<String, dynamic>? options) {
    options?.remove(KEY_PARENT_TYPE);
    options?.remove(KEY_BYTES_LENGTH);
    options?.remove(KEY_TOTAL);
    options?.remove(KEY_PARITY);
    options?.remove(KEY_INDEX);
  }
}

class MessageStatus {
  static const int Sending = 100;
  static const int SendFail = 110;
  static const int SendSuccess = 120;
  static const int SendWithReceipt = 130;
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
    } else if (status == SendWithReceipt) {
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
        return SendWithReceipt;
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
      'id': Uuid().v4(),
      'contentType': ContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  static String getContactRequest(String requestType, String? profileVersion, DateTime expiresAt) {
    Map data = {
      'id': Uuid().v4(),
      'contentType': ContentType.contact,
      'requestType': requestType,
      'version': profileVersion,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getContactResponseHeader(String? profileVersion, DateTime expiresAt) {
    Map data = {
      'id': Uuid().v4(),
      'contentType': ContentType.contact,
      'responseType': RequestType.header,
      'version': profileVersion,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
    // data['onePieceReady'] = '1';
    return jsonEncode(data);
  }

  static Future<String> getContactResponseFull(String? firstName, String? lastName, File? avatar, String? profileVersion, DateTime expiresAt) async {
    Map data = {
      'id': Uuid().v4(),
      'contentType': ContentType.contact,
      'responseType': RequestType.full,
      'version': profileVersion,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
    Map<String, dynamic> content = Map();
    if (firstName?.isNotEmpty == true) {
      content['first_name'] = firstName;
      content['last_name'] = lastName;
      // SUPPORT:START
      content['name'] = firstName;
      // SUPPORT:END
    }
    if (avatar != null && await avatar.exists()) {
      String base64 = base64Encode(await avatar.readAsBytes());
      if (base64.isNotEmpty == true) {
        content['avatar'] = {'type': 'base64', 'data': base64};
      }
    }
    data['content'] = content;
    // data['onePieceReady'] = '1';
    return jsonEncode(data);
  }

  static String getPiece(MessageSchema schema) {
    Map data = {
      'id': schema.msgId,
      'contentType': ContentType.piece,
      'content': schema.content,
      'timestamp': schema.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'parentType': schema.parentType ?? schema.contentType,
      'bytesLength': schema.bytesLength,
      'total': schema.total,
      'parity': schema.parity,
      'index': schema.index,
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

  static Future<String?> getImage(MessageSchema schema) async {
    File? file = schema.content as File?;
    if (file == null) return null;
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

  static Future<String?> getAudio(MessageSchema schema) async {
    File? file = schema.content as File?;
    if (file == null) return null;
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
  int? bytesLength;
  int? total;
  int? parity;
  int? index;

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
    if (msgId == null || msgId.isEmpty) msgId = Uuid().v4();
    if (sendTime == null) sendTime = DateTime.now();
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null || raw.data == null || raw.src == null) return null;
    Map<String, dynamic>? data = jsonFormat(raw.data);
    if (data == null || data['id'] == null || data['contentType'] == null) return null;
    MessageSchema schema = MessageSchema(
      data['id']!,
      raw.src!,
      data['contentType']!,
      pid: raw.messageId,
      to: chatCommon.id,
      topic: data['topic'],
      options: data['options'],
    );

    switch (schema.contentType) {
      case ContentType.receipt:
        schema.content = data['targetID'];
        break;
      case ContentType.contact:
        schema.content = data;
        break;
      default:
        schema.content = data['content'];
        break;
    }

    if (data['timestamp'] != null) {
      schema.sendTime = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
    }
    schema.receiveTime = DateTime.now();
    schema.deleteTime = null; // set in messages bubble

    schema = MessageStatus.set(schema, MessageStatus.Received);

    schema.parentType = data['parentType'];
    schema.bytesLength = data['bytesLength'];
    schema.total = data['total'];
    schema.parity = data['parity'];
    schema.index = data['index'];

    return schema;
  }

  static MessageSchema fromPieces(List<MessageSchema> sortPieces, String base64String) {
    MessageSchema piece = sortPieces.firstWhere((element) => element.pid != null);

    MessageSchema combine = MessageSchema(
      piece.msgId,
      piece.from,
      piece.parentType ?? "",
      pid: piece.pid,
      topic: piece.topic,
      to: piece.to,
      content: base64String,
      sendTime: piece.sendTime,
    );

    combine.options = MessageOptions.clearPiece(piece.options);

    combine.receiveTime = DateTime.now();
    combine.deleteTime = null; // set in messages bubble

    combine = MessageStatus.set(combine, MessageStatus.Received);

    // combine.parentType = data['parentType'];
    // combine.bytesLength = data['bytesLength'];
    // combine.total = data['total'];
    // combine.parity = data['parity'];
    // combine.index = data['index'];

    return combine;
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
    this.bytesLength,
    this.total,
    this.parity,
    this.index,
  }) {
    // pid (SDK create)
    if (msgId == null || msgId.isEmpty) msgId = Uuid().v4();

    sendTime = DateTime.now();
    receiveTime = null;
    deleteTime = null; // set in messages bubble

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

    if (schema.contentType == ContentType.nknImage || schema.contentType == ContentType.media) {
      schema.content = File(Path.getCompleteFile(e['content']));
    } else if (schema.contentType == ContentType.audio) {
      schema.content = File(Path.getCompleteFile(e['content']));
    } else if (schema.contentType == ContentType.piece) {
      schema.content = File(Path.getCompleteFile(e['content']));
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
    schema.bytesLength = options[MessageOptions.KEY_BYTES_LENGTH];
    schema.total = options[MessageOptions.KEY_TOTAL];
    schema.parity = options[MessageOptions.KEY_PARITY];
    schema.index = options[MessageOptions.KEY_INDEX];

    return schema;
  }

  /// to sqlite
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid!) : null,
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
    // String pubKey = hexEncode(chatCommon.publicKey);
    if (contentType == ContentType.nknImage || contentType == ContentType.media) {
      if (content is File) {
        map['content'] = Path.getLocalFile((content as File).path);
      }
    } else if (contentType == ContentType.audio) {
      if (content is File) {
        map['content'] = Path.getLocalFile((content as File).path);
      }
    } else if (contentType == ContentType.piece) {
      if (content is File) {
        map['content'] = Path.getLocalFile((content as File).path);
      }
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

  String? get getTargetId {
    return topic != null
        ? topic
        : isOutbound
            ? to
            : from;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, contentType: $contentType, content: ${(content is String && (content as String).length <= 100) ? content : "~~~~~"}, options: $options, sendTime: $sendTime, receiveTime: $receiveTime, deleteTime: $deleteTime, isOutbound: $isOutbound, isSendError: $isSendError, isSuccess: $isSuccess, isRead: $isRead, parentType: $parentType, bytesLength: $bytesLength, total: $total, parity: $parity, index: $index}';
  }

  @override
  List<Object?> get props => [pid];
}
