import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime_type/mime_type.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';
import 'package:uuid/uuid.dart';

class MessageStatus {
  static const int Error = -10;
  static const int Sending = 0;
  static const int Success = 10;
  static const int Receipt = 20;
  static const int Read = 30;
}

class MessageContentType {
  static const String ping = 'ping'; // .
  // static const String system = 'system';

  static const String receipt = 'receipt'; // status
  static const String read = 'read'; // status
  static const String queue = 'queue'; // .

  static const String contactProfile = 'contact:profile'; // .
  static const String contactOptions = 'contact:options'; // db + visible

  static const String deviceRequest = 'device:request'; // .
  static const String deviceInfo = 'device:info'; // .

  static const String text = 'text'; // db + visible
  static const String textExtension = 'textExtension'; // db + visible
  static const String ipfs = 'ipfs'; // db + visible
  static const String file = 'file'; // db + visible
  static const String image = 'image'; // db + visible
  static const String audio = 'audio'; // db + visible
  static const String video = 'video'; // db + visible
  static const String piece = 'piece'; // db(delete)

  static const String topicSubscribe = 'topic:subscribe'; // db + visible
  static const String topicUnsubscribe = 'topic:unsubscribe'; // .
  static const String topicInvitation = 'topic:invitation'; // db + visible
  static const String topicKickOut = 'topic:kickOut'; // .

  static const String privateGroupInvitation = 'privateGroup:invitation'; // db + visible
  static const String privateGroupAccept = 'privateGroup:accept'; // .
  static const String privateGroupSubscribe = 'privateGroup:subscribe'; // db + visible
  static const String privateGroupQuit = 'privateGroup:quit'; // .
  static const String privateGroupOptionRequest = 'privateGroup:optionRequest'; // .
  static const String privateGroupOptionResponse = 'privateGroup:optionResponse'; // .
  static const String privateGroupMemberRequest = 'privateGroup:memberRequest'; // .
  static const String privateGroupMemberResponse = 'privateGroup:memberResponse'; // .

  // revoke message
  static const String revoke = 'revoke';

  // SUPPORT:START
  static const String msgStatus = 'msgStatus';
// SUPPORT:END
}

class MessageSchema {
  Uint8List? pid; // <-> pid
  String msgId; // (required) <-> msg_id
  String deviceId; // (required) <-> device_id
  int queueId; // (required) <-> queue_id

  String sender; // (required) <-> sender
  String targetId; // (required) <-> target_id
  int targetType; // (required) <-> target_type

  bool isOutbound; // <-> is_outbound
  int status; // <-> status

  int sendAt; // <-> send_at (== create_at/send_at)
  int? receiveAt; // <-> receive_at (== receive_at or ack_at)

  bool isDelete; // <-> is_delete
  int? deleteAt; // <-> delete_at

  String contentType; // (required) <-> type
  dynamic content; // <-> content

  Map<String, dynamic>? options; // <-> options
  String? data; // <-> data

  Map<String, dynamic>? temp; // no_sql

  MessageSchema({
    this.pid,
    required this.msgId,
    this.deviceId = "",
    this.queueId = 0,
    // target
    required this.sender,
    required this.targetId,
    required this.targetType,
    // status
    required this.isOutbound,
    required this.status,
    // at
    required this.sendAt,
    this.receiveAt,
    // delete
    this.isDelete = false,
    this.deleteAt,
    // data
    required this.contentType,
    this.content,
    this.options,
    this.data,
  }) {
    contentType = futureContentType(contentType);
    if (options == null) options = Map();
  }

  bool get isTargetContact {
    return targetType == SessionType.CONTACT;
  }

  bool get isTargetTopic {
    return targetType == SessionType.TOPIC;
  }

  bool get isTargetGroup {
    return targetType == SessionType.PRIVATE_GROUP;
  }

  bool get isTargetSelf {
    return isTargetContact && (isOutbound ? (sender == targetId) : ((sender == clientCommon.address) && (clientCommon.address?.isNotEmpty == true)));
  }

  // burning
  bool get canBurning {
    bool isText = contentType == MessageContentType.text || contentType == MessageContentType.textExtension;
    bool isIpfs = contentType == MessageContentType.ipfs;
    bool isFile = contentType == MessageContentType.file;
    bool isImage = contentType == MessageContentType.image;
    bool isAudio = contentType == MessageContentType.audio;
    bool isVideo = contentType == MessageContentType.video;
    return isText || isIpfs || isFile || isImage || isAudio || isVideo;
  }

  // ++ receipt
  bool get canReceipt {
    return canBurning;
  }

  // ++ unReadCount / notification
  bool get canNotification {
    bool isEvent = contentType == MessageContentType.topicInvitation || contentType == MessageContentType.privateGroupInvitation;
    return canReceipt || isEvent;
  }

  // ++ session
  bool get canDisplay {
    bool isEvent = contentType == MessageContentType.contactOptions || contentType == MessageContentType.topicSubscribe || contentType == MessageContentType.privateGroupSubscribe; // || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicKickOut
    return canNotification || isEvent;
  }

  bool get isTopicAction {
    return contentType == MessageContentType.topicSubscribe || contentType == MessageContentType.topicUnsubscribe || contentType == MessageContentType.topicInvitation || contentType == MessageContentType.topicKickOut;
  }

  bool get isGroupAction {
    bool isAction = contentType == MessageContentType.privateGroupInvitation || contentType == MessageContentType.privateGroupAccept || contentType == MessageContentType.privateGroupSubscribe || contentType == MessageContentType.privateGroupQuit;
    bool isSync = contentType == MessageContentType.privateGroupOptionRequest || contentType == MessageContentType.privateGroupOptionResponse || contentType == MessageContentType.privateGroupMemberRequest || contentType == MessageContentType.privateGroupMemberResponse;
    return isAction || isSync;
  }

  bool get canTryPiece {
    bool isImage = contentType == MessageContentType.image;
    bool isAudio = contentType == MessageContentType.audio;
    return isImage || isAudio;
  }

  bool get canQueue {
    return canReceipt && isTargetContact;
  }

  bool get isContentFile {
    return (content != null) && (content is File);
  }

  /// from receive
  static MessageSchema? fromReceive(OnMessage? raw) {
    if (raw == null) {
      logger.e("MessageSchema - fromReceive - raw nil");
      return null;
    } else if ((raw.src == null) || (raw.src?.isEmpty == true)) {
      logger.e("MessageSchema - fromReceive - src nil");
      return null;
    } else if ((raw.data == null) || (raw.data?.isEmpty == true)) {
      logger.e("MessageSchema - fromReceive - data nil");
      return null;
    }
    Map<String, dynamic>? data = Util.jsonFormatMap(raw.data);
    if (data == null) {
      logger.e("MessageSchema - fromReceive - data<map> nil");
      return null;
    }
    String msgId = data['id']?.toString() ?? "";
    String contentType = data['contentType']?.toString() ?? "";
    if (msgId.isEmpty || contentType.isEmpty) {
      logger.e("MessageSchema - fromReceive - info nil");
      return null;
    }
    // target
    String sender = raw.src ?? "";
    String topic = data['topic']?.toString() ?? "";
    String groupId = data['groupId']?.toString() ?? "";
    String targetId = topic.isNotEmpty ? topic : (groupId.isNotEmpty ? groupId : sender);
    int targetType = topic.isNotEmpty ? SessionType.TOPIC : (groupId.isNotEmpty ? SessionType.PRIVATE_GROUP : SessionType.CONTACT);
    // schema
    MessageSchema schema = MessageSchema(
      pid: raw.messageId,
      msgId: msgId,
      deviceId: data['deviceId']?.toString() ?? "",
      queueId: int.tryParse(data['queueId']?.toString() ?? "0") ?? 0,
      // target
      sender: sender,
      targetId: targetId,
      targetType: targetType,
      // status
      isOutbound: false,
      status: MessageStatus.Success,
      // at
      sendAt: int.tryParse(data['send_timestamp']?.toString() ?? "") ?? int.tryParse(data['timestamp']?.toString() ?? "") ?? DateTime.now().millisecondsSinceEpoch,
      receiveAt: DateTime.now().millisecondsSinceEpoch,
      // delete
      isDelete: false,
      deleteAt: null,
      // data
      contentType: contentType,
      options: (data['options'] is Map) ? data['options'] : Map(),
      data: null, // just send set
    );
    schema.status = schema.canReceipt ? (schema.isTargetContact ? schema.status : MessageStatus.Receipt) : MessageStatus.Read;
    // content
    switch (schema.contentType) {
      case MessageContentType.receipt:
        schema.content = data['targetID'];
        break;
      case MessageContentType.read:
        schema.content = data['readIds'];
        break;
      case MessageContentType.queue:
        schema.content = data['queueIds'];
        break;
      case MessageContentType.msgStatus:
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
        schema.content = data;
        break;
      case MessageContentType.revoke:
        schema.content = data['targetId'];
        break;
      case MessageContentType.ipfs:
        schema.content = null;
        break;
      default:
        schema.content = data['content'];
        break;
    }
    return schema;
  }

  /// to send
  static MessageSchema fromSend(
    String targetId,
    int targetType,
    String contentType,
    dynamic content, {
    String? msgId,
    int? queueId,
    Map<String, dynamic>? options,
    Map<String, dynamic>? extra,
  }) {
    MessageSchema schema = MessageSchema(
      pid: null, // set after sendSuccess
      msgId: msgId ?? Uuid().v4(),
      deviceId: Settings.deviceId,
      queueId: queueId ?? 0, // can set after newQueueId
      // target
      sender: clientCommon.address ?? "", // no importance
      targetId: targetId,
      targetType: targetType,
      // status
      isOutbound: true,
      status: MessageStatus.Sending,
      // at
      sendAt: DateTime.now().millisecondsSinceEpoch,
      receiveAt: null, // set in receive ACK
      // delete
      isDelete: false,
      deleteAt: null, // can set in messages bubble
      // data
      contentType: contentType,
      content: content,
      options: options,
      data: null, // set after getData
    );
    // options
    String? profileVersion = extra?["profileVersion"];
    if (profileVersion != null && profileVersion.isNotEmpty) {
      schema.options = MessageOptions.setProfileVersion(schema.options, profileVersion);
    }
    String? deviceToken = extra?["deviceToken"];
    if (deviceToken != null && deviceToken.isNotEmpty) {
      schema.options = MessageOptions.setDeviceToken(schema.options, deviceToken);
    }
    String? deviceProfile = extra?["deviceProfile"];
    if (deviceProfile != null && deviceProfile.isNotEmpty) {
      schema.options = MessageOptions.setDeviceProfile(schema.options, deviceProfile);
    }
    String? privateGroupVersion = extra?["privateGroupVersion"];
    if (privateGroupVersion != null && privateGroupVersion.isNotEmpty) {
      schema.options = MessageOptions.setPrivateGroupVersion(schema.options, privateGroupVersion);
    }
    int? deleteAfterSeconds = extra?["deleteAfterSeconds"];
    if (deleteAfterSeconds != null && deleteAfterSeconds > 0) {
      schema.options = MessageOptions.setOptionsBurningDeleteSec(schema.options, deleteAfterSeconds);
    }
    int? burningUpdateAt = extra?["burningUpdateAt"];
    if (burningUpdateAt != null && burningUpdateAt > 0) {
      schema.options = MessageOptions.setOptionsBurningUpdateAt(schema.options, burningUpdateAt);
    }
    String? queueIds = extra?["queueIds"];
    if (queueIds != null && queueIds.isNotEmpty) {
      schema.options = MessageOptions.setMessageQueueIds(schema.options, queueIds);
    }
    int? size = int.tryParse(extra?["size"]?.toString() ?? "");
    if (size != null && size != 0) {
      schema.options = MessageOptions.setFileSize(schema.options, size);
    }
    String? fileName = extra?["name"];
    if (fileName != null && fileName.isNotEmpty) {
      schema.options = MessageOptions.setFileName(schema.options, fileName);
    }
    String? fileExt = extra?["fileExt"];
    if (fileExt != null && fileExt.isNotEmpty) {
      schema.options = MessageOptions.setFileExt(schema.options, fileExt);
    }
    String? fileMimeType = extra?["mimeType"];
    if (fileMimeType != null && fileMimeType.isNotEmpty) {
      schema.options = MessageOptions.setFileMimeType(schema.options, fileMimeType);
    }
    int? fileType = int.tryParse(extra?["fileType"]?.toString() ?? "");
    if (fileType != null && fileType >= 0) {
      schema.options = MessageOptions.setFileType(schema.options, fileType);
    } else if (((size ?? 0) > 0) || (fileMimeType?.isNotEmpty == true) || (fileExt?.isNotEmpty == true)) {
      if ((fileMimeType?.contains("image") == true)) {
        schema.options = MessageOptions.setFileType(schema.options, MessageOptions.fileTypeImage);
      } else if ((fileMimeType?.contains("audio") == true)) {
        schema.options = MessageOptions.setFileType(schema.options, MessageOptions.fileTypeAudio);
      } else if ((fileMimeType?.contains("video") == true)) {
        schema.options = MessageOptions.setFileType(schema.options, MessageOptions.fileTypeVideo);
      } else {
        // file_picker is here, because no mime_type
        schema.options = MessageOptions.setFileType(schema.options, MessageOptions.fileTypeNormal);
      }
    }
    int? mediaWidth = int.tryParse(extra?["width"]?.toString() ?? "");
    int? mediaHeight = int.tryParse(extra?["height"]?.toString() ?? "");
    if (mediaWidth != null && mediaWidth != 0 && mediaHeight != null && mediaHeight != 0) {
      schema.options = MessageOptions.setMediaSizeWH(schema.options, mediaWidth, mediaHeight);
    }
    double? duration = double.tryParse(extra?["duration"]?.toString() ?? "");
    if (duration != null && duration >= 0) {
      schema.options = MessageOptions.setMediaDuration(schema.options, duration);
      // SUPPORT:START
      schema.options?["audioDuration"] = duration;
      // SUPPORT:END
    }
    String? thumbnailPath = extra?["thumbnailPath"];
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      schema.options = MessageOptions.setMediaThumbnailPath(schema.options, thumbnailPath);
    }
    // piece
    String? parentType = extra?["piece_parent_type"];
    int? bytesLength = extra?["piece_bytes_length"];
    int? total = extra?["piece_total"];
    int? parity = extra?["piece_parity"];
    int? index = extra?["piece_index"];
    if ((parentType?.isNotEmpty == true) && ((total ?? 0) > 0)) {
      schema.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] = parentType;
      schema.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH] = bytesLength;
      schema.options?[MessageOptions.KEY_PIECE_TOTAL] = total;
      schema.options?[MessageOptions.KEY_PIECE_PARITY] = parity;
      schema.options?[MessageOptions.KEY_PIECE_INDEX] = index;
    }
    return schema;
  }

  /// to sqlite
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'pid': (pid?.isNotEmpty == true) ? hexEncode(pid!) : null,
      'msg_id': msgId,
      'device_id': deviceId,
      'queue_id': queueId,
      // target
      'sender': sender,
      'target_id': targetId,
      'target_type': targetType,
      // status
      'is_outbound': isOutbound ? 1 : 0,
      'status': status,
      // at
      'send_at': sendAt,
      'receive_at': receiveAt,
      // delete
      'is_delete': isDelete ? 1 : 0,
      'delete_at': deleteAt,
      // data
      'type': contentType,
      // content:,
      'options': jsonEncode(options ?? Map()),
      'data': data,
    };
    // content
    switch (contentType) {
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
        map['content'] = (content is Map) ? jsonEncode(content) : content;
        break;
      case MessageContentType.ipfs: // maybe null
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        if (isContentFile) map['content'] = Path.convert2Local((content as File).path);
        break;
      case MessageContentType.revoke:
        map['content'] = content;
        break;
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupQuit:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupOptionResponse:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberResponse:
        map['content'] = (content is Map) ? jsonEncode(content) : content;
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
      pid: (e['pid'] != null) ? hexDecode(e['pid']) : null,
      msgId: e['msg_id'] ?? "",
      deviceId: e['device_id'] ?? "",
      queueId: e['queue_id'] ?? 0,
      // target
      sender: e['sender'] ?? "",
      targetId: e['target_id'] ?? "",
      targetType: e['target_type'] ?? 0,
      // status
      isOutbound: (e['is_outbound'] != null && e['is_outbound'] == 1) ? true : false,
      status: e['status'] ?? 0,
      // at
      sendAt: e['send_at'] ?? DateTime.now().millisecondsSinceEpoch,
      receiveAt: e['receive_at'],
      // delete
      isDelete: (e['is_delete'] != null && e['is_delete'] == 1) ? true : false,
      deleteAt: e['delete_at'],
      // data
      contentType: e['type'] ?? "",
      options: (e['options']?.toString().isNotEmpty == true) ? Util.jsonFormatMap(e['options']) : null,
      data: e['data'],
    );
    // content
    switch (schema.contentType) {
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
        if ((e['content']?.toString().isNotEmpty == true) && (e['content'] is String)) {
          schema.content = Util.jsonFormatMap(e['content']);
        } else {
          schema.content = e['content'];
        }
        break;
      case MessageContentType.ipfs: // maybe null
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
        String? completePath = Path.convert2Complete(e['content']);
        schema.content = (completePath?.isNotEmpty == true) ? File(completePath!) : null;
        break;
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupQuit:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupOptionResponse:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberResponse:
        if ((e['content']?.toString().isNotEmpty == true) && (e['content'] is String)) {
          schema.content = Util.jsonFormatMap(e['content']);
        } else {
          schema.content = e['content'];
        }
        break;
      case MessageContentType.revoke:
        schema.content = e['content'];
        break;
      default:
        schema.content = e['content'];
        break;
    }
    return schema;
  }

  static Future<Map<String, dynamic>> piecesSplits(MessageSchema msg) async {
    if (!msg.isContentFile) return {};
    File? file = msg.content as File?;
    if (file == null || !file.existsSync()) return {};
    int length = await file.length();
    if (length <= Settings.piecesPreMinLen) return {};
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    int bytesLength = base64Data.length;
    // total (2~192)
    int total;
    if (bytesLength < (Settings.piecesPreMinLen * Settings.piecesMinTotal)) {
      return {};
    } else if (bytesLength <= (Settings.piecesPreMinLen * Settings.piecesMaxTotal)) {
      total = bytesLength ~/ Settings.piecesPreMinLen;
      if (bytesLength % Settings.piecesPreMinLen > 0) {
        total += 1;
      }
    } else {
      total = Settings.piecesMaxTotal;
    }
    // parity(1~63)
    int parity = (total * (Settings.piecesMaxParity / (Settings.piecesMaxTotal + Settings.piecesMaxParity))).toInt();
    if (total % (Settings.piecesMaxParity / (Settings.piecesMaxTotal + Settings.piecesMaxParity)) > 0) {
      parity += 1;
    }
    if (parity > Settings.piecesMaxParity) {
      parity = Settings.piecesMaxParity;
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
    return await Common.combinePieces(recoverList, total, parity, bytesLength);
  }

  static MessageSchema? combinePiecesMsg(List<MessageSchema> sortPieces, String base64String) {
    List<MessageSchema> finds = sortPieces.where((element) {
      bool pid = element.pid != null;
      bool contentType = (element.options?[MessageOptions.KEY_PIECE_PARENT_TYPE]?.toString() ?? "").isNotEmpty;
      return pid && contentType;
    }).toList();
    if (finds.isEmpty) return null;
    MessageSchema piece = finds[0];
    // schema(same with fromReceive)
    MessageSchema schema = MessageSchema(
      pid: piece.pid,
      msgId: piece.msgId,
      deviceId: piece.deviceId,
      queueId: piece.queueId,
      // target
      sender: piece.sender,
      targetId: piece.targetId,
      targetType: piece.targetType,
      // status
      isOutbound: false,
      status: MessageStatus.Success,
      // at
      sendAt: piece.sendAt,
      receiveAt: DateTime.now().millisecondsSinceEpoch,
      // delete
      isDelete: false,
      deleteAt: null,
      // data
      contentType: piece.options?[MessageOptions.KEY_PIECE_PARENT_TYPE] ?? "",
      content: base64String,
      options: piece.options,
      data: null, // just send set
    );
    schema.status = schema.canReceipt ? schema.status : MessageStatus.Read;
    // pieces
    schema.options?.remove(MessageOptions.KEY_PIECE_PARENT_TYPE);
    schema.options?.remove(MessageOptions.KEY_PIECE_BYTES_LENGTH);
    schema.options?.remove(MessageOptions.KEY_PIECE_TOTAL);
    schema.options?.remove(MessageOptions.KEY_PIECE_PARITY);
    schema.options?.remove(MessageOptions.KEY_PIECE_INDEX);
    schema.options?.remove("piece");
    schema.options?[MessageOptions.KEY_FROM_PIECE] = true;
    return schema;
  }

  // SUPPORT:GG
  static String futureContentType(String oldType) {
    String contentType = oldType;
    switch (oldType) {
      case "contact":
        contentType = MessageContentType.contactProfile;
        break;
      case "event:contactOptions":
        contentType = MessageContentType.contactOptions;
        break;
      case "media":
      case "nknImage":
        contentType = MessageContentType.image;
        break;
      case "nknOnePiece":
        contentType = MessageContentType.piece;
        break;
      case "event:subscribe":
      case "dchat/subscribe":
        contentType = MessageContentType.topicSubscribe;
        break;
      case "event:unsubscribe":
        contentType = MessageContentType.topicUnsubscribe;
        break;
      case "event:channelInvitation":
        contentType = MessageContentType.topicInvitation;
        break;
      case "event:channelKickOut":
        contentType = MessageContentType.topicKickOut;
        break;
      default:
        // nothing
        break;
    }
    return contentType;
  }

  // SUPPORT:GG
  static String supportContentType(String newType) {
    String contentType = newType;
    switch (newType) {
      case MessageContentType.contactProfile:
        contentType = "contact";
        break;
      case MessageContentType.contactOptions:
        contentType = "event:contactOptions";
        break;
      case MessageContentType.image:
        contentType = "media";
        break;
      case MessageContentType.piece:
        contentType = "nknOnePiece";
        break;
      case MessageContentType.topicSubscribe:
        contentType = "event:subscribe";
        break;
      case MessageContentType.topicUnsubscribe:
        contentType = "event:unsubscribe";
        break;
      case MessageContentType.topicInvitation:
        contentType = "event:channelInvitation";
        break;
      case MessageContentType.topicKickOut:
        contentType = "event:channelKickOut";
        break;
      default:
        // nothing
        break;
    }
    return contentType;
  }

  @override
  String toString() {
    return 'MessageSchema{pid: $pid, msgId: $msgId, deviceId: $deviceId, queueId: $queueId, sender: $sender, targetId: $targetId, targetType: $targetType, isOutbound: $isOutbound, status: $status, sendAt: $sendAt, receiveAt: $receiveAt, isDelete: $isDelete, deleteAt: $deleteAt, contentType: $contentType, content: $content, options: $options, data: $data, temp: $temp}';
  }

  String toStringSimple() {
    return 'MessageSchema{msgId: $msgId, deviceId: $deviceId, queueId: $queueId, sender: $sender, targetId: $targetId, targetType: $targetType, isOutbound: $isOutbound, status: $status, sendAt: $sendAt, receiveAt: $receiveAt, isDelete: $isDelete, deleteAt: $deleteAt, contentType: $contentType, options: $options, temp: $temp}';
  }
}

class MessageOptions {
  static const KEY_SEND_SUCCESS_AT = "sendSuccessAt"; // native
  static const KEY_RESEND_MUTE_AT = "resendMuteAt"; // native
  static const KEY_SUCCESS_TIMES = "successTimes"; // native

  static const KEY_PROFILE_VERSION = "profileVersion";
  static const KEY_DEVICE_TOKEN = "deviceToken";
  static const KEY_DEVICE_PROFILE = "deviceProfile";
  static const KEY_FIRST_MESSAGE_QUEUE_IDS = "firstMessageQueueIds";
  static const KEY_MESSAGE_QUEUE_IDS = "messageQueueIds";
  static const KEY_PRIVATE_GROUP_VERSION = "privateGroupVersion";

  static const KEY_DELETE_AFTER_SECONDS = "deleteAfterSeconds";
  static const KEY_UPDATE_BURNING_AFTER_AT = "updateBurnAfterAt";

  static const KEY_PUSH_NOTIFY_ID = "pushNotifyId"; // native

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
  static const KEY_MEDIA_THUMBNAIL = "mediaThumbnail"; // native

  static const KEY_IPFS_STATE = "ipfsState"; // native
  static const ipfsStateNo = 0;
  static const ipfsStateIng = 1;
  static const ipfsStateYes = 2;

  static const KEY_IPFS_THUMBNAIL_STATE = "ipfsThumbnailState"; // native
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

  static const KEY_FROM_PIECE = "from_piece";

  static const KEY_PIECE_PARENT_TYPE = "piece_parent_type";
  static const KEY_PIECE_BYTES_LENGTH = "piece_bytes_length";
  static const KEY_PIECE_PARITY = "piece_parity";
  static const KEY_PIECE_TOTAL = "piece_total";
  static const KEY_PIECE_INDEX = "piece_index";

  static Map<String, dynamic> setSendSuccessAt(Map<String, dynamic>? options, int sendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_SEND_SUCCESS_AT] = sendAt;
    return options;
  }

  static int? getSendSuccessAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_SEND_SUCCESS_AT]?.toString() ?? "");
  }

  static Map<String, dynamic> setResendMuteAt(Map<String, dynamic>? options, int resendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_RESEND_MUTE_AT] = resendAt;
    return options;
  }

  static int? getResendMuteAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_RESEND_MUTE_AT]?.toString() ?? "");
  }

  static Map<String, dynamic> setSuccessTimes(Map<String, dynamic>? options, int resendAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_SUCCESS_TIMES] = resendAt;
    return options;
  }

  static int? getSuccessTimes(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return int.tryParse(options[MessageOptions.KEY_SUCCESS_TIMES]?.toString() ?? "");
  }

  static Map<String, dynamic> setProfileVersion(Map<String, dynamic>? options, String profileVersion) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_PROFILE_VERSION] = profileVersion;
    return options;
  }

  static String? getProfileVersion(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_PROFILE_VERSION]?.toString();
  }

  static Map<String, dynamic> setDeviceToken(Map<String, dynamic>? options, String deviceToken) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DEVICE_TOKEN] = deviceToken;
    return options;
  }

  static String? getDeviceToken(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_DEVICE_TOKEN]?.toString();
  }

  static Map<String, dynamic> setDeviceProfile(Map<String, dynamic>? options, String deviceProfile) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DEVICE_PROFILE] = deviceProfile;
    return options;
  }

  static String? getDeviceProfile(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_DEVICE_PROFILE]?.toString();
  }

  static Map<String, dynamic> setFirstMessageQueueIds(Map<String, dynamic>? options, String queueIds) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_FIRST_MESSAGE_QUEUE_IDS] = queueIds;
    return options;
  }

  static String? getFirstMessageQueueIds(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_FIRST_MESSAGE_QUEUE_IDS]?.toString();
  }

  static Map<String, dynamic> setMessageQueueIds(Map<String, dynamic>? options, String queueIds) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_MESSAGE_QUEUE_IDS] = queueIds;
    return options;
  }

  static String? getMessageQueueIds(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_MESSAGE_QUEUE_IDS]?.toString();
  }

  static Map<String, dynamic> setPrivateGroupVersion(Map<String, dynamic>? options, String peivateGroupVersion) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_PRIVATE_GROUP_VERSION] = peivateGroupVersion;
    return options;
  }

  static String? getPrivateGroupVersion(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    return options[MessageOptions.KEY_PRIVATE_GROUP_VERSION]?.toString();
  }

  static Map<String, dynamic> setOptionsBurningDeleteSec(Map<String, dynamic>? options, int deleteTimeSec) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_DELETE_AFTER_SECONDS] = deleteTimeSec;
    return options;
  }

  static int? getOptionsBurningDeleteSec(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var seconds = options[MessageOptions.KEY_DELETE_AFTER_SECONDS]?.toString();
    return int.tryParse(seconds ?? "");
  }

  static Map<String, dynamic> setOptionsBurningUpdateAt(Map<String, dynamic>? options, int? updateAt) {
    if (options == null) options = Map<String, dynamic>();
    options[MessageOptions.KEY_UPDATE_BURNING_AFTER_AT] = updateAt;
    return options;
  }

  static int? getOptionsBurningUpdateAt(Map<String, dynamic>? options) {
    if (options == null || options.keys.length == 0) return null;
    var update = options[MessageOptions.KEY_UPDATE_BURNING_AFTER_AT]?.toString();
    return int.tryParse(update ?? "");
  }

  static Map<String, dynamic> setPushNotifyId(Map<String, dynamic>? options, String uuid) {
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
}

class MessageData {
  static Map _base(String contentType, {String? id, int? timestamp, int? queueId}) {
    Map map = {
      'id': (id == null || id.isEmpty) ? Uuid().v4() : id,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'deviceId': Settings.deviceId,
      'contentType': contentType,
    };
    if ((queueId != null) && (queueId > 0)) map.addAll({"queueId": queueId});
    return map;
  }

  static Map<String, dynamic>? _simpleOptions(Map<String, dynamic>? options) {
    Map<String, dynamic> map = Map()..addAll(options ?? Map());
    map.remove(MessageOptions.KEY_SEND_SUCCESS_AT);
    map.remove(MessageOptions.KEY_RESEND_MUTE_AT);
    map.remove(MessageOptions.KEY_SUCCESS_TIMES);
    map.remove(MessageOptions.KEY_PUSH_NOTIFY_ID);
    map.remove(MessageOptions.KEY_IPFS_STATE);
    map.remove(MessageOptions.KEY_IPFS_THUMBNAIL_STATE);
    map.remove(MessageOptions.KEY_MEDIA_THUMBNAIL);
    return map;
  }

  static String getPing(
    bool isPing, {
    String? profileVersion,
    String? deviceToken,
    String? deviceProfile,
    String? queueIds,
  }) {
    Map data = _base(MessageContentType.ping);
    data.addAll({
      'content': isPing ? "ping" : "pong",
    });
    if (data['options'] == null) data['options'] = Map();
    if ((profileVersion != null) && profileVersion.isNotEmpty) {
      data['options'][MessageOptions.KEY_PROFILE_VERSION] = profileVersion;
    }
    if ((deviceToken != null) && deviceToken.isNotEmpty) {
      data['options'][MessageOptions.KEY_DEVICE_TOKEN] = deviceToken;
    }
    if ((deviceProfile != null) && deviceProfile.isNotEmpty) {
      data['options'][MessageOptions.KEY_DEVICE_PROFILE] = deviceProfile;
    }
    if ((queueIds != null) && queueIds.isNotEmpty) {
      data['options'][MessageOptions.KEY_MESSAGE_QUEUE_IDS] = queueIds;
    }
    return jsonEncode(data);
  }

  static String getReceipt(String targetId) {
    Map data = _base(MessageContentType.receipt);
    data.addAll({
      'targetID': targetId,
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

  static String getQueue(String queueIds) {
    Map data = _base(MessageContentType.queue);
    data.addAll({
      'queueIds': queueIds,
    });
    return jsonEncode(data);
  }

  static String getRevoke(String targetMsgId) {
    Map data = _base(MessageContentType.revoke);
    data.addAll({
      'targetId': targetMsgId,
    });
    return jsonEncode(data);
  }

  static String getContactProfileRequest(String requestType, String? profileVersion) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.contactProfile));
    data.addAll({
      'requestType': requestType,
      'version': profileVersion,
    });
    return jsonEncode(data);
  }

  static String getContactProfileResponseHeader(String? profileVersion) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.contactProfile));
    data.addAll({
      'responseType': ContactRequestType.header,
      'version': profileVersion,
    });
    return jsonEncode(data);
  }

  static Future<String> getContactProfileResponseFull(String? profileVersion, File? avatar, String? firstName, String? lastName) async {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.contactProfile));
    data.addAll({
      'responseType': ContactRequestType.full,
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
      content['first_name'] = firstName;
      content['last_name'] = lastName;
      content['name'] = firstName;
    }
    data['content'] = content;
    return jsonEncode(data);
  }

  static String getContactOptionsBurn(String msgId, int? burnAfterSeconds, int? updateBurnAfterAt) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.contactOptions), id: msgId);
    data.addAll({
      'optionType': '0',
      'content': {
        'deleteAfterSeconds': burnAfterSeconds,
        'updateBurnAfterAt': updateBurnAfterAt,
      },
    });
    return jsonEncode(data);
  }

  static String getContactOptionsToken(String msgId, String? deviceToken) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.contactOptions), id: msgId);
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

  static String getDeviceInfo(DeviceInfoSchema info) {
    Map data = _base(MessageContentType.deviceInfo);
    data.addAll({
      'deviceId': info.deviceId,
      'appName': info.appName,
      'appVersion': info.appVersion,
      'platform': info.platform,
      'platformVersion': info.platformVersion,
      'deviceToken': info.deviceToken,
    });
    return jsonEncode(data);
  }

  static String getText(MessageSchema message) {
    Map data = _base(message.contentType, id: message.msgId, timestamp: message.sendAt, queueId: message.queueId);
    data.addAll({
      'content': message.content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTargetTopic) {
      data['topic'] = message.targetId;
    } else if (message.isTargetGroup) {
      data['groupId'] = message.targetId;
    }
    return jsonEncode(data);
  }

  static String? getIpfs(MessageSchema message) {
    String? content = MessageOptions.getIpfsHash(message.options);
    if (content == null || content.isEmpty) return null;
    Map data = _base(message.contentType, id: message.msgId, timestamp: message.sendAt, queueId: message.queueId);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTargetTopic) {
      data['topic'] = message.targetId;
    } else if (message.isTargetGroup) {
      data['groupId'] = message.targetId;
    }
    return jsonEncode(data);
  }

  static Future<String?> getImage(MessageSchema message) async {
    File? file = message.content as File?;
    if (file == null) return null;
    String? content = await FileHelper.convertFileToBase64(file, type: "image");
    if (content == null) return null;
    Map data = _base(MessageSchema.supportContentType(message.contentType), id: message.msgId, timestamp: message.sendAt, queueId: message.queueId);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTargetTopic) {
      data['topic'] = message.targetId;
    } else if (message.isTargetGroup) {
      data['groupId'] = message.targetId;
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
    Map data = _base(message.contentType, id: message.msgId, timestamp: message.sendAt, queueId: message.queueId);
    data.addAll({
      'content': content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTargetTopic) {
      data['topic'] = message.targetId;
    } else if (message.isTargetGroup) {
      data['groupId'] = message.targetId;
    }
    return jsonEncode(data);
  }

  static String getPiece(MessageSchema message) {
    Map data = _base(MessageSchema.supportContentType(message.contentType), id: message.msgId, timestamp: message.sendAt, queueId: message.queueId);
    data.addAll({
      'content': message.content,
      'options': _simpleOptions(message.options),
    });
    if (message.isTargetTopic) {
      data['topic'] = message.targetId;
    } else if (message.isTargetGroup) {
      data['groupId'] = message.targetId;
    }
    return jsonEncode(data);
  }

  static String getTopicSubscribe(String? msgId, String topicId) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.topicSubscribe), id: msgId);
    data.addAll({
      'topic': topicId,
    });
    return jsonEncode(data);
  }

  static String getTopicUnSubscribe(String topicId) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.topicUnsubscribe));
    data.addAll({
      'topic': topicId,
    });
    return jsonEncode(data);
  }

  static String getTopicInvitee(MessageSchema message) {
    Map data = _base(MessageSchema.supportContentType(message.contentType), id: message.msgId, timestamp: message.sendAt);
    data.addAll({
      'content': message.content,
    });
    return jsonEncode(data);
  }

  static String getTopicKickOut(String topic, String targetId) {
    Map data = _base(MessageSchema.supportContentType(MessageContentType.topicKickOut));
    data.addAll({
      'topic': topic,
      'content': targetId,
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupInvitation(MessageSchema message) {
    Map data = _base(MessageContentType.privateGroupInvitation, id: message.msgId, timestamp: message.sendAt);
    data.addAll({
      'content': message.content,
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupAccept(PrivateGroupItemSchema item) {
    Map data = _base(MessageContentType.privateGroupAccept);
    item.toMap();
    data.addAll({
      'content': {
        'groupId': item.groupId,
        'permission': item.permission,
        'expiresAt': item.expiresAt,
        'inviter': item.inviter,
        'invitee': item.invitee,
        'inviterRawData': item.inviterRawData,
        'inviteeRawData': item.inviteeRawData,
        'inviterSignature': item.inviterSignature,
        'inviteeSignature': item.inviteeSignature,
      }
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupQuit(PrivateGroupItemSchema item) {
    Map data = _base(MessageContentType.privateGroupQuit);
    data.addAll({
      'content': {
        'groupId': item.groupId,
        'permission': item.permission,
        'expiresAt': item.expiresAt,
        'inviter': item.inviter,
        'invitee': item.invitee,
        'inviterRawData': item.inviterRawData,
        'inviteeRawData': item.inviteeRawData,
        'inviterSignature': item.inviterSignature,
        'inviteeSignature': item.inviteeSignature,
      }
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupOptionRequest(String groupId, String? privateGroupVersion) {
    Map data = _base(MessageContentType.privateGroupOptionRequest);
    data.addAll({
      'content': {
        'groupId': groupId,
        'version': privateGroupVersion,
      }
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupOptionResponse(PrivateGroupSchema privateGroup) {
    Map data = _base(MessageContentType.privateGroupOptionResponse);
    data.addAll({
      'content': {
        'groupId': privateGroup.groupId,
        'rawData': jsonEncode(privateGroup.getRawDataMap()),
        'version': privateGroup.version,
        'count': privateGroup.count,
        'signature': privateGroup.signature,
      },
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberRequest(String groupId, String? privateGroupVersion) {
    Map data = _base(MessageContentType.privateGroupMemberRequest);
    data.addAll({
      'content': {
        'groupId': groupId,
        'version': privateGroupVersion,
      },
    });
    return jsonEncode(data);
  }

  static String getPrivateGroupMemberResponse(PrivateGroupSchema privateGroup, List<Map<String, dynamic>> membersData) {
    Map data = _base(MessageContentType.privateGroupMemberResponse);
    data.addAll({
      'content': {
        'groupId': privateGroup.groupId,
        'version': privateGroup.version,
        'membersData': membersData,
      },
    });
    return jsonEncode(data);
  }
}
