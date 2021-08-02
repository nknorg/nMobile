import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'contact.dart';

class MessageContentType {
  // static const String system = 'system';
  static const String receipt = 'receipt'; // db
  // static const String read = 'read'; // db

  static const String contact = 'contact'; // .
  static const String contactOptions = 'event:contactOptions'; // db + visible

  static const String deviceRequest = 'device:request'; // .
  static const String deviceInfo = 'device:info'; // db

  static const String text = 'text'; // db + visible
  static const String textExtension = 'textExtension'; // db + visible
  static const String media = 'media'; // db + visible
  static const String image = 'image'; // db + visible
  static const String audio = 'audio'; // db + visible

  static const String piece = 'piece'; // db

  static const String topicSubscribe = 'event:subscribe';
  static const String topicUnsubscribe = 'event:unsubscribe';
  static const String topicInvitation = 'event:channelInvitation';
  static const String topicKickOut = 'event:channelKickOut';

  // SUPPORT:START
  static const String nknImage = 'nknImage';
  // SUPPORT:END
}

class MessageOptions {
  static const KEY_AUDIO_DURATION = "audioDuration";

  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";
  static const KEY_UPDATE_BURNING_AFTER_AT = "updateBurnAfterAt";
  static const KEY_DEVICE_TOKEN = "deviceToken";

  static const KEY_PARENT_TYPE = "parentType";
  static const KEY_BYTES_LENGTH = "bytesLength";
  static const KEY_PARITY = "parity";
  static const KEY_TOTAL = "total";
  static const KEY_INDEX = "index";

  static const KEY_PARENT_PIECE = "parent_piece";

  static MessageSchema setAudioDuration(MessageSchema message, double? durationS) {
    if (message.options == null) message.options = Map<String, dynamic>();
    message.options![MessageOptions.KEY_AUDIO_DURATION] = durationS;
    return message;
  }

  static double? getAudioDuration(MessageSchema? message) {
    if (message == null || message.options == null || message.options!.keys.length == 0) return null;
    var duration = message.options![MessageOptions.KEY_AUDIO_DURATION]?.toString();
    if (duration == null || duration.isEmpty) return null;
    return double.parse(duration);
  }

  static MessageSchema setContactBurning(MessageSchema message, int deleteTimeSec, int? updateAt) {
    if (message.options == null) message.options = Map<String, dynamic>();
    message.options![MessageOptions.KEY_DELETE_AFTER_SECONDS] = deleteTimeSec;
    message.options![MessageOptions.KEY_UPDATE_BURNING_AFTER_AT] = updateAt;
    return message;
  }

  static List<int?> getContactBurning(MessageSchema? message) {
    if (message == null || message.options == null || message.options!.keys.length == 0) return [];
    var seconds = message.options![MessageOptions.KEY_DELETE_AFTER_SECONDS]?.toString();
    var update = message.options![MessageOptions.KEY_UPDATE_BURNING_AFTER_AT]?.toString();
    int? t1 = (seconds == null || seconds.isEmpty) ? null : int.tryParse(seconds);
    int? t2 = (update == null || update.isEmpty) ? null : int.tryParse(update);
    return [t1, t2];
  }

  static MessageSchema setDeviceToken(MessageSchema message, String deviceToken) {
    if (message.options == null) message.options = Map<String, dynamic>();
    message.options![MessageOptions.KEY_DEVICE_TOKEN] = deviceToken;
    return message;
  }

  static String? getDeviceToken(MessageSchema? message) {
    if (message == null || message.options == null || message.options!.keys.length == 0) return null;
    var deviceToken = message.options![MessageOptions.KEY_DEVICE_TOKEN]?.toString();
    return deviceToken;
  }

  static Map<String, dynamic> createPiece(MessageSchema message) {
    return {
      KEY_PARENT_TYPE: message.parentType,
      KEY_BYTES_LENGTH: message.bytesLength,
      KEY_TOTAL: message.total,
      KEY_PARITY: message.parity,
      KEY_INDEX: message.index,
    };
  }

  static Map<String, dynamic>? clearPiece(Map<String, dynamic>? options) {
    options?.remove(KEY_PARENT_TYPE);
    options?.remove(KEY_BYTES_LENGTH);
    options?.remove(KEY_TOTAL);
    options?.remove(KEY_PARITY);
    options?.remove(KEY_INDEX);
    return options;
  }
}

class MessageStatus {
  static const int Sending = 100;
  static const int SendFail = 110;
  static const int SendSuccess = 120;
  static const int SendWithReceipt = 130;
  static const int Received = 200;
  static const int ReceivedRead = 210;

  static MessageSchema set(MessageSchema message, int status) {
    if (status == Sending) {
      message.isOutbound = true;
      message.isSendError = false;
      message.isSuccess = false;
      message.isRead = false;
    } else if (status == SendFail) {
      message.isOutbound = true;
      message.isSendError = true;
      message.isSuccess = false;
      message.isRead = false;
    } else if (status == SendSuccess) {
      message.isOutbound = true;
      message.isSendError = false;
      message.isSuccess = true;
      message.isRead = false;
    } else if (status == SendWithReceipt) {
      message.isOutbound = true;
      message.isSendError = false;
      message.isSuccess = true;
      message.isRead = true;
    }
    if (status == Received) {
      message.isOutbound = false;
      message.isSendError = false;
      message.isSuccess = true;
      message.isRead = false;
    } else if (status == ReceivedRead) {
      message.isOutbound = false;
      message.isSendError = false;
      message.isSuccess = true;
      message.isRead = true;
    }
    return message;
  }

  static int get(MessageSchema message) {
    if (message.isOutbound) {
      if (message.isSendError) {
        // || message.pid == null
        return SendFail;
      } else if (message.isSuccess && message.isRead) {
        return SendWithReceipt;
      } else if (message.isSuccess) {
        return SendSuccess;
      } else {
        return Sending;
      }
    } else {
      if (message.isRead) {
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
      'contentType': MessageContentType.receipt,
      'targetID': msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  static String getContactRequest(String requestType, String? profileVersion, int expiresAt) {
    Map data = {
      'id': Uuid().v4(),
      'contentType': MessageContentType.contact,
      'requestType': requestType,
      'version': profileVersion,
      'expiresAt': expiresAt,
    };
    return jsonEncode(data);
  }

  static String getContactResponseHeader(String? profileVersion, int expiresAt) {
    Map data = {
      'id': Uuid().v4(),
      'contentType': MessageContentType.contact,
      'responseType': RequestType.header,
      'version': profileVersion,
      'expiresAt': expiresAt,
    };
    return jsonEncode(data);
  }

  static Future<String> getContactResponseFull(String? firstName, String? lastName, File? avatar, String? profileVersion, int expiresAt) async {
    Map data = {
      'id': Uuid().v4(),
      'contentType': MessageContentType.contact,
      'responseType': RequestType.full,
      'version': profileVersion,
      'expiresAt': expiresAt,
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
    return jsonEncode(data);
  }

  static String getContactOptionsBurn(MessageSchema message) {
    List<int?> burningOptions = MessageOptions.getContactBurning(message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    int? updateBurnAfterAt = burningOptions.length >= 2 ? burningOptions[1] : null;
    Map data = {
      'id': message.msgId,
      'contentType': MessageContentType.contactOptions,
      'optionType': '0',
      'content': {
        'deleteAfterSeconds': burnAfterSeconds,
        'updateBurnAfterAt': updateBurnAfterAt,
        // SUPPORT:START
        'updateBurnAfterTime': updateBurnAfterAt,
        // SUPPORT:END
      },
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getContactOptionsToken(MessageSchema message) {
    String? deviceToken = MessageOptions.getDeviceToken(message);
    Map data = {
      'id': message.msgId,
      'contentType': MessageContentType.contactOptions,
      'optionType': '1',
      'content': {
        'deviceToken': deviceToken,
      },
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getDeviceRequest() {
    Map data = {
      'id': Uuid().v4(),
      'contentType': MessageContentType.deviceRequest,
    };
    return jsonEncode(data);
  }

  static String getDeviceInfo() {
    Map data = {
      'id': Uuid().v4(),
      'contentType': MessageContentType.deviceInfo,
      'deviceId': Global.deviceId,
      'appName': Settings.appName,
      'appVersion': Global.build,
      'platform': PlatformName.get(),
      'platformVersion': Global.deviceVersion,
    };
    return jsonEncode(data);
  }

  static String getText(MessageSchema message) {
    Map map = {
      'id': message.msgId,
      'contentType': message.contentType,
      'content': message.content,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (message.isTopic) {
      map['topic'] = message.topic;
    }
    if (message.options != null && message.options!.keys.length > 0) {
      map['options'] = message.options;
    }
    return jsonEncode(map);
  }

  static Future<String?> getImage(MessageSchema message) async {
    File? file = message.content as File?;
    if (file == null) return null;
    String content = '![image](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    Map data = {
      'id': message.msgId,
      'contentType': message.contentType,
      'content': content,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (message.isTopic) {
      data['topic'] = message.topic;
    }
    if (message.options != null && message.options!.keys.length > 0) {
      data['options'] = message.options;
    }
    return jsonEncode(data);
  }

  static Future<String?> getAudio(MessageSchema message) async {
    File? file = message.content as File?;
    if (file == null) return null;
    var mimeType = mime(file.path) ?? "";
    if (mimeType.split('aac').length <= 0) return null;
    String content = '![audio](data:${mime(file.path)};base64,${base64Encode(file.readAsBytesSync())})';
    Map data = {
      'id': message.msgId,
      'contentType': message.contentType,
      'content': content,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (message.isTopic) {
      data['topic'] = message.topic;
    }
    if (message.options != null && message.options!.keys.length > 0) {
      data['options'] = message.options;
    }
    return jsonEncode(data);
  }

  static String getPiece(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'contentType': message.contentType,
      'content': message.content,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'parentType': message.parentType ?? message.contentType,
      'bytesLength': message.bytesLength,
      'total': message.total,
      'parity': message.parity,
      'index': message.index,
    };
    if (message.isTopic) {
      data['topic'] = message.topic;
    }
    if (message.options != null && message.options!.keys.length > 0) {
      data['options'] = message.options;
    }
    return jsonEncode(data);
  }

  static String getTopicSubscribe(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'topic': message.topic,
      'contentType': MessageContentType.topicSubscribe,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getTopicUnSubscribe(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'topic': message.topic,
      'contentType': MessageContentType.topicUnsubscribe,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getTopicInvitee(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'contentType': MessageContentType.topicInvitation,
      'content': message.content,
      'timestamp': message.sendTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  static String getTopicKickOut(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'topic': message.topic,
      'contentType': MessageContentType.topicKickOut,
      'content': message.content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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

  // TODO:GG time -> at
  DateTime? sendTime; // <-> send_time
  DateTime? receiveTime; // <-> receive_time
  DateTime? deleteTime; // <-> delete_time

  // TODO:GG merge to one field ??? (status)
  bool isOutbound = false; // <-> is_outbound
  bool isSendError = false; // <-> is_send_error
  bool isSuccess = false; // <-> is_success
  bool isRead = false; // <-> is_read

  // TODO:GG move to options?
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
    if (msgId.isEmpty) msgId = Uuid().v4();
    if (sendTime == null) sendTime = DateTime.now();
  }

  String? get targetId {
    return isTopic ? topic : (isOutbound ? to : from);
  }

  bool get isTopic {
    return topic?.isNotEmpty == true;
  }

  // Burning
  bool get canBurning {
    bool isText = contentType == MessageContentType.text || contentType == MessageContentType.textExtension;
    bool isImage = contentType == MessageContentType.media || contentType == MessageContentType.image || contentType == MessageContentType.nknImage;
    bool isAudio = contentType == MessageContentType.audio;
    return isText || isImage || isAudio;
  }

  // ++ UnReadCount / Notification
  bool get canDisplayAndRead {
    bool isEvent = contentType == MessageContentType.topicInvitation;
    return canBurning || isEvent;
  }

  // ++ Session
  bool get canDisplay {
    bool isEvent = contentType == MessageContentType.contactOptions || contentType == MessageContentType.topicSubscribe; // || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicKickOut
    return canDisplayAndRead || isEvent;
  }

  bool get isTopicAction {
    return contentType == MessageContentType.topicSubscribe || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicInvitation || contentType == MessageContentType.topicKickOut;
  }

  bool get needReceipt {
    return contentType == MessageContentType.contactOptions || contentType == MessageContentType.text || contentType == MessageContentType.textExtension || contentType == MessageContentType.media || contentType == MessageContentType.image || contentType == MessageContentType.nknImage || contentType == MessageContentType.audio || contentType == MessageContentType.topicSubscribe || contentType == MessageContentType.topicInvitation;
  }

  Future<ContactSchema?> getSender({bool emptyAdd = false}) async {
    ContactSchema? _contact = await contactCommon.queryByClientAddress(from);
    if (_contact != null || !emptyAdd) return _contact;
    return await contactCommon.addByType(from, ContactType.stranger, notify: true, checkDuplicated: false);
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null || raw.data == null || raw.src == null) return null;
    Map<String, dynamic>? data = jsonFormat(raw.data);
    if (data == null || data['id'] == null || data['contentType'] == null) return null;
    MessageSchema schema = MessageSchema(
      data['id'] ?? "",
      raw.src ?? "",
      data['contentType'] ?? "",
      pid: raw.messageId,
      to: clientCommon.address,
      topic: data['topic'],
      options: data['options'],
    );

    switch (schema.contentType) {
      case MessageContentType.receipt:
        schema.content = data['targetID'];
        break;
      case MessageContentType.contact:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceInfo:
      case MessageContentType.deviceRequest:
        schema.content = data;
        break;
      // case ContentType.text:
      // case ContentType.textExtension:
      // case ContentType.media:
      // case ContentType.image:
      // case ContentType.nknImage:
      // case ContentType.audio:
      // case ContentType.piece:
      // case ContentType.topicSubscribe:
      // case ContentType.topicUnsubscribe:
      // case ContentType.topicInvitation:
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
    if (combine.options == null) combine.options = Map();
    combine.options?[MessageOptions.KEY_PARENT_PIECE] = true; // diff with really image

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
    double? audioDurationS,
    int? deleteAfterSeconds,
    int? burningUpdateAt,
  }) {
    // pid (SDK create)
    if (msgId.isEmpty) msgId = Uuid().v4();

    sendTime = DateTime.now();
    receiveTime = null;
    deleteTime = null; // set in messages bubble

    MessageStatus.set(this, MessageStatus.Sending);

    // duration
    if (audioDurationS != null && audioDurationS > 0) {
      MessageOptions.setAudioDuration(this, audioDurationS);
    }
    // burn
    if (deleteAfterSeconds != null && deleteAfterSeconds > 0) {
      MessageOptions.setContactBurning(this, deleteAfterSeconds, burningUpdateAt);
    }
  }

  /// to sqlite
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid!) : null,
      'msg_id': msgId,
      'sender': from,
      'receiver': to,
      'topic': topic,
      'target_id': targetId,
      'type': contentType,
      'send_time': sendTime?.millisecondsSinceEpoch,
      'receive_time': receiveTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'delete_time': deleteTime?.millisecondsSinceEpoch,
      'is_read': isRead ? 1 : 0,
      'is_outbound': isOutbound ? 1 : 0,
      'is_success': isSuccess ? 1 : 0,
      'is_send_error': isSendError ? 1 : 0,
    };

    // content = String
    switch (contentType) {
      // case ContentType.receipt:
      case MessageContentType.contact:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
        map['content'] = content is Map ? jsonEncode(content) : content;
        break;
      // case ContentType.text:
      // case ContentType.textExtension:
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.nknImage:
      case MessageContentType.audio:
      case MessageContentType.piece:
        if (content is File) {
          map['content'] = Path.getLocalFile((content as File).path);
        }
        break;
      // case ContentType.topicSubscribe:
      // case ContentType.topicUnsubscribe:
      // case ContentType.topicInvitation:
      default:
        map['content'] = content;
        break;
    }

    if (contentType == MessageContentType.piece) {
      if (options == null) {
        options = Map<String, dynamic>();
      }
      Map<String, dynamic> piece = MessageOptions.createPiece(this);
      options?.addAll(piece);
    }
    map['options'] = options != null ? jsonEncode(options) : null;

    return map;
  }

  /// from sqlite
  static MessageSchema fromMap(Map<String, dynamic> e) {
    MessageSchema schema = MessageSchema(
      e['msg_id'] ?? "",
      e['sender'] ?? "",
      e['type'] ?? "",
      pid: e['pid'] != null ? hexDecode(e['pid']) : null,
      to: e['receiver'],
      topic: e['topic'],
      options: (e['options']?.toString().isNotEmpty == true) ? jsonFormat(e['options']) : null,
    );

    // content = File/Map/String...
    switch (schema.contentType) {
      case MessageContentType.receipt:
        schema.content = e['targetID'];
        break;
      case MessageContentType.contact:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceInfo:
      case MessageContentType.deviceRequest:
        if ((e['content']?.toString().isNotEmpty == true) && (e['content'] is String)) {
          schema.content = jsonFormat(e['content']);
        } else {
          schema.content = e['content'];
        }
        break;
      // case ContentType.text:
      // case ContentType.textExtension:
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.nknImage:
      case MessageContentType.audio:
      case MessageContentType.piece:
        String? completePath = Path.getCompleteFile(e['content']);
        schema.content = (completePath?.isNotEmpty == true) ? File(completePath!) : null;
        break;
      // case ContentType.topicSubscribe:
      // case ContentType.topicUnsubscribe:
      // case ContentType.topicInvitation:
      default:
        schema.content = e['content'];
        break;
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

  @override
  List<Object?> get props => [pid];

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, contentType: $contentType, content: ${(content is String && (content as String).length <= 1000) ? content : "~~~~~"}, options: $options, sendTime: $sendTime, receiveTime: $receiveTime, deleteTime: $deleteTime, isOutbound: $isOutbound, isSendError: $isSendError, isSuccess: $isSuccess, isRead: $isRead, parentType: $parentType, bytesLength: $bytesLength, total: $total, parity: $parity, index: $index}';
  }
}
