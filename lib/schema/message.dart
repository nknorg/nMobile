import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class MessageStatus {
  // send
  static const int Sending = 100;
  static const int SendFail = 110;
  static const int SendSuccess = 120;
  static const int SendReceipt = 130;
  // receive
  static const int Received = 200;
  // common
  static const int Read = 310;
}

class MessageContentType {
  static const String ping = 'ping'; // .
  // static const String system = 'system';
  static const String receipt = 'receipt'; // status
  static const String read = 'read'; // status
  static const String msgStatus = 'msgStatus'; // status + resend

  static const String contact = 'contact'; // .
  static const String contactOptions = 'event:contactOptions'; // db + visible

  static const String deviceRequest = 'device:request'; // .
  static const String deviceInfo = 'device:info'; // db

  static const String text = 'text'; // db + visible
  static const String textExtension = 'textExtension'; // db + visible
  static const String media = 'media'; // db + visible
  static const String image = 'nknImage'; // db + visible
  static const String audio = 'audio'; // db + visible

  static const String piece = 'nknOnePiece'; // db(delete)

  static const String topicSubscribe = 'event:subscribe'; // db + visible
  static const String topicUnsubscribe = 'event:unsubscribe'; // .
  static const String topicInvitation = 'event:channelInvitation'; // db + visible
  static const String topicKickOut = 'event:channelKickOut'; // .
}

class MessageSchema {
  Uint8List? pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String from; // (required) <-> sender / -> target_id(session_id)
  String? to; // <-> receiver / -> target_id(session_id)
  String? topic; // <-> topic / -> target_id(session_id)

  int status; // <-> status
  bool isOutbound; // <-> is_outbound
  bool isDelete; // <-> is_delete

  int? sendAt; // <-> send_at (== create_at/receive_at)
  int? receiveAt; // <-> receive_at (== ack_at/read_at)
  int? deleteAt; // <-> delete_at

  String contentType; // (required) <-> type
  dynamic content; // <-> content
  Map<String, dynamic>? options; // <-> options

  MessageSchema({
    this.pid,
    required this.msgId,
    required this.from,
    this.to,
    this.topic,
    // status
    required this.status,
    required this.isOutbound,
    this.isDelete = false,
    // at
    required this.sendAt,
    this.receiveAt,
    this.deleteAt,
    // data
    required this.contentType,
    this.content,
    this.options,
  });

  String? get targetId {
    return isTopic ? topic : (isOutbound ? to : from);
  }

  bool get isTopic {
    return topic?.isNotEmpty == true;
  }

  // burning
  bool get canBurning {
    bool isText = contentType == MessageContentType.text || contentType == MessageContentType.textExtension;
    bool isImage = contentType == MessageContentType.media || contentType == MessageContentType.image;
    bool isAudio = contentType == MessageContentType.audio;
    return isText || isImage || isAudio;
  }

  // ++ resend
  bool get canResend {
    return canBurning;
  }

  // ++ receipt
  bool get canReceipt {
    bool isEvent = contentType == MessageContentType.topicInvitation;
    return canResend || isEvent;
  }

  // ++ unReadCount / notification
  bool get canNotification {
    return canReceipt;
  }

  // ++ session
  bool get canDisplay {
    bool isEvent = contentType == MessageContentType.contactOptions || contentType == MessageContentType.topicSubscribe; // || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicKickOut
    return canNotification || isEvent;
  }

  bool get isTopicAction {
    return contentType == MessageContentType.topicSubscribe || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicInvitation || contentType == MessageContentType.topicKickOut;
  }

  bool get isContentMedia {
    bool isImage = contentType == MessageContentType.media || contentType == MessageContentType.image;
    bool isAudio = contentType == MessageContentType.audio;
    return isImage || isAudio;
  }

  ContactSchema? contact;
  Future<ContactSchema?> getSender({bool emptyAdd = false}) async {
    if (contact != null) return contact;
    contact = await contactCommon.queryByClientAddress(from);
    if (contact != null || !emptyAdd) return contact;
    contact = await contactCommon.addByType(from, ContactType.none, notify: true, checkDuplicated: false);
    return contact;
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null || raw.data == null || raw.src == null) return null;
    Map<String, dynamic>? data = jsonFormat(raw.data);
    if (data == null || data['id'] == null || data['contentType'] == null) return null;
    MessageSchema schema = MessageSchema(
      pid: raw.messageId,
      msgId: data['id'] ?? "",
      from: raw.src ?? "",
      to: clientCommon.address,
      topic: data['topic'],
      // status
      status: MessageStatus.Received,
      isOutbound: false,
      isDelete: false,
      // at
      sendAt: DateTime.now().millisecondsSinceEpoch, // data['timestamp'] != null ? data['timestamp'] : null, (used by receive_at, for sort)
      receiveAt: null, // set in ack(isTopic) / read(contact)
      deleteAt: null, // set in messages bubble
      // data
      contentType: data['contentType'] ?? "",
      options: data['options'],
    );

    switch (schema.contentType) {
      case MessageContentType.receipt:
        schema.receiveAt = data['readAt'];
        schema.content = data['targetID'];
        break;
      case MessageContentType.read:
        schema.content = data['readIds'];
        break;
      case MessageContentType.msgStatus:
      case MessageContentType.contact:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceInfo:
      case MessageContentType.deviceRequest:
        schema.content = data;
        break;
      // case MessageContentType.ping:
      // case MessageContentType.text:
      // case MessageContentType.textExtension:
      // case MessageContentType.media:
      // case MessageContentType.image:
      // case MessageContentType.audio:
      // case MessageContentType.piece:
      // case MessageContentType.topicSubscribe:
      // case MessageContentType.topicUnsubscribe:
      // case MessageContentType.topicInvitation:
      // case MessageContentType.topicKickOut:
      default:
        schema.content = data['content'];
        break;
    }

    if (schema.options == null) {
      schema.options = Map();
    }

    // piece
    if (data['parentType'] != null || data['total'] != null) {
      if (schema.options![MessageOptions.KEY_PIECE] == null) {
        schema.options![MessageOptions.KEY_PIECE] = Map();
      }
      schema.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARENT_TYPE] = data['parentType'];
      schema.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_BYTES_LENGTH] = data['bytesLength'];
      schema.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL] = data['total'];
      schema.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARITY] = data['parity'];
      schema.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] = data['index'];
    }

    // sendAt
    if (data['timestamp'] != null && data['timestamp'] is int) {
      schema = MessageOptions.setSendAt(schema, data['timestamp']);
    }

    return schema;
  }

  static MessageSchema? fromPiecesReceive(List<MessageSchema> sortPieces, String base64String) {
    List<MessageSchema> finds = sortPieces.where((element) => element.pid != null).toList();
    if (finds.isEmpty) return null;
    MessageSchema piece = finds[0];

    MessageSchema schema = MessageSchema(
      pid: piece.pid,
      msgId: piece.msgId,
      from: piece.from,
      to: piece.to,
      topic: piece.topic,
      // status
      status: MessageStatus.Received,
      isOutbound: false,
      isDelete: false,
      // at
      sendAt: DateTime.now().millisecondsSinceEpoch, // piece.sendAt, (used by receive_at, for sort)
      receiveAt: null, // set in ack(isTopic) / read(contact)
      deleteAt: null, // set in messages bubble
      // data
      contentType: piece.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARENT_TYPE] ?? "",
      content: base64String,
      // options: piece.options,
    );

    piece.options?.remove(MessageOptions.KEY_PIECE);
    schema.options = piece.options;

    if (schema.options == null) {
      schema.options = Map();
    }

    // diff with no pieces image
    schema.options?[MessageOptions.KEY_FROM_PIECE] = true;

    return schema;
  }

  /// to send
  MessageSchema.fromSend({
    // this.pid, // SDK create
    required this.msgId,
    required this.from,
    this.to,
    this.topic,
    // status
    this.status = MessageStatus.Sending,
    this.isOutbound = true,
    this.isDelete = false,
    // at
    // this.sendAt,
    // this.receiveAt, // null
    // this.deleteAt, // set in messages bubble
    // data
    required this.contentType,
    this.content,
    this.options,
    // piece
    String? parentType,
    int? bytesLength,
    int? total,
    int? parity,
    int? index,
    // other
    double? audioDurationS,
    int? deleteAfterSeconds,
    int? burningUpdateAt,
  }) {
    // at
    this.sendAt = DateTime.now().millisecondsSinceEpoch;
    this.receiveAt = null; // set in receive ACK
    this.deleteAt = null; // set in messages bubble

    // piece
    if (parentType != null || total != null) {
      if (this.options == null) {
        this.options = Map();
      }
      if (this.options![MessageOptions.KEY_PIECE] == null) {
        this.options![MessageOptions.KEY_PIECE] = Map();
      }
      this.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARENT_TYPE] = parentType;
      this.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_BYTES_LENGTH] = bytesLength;
      this.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL] = total;
      this.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARITY] = parity;
      this.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] = index;
    }

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
      // status
      'status': status,
      'is_outbound': isOutbound ? 1 : 0,
      'is_delete': isDelete ? 1 : 0,
      // at
      'send_at': sendAt,
      'receive_at': receiveAt,
      'delete_at': deleteAt,
      // data
      'type': contentType,
      // content:,
      'options': options != null ? jsonEncode(options) : null,
    };

    // content = String
    switch (contentType) {
      case MessageContentType.contact:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
        map['content'] = content is Map ? jsonEncode(content) : content;
        break;
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        if (content is File) {
          map['content'] = Path.getLocalFile((content as File).path);
        }
        break;
      // case MessageContentType.ping:
      // case MessageContentType.receipt:
      // case MessageContentType.read:
      // case MessageContentType.msgStatus:
      // case MessageContentType.text:
      // case MessageContentType.textExtension:
      // case MessageContentType.topicSubscribe:
      // case MessageContentType.topicUnsubscribe:
      // case MessageContentType.topicInvitation:
      // case MessageContentType.topicKickOut:
      default:
        map['content'] = content;
        break;
    }
    return map;
  }

  /// from sqlite
  static MessageSchema fromMap(Map<String, dynamic> e) {
    MessageSchema schema = MessageSchema(
      pid: e['pid'] != null ? hexDecode(e['pid']) : null,
      msgId: e['msg_id'] ?? "",
      from: e['sender'] ?? "",
      to: e['receiver'],
      topic: e['topic'],
      // status
      status: e['status'] ?? 0,
      isOutbound: (e['is_outbound'] != null && e['is_outbound'] == 1) ? true : false,
      isDelete: (e['is_delete'] != null && e['is_delete'] == 1) ? true : false,
      // at
      sendAt: e['send_at'] != null ? e['send_at'] : null,
      receiveAt: e['receive_at'] != null ? e['receive_at'] : null,
      deleteAt: e['delete_at'] != null ? e['delete_at'] : null,
      // data
      contentType: e['type'] ?? "",
      options: (e['options']?.toString().isNotEmpty == true) ? jsonFormat(e['options']) : null,
    );

    // content = File/Map/String...
    switch (schema.contentType) {
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
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        String? completePath = Path.getCompleteFile(e['content']);
        schema.content = (completePath?.isNotEmpty == true) ? File(completePath!) : null;
        break;
      // case MessageContentType.ping:
      // case MessageContentType.receipt:
      // case MessageContentType.read:
      // case MessageContentType.msgStatus:
      // case MessageContentType.text:
      // case MessageContentType.textExtension:
      // case MessageContentType.topicSubscribe:
      // case MessageContentType.topicUnsubscribe:
      // case MessageContentType.topicInvitation:
      // case MessageContentType.topicKickOut:
      default:
        schema.content = e['content'];
        break;
    }
    return schema;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, status: $status, isOutbound: $isOutbound, isDelete: $isDelete, sendAt: $sendAt, receiveAt: $receiveAt, deleteAt: $deleteAt, contentType: $contentType, options: $options, content: $content}';
  }
}

class MessageOptions {
  static const KEY_AUDIO_DURATION = "audioDuration";

  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";
  static const KEY_UPDATE_BURNING_AFTER_AT = "updateBurnAfterAt";
  static const KEY_DEVICE_TOKEN = "deviceToken";

  static const KEY_SEND_AT = "send_at";

  static const KEY_FROM_PIECE = "from_piece";

  static const KEY_PIECE = 'piece';
  static const KEY_PIECE_PARENT_TYPE = "parentType";
  static const KEY_PIECE_BYTES_LENGTH = "bytesLength";
  static const KEY_PIECE_PARITY = "parity";
  static const KEY_PIECE_TOTAL = "total";
  static const KEY_PIECE_INDEX = "index";

  static MessageSchema setAudioDuration(MessageSchema message, double? durationS) {
    if (message.options == null) message.options = Map<String, dynamic>();
    message.options![MessageOptions.KEY_AUDIO_DURATION] = durationS;
    return message;
  }

  static double? getAudioDuration(MessageSchema? message) {
    if (message == null || message.options == null || message.options!.keys.length == 0) return null;
    var duration = message.options![MessageOptions.KEY_AUDIO_DURATION]?.toString();
    if (duration == null || duration.isEmpty) return null;
    return double.tryParse(duration) ?? 0;
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
    return message.options![MessageOptions.KEY_DEVICE_TOKEN]?.toString();
  }

  static MessageSchema setSendAt(MessageSchema message, int sendAt) {
    if (message.options == null) message.options = Map<String, dynamic>();
    message.options![MessageOptions.KEY_SEND_AT] = sendAt;
    return message;
  }

  static int? getSendAt(MessageSchema? message) {
    if (message == null || message.options == null || message.options!.keys.length == 0) return null;
    return message.options![MessageOptions.KEY_SEND_AT];
  }
}

class MessageData {
  static String getPing(bool isPing) {
    Map map = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.ping,
      'content': isPing ? "ping" : "pong",
    };
    return jsonEncode(map);
  }

  static String getReceipt(String targetId, int? readAt) {
    Map map = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.receipt,
      'targetID': targetId,
      'readAt': readAt,
    };
    return jsonEncode(map);
  }

  static String getRead(List<String> msgIdList) {
    Map map = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.read,
      'readIds': msgIdList,
    };
    return jsonEncode(map);
  }

  static String getMsgStatus(bool ask, List<String>? msgIdList) {
    Map map = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.msgStatus,
      'requestType': ask ? "ask" : "reply",
      'messageIds': msgIdList,
    };
    return jsonEncode(map);
  }

  static String getContactRequest(String requestType, String? profileVersion, int expiresAt) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.contact,
      'responseType': RequestType.header,
      'version': profileVersion,
      'expiresAt': expiresAt,
      // SUPPORT:START
      'onePieceReady': '1',
      // SUPPORT:END
    };
    return jsonEncode(data);
  }

  static Future<String> getContactResponseFull(String? firstName, String? lastName, File? avatar, String? profileVersion, int expiresAt) async {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.contact,
      'responseType': RequestType.full,
      'version': profileVersion,
      'expiresAt': expiresAt,
      // SUPPORT:START
      'onePieceReady': '1',
      // SUPPORT:END
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.contactOptions,
      'optionType': '0',
      'content': {
        'deleteAfterSeconds': burnAfterSeconds,
        'updateBurnAfterAt': updateBurnAfterAt,
        // SUPPORT:START
        'updateBurnAfterTime': updateBurnAfterAt,
        // SUPPORT:END
      },
    };
    return jsonEncode(data);
  }

  static String getContactOptionsToken(MessageSchema message) {
    String? deviceToken = MessageOptions.getDeviceToken(message);
    Map data = {
      'id': message.msgId,
      'timestamp': message.sendAt ?? DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.contactOptions,
      'optionType': '1',
      'content': {
        'deviceToken': deviceToken,
      },
    };
    return jsonEncode(data);
  }

  static String getDeviceRequest() {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.deviceRequest,
    };
    return jsonEncode(data);
  }

  static String getDeviceInfo() {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': message.contentType,
      'content': message.content,
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': message.contentType,
      'content': content,
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': message.contentType,
      'content': content,
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': message.contentType,
      'content': message.content,
      'parentType': message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARENT_TYPE] ?? message.contentType,
      'bytesLength': message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_BYTES_LENGTH],
      'total': message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL],
      'parity': message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARITY],
      'index': message.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX],
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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'topic': message.topic,
      'contentType': MessageContentType.topicSubscribe,
    };
    return jsonEncode(data);
  }

  static String getTopicUnSubscribe(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'topic': message.topic,
      'contentType': MessageContentType.topicUnsubscribe,
    };
    return jsonEncode(data);
  }

  static String getTopicInvitee(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'timestamp': message.sendAt ?? DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.topicInvitation,
      'content': message.content,
    };
    return jsonEncode(data);
  }

  static String getTopicKickOut(MessageSchema message) {
    Map data = {
      'id': message.msgId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'topic': message.topic,
      'contentType': MessageContentType.topicKickOut,
      'content': message.content,
    };
    return jsonEncode(data);
  }
}
