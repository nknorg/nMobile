import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

import '../locator.dart';

class ChatInCommon with Tag {
  ChatInCommon() {
    start();
  }

  // ignore: close_sinks
  StreamController<MessageSchema> _onReceiveController = StreamController<MessageSchema>(); //.broadcast();
  StreamSink<MessageSchema> get _onReceiveSink => _onReceiveController.sink;
  Stream<MessageSchema> get _onReceiveStream => _onReceiveController.stream.distinct((prev, next) => prev.pid == next.pid);

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

  MessageStorage _messageStorage = MessageStorage();

  Future onClientMessage(MessageSchema? message, {bool needWait = false}) async {
    if (message == null) return;
    // contact
    ContactSchema? contact = await chatCommon.contactHandle(message);
    // topic
    TopicSchema? topic = await chatCommon.topicHandle(message);
    // session
    await chatCommon.sessionHandle(message); // before by notification
    // notification
    chatCommon.notificationHandle(contact, topic, message); // await
    // message
    if (needWait) {
      await _messageHandle(message, contact: contact);
    } else {
      _onReceiveSink.add(message);
    }
  }

  Future start() async {
    await for (MessageSchema received in _onReceiveStream) {
      await _messageHandle(received);
    }
  }

  Future _messageHandle(MessageSchema received, {ContactSchema? contact}) async {
    switch (received.contentType) {
      case ContentType.receipt:
        _receiveReceipt(received); // await
        break;
      case ContentType.contact:
        _receiveContact(received, contact: contact); // await
        break;
      case ContentType.piece:
        await _receivePiece(received);
        break;
      case ContentType.text:
      case ContentType.textExtension:
        await _receiveText(received, contact: contact);
        chatOutCommon.sendReceipt(received); // await
        break;
      case ContentType.media:
      case ContentType.image:
      case ContentType.nknImage:
        await _receiveImage(received, contact: contact);
        chatOutCommon.sendReceipt(received); // await
        break;
      case ContentType.eventContactOptions:
        _receiveContactOptions(received, contact: contact); // await
        chatOutCommon.sendReceipt(received); // await
        break;
      // TODO:GG receive contentType
      case ContentType.system:
      case ContentType.audio:
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
      case ContentType.eventChannelInvitation:
        break;
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future _receiveReceipt(MessageSchema received) async {
    List<MessageSchema> _schemaList = await _messageStorage.queryList(received.content);
    _schemaList.forEach((MessageSchema element) async {
      element = MessageStatus.set(element, MessageStatus.SendWithReceipt);
      bool updated = await _messageStorage.updateMessageStatus(element);
      if (updated) {
        // update send by receipt
        chatCommon.onUpdateSink.add(element);
      }
      logger.d("$TAG - receiveReceipt - updated:$element");
    });
  }

  // NO DB NO display (1 to 1)
  Future _receiveContact(MessageSchema received, {ContactSchema? contact}) async {
    if (received.content == null) return;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? exist = contact ?? await contactCommon.queryByClientAddress(received.from);
    if (exist == null) {
      logger.w("$TAG - receiveContact - empty - data:$data");
      return;
    }
    // D-Chat NO support piece
    String? supportPiece = data[MessageData.K_CONTACT_PIECE_SUPPORT]?.toString();
    if (supportPiece?.isNotEmpty == true) {
      contactCommon.setSupportPiece(received.from, value: supportPiece); // await
    }
    // D-Chat NO RequestType.header
    String? requestType = data['requestType']?.toString();
    String? responseType = data['responseType']?.toString();
    String? version = data['version']?.toString();
    Map<String, dynamic>? content = data['content'];
    if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
      // need reply
      if (requestType == RequestType.header) {
        await chatOutCommon.sendContactResponse(exist, RequestType.header);
      } else {
        await chatOutCommon.sendContactResponse(exist, RequestType.full);
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
        if (responseType != RequestType.full && content == null) {
          await chatOutCommon.sendContactRequest(exist, RequestType.full);
        } else {
          if (content == null) {
            logger.w("$TAG - receiveContact - content is empty - data:$data");
            return;
          }
          String firstName = content['first_name'] ?? content['name'] ?? "";
          String lastName = content['last_name'] ?? "";
          File? avatar;
          String? avatarType = content['avatar'] != null ? content['avatar']['type'] : null;
          if (avatarType?.isNotEmpty == true) {
            String? avatarData = content['avatar'] != null ? content['avatar']['data'] : null;
            if (avatarData?.isNotEmpty == true) {
              if (avatarData.toString().split(",").length != 1) {
                avatarData = avatarData.toString().split(",")[1];
              }
              avatar = await FileHelper.convertBase64toFile(avatarData, SubDirType.contact, extension: "jpg");
            }
          }
          await contactCommon.setOtherProfile(exist, firstName, lastName, avatar?.path ?? "", version, notify: true);
          logger.i("$TAG - receiveContact - setProfile - firstName:$firstName - avatar:${avatar?.path} - version:$version - data:$data");
        }
      } else {
        logger.d("$TAG - receiveContact - profileVersionSame - contact:$exist - data:$data");
      }
    }
  }

  // NO DB NO display
  Future _receivePiece(MessageSchema received) async {
    // duplicated
    List<MessageSchema> existsCombine = await _messageStorage.queryListByType(received.msgId, received.parentType);
    if (existsCombine.isNotEmpty) {
      logger.d("$TAG - receivePiece - duplicated - schema:$existsCombine");
      return;
    }
    // piece
    MessageSchema? piece = await _messageStorage.queryByPid(received.pid);
    if (piece == null) {
      received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.cache, extension: received.parentType);
      piece = await _messageStorage.insert(received);
    }
    if (piece == null) return;
    // pieces
    int total = piece.total ?? ChatOutCommon.maxPiecesTotal;
    int parity = piece.parity ?? (total ~/ ChatOutCommon.piecesParity);
    int bytesLength = piece.bytesLength ?? 0;
    int piecesCount = await _messageStorage.queryCountByType(piece.msgId, piece.contentType);
    logger.d("$TAG - receivePiece - progress:$piecesCount/${piece.total}/${total + parity}");
    if (piecesCount < total || bytesLength <= 0) return;
    logger.d("$TAG - receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema> pieces = await _messageStorage.queryListByType(piece.msgId, piece.contentType);
    pieces.sort((prev, next) => (prev.index ?? ChatOutCommon.maxPiecesTotal).compareTo((next.index ?? ChatOutCommon.maxPiecesTotal)));
    // recover
    List<Uint8List> recoverList = <Uint8List>[];
    for (int index = 0; index < total + parity; index++) {
      recoverList.add(Uint8List(0)); // fill
    }
    int recoverCount = 0;
    for (int index = 0; index < pieces.length; index++) {
      MessageSchema item = pieces[index];
      File? file = item.content as File?;
      if (file == null || !file.existsSync()) {
        logger.w("$TAG - receivePiece - COMBINE:ERROR - file no exists - item:$item - file:${file?.path}");
        continue;
      }
      Uint8List itemBytes = file.readAsBytesSync();
      if (item.index != null && item.index! >= 0 && item.index! < recoverList.length) {
        recoverList[item.index!] = itemBytes;
        recoverCount++;
      }
    }
    if (recoverCount < total) {
      logger.w("$TAG - receivePiece - COMBINE:FAIL - recover_lost:${pieces.length - recoverCount}");
      return;
    }
    // combine
    String? base64String = await Common.combinePieces(recoverList, total, parity, bytesLength);
    if (base64String == null || base64String.isEmpty) {
      logger.w("$TAG - receivePiece - COMBINE:FAIL - base64String is empty");
      return;
    }
    MessageSchema combine = MessageSchema.fromPieces(pieces, base64String);
    // combine.content - handle later
    logger.d("$TAG - receivePiece - COMBINE:SUCCESS - combine:$combine");
    await onClientMessage(combine, needWait: true);
    // delete
    logger.d("$TAG - receivePiece - DELETE:START - pieces_count:${pieces.length}");
    bool deleted = await _messageStorage.deleteByType(piece.msgId, piece.contentType);
    if (deleted) {
      pieces.forEach((MessageSchema element) {
        if (element.content is File) {
          if ((element.content as File).existsSync()) {
            (element.content as File).delete(); // await
            logger.d("$TAG - receivePiece - DELETE:PROGRESS - path:${(element.content as File).path}");
          } else {
            logger.w("$TAG - receivePiece - DELETE:ERROR - NoExists - path:${(element.content as File).path}");
          }
        } else {
          logger.w("$TAG - receivePiece - DELETE:ERROR - empty:${element.content?.toString()}");
        }
      });
      logger.d("$TAG - receivePiece - DELETE:SUCCESS - count:${pieces.length}");
    } else {
      logger.w("$TAG - receivePiece - DELETE:FAIL - empty - pieces:$pieces");
    }
  }

  Future _receiveText(MessageSchema received, {ContactSchema? contact}) async {
    // duplicated
    List<MessageSchema> exists = await _messageStorage.queryList(received.msgId);
    if (exists.isNotEmpty) {
      logger.d("$TAG - receiveText - duplicated - schema:$exists");
      return;
    }
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // display
    _onSavedSink.add(schema);
  }

  Future _receiveImage(MessageSchema received, {ContactSchema? contact}) async {
    bool isPieceCombine = received.options != null ? received.options![MessageOptions.KEY_PARENT_PIECE] : false;
    // duplicated
    List<MessageSchema> exists = [];
    if (isPieceCombine) {
      exists = await _messageStorage.queryListByType(received.msgId, received.contentType);
    } else {
      // SUPPORT:START
      exists = await _messageStorage.queryList(received.msgId); // old version will send type nknImage/media/image
      // SUPPORT:END
    }
    if (exists.isNotEmpty) {
      logger.d("$TAG - receiveImage - duplicated - schema:$exists");
      return;
    }
    // File
    received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.chat, extension: isPieceCombine ? "jpg" : null);
    if (received.content == null) return;
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // display
    _onSavedSink.add(schema);
  }

  // NO topic (1 to 1)
  Future _receiveContactOptions(MessageSchema received, {ContactSchema? contact}) async {
    if (received.content == null) return;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? existContact = contact ?? await contactCommon.queryByClientAddress(received.from);
    if (existContact == null) {
      logger.w("$TAG - _receiveContactOptions - empty - received:$received");
      return;
    }
    List<MessageSchema> existsMsg = await _messageStorage.queryList(received.msgId);
    if (existsMsg.isNotEmpty) {
      logger.d("$TAG - receiveText - duplicated - schema:$existsMsg");
      return;
    }
    // options type
    String? optionsType = data[MessageData.K_CONTACT_OPTIONS_TYPE]?.toString();
    Map<String, dynamic> content = data['content'] ?? Map();
    if (optionsType == null || optionsType.isEmpty) return;
    if (optionsType == MessageData.V_CONTACT_OPTIONS_TYPE_BURN_TIME) {
      int seconds = (content['deleteAfterSeconds'] as int?) ?? 0;
      logger.i("$TAG - _receiveContactOptions - setBurn - seconds:$seconds - data:$data");
      contactCommon.setOptionsBurn(existContact, seconds, notify: true); // await
    } else if (optionsType == MessageData.V_CONTACT_OPTIONS_TYPE_DEVICE_TOKEN) {
      String deviceToken = (content['deviceToken']?.toString()) ?? "";
      logger.i("$TAG - _receiveContactOptions - setDeviceToken - deviceToken:$deviceToken - data:$data");
      contactCommon.setDeviceToken(existContact.id, deviceToken, notify: true); // await
    } else {
      logger.w("$TAG - _receiveContactOptions - setNothing - data:$data");
      return;
    }
    // DB
    MessageSchema? schema = await _messageStorage.insert(received);
    if (schema == null) return;
    // display
    _onSavedSink.add(schema);
  }
}
