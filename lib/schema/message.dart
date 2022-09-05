import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';
import 'package:uuid/uuid.dart';

// TODO:GG PG check
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

  static const String contactProfile = 'contact'; // . TODO:GG rename to 'contact:profile'
  static const String contactOptions = 'event:contactOptions'; // db + visible TODO:GG rename to 'contact:options'

  static const String deviceRequest = 'device:request'; // .
  static const String deviceResponse = 'device:info'; // db

  static const String text = 'text'; // db + visible
  static const String textExtension = 'textExtension'; // db + visible TODO:GG maybe can remove
  static const String ipfs = 'ipfs'; // db + visible
  static const String media = 'media'; // db + visible // TODO:GG adapter d-chat，maybe can remove
  static const String image = 'nknImage'; // db + visible // TODO:GG rename to 'image'
  static const String audio = 'audio'; // db + visible
  static const String video = 'video'; // just bubble visible
  static const String file = 'file'; // just bubble visible
  static const String piece = 'nknOnePiece'; // db(delete) // TODO:GG rename to 'piece'

  static const String topicSubscribe = 'event:subscribe'; // db + visible
  static const String topicUnsubscribe = 'event:unsubscribe'; // .
  static const String topicInvitation = 'event:channelInvitation'; // db + visible
  static const String topicKickOut = 'event:channelKickOut'; // .

  static const String privateGroupInvitation = 'event:privateGroupInvitation';
  static const String privateGroupAccept = 'event:privateGroupAccept';
  static const String privateGroupOptionSync = 'event:privateGroupOptionSync';
  static const String privateGroupMemberRequest = 'event:privateGroupMemberRequest';
  static const String privateGroupMemberSync = 'event:privateGroupMemberSync';
  static const String privateGroupOptionRequest = 'event:privateGroupOptionRequest';
  static const String privateGroupMemberKeyRequest = 'event:privateGroupMemberKeyRequest';
  static const String privateGroupMemberKeyResponse = 'event:privateGroupMemberKeyResponse';
}

class MessageSchema {
  // piece
  static const int piecesPreMinLen = 10 * 1000; // >= 10K
  static const int piecesPreMaxLen = 16 * 1000; // <= 16K < 32K
  static const int piecesMinParity = 1; // >= 1
  static const int piecesMinTotal = 3 - piecesMinParity; // >= 2 ((2*10)K < 32K)
  static const int piecesMaxParity = 2; // <= 2
  static const int piecesMaxTotal = 12 - piecesMaxParity; // <= 10
  static const int piecesMaxSize = piecesMaxTotal * piecesPreMaxLen; // <= 160K

  // size
  static const int msgMaxSize = 32 * 1000; // < 32K
  static const int nknMaxSize = 4 * 1000 * 1000; // < 4,000,000
  static const int ipfsMaxSize = 100 * 1000 * 1000; // 100M
  static const int avatarMaxSize = 25 * 1000; // 25K < 32K
  static const int avatarBestSize = avatarMaxSize ~/ 2; // 12K

  Uint8List? pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String from; // (required) <-> sender / -> target_id(session_id)
  String to; // <-> receiver / -> target_id(session_id)
  String topic; // <-> topic / -> target_id(session_id)
  String groupId; // TODO:GG PG ???

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
    this.to = "",
    this.topic = "",
    this.groupId = "",
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

  String get targetId {
    if (contentType == MessageContentType.privateGroupInvitation || contentType == MessageContentType.privateGroupAccept) {
      return isOutbound ? to : from;
    }
    return isTopic
        ? topic
        : isPrivateGroup
            ? groupId
            : isOutbound
                ? to
                : from;
  }

  bool get isTopic {
    return topic.isNotEmpty == true;
  }

  bool get isPrivateGroup {
    return groupId.isNotEmpty == true;
  }

  // burning
  bool get canBurning {
    bool isText = contentType == MessageContentType.text || contentType == MessageContentType.textExtension;
    bool isIpfs = contentType == MessageContentType.ipfs;
    bool isImage = contentType == MessageContentType.media || contentType == MessageContentType.image;
    bool isAudio = contentType == MessageContentType.audio;
    return isText || isIpfs || isImage || isAudio;
  }

  // ++ resend
  bool get canResend {
    return canBurning;
  }

  // ++ receipt
  bool get canReceipt {
    bool isEvent = contentType == MessageContentType.topicInvitation || contentType == MessageContentType.privateGroupInvitation;
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

  bool get isContentFile {
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

  MessageSchema copy() {
    MessageSchema copy = MessageSchema(
      pid: pid,
      msgId: msgId,
      from: from,
      to: to,
      topic: topic,
      groupId: groupId,
      status: status,
      isOutbound: isOutbound,
      isDelete: isDelete,
      sendAt: sendAt,
      receiveAt: receiveAt,
      deleteAt: deleteAt,
      contentType: contentType,
      content: content,
      options: options,
    );
    return copy;
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null || raw.data == null || raw.src == null) return null;
    Map<String, dynamic>? data = Util.jsonFormat(raw.data);
    if (data == null || data['id'] == null || data['contentType'] == null) return null;

    MessageSchema schema = MessageSchema(
      pid: raw.messageId,
      msgId: data['id'] ?? "",
      from: raw.src ?? "",
      to: clientCommon.address ?? "",
      topic: data['topic'] ?? "",
      groupId: data['groupId'] ?? "",
      // status
      status: MessageStatus.Received,
      isOutbound: false,
      isDelete: false,
      // at
      sendAt: data['send_timestamp'] ?? data['sendTimestamp'] ?? data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
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
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceResponse:
        schema.content = data;
        break;
      case MessageContentType.ipfs:
        schema.content = null;
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
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupOptionSync:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberSync:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupMemberKeyRequest:
      case MessageContentType.privateGroupMemberKeyResponse:
        schema.content = Map<String, dynamic>();
        if (data['groupId'] != null) schema.content['groupId'] = data['groupId'];
        if (data['groupName'] != null) schema.content['groupName'] = data['groupName'];
        if (data['version'] != null) schema.content['version'] = data['version'];
        schema.content['data'] = data['data'];
        if (data['signature'] != null) schema.content['signature'] = data['signature'];
        break;
      default:
        schema.content = data['content'];
        break;
    }

    // options
    if (schema.options == null) {
      schema.options = Map();
    }

    // getAt
    schema.options = MessageOptions.setInAt(schema.options, DateTime.now().millisecondsSinceEpoch);

    // SUPPORT:START
    // piece
    if (data['parentType'] != null || data['total'] != null) {
      schema.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] = data['parentType'];
      schema.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH] = data['bytesLength'];
      schema.options?[MessageOptions.KEY_PIECE_TOTAL] = data['total'];
      schema.options?[MessageOptions.KEY_PIECE_PARITY] = data['parity'];
      schema.options?[MessageOptions.KEY_PIECE_INDEX] = data['index'];
    }
    schema.options?.remove("piece");
    // SUPPORT:END
    return schema;
  }

  /// to send
  MessageSchema.fromSend({
    // this.pid, // SDK create
    required this.msgId,
    required this.from,
    this.to = "",
    this.topic = "",
    this.groupId = "",
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
    Map<String, dynamic>? extra,
  }) {
    // at
    this.sendAt = DateTime.now().millisecondsSinceEpoch;
    this.receiveAt = null; // set in receive ACK
    this.deleteAt = null; // set in messages bubble

    if (this.options == null) this.options = Map();

    // settings
    String? deviceToken = extra?["deviceToken"];
    if (deviceToken != null && deviceToken.isNotEmpty) {
      this.options = MessageOptions.setDeviceToken(this.options, deviceToken);
    }
    String? profileVersion = extra?["profileVersion"];
    if (profileVersion != null && profileVersion.isNotEmpty) {
      this.options = MessageOptions.setProfileVersion(this.options, profileVersion);
    }
    String? deviceProfile = extra?["deviceProfile"];
    if (deviceProfile != null && deviceProfile.isNotEmpty) {
      this.options = MessageOptions.setDeviceProfile(this.options, deviceProfile);
    }
    // burn
    int? deleteAfterSeconds = extra?["deleteAfterSeconds"];
    if (deleteAfterSeconds != null && deleteAfterSeconds > 0) {
      this.options = MessageOptions.setContactBurningDeleteSec(this.options, deleteAfterSeconds);
    }
    int? burningUpdateAt = extra?["burningUpdateAt"];
    if (burningUpdateAt != null && burningUpdateAt > 0) {
      this.options = MessageOptions.setContactBurningUpdateAt(this.options, burningUpdateAt);
    }
    // file
    int? size = int.tryParse(extra?["size"]?.toString() ?? "");
    if (size != null && size != 0) {
      this.options = MessageOptions.setFileSize(this.options, size);
    }
    String? fileName = extra?["name"];
    if (fileName != null && fileName.isNotEmpty) {
      this.options = MessageOptions.setFileName(this.options, fileName);
    }
    String? fileExt = extra?["fileExt"];
    if (fileExt != null && fileExt.isNotEmpty) {
      this.options = MessageOptions.setFileExt(this.options, fileExt);
    }
    String? fileMimeType = extra?["mimeType"];
    if (fileMimeType != null && fileMimeType.isNotEmpty) {
      this.options = MessageOptions.setFileMimeType(this.options, fileMimeType);
    }
    int? fileType = int.tryParse(extra?["fileType"]?.toString() ?? "");
    if (fileType != null && fileType >= 0) {
      this.options = MessageOptions.setFileType(this.options, fileType);
    } else if (((size ?? 0) > 0) || (fileMimeType?.isNotEmpty == true) || (fileExt?.isNotEmpty == true)) {
      if ((fileMimeType?.contains("image") == true)) {
        this.options = MessageOptions.setFileType(this.options, MessageOptions.fileTypeImage);
      } else if ((fileMimeType?.contains("audio") == true)) {
        this.options = MessageOptions.setFileType(this.options, MessageOptions.fileTypeAudio);
      } else if ((fileMimeType?.contains("video") == true)) {
        this.options = MessageOptions.setFileType(this.options, MessageOptions.fileTypeVideo);
      } else {
        // file_picker is here, because no mime_type
        this.options = MessageOptions.setFileType(this.options, MessageOptions.fileTypeNormal);
      }
    }
    int? mediaWidth = int.tryParse(extra?["width"]?.toString() ?? "");
    int? mediaHeight = int.tryParse(extra?["height"]?.toString() ?? "");
    if (mediaWidth != null && mediaWidth != 0 && mediaHeight != null && mediaHeight != 0) {
      this.options = MessageOptions.setMediaSizeWH(this.options, mediaWidth, mediaHeight);
    }
    double? duration = double.tryParse(extra?["duration"]?.toString() ?? "");
    if (duration != null && duration >= 0) {
      this.options = MessageOptions.setMediaDuration(this.options, duration);
    }
    String? thumbnailPath = extra?["thumbnailPath"];
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      this.options = MessageOptions.setMediaThumbnailPath(this.options, thumbnailPath);
    }
    // piece
    String? parentType = extra?["piece_parent_type"];
    int? bytesLength = extra?["piece_bytes_length"];
    int? total = extra?["piece_total"];
    int? parity = extra?["piece_parity"];
    int? index = extra?["piece_index"];
    if (parentType != null || total != null) {
      this.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] = parentType;
      this.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH] = bytesLength;
      this.options?[MessageOptions.KEY_PIECE_TOTAL] = total;
      this.options?[MessageOptions.KEY_PIECE_PARITY] = parity;
      this.options?[MessageOptions.KEY_PIECE_INDEX] = index;
    }
    // SUPPORT:START
    double? audioDurationS = extra?["audioDurationS"];
    if (audioDurationS != null && audioDurationS >= 0) {
      this.options = MessageOptions.setMediaDuration(this.options, audioDurationS);
      this.options = MessageOptions.setAudioDuration(this.options, audioDurationS);
    }
    // SUPPORT:END
  }

  /// to sqlite
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'pid': pid != null ? hexEncode(pid!) : null,
      'msg_id': msgId,
      'sender': from,
      'receiver': to,
      'topic': topic,
      'group_id': groupId,
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
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceResponse:
        map['content'] = content is Map ? jsonEncode(content) : content;
        break;
      case MessageContentType.ipfs: // maybe null
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        if ((content != null) && (content is File)) {
          map['content'] = Path.convert2Local((content as File).path);
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
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupOptionSync:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberSync:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupMemberKeyRequest:
      case MessageContentType.privateGroupMemberKeyResponse:
        map['content'] = content is Map ? jsonEncode(content) : content;
        break;
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
      to: e['receiver'] ?? "",
      topic: e['topic'] ?? "",
      groupId: e['group_id'],
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
      options: (e['options']?.toString().isNotEmpty == true) ? Util.jsonFormat(e['options']) : null,
    );

    // content = File/Map/String...
    switch (schema.contentType) {
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceResponse:
        if ((e['content']?.toString().isNotEmpty == true) && (e['content'] is String)) {
          schema.content = Util.jsonFormat(e['content']);
        } else {
          schema.content = e['content'];
        }
        break;
      case MessageContentType.ipfs: // maybe null
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        String? completePath = Path.convert2Complete(e['content']);
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
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupOptionSync:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberSync:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupMemberKeyRequest:
      case MessageContentType.privateGroupMemberKeyResponse:
        if ((e['content']?.toString().isNotEmpty == true) && (e['content'] is String)) {
          schema.content = Util.jsonFormat(e['content']);
        } else {
          schema.content = e['content'];
        }
        break;
      default:
        schema.content = e['content'];
        break;
    }
    return schema;
  }

  static Future<Map<String, dynamic>> piecesSplits(MessageSchema msg) async {
    if (!(msg.content is File?)) return {};
    File? file = msg.content as File?;
    if (file == null || !file.existsSync()) return {};
    int length = await file.length();
    if (length <= piecesPreMinLen) return {};
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    int bytesLength = base64Data.length;
    // total (2~192)
    int total;
    if (bytesLength < piecesPreMinLen * piecesMinTotal) {
      return {};
    } else if (bytesLength <= piecesPreMinLen * piecesMaxTotal) {
      total = bytesLength ~/ piecesPreMinLen;
      if (bytesLength % piecesPreMinLen > 0) {
        total += 1;
      }
    } else {
      total = piecesMaxTotal;
    }
    // parity(1~63)
    int parity = (total * (piecesMaxParity / (piecesMaxTotal + piecesMaxParity))).toInt();
    if (total % (piecesMaxParity / (piecesMaxTotal + piecesMaxParity)) > 0) {
      parity += 1;
    }
    if (parity > piecesMaxParity) {
      parity = piecesMaxParity;
    } else if (parity >= total) {
      parity = total - 1;
    } else if (parity < 1) {
      parity = 1;
    }

    // (total + parity) < 256
    return {
      "data": base64Data,
      "length": bytesLength,
      "total": total,
      "parity": parity,
    };
  }

  static Future<String?> combinePiecesData(List<MessageSchema> pieces, int total, int parity, int bytesLength) async {
    List<Uint8List> recoverList = <Uint8List>[];
    for (int i = 0; i < (total + parity); i++) {
      recoverList.add(Uint8List(0)); // fill
    }
    int recoverCount = 0;
    for (int i = 0; i < pieces.length; i++) {
      MessageSchema item = pieces[i];
      File? file = item.content as File?;
      if (file == null || !file.existsSync()) {
        logger.e("Message - combinePiecesData - combine sub_file no exists - item:$item - file:${file?.path}");
        continue;
      }
      Uint8List itemBytes = file.readAsBytesSync();
      int? pieceIndex = item.options?[MessageOptions.KEY_PIECE_INDEX];
      if (itemBytes.isNotEmpty && (pieceIndex != null) && (pieceIndex >= 0) && (pieceIndex < recoverList.length)) {
        recoverList[pieceIndex] = itemBytes;
        recoverCount++;
      }
    }
    if (recoverCount < total) {
      logger.e("Message - combinePiecesData - combine fail - recover_lost:${pieces.length - recoverCount}");
      return null;
    }
    return Common.combinePieces(recoverList, total, parity, bytesLength);
  }

  static MessageSchema? combinePiecesMsg(List<MessageSchema> sortPieces, String base64String) {
    List<MessageSchema> finds = sortPieces.where((element) {
      bool pid = element.pid != null;
      bool contentType = (element.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]?.toString() ?? "").isNotEmpty;
      return pid && contentType;
    }).toList();
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
      sendAt: piece.sendAt,
      receiveAt: null, // set in ack(isTopic) / read(contact)
      deleteAt: null, // set in messages bubble
      // data
      contentType: piece.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] ?? "",
      content: base64String,
      // options: piece.options,
    );

    // options
    schema.options = piece.options;
    if (schema.options == null) {
      schema.options = Map();
    }

    // getAt
    schema.options = MessageOptions.setInAt(schema.options, DateTime.now().millisecondsSinceEpoch);

    // diff with no pieces image
    schema.options?[MessageOptions.KEY_FROM_PIECE] = true;

    // pieces
    schema.options?.remove(MessageOptions.KEY_PIECE_PARENT_TYPE);
    schema.options?.remove(MessageOptions.KEY_PIECE_BYTES_LENGTH);
    schema.options?.remove(MessageOptions.KEY_PIECE_TOTAL);
    schema.options?.remove(MessageOptions.KEY_PIECE_PARITY);
    schema.options?.remove(MessageOptions.KEY_PIECE_INDEX);
    schema.options?.remove("piece");
    return schema;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, from: $from, to: $to, topic: $topic, groupId: $groupId, status: $status, isOutbound: $isOutbound, isDelete: $isDelete, sendAt: $sendAt, receiveAt: $receiveAt, deleteAt: $deleteAt, contentType: $contentType, options: $options, content: $content}';
  }
}

class MessageOptions {
  static const KEY_OUT_AT = "out_at"; // TODO:GG rename to 'outAt'
  static const KEY_IN_AT = "in_at"; // TODO:GG rename to 'inAt'
  static const KEY_RESEND_MUTE_AT = "resendMuteAt";

  static const KEY_DEVICE_TOKEN = "deviceToken";
  static const KEY_PROFILE_VERSION = "profileVersion";
  static const KEY_DEVICE_PROFILE = "deviceProfile";

  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";
  static const KEY_UPDATE_BURNING_AFTER_AT = "updateBurnAfterAt";

  static const KEY_PUSH_NOTIFY_ID = "pushNotifyId";

  static const KEY_FILE_TYPE = "fileType";
  static const fileTypeNormal = 0;
  static const fileTypeImage = 1;
  static const fileTypeAudio = 2;
  static const fileTypeVideo = 3;

  static const KEY_FILE_NAME = "fileName";
  static const KEY_FILE_SIZE = "fileSize";
  static const KEY_FILE_EXT = "fileExt";
  static const KEY_FILE_MIME_TYPE = "fileMimeType";
  static const KEY_MEDIA_WIDTH = "mediaWidth";
  static const KEY_MEDIA_HEIGHT = "mediaHeight";
  static const KEY_MEDIA_DURATION = "mediaDuration";
  static const KEY_MEDIA_THUMBNAIL = "mediaThumbnail";
  static const KEY_AUDIO_DURATION = "audioDuration"; // TODO:GG replace by 'mediaDuration'

  static const KEY_IPFS_STATE = "ipfsState";
  static const ipfsStateNo = 0;
  static const ipfsStateIng = 1;
  static const ipfsStateYes = 2;

  static const KEY_IPFS_THUMBNAIL_STATE = "ipfsThumbnailState";
  static const ipfsThumbnailStateNo = 0;
  static const ipfsThumbnailStateIng = 1;
  static const ipfsThumbnailStateYes = 2;

  static const KEY_IPFS_IP = "ipfsIp";
  static const KEY_IPFS_HASH = "ipfsHash";
  static const KEY_IPFS_ENCRYPT = "ipfsEncrypt";
  static const KEY_IPFS_ENCRYPT_ALGORITHM = "ipfsEncryptAlgorithm";
  static const KEY_IPFS_ENCRYPT_KEY_BYTES = "ipfsEncryptKeyBytes";
  static const KEY_IPFS_ENCRYPT_NONCE_SIZE = "ipfsEncryptNonceSize";
  static const KEY_IPFS_THUMBNAIL_IP = "ipfsThumbnailIp";
  static const KEY_IPFS_THUMBNAIL_HASH = "ipfsThumbnailHash";
  static const KEY_IPFS_THUMBNAIL_ENCRYPT = "ipfsThumbnailEncrypt";
  static const KEY_IPFS_THUMBNAIL_ENCRYPT_ALGORITHM = "ipfsThumbnailEncryptAlgorithm";
  static const KEY_IPFS_THUMBNAIL_ENCRYPT_KEY_BYTES = "ipfsThumbnailEncryptKeyBytes";
  static const KEY_IPFS_THUMBNAIL_ENCRYPT_NONCE_SIZE = "ipfsThumbnailEncryptNonceSize";

  static const KEY_FROM_PIECE = "from_piece"; // TODO:GG rename to 'fromPiece'

  static const KEY_PIECE_PARENT_TYPE = "piece_parent_type"; // TODO:GG rename to 'pieceParentType'
  static const KEY_PIECE_BYTES_LENGTH = "piece_bytes_length"; // TODO:GG rename to 'pieceBytesLength'
  static const KEY_PIECE_PARITY = "piece_parity"; // TODO:GG rename to 'pieceParity'
  static const KEY_PIECE_TOTAL = "piece_total"; // TODO:GG rename to 'pieceTotal'
  static const KEY_PIECE_INDEX = "piece_index"; // TODO:GG rename to 'pieceIndex'

  static const KEY_VERSION = "version"; // TODO:GG PG 直接version???

  static Map<String, dynamic>? setOutAt(Map<String, dynamic>? options, int sendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_OUT_AT] = sendAt;
    return options;
  }

  static int? getOutAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_OUT_AT]?.toString() ?? "");
  }

  static Map<String, dynamic>? setInAt(Map<String, dynamic>? options, int sendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_IN_AT] = sendAt;
    return options;
  }

  static int? getInAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_IN_AT]?.toString() ?? "");
  }

  static Map<String, dynamic>? setResendMuteAt(Map<String, dynamic>? options, int resendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_RESEND_MUTE_AT] = resendAt;
    return options;
  }

  static int? getResendMuteAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_RESEND_MUTE_AT]?.toString() ?? "");
  }

  static Map<String, dynamic>? setDeviceToken(Map<String, dynamic>? options, String deviceToken) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DEVICE_TOKEN] = deviceToken;
    return options;
  }

  static String? getDeviceToken(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_DEVICE_TOKEN]?.toString();
  }

  static Map<String, dynamic>? setProfileVersion(Map<String, dynamic>? options, String profileVersion) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_PROFILE_VERSION] = profileVersion;
    return options;
  }

  static String? getProfileVersion(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_PROFILE_VERSION]?.toString();
  }

  static Map<String, dynamic>? setDeviceProfile(Map<String, dynamic>? options, String deviceProfile) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DEVICE_PROFILE] = deviceProfile;
    return options;
  }

  static String? getDeviceProfile(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_DEVICE_PROFILE]?.toString();
  }

  static Map<String, dynamic>? setContactBurningDeleteSec(Map<String, dynamic>? options, int deleteTimeSec) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DELETE_AFTER_SECONDS] = deleteTimeSec;
    return options;
  }

  static int? getContactBurningDeleteSec(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var seconds = options[MessageOptions.KEY_DELETE_AFTER_SECONDS]?.toString();
    return int.tryParse(seconds ?? "");
  }

  static Map<String, dynamic>? setContactBurningUpdateAt(Map<String, dynamic>? options, int? updateAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_UPDATE_BURNING_AFTER_AT] = updateAt;
    return options;
  }

  static int? getContactBurningUpdateAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var update = options[MessageOptions.KEY_UPDATE_BURNING_AFTER_AT]?.toString();
    return int.tryParse(update ?? "");
  }

  static Map<String, dynamic>? setPushNotifyId(Map<String, dynamic>? options, String uuid) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_PUSH_NOTIFY_ID] = uuid;
    return options;
  }

  static String? getPushNotifyId(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_PUSH_NOTIFY_ID]?.toString();
  }

  static Map<String, dynamic> setFileType(Map<String, dynamic>? options, int type) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FILE_TYPE] = type;
    return options;
  }

  static int? getFileType(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var type = options[MessageOptions.KEY_FILE_TYPE]?.toString();
    if (type == null || type.isEmpty) return null;
    return int.tryParse(type);
  }

  static Map<String, dynamic> setFileName(Map<String, dynamic>? options, String? ext) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FILE_NAME] = ext;
    return options;
  }

  static String? getFileName(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_FILE_NAME]?.toString();
  }

  static Map<String, dynamic> setFileSize(Map<String, dynamic>? options, int? size) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FILE_SIZE] = size;
    return options;
  }

  static int? getFileSize(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var size = options[MessageOptions.KEY_FILE_SIZE]?.toString();
    if (size == null || size.isEmpty) return null;
    return int.tryParse(size);
  }

  static Map<String, dynamic> setFileExt(Map<String, dynamic>? options, String? ext) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FILE_EXT] = ext;
    return options;
  }

  static String? getFileExt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_FILE_EXT]?.toString();
  }

  static Map<String, dynamic> setFileMimeType(Map<String, dynamic>? options, String? mimeType) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FILE_MIME_TYPE] = mimeType;
    return options;
  }

  static String? getFileMimeType(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_FILE_MIME_TYPE]?.toString();
  }

  static Map<String, dynamic> setMediaSizeWH(Map<String, dynamic>? options, int? width, int? height) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_MEDIA_WIDTH] = width;
    options[MessageOptions.KEY_MEDIA_HEIGHT] = height;
    return options;
  }

  static List<double> getMediaWH(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return [0, 0];
    var width = options[MessageOptions.KEY_MEDIA_WIDTH]?.toString();
    var height = options[MessageOptions.KEY_MEDIA_HEIGHT]?.toString();
    if (width == null || width.isEmpty || height == null || height.isEmpty) return [0, 0];
    return [double.tryParse(width) ?? 0, double.tryParse(height) ?? 0];
  }

  static Map<String, dynamic> setMediaDuration(Map<String, dynamic>? options, double? durationS) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_MEDIA_DURATION] = durationS;
    return options;
  }

  static double? getMediaDuration(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var duration = options[MessageOptions.KEY_MEDIA_DURATION]?.toString();
    if (duration == null || duration.isEmpty) return null;
    return double.tryParse(duration);
  }

  static Map<String, dynamic> setMediaThumbnailPath(Map<String, dynamic>? options, String? thumbnailPath) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_MEDIA_THUMBNAIL] = Path.convert2Local(thumbnailPath);
    return options;
  }

  static String? getMediaThumbnailPath(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return Path.convert2Complete(options[MessageOptions.KEY_MEDIA_THUMBNAIL]?.toString());
  }

  static Map<String, dynamic> setIpfsState(Map<String, dynamic>? options, int state) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_IPFS_STATE] = state;
    return options;
  }

  static int getIpfsState(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return ipfsStateNo;
    var complete = options[MessageOptions.KEY_IPFS_STATE]?.toString();
    if (complete == null || complete.isEmpty) return ipfsStateNo;
    return int.tryParse(complete) ?? ipfsStateNo;
  }

  static Map<String, dynamic> setIpfsThumbnailState(Map<String, dynamic>? options, int state) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_IPFS_THUMBNAIL_STATE] = state;
    return options;
  }

  static int getIpfsThumbnailState(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return ipfsThumbnailStateNo;
    var complete = options[MessageOptions.KEY_IPFS_THUMBNAIL_STATE]?.toString();
    if (complete == null || complete.isEmpty) return ipfsThumbnailStateNo;
    return int.tryParse(complete) ?? ipfsThumbnailStateNo;
  }

  static Map<String, dynamic> setIpfsResult(
    Map<String, dynamic>? options,
    String? ip,
    String? hash,
    int? encrypt,
    String? encryptAlgorithm,
    List? encryptKey,
    int? encryptNonce,
  ) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_IPFS_IP] = ip;
    options[MessageOptions.KEY_IPFS_HASH] = hash;
    options[MessageOptions.KEY_IPFS_ENCRYPT] = encrypt;
    options[MessageOptions.KEY_IPFS_ENCRYPT_ALGORITHM] = encryptAlgorithm;
    options[MessageOptions.KEY_IPFS_ENCRYPT_KEY_BYTES] = encryptKey;
    options[MessageOptions.KEY_IPFS_ENCRYPT_NONCE_SIZE] = encryptNonce;
    return options;
  }

  static String? getIpfsIp(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_IP]?.toString();
  }

  static String? getIpfsHash(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_HASH]?.toString();
  }

  static bool getIpfsEncrypt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return false;
    var encrypt = options[MessageOptions.KEY_IPFS_ENCRYPT]?.toString();
    if (encrypt == null || encrypt.isEmpty) return false;
    return (int.tryParse(encrypt) ?? 0) > 0 ? true : false;
  }

  static String? getIpfsEncryptAlgorithm(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_ENCRYPT_ALGORITHM]?.toString();
  }

  static Uint8List? getIpfsEncryptKeyBytes(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    final bytes = options[MessageOptions.KEY_IPFS_ENCRYPT_KEY_BYTES];
    if (bytes == null || !(bytes is List)) return null;
    return Uint8List.fromList(List<int>.from(bytes));
  }

  static int? getIpfsEncryptNonceSize(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var nonceLen = options[MessageOptions.KEY_IPFS_ENCRYPT_NONCE_SIZE]?.toString();
    if (nonceLen == null || nonceLen.isEmpty) return null;
    return int.tryParse(nonceLen);
  }

  static Map<String, dynamic> setIpfsResultThumbnail(
    Map<String, dynamic>? options,
    String? ip,
    String? hash,
    int? encrypt,
    String? encryptAlgorithm,
    List? encryptKey,
    int? encryptNonce,
  ) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_IPFS_THUMBNAIL_IP] = ip;
    options[MessageOptions.KEY_IPFS_THUMBNAIL_HASH] = hash;
    options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT] = encrypt;
    options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_ALGORITHM] = encryptAlgorithm;
    options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_KEY_BYTES] = encryptKey;
    options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_NONCE_SIZE] = encryptNonce;
    return options;
  }

  static String? getIpfsThumbnailIp(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_THUMBNAIL_IP]?.toString();
  }

  static String? getIpfsThumbnailHash(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_THUMBNAIL_HASH]?.toString();
  }

  static bool getIpfsThumbnailEncrypt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return false;
    var encrypt = options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT]?.toString();
    if (encrypt == null || encrypt.isEmpty) return false;
    return (int.tryParse(encrypt) ?? 0) > 0 ? true : false;
  }

  static String? getIpfsThumbnailEncryptAlgorithm(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_ALGORITHM]?.toString();
  }

  static Uint8List? getIpfsThumbnailEncryptKeyBytes(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    final bytes = options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_KEY_BYTES];
    if (bytes == null || !(bytes is List)) return null;
    return Uint8List.fromList(List<int>.from(bytes));
  }

  static int? getIpfsThumbnailEncryptNonceSize(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var nonceLen = options[MessageOptions.KEY_IPFS_THUMBNAIL_ENCRYPT_NONCE_SIZE]?.toString();
    if (nonceLen == null || nonceLen.isEmpty) return null;
    return int.tryParse(nonceLen);
  }

// SUPPORT:START
  static Map<String, dynamic>? setAudioDuration(Map<String, dynamic>? options, double? durationS) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_AUDIO_DURATION] = durationS;
    return options;
  }

  static double? getAudioDuration(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var duration = options[MessageOptions.KEY_AUDIO_DURATION]?.toString();
    if (duration == null || duration.isEmpty) return null;
    return double.tryParse(duration);
  }
// SUPPORT:END
}

class MessageData {
  static Map _base(
    String contentType, {
    String? id,
    int? timestamp,
    int? sendTimestamp,
  }) {
    Map map = {
      'id': id ?? Uuid().v4(),
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'sendTimestamp': sendTimestamp ?? DateTime.now().millisecondsSinceEpoch,
      'send_timestamp': sendTimestamp ?? DateTime.now().millisecondsSinceEpoch, // TODO:GG replace by 'sendTimestamp'
      'contentType': contentType,
    };
    return map;
  }

  static Map<String, dynamic>? _simpleOptions(Map<String, dynamic>? options) {
    Map<String, dynamic> map = Map()..addAll(options ?? Map());
    map.remove(MessageOptions.KEY_RESEND_MUTE_AT);
    map.remove(MessageOptions.KEY_PUSH_NOTIFY_ID);
    map.remove(MessageOptions.KEY_IPFS_STATE);
    map.remove(MessageOptions.KEY_IPFS_THUMBNAIL_STATE);
    map.remove(MessageOptions.KEY_MEDIA_THUMBNAIL);
    return map;
  }

  static String getPing(bool isPing, String? profileVersion, String? deviceProfile) {
    Map data = _base(MessageContentType.ping);
    data.addAll({
      'content': isPing ? "ping" : "pong",
    });
    if (profileVersion != null && profileVersion.isNotEmpty) {
      if (data['options'] == null) data['options'] = Map();
      data['options']["profileVersion"] = profileVersion;
    }
    if (deviceProfile != null && deviceProfile.isNotEmpty) {
      if (data['options'] == null) data['options'] = Map();
      data['options']["deviceProfile"] = deviceProfile;
    }
    return jsonEncode(data);
  }

  static String getReceipt(String targetId, int? readAt) {
    Map data = _base(MessageContentType.receipt);
    data.addAll({
      'targetID': targetId,
      'readAt': readAt,
    });
    return jsonEncode(data);
  }

  static String getRead(List<String> msgIdList) {
    Map data = _base(MessageContentType.read);
    data.addAll({
      'readIds': msgIdList,
    });
    return jsonEncode(data);
  }

  static String getMsgStatus(bool ask, List<String>? msgIdList) {
    Map data = _base(MessageContentType.msgStatus);
    data.addAll({
      'requestType': ask ? "ask" : "reply",
      'messageIds': msgIdList,
    });
    return jsonEncode(data);
  }

  static String getContactProfileRequest(String requestType, String? profileVersion) {
    Map data = _base(MessageContentType.contactProfile);
    data.addAll({
      'requestType': requestType,
      'version': profileVersion,
      // 'expiresAt': expiresAt,
    });
    return jsonEncode(data);
  }

  static String getContactProfileResponseHeader(String? profileVersion) {
    Map data = _base(MessageContentType.contactProfile);
    data.addAll({
      'responseType': RequestType.header,
      'version': profileVersion,
    });
    return jsonEncode(data);
  }

  static Future<String> getContactProfileResponseFull(String? profileVersion, File? avatar, String? firstName, String? lastName) async {
    Map data = _base(MessageContentType.contactProfile);
    data.addAll({
      'responseType': RequestType.full,
      'version': profileVersion,
    });
    Map<String, dynamic> content = Map();
    if (avatar != null && await avatar.exists()) {
      String base64 = base64Encode(await avatar.readAsBytes());
      if (base64.isNotEmpty == true) {
        content['avatar'] = {'type': 'base64', 'data': base64, 'ext': Path.getFileExt(avatar, FileHelper.DEFAULT_IMAGE_EXT)};
      }
    }
    if (firstName?.isNotEmpty == true) {
      content['first_name'] = firstName; // TODO:GG rename to 'firstName'
      content['last_name'] = lastName; // TODO:GG rename to 'lastName'
      // SUPPORT:START
      content['name'] = firstName;
      // SUPPORT:END
    }
    data['content'] = content;
    return jsonEncode(data);
  }

  static String getContactOptionsBurn(MessageSchema message) {
    int? burnAfterSeconds = MessageOptions.getContactBurningDeleteSec(message.options);
    int? updateBurnAfterAt = MessageOptions.getContactBurningUpdateAt(message.options);
    Map data = _base(MessageContentType.contactOptions, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'optionType': '0',
      'content': {
        'deleteAfterSeconds': burnAfterSeconds,
        'updateBurnAfterAt': updateBurnAfterAt,
        // SUPPORT:START
        'updateBurnAfterTime': updateBurnAfterAt,
        // SUPPORT:END
      },
    });
    return jsonEncode(data);
  }

  static String getContactOptionsToken(MessageSchema message) {
    String? deviceToken = MessageOptions.getDeviceToken(message.options);
    Map data = _base(MessageContentType.contactOptions, id: message.msgId, timestamp: message.sendAt, sendTimestamp: message.sendAt);
    data.addAll({
      'optionType': '1',
      'content': {
        'deviceToken': deviceToken,
      },
    });
    return jsonEncode(data);
  }

  static String getDeviceRequest() {
    Map data = _base(MessageContentType.deviceRequest);
    return jsonEncode(data);
  }

  static String getDeviceInfo() {
    Map data = _base(MessageContentType.deviceResponse);
    data.addAll({
      'deviceId': Global.deviceId,
      'appName': Settings.appName,
      'appVersion': Global.build,
      'platform': PlatformName.get(),
      'platformVersion': Global.deviceVersion,
    });
    return jsonEncode(data);
  }

  static String getText(MessageSchema message) {
    Map data = _base(message.contentType, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': message.content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTopic) {
      data['topic'] = message.topic;
    } else if (message.isPrivateGroup) {
      data['groupId'] = message.groupId;
    }
    return jsonEncode(data);
  }

  static String? getIpfs(MessageSchema message) {
    String? content = MessageOptions.getIpfsHash(message.options);
    if (content == null || content.isEmpty) return null;
    Map data = _base(MessageContentType.ipfs, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTopic) {
      data['topic'] = message.topic;
    } else if (message.isPrivateGroup) {
      data['groupId'] = message.groupId;
    }
    return jsonEncode(data);
  }

  static Future<String?> getImage(MessageSchema message) async {
    File? file = message.content as File?;
    if (file == null) return null;
    String? content = await FileHelper.convertFileToBase64(file, type: "image");
    if (content == null) return null;
    Map data = _base(message.contentType, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTopic) {
      data['topic'] = message.topic;
    } else if (message.isPrivateGroup) {
      data['groupId'] = message.groupId;
    }
    return jsonEncode(data);
  }

  static Future<String?> getAudio(MessageSchema message) async {
    File? file = message.content as File?;
    if (file == null) return null;
    var mimeType = mime(file.path) ?? "";
    if (mimeType.split(FileHelper.DEFAULT_AUDIO_EXT).length <= 0) return null;
    String? content = await FileHelper.convertFileToBase64(file, type: "audio");
    if (content == null) return null;
    Map data = _base(message.contentType, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTopic) {
      data['topic'] = message.topic;
    } else if (message.isPrivateGroup) {
      data['groupId'] = message.groupId;
    }
    return jsonEncode(data);
  }

  static String getPiece(MessageSchema message) {
    Map data = _base(message.contentType, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': message.content,
      'options': _simpleOptions(message.options),
      // SUPPORT:START
      'parentType': message.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] ?? message.contentType,
      'bytesLength': message.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH],
      'total': message.options?[MessageOptions.KEY_PIECE_TOTAL],
      'parity': message.options?[MessageOptions.KEY_PIECE_PARITY],
      'index': message.options?[MessageOptions.KEY_PIECE_INDEX],
      // SUPPORT:END
    });
    if (message.isTopic) {
      data['topic'] = message.topic;
    } else if (message.isPrivateGroup) {
      data['groupId'] = message.groupId;
    }
    return jsonEncode(data);
  }

  static String getPrivateGroupSubscribe(MessageSchema message) {
    Map data = _base(MessageContentType.topicSubscribe, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'groupId': message.groupId,
    });
    return jsonEncode(data);
  }

  static String getTopicSubscribe(MessageSchema message) {
    Map data = _base(MessageContentType.topicSubscribe, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'topic': message.topic,
    });
    return jsonEncode(data);
  }

  static String getTopicUnSubscribe(MessageSchema message) {
    Map data = _base(MessageContentType.topicUnsubscribe, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'topic': message.topic,
    });
    return jsonEncode(data);
  }

  static String getTopicInvitee(MessageSchema message) {
    Map data = _base(MessageContentType.topicInvitation, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'content': message.content,
    });
    return jsonEncode(data);
  }

  static String getTopicKickOut(MessageSchema message) {
    Map data = _base(MessageContentType.topicKickOut, id: message.msgId, sendTimestamp: message.sendAt);
    data.addAll({
      'topic': message.topic,
      'content': message.content,
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupInvitation(PrivateGroupSchema privateGroup, PrivateGroupItemSchema item) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupInvitation,
      'groupId': privateGroup.groupId,
      'groupName': privateGroup.name,
      'version': privateGroup.version,
      'data': {
        'inviterData': item.inviterRawData,
        'inviterSignature': item.inviterSignature,
      }
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupAccept(PrivateGroupItemSchema item) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupAccept,
      'groupId': item.groupId,
      'data': {
        'inviterData': item.inviterRawData,
        'inviterSignature': item.inviterSignature,
        'inviteeData': item.inviteeRawData,
        'inviteeSignature': item.inviteeSignature,
      }
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupOptionSync(PrivateGroupSchema privateGroup, List<String> list) {
    list.sort((a, b) => a.compareTo(b));
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupOptionSync,
      'groupId': privateGroup.groupId,
      'version': privateGroup.version,
      'data': {
        'members': jsonEncode(list),
        'options': jsonEncode(privateGroup.options!.getData()),
      },
      'signature': privateGroup.options!.signature,
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberRequest(String groupId, List<String> list) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupMemberRequest,
      'groupId': groupId,
      'data': list,
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberSync(PrivateGroupSchema privateGroup, List<PrivateGroupItemSchema> list) {
    var members = privateGroupCommon.getMembersData(list);
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupMemberSync,
      'groupId': privateGroup.groupId,
      'version': privateGroup.version,
      'data': members,
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupOptionRequest(String groupId) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupOptionRequest,
      'groupId': groupId,
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberKeyRequest(String groupId) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupMemberKeyRequest,
      'groupId': groupId,
    };
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberKeyResponse(PrivateGroupSchema privateGroup, List<String> list) {
    Map data = {
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'contentType': MessageContentType.privateGroupMemberKeyResponse,
      'groupId': privateGroup.groupId,
      'version': privateGroup.version,
      'data': list,
    };
    return jsonEncode(data);
  }
}
