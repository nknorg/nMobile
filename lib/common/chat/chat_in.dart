import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class ChatInCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onReceiveController = StreamController<MessageSchema>(); //.broadcast();
  StreamSink<MessageSchema> get _onReceiveSink => _onReceiveController.sink;
  Stream<MessageSchema> get _onReceiveStream => _onReceiveController.stream.distinct((prev, next) => prev.pid == next.pid);

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

  MessageStorage _messageStorage = MessageStorage();

  ChatInCommon() {
    start();
  }

  Future onClientMessage(MessageSchema? message, {bool needWait = false}) async {
    if (message == null) return;
    // topic msg published callback can be used receipt
    if (message.isTopic && !message.isOutbound && (message.from == message.to || message.from == clientCommon.address)) {
      message.contentType = MessageContentType.receipt;
      message.content = message.msgId;
    }
    // message
    if (needWait) {
      await _messageHandle(message);
    } else {
      _onReceiveSink.add(message);
    }
  }

  Future start() async {
    await for (MessageSchema received in _onReceiveStream) {
      try {
        await _messageHandle(received);
      } catch (e) {
        handleError(e);
      }
    }
  }

  Future _messageHandle(MessageSchema received) async {
    // contact
    ContactSchema? contact = await chatCommon.contactHandle(received);
    DeviceInfoSchema? deviceInfo = await chatCommon.deviceInfoHandle(received, contact);
    // topic
    TopicSchema? topic = await chatCommon.topicHandle(received);
    SubscriberSchema? subscriber = await chatCommon.subscriberHandle(received, topic, deviceInfo: deviceInfo);
    if (topic != null && subscriber != null) {
      if (topic.joined != true) {
        logger.w("$TAG - _messageHandle - deny message - topic unsubscribe - subscriber:$subscriber - topic:$topic");
        return;
      } else if (received.isTopicAction) {
        logger.i("$TAG - _messageHandle - accept message - just action - subscriber:$subscriber - topic:$topic");
      } else if (subscriber.status == SubscriberStatus.Subscribed) {
        logger.v("$TAG - _messageHandle - receive message - subscriber ok permission - subscriber:$subscriber - topic:$topic");
      } else {
        // joined + message(content) + noSubscribe
        // SUPPORT:START
        if (!deviceInfoCommon.isTopicPermissionEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
          if (subscriber.status == SubscriberStatus.None) {
            logger.i("$TAG - _messageHandle - accept message - subscriber maybe ok permission (old version) - subscriber:$subscriber - topic:$topic");
          } else {
            logger.w("$TAG - _messageHandle - deny message - subscriber no permission (old version) - subscriber:$subscriber - topic:$topic");
            return;
          }
        } else {
          // SUPPORT:END
          logger.w("$TAG - _messageHandle - deny message - subscriber no permission - subscriber:$subscriber - topic:$topic");
          return;
        }
      }
    }
    // session
    await chatCommon.sessionHandle(received); // must await
    // message
    bool receiveOk = false;
    switch (received.contentType) {
      case MessageContentType.ping:
        _receivePing(received); // await
        break;
      case MessageContentType.receipt:
        receiveOk = await _receiveReceipt(received);
        break;
      case MessageContentType.read:
        receiveOk = await _receiveRead(received);
        break;
      case MessageContentType.contact:
        _receiveContact(received, contact: contact); // await
        break;
      case MessageContentType.contactOptions:
        receiveOk = await _receiveContactOptions(received, contact: contact);
        break;
      case MessageContentType.deviceRequest:
        _receiveDeviceRequest(received, contact: contact); // await
        break;
      case MessageContentType.deviceInfo:
        _receiveDeviceInfo(received, contact: contact); // await
        break;
      case MessageContentType.text:
      case MessageContentType.textExtension:
        receiveOk = await _receiveText(received);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        receiveOk = await _receiveImage(received);
        break;
      case MessageContentType.audio:
        receiveOk = await _receiveAudio(received);
        break;
      case MessageContentType.piece:
        receiveOk = await _receivePiece(received);
        break;
      case MessageContentType.topicSubscribe:
        receiveOk = await _receiveTopicSubscribe(received);
        break;
      case MessageContentType.topicUnsubscribe:
        receiveOk = await _receiveTopicUnsubscribe(received);
        break;
      case MessageContentType.topicInvitation:
        receiveOk = await _receiveTopicInvitation(received);
        break;
      case MessageContentType.topicKickOut:
        receiveOk = await _receiveTopicKickOut(received);
        break;
    }

    // receipt
    if (!received.isTopic && received.canDisplay) {
      chatOutCommon.sendReceipt(received); // await
    }
    // status (not handle in messages screen)
    if (received.isTopic) {
      if (received.contentType != MessageContentType.piece && received.status != MessageStatus.Read) {
        chatCommon.updateMessageStatus(received, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false); // await
      }
    } else if (!received.canRead) {
      if (received.contentType != MessageContentType.piece && received.status != MessageStatus.Read) {
        chatCommon.updateMessageStatus(received, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false); // await
      }
    }
    // badge
    if (received.canRead) {
      bool skipBadgeUp = (chatCommon.currentChatTargetId == received.targetId) && (application.appLifecycleState == AppLifecycleState.resumed);
      if (receiveOk && !skipBadgeUp) {
        Badge.onCountUp(1); // await
      }
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receivePing(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    if (received.from == received.to || received.from == clientCommon.address) {
      logger.i("$TAG - _receivePing - ping self receive - received:$received");
      await clientCommon.pingSuccess();
      return true;
    }
    if (received.content! is String) {
      logger.w("$TAG - _receivePing - content type error - received:$received");
      return false;
    }
    String content = received.content as String;
    if (content == "ping") {
      logger.i("$TAG - _receivePing - replay others ping - received:$received");
      await chatOutCommon.sendPing(received.from, false);
    } else if (content == "pong") {
      logger.i("$TAG - _receivePing - receive others ping - received:$received");
      // TODO:GG check received.sendAt?
      // TODO:GG other client status?
    } else {
      logger.w("$TAG - _receivePing - content content error - received:$received");
      return false;
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveReceipt(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    MessageSchema? exists = await _messageStorage.query(received.content);
    if (exists == null) {
      logger.w("$TAG - _receiveReceipt - target is empty - received:$received");
      return false;
    } else if (exists.status == MessageStatus.SendReceipt || exists.status == MessageStatus.Read) {
      logger.d("$TAG - receiveReceipt - duplicated - exists:$exists");
      return false;
    }

    // deviceInfo
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(received.from);
    bool readEnable = deviceInfoCommon.isMsgReadEnable(deviceInfo?.platform, deviceInfo?.appVersion);

    // status
    int status = (exists.isTopic || received.receiveAt != null || !readEnable) ? MessageStatus.Read : MessageStatus.SendReceipt;
    exists = await chatCommon.updateMessageStatus(exists, status, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: true);

    // topicInvitation
    if (exists.contentType == MessageContentType.topicInvitation) {
      subscriberCommon.onInvitedReceipt(exists.content, received.from); // await
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveRead(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    String targetId = received.from;
    List? readIds = (received.content as List?);
    if (targetId.isEmpty || readIds == null || readIds.isEmpty) {
      logger.w("$TAG - _receiveRead - targetId or content type error - received:$received");
      return false;
    }

    // messages
    List<MessageSchema> msgList = [];
    List<Future> futures = [];
    readIds.forEach((element) {
      futures.add(_messageStorage.query(element).then((value) {
        if (value == null) {
          logger.w("$TAG - _receiveRead - message is empty - msgId:$element");
        } else if (value.status == MessageStatus.Read) {
          logger.i("$TAG - _receiveRead - message already read - message:$value");
        } else {
          logger.d("$TAG - _receiveRead - message none read - message:$value");
          msgList.add(value);
        }
        return;
      }));
    });
    await Future.wait(futures);

    // status
    futures.clear();
    msgList.forEach((element) {
      futures.add(chatCommon.updateMessageStatus(element, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: true));
    });
    await Future.wait(futures);
    return true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> _receiveContact(MessageSchema received, {ContactSchema? contact}) async {
    if (received.content == null) return false;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? exist = contact ?? await received.getSender(emptyAdd: true);
    if (exist == null) {
      logger.w("$TAG - receiveContact - empty - data:$data");
      return false;
    }
    // D-Chat NO support piece
    // String? supportPiece = data['onePieceReady']?.toString();
    // if (supportPiece?.isNotEmpty == true) {
    //   contactCommon.setSupportPiece(received.from, value: supportPiece); // await
    // }
    // D-Chat NO RequestType.header
    String? requestType = data['requestType']?.toString();
    String? responseType = data['responseType']?.toString();
    String? version = data['version']?.toString();
    Map<String, dynamic>? content = data['content'];
    if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
      // need reply
      if (requestType == RequestType.header) {
        chatOutCommon.sendContactResponse(exist, RequestType.header); // await
      } else {
        chatOutCommon.sendContactResponse(exist, RequestType.full); // await
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
        if (responseType != RequestType.full && content == null) {
          chatOutCommon.sendContactRequest(exist, RequestType.full); // await
        } else {
          if (content == null) {
            logger.w("$TAG - receiveContact - content is empty - data:$data");
            return false;
          }
          String? firstName = content['first_name'] ?? content['name'];
          String? lastName = content['last_name'];
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
          // if (firstName.isEmpty || lastName.isEmpty || (avatar?.path ?? "").isEmpty) {
          //   logger.i("$TAG - receiveContact - setProfile - NULL");
          // } else {
          contactCommon.setOtherProfile(exist, firstName, lastName, Path.getLocalFile(avatar?.path), version, notify: true); // await
          logger.i("$TAG - receiveContact - setProfile - firstName:$firstName - avatar:${avatar?.path} - version:$version - data:$data");
          // }
        }
      } else {
        logger.d("$TAG - receiveContact - profile version same - contact:$exist - data:$data");
      }
    }
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveContactOptions(MessageSchema received, {ContactSchema? contact}) async {
    if (received.content == null) return false; // received.isTopic (limit in out)
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? existContact = contact ?? await received.getSender(emptyAdd: true);
    if (existContact == null) {
      logger.w("$TAG - _receiveContactOptions - empty - received:$received");
      return false;
    }
    MessageSchema? exists = await _messageStorage.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveContactOptions - duplicated - message:$exists");
      return false;
    }
    // options type
    String? optionsType = data['optionType']?.toString();
    Map<String, dynamic> content = data['content'] ?? Map();
    if (optionsType == null || optionsType.isEmpty) return false;
    if (optionsType == '0') {
      int burningSeconds = (content['deleteAfterSeconds'] as int?) ?? 0;
      int updateAt = ((content['updateBurnAfterAt'] ?? content['updateBurnAfterTime']) as int?) ?? DateTime.now().millisecondsSinceEpoch;
      logger.d("$TAG - _receiveContactOptions - setBurn - burningSeconds:$burningSeconds - updateAt:${DateTime.fromMillisecondsSinceEpoch(updateAt)} - data:$data");
      contactCommon.setOptionsBurn(existContact, burningSeconds, updateAt, notify: true); // await
    } else if (optionsType == '1') {
      String deviceToken = (content['deviceToken']?.toString()) ?? "";
      logger.d("$TAG - _receiveContactOptions - setDeviceToken - deviceToken:$deviceToken - data:$data");
      contactCommon.setDeviceToken(existContact.id, deviceToken, notify: true); // await
    } else {
      logger.w("$TAG - _receiveContactOptions - setNothing - data:$data");
      return false;
    }
    // DB
    MessageSchema? inserted = await _messageStorage.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceRequest(MessageSchema received, {ContactSchema? contact}) async {
    ContactSchema? exist = contact ?? await received.getSender(emptyAdd: true);
    if (exist == null) {
      logger.w("$TAG - _receiveDeviceRequest - contact - empty - data:${received.content}");
      return false;
    }
    chatOutCommon.sendDeviceInfo(exist.clientAddress); // await
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceInfo(MessageSchema received, {ContactSchema? contact}) async {
    if (received.content == null) return false;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? exist = contact ?? await received.getSender(emptyAdd: true);
    if (exist == null || exist.id == null) {
      logger.w("$TAG - _receiveDeviceInfo - contact - empty - received:$received");
      return false;
    }
    DeviceInfoSchema message = DeviceInfoSchema(
      contactAddress: exist.clientAddress,
      deviceId: data["deviceId"],
      data: {
        'appName': data["appName"],
        'appVersion': data["appVersion"],
        'platform': data["platform"],
        'platformVersion': data["platformVersion"],
      },
    );
    logger.d("$TAG - _receiveDeviceInfo - addOrUpdate - message:$message - data:$data");
    deviceInfoCommon.set(message); // await
    return true;
  }

  Future<bool> _receiveText(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await _messageStorage.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - receiveText - duplicated - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await _messageStorage.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveImage(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await _messageStorage.queryByNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - receiveImage - duplicated - message:$exists");
      return false;
    }
    // File
    bool isPieceCombine = received.options != null ? (received.options![MessageOptions.KEY_FROM_PIECE] ?? false) : false;
    received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.chat, extension: isPieceCombine ? "jpg" : null, chatTarget: received.from);
    if (received.content == null) {
      logger.w("$TAG - receiveImage - content is null - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await _messageStorage.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveAudio(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await _messageStorage.queryByNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - receiveAudio - duplicated - message:$exists");
      return false;
    }
    // File
    bool isPieceCombine = received.options != null ? (received.options![MessageOptions.KEY_FROM_PIECE] ?? false) : false;
    received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.chat, extension: isPieceCombine ? "aac" : null, chatTarget: received.from);
    if (received.content == null) {
      logger.w("$TAG - receiveAudio - content is null - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await _messageStorage.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receivePiece(MessageSchema received) async {
    String? parentType = received.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARENT_TYPE];
    int bytesLength = received.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_BYTES_LENGTH] ?? 0;
    int total = received.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_TOTAL] ?? 1;
    int parity = received.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_PARITY] ?? 1;
    int index = received.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 1;
    // combined duplicated
    List<MessageSchema> existsCombine = await _messageStorage.queryListByContentType(received.msgId, parentType);
    if (existsCombine.isNotEmpty) {
      logger.d("$TAG - receivePiece - duplicated - index:$index - message:$existsCombine");
      if (index <= 1) {
        chatOutCommon.sendReceipt(existsCombine[0]); // await
      }
      return false;
    }
    // piece
    MessageSchema? piece = await _messageStorage.queryByPid(received.pid);
    if (piece == null) {
      received.status = MessageStatus.Read;
      received.receiveAt = DateTime.now().millisecondsSinceEpoch;
      received.content = await FileHelper.convertBase64toFile(received.content, SubDirType.cache, extension: parentType);
      piece = await _messageStorage.insert(received);
    } else {
      int existIndex = piece.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 1;
      if (existIndex == index) {
        logger.d("$TAG - receivePiece - duplicated - receive:$received - exist:$piece");
        return false;
      }
    }
    if (piece == null) {
      logger.w("$TAG - receivePiece - piece is null - message:$received");
      return false;
    }
    // pieces
    int piecesCount = await _messageStorage.queryCountByContentType(piece.msgId, piece.contentType);
    logger.v("$TAG - receivePiece - progress:$total/$piecesCount/${total + parity}");
    if (piecesCount < total || bytesLength <= 0) return false;
    logger.i("$TAG - receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema> pieces = await _messageStorage.queryListByContentType(piece.msgId, piece.contentType);
    pieces.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    // recover
    List<Uint8List> recoverList = <Uint8List>[];
    for (int i = 0; i < (total + parity); i++) {
      recoverList.add(Uint8List(0)); // fill
    }
    int recoverCount = 0;
    for (int i = 0; i < pieces.length; i++) {
      MessageSchema item = pieces[i];
      File? file = item.content as File?;
      if (file == null || !file.existsSync()) {
        logger.e("$TAG - receivePiece - COMBINE:ERROR - file no exists - item:$item - file:${file?.path}");
        continue;
      }
      Uint8List itemBytes = file.readAsBytesSync();
      int? pieceIndex = item.options?[MessageOptions.KEY_PIECE]?[MessageOptions.KEY_PIECE_INDEX];
      if (pieceIndex != null && pieceIndex >= 0 && pieceIndex < recoverList.length) {
        recoverList[pieceIndex] = itemBytes;
        recoverCount++;
      }
    }
    if (recoverCount < total) {
      logger.w("$TAG - receivePiece - COMBINE:FAIL - recover_lost:${pieces.length - recoverCount}");
      return false;
    }
    // combine
    String? base64String = await Common.combinePieces(recoverList, total, parity, bytesLength);
    if (base64String == null || base64String.isEmpty) {
      logger.e("$TAG - receivePiece - COMBINE:FAIL - base64String is empty");
      return false;
    }
    MessageSchema? combine = MessageSchema.fromPiecesReceive(pieces, base64String);
    if (combine == null) {
      logger.e("$TAG - receivePiece - COMBINE:FAIL - message combine is empty");
      return false;
    }
    // combine.content - handle later
    logger.i("$TAG - receivePiece - COMBINE:SUCCESS - combine:$combine");
    await onClientMessage(combine, needWait: true);
    // delete
    logger.i("$TAG - receivePiece - DELETE:START - pieces_count:${pieces.length}");
    bool deleted = await _messageStorage.deleteByContentType(piece.msgId, piece.contentType);
    if (deleted) {
      pieces.forEach((MessageSchema element) {
        if (element.content is File) {
          if ((element.content as File).existsSync()) {
            (element.content as File).delete(); // await
            // logger.v("$TAG - receivePiece - DELETE:PROGRESS - path:${(element.content as File).path}");
          } else {
            logger.e("$TAG - receivePiece - DELETE:ERROR - NoExists - path:${(element.content as File).path}");
          }
        } else {
          logger.e("$TAG - receivePiece - DELETE:ERROR - empty:${element.content?.toString()}");
        }
      });
      logger.i("$TAG - receivePiece - DELETE:SUCCESS - count:${pieces.length}");
    } else {
      logger.w("$TAG - receivePiece - DELETE:FAIL - empty - pieces:$pieces");
    }
    return true;
  }

  // NO single
  Future<bool> _receiveTopicSubscribe(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await _messageStorage.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveTopicSubscribe - duplicated - message:$exists");
      return false;
    }
    // subscriber
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(received.topic, received.from);
    bool historySubscribed = _subscriber?.status == SubscriberStatus.Subscribed;
    topicCommon.onSubscribe(received.topic, received.from).then((value) async {
      if (!historySubscribed && value != null) {
        // DB
        MessageSchema? inserted = await _messageStorage.insert(received);
        if (inserted == null) return false;
        // display
        _onSavedSink.add(inserted);
      }
    });
    return true;
  }

  // NO single
  Future<bool> _receiveTopicUnsubscribe(MessageSchema received) async {
    topicCommon.onUnsubscribe(received.topic, received.from); // await
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveTopicInvitation(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await _messageStorage.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveTopicInvitation - duplicated - message:$exists");
      return false;
    }
    // permission checked in message click
    // DB
    MessageSchema? inserted = await _messageStorage.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO single
  Future<bool> _receiveTopicKickOut(MessageSchema received) async {
    topicCommon.onKickOut(received.topic, received.from, received.content); // await
    return true;
  }
}
