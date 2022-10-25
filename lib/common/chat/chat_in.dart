import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';

class ChatInCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

  // receive queue
  Map<String, Map<String, ParallelQueue>> _receiveQueues = Map();

  ChatInCommon();

  void clear() {}

  Future onMessageReceive(MessageSchema? message, {bool needFast = false}) async {
    if (message == null) {
      logger.e("$TAG - onMessageReceive - message is null - received:$message");
      return;
    } else if (message.targetId.isEmpty) {
      logger.e("$TAG - onMessageReceive - targetId is empty - received:$message");
      return;
    } else if (message.contentType.isEmpty) {
      logger.e("$TAG - onMessageReceive - contentType is empty - received:$message");
      return;
    }

    // topic msg published callback can be used receipt
    if ((message.isTopic || message.isPrivateGroup) && !message.isOutbound && ((message.from == message.to) || (message.from == clientCommon.address))) {
      if (message.contentType != MessageContentType.receipt) {
        if (message.from.isEmpty) message.from = clientCommon.address ?? message.to;
        if (message.to.isEmpty) message.to = clientCommon.address ?? message.from;
        message.contentType = MessageContentType.receipt;
        message.content = message.msgId;
      }
    }

    // queue
    if (_receiveQueues[message.targetId] == null) {
      _receiveQueues[message.targetId] = Map();
    }
    if (_receiveQueues[message.targetId]?[message.contentType] == null) {
      _receiveQueues[message.targetId]?[message.contentType] = ParallelQueue("chat_receive_${message.targetId}", onLog: (log, error) => error ? logger.w(log) : null);
    }
    _receiveQueues[message.targetId]?[message.contentType]?.add(() async {
      try {
        return await _handleMessage(message);
      } catch (e, st) {
        handleError(e, st);
      }
    }, id: message.msgId, priority: needFast);
  }

  Future _handleMessage(MessageSchema received) async {
    // contact
    ContactSchema? contact = await chatCommon.contactHandle(received);
    await chatCommon.deviceInfoHandle(received);

    // topic
    TopicSchema? topic = await chatCommon.topicHandle(received);
    if (topic != null) {
      if (topic.joined != true) {
        logger.w("$TAG - _handleMessage - topic - deny message - unsubscribe - topic:$topic");
        return;
      }
      SubscriberSchema? me = await subscriberCommon.queryByTopicChatId(topic.topic, clientCommon.address);
      if ((me == null) || (me.status != SubscriberStatus.Subscribed)) {
        logger.w("$TAG - _handleMessage - topic - deny message - me no permission - me:$me - topic:$topic");
        return;
      }
      if (!received.isTopicAction) {
        SubscriberSchema? sender = await chatCommon.subscriberHandle(received, topic);
        if ((sender == null) || (sender.status != SubscriberStatus.Subscribed)) {
          logger.w("$TAG - _handleMessage - topic - deny message - sender no permission - sender:$sender - topic:$topic");
          return;
        }
      }
    }

    // group
    PrivateGroupSchema? privateGroup = await chatCommon.privateGroupHandle(received);
    if (privateGroup != null) {
      if (received.isGroupAction) {
        // nothing
      } else {
        PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(privateGroup.groupId, clientCommon.address);
        if ((_me == null) || ((_me.permission ?? 0) <= PrivateGroupItemPerm.none)) {
          logger.w("$TAG - _handleMessage - group - deny message - me no permission - me:$_me - group:$privateGroup");
          return;
        }
        PrivateGroupItemSchema? _sender = await privateGroupCommon.queryGroupItem(privateGroup.groupId, received.from);
        if ((_sender == null) || ((_sender.permission ?? 0) <= PrivateGroupItemPerm.none)) {
          logger.w("$TAG - _handleMessage - group - deny message - sender no permission - sender:$_sender - group:$privateGroup");
          return;
        }
      }
    }

    // status
    received.status = received.canNotification ? received.status : MessageStatus.Read;

    // message
    bool insertOk = false;
    switch (received.contentType) {
      case MessageContentType.ping:
        await _receivePing(received); // need interval
        break;
      case MessageContentType.receipt:
        await _receiveReceipt(received);
        break;
      case MessageContentType.read:
        await _receiveRead(received);
        break;
      case MessageContentType.msgStatus:
        await _receiveMsgStatus(received); // need interval
        break;
      case MessageContentType.contactProfile:
        await _receiveContact(received, contact: contact);
        break;
      case MessageContentType.contactOptions:
        insertOk = await _receiveContactOptions(received, contact: contact);
        break;
      case MessageContentType.deviceRequest:
        await _receiveDeviceRequest(received, contact: contact); // need interval
        break;
      case MessageContentType.deviceResponse:
        await _receiveDeviceInfo(received, contact: contact);
        break;
      case MessageContentType.text:
      case MessageContentType.textExtension:
        insertOk = await _receiveText(received);
        break;
      case MessageContentType.ipfs:
        insertOk = await _receiveIpfs(received);
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        insertOk = await _receiveImage(received);
        break;
      case MessageContentType.audio:
        insertOk = await _receiveAudio(received);
        break;
      case MessageContentType.piece:
        insertOk = await _receivePiece(received);
        break;
      case MessageContentType.topicSubscribe:
        insertOk = await _receiveTopicSubscribe(received);
        break;
      case MessageContentType.topicUnsubscribe:
        await _receiveTopicUnsubscribe(received);
        break;
      case MessageContentType.topicInvitation:
        insertOk = await _receiveTopicInvitation(received);
        break;
      case MessageContentType.topicKickOut:
        await _receiveTopicKickOut(received);
        break;
      case MessageContentType.privateGroupInvitation:
        insertOk = await _receivePrivateGroupInvitation(received);
        break;
      case MessageContentType.privateGroupAccept:
        await _receivePrivateGroupAccept(received);
        break;
      case MessageContentType.privateGroupOptionRequest:
        await _receivePrivateGroupOptionRequest(received);
        break;
      case MessageContentType.privateGroupOptionResponse:
        await _receivePrivateGroupOptionResponse(received);
        break;
      case MessageContentType.privateGroupMemberRequest:
        await _receivePrivateGroupMemberRequest(received);
        break;
      case MessageContentType.privateGroupMemberResponse:
        await _receivePrivateGroupMemberResponse(received);
        break;
    }

    // session
    if (insertOk && received.canDisplay) {
      await chatCommon.sessionHandle(received); // must await
    }

    // receipt (no judge insertOk, maybe just want reply receipt)
    if (received.canReceipt) {
      if (received.isTopic) {
        // handle in send topic with self receipt
      } else if (received.isPrivateGroup) {
        // handle in send group with self receipt
      } else {
        chatOutCommon.sendReceipt(received); // await
      }
    }

    // badge
    bool skipBadgeUp = (chatCommon.currentChatTargetId == received.targetId) && (application.appLifecycleState == AppLifecycleState.resumed);
    if (insertOk && received.canNotification && !skipBadgeUp) {
      Badge.onCountUp(1); // await
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receivePing(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    if (received.from == received.to || received.from == clientCommon.address) {
      logger.i("$TAG - _receivePing - ping self receive - received:$received");
      clientCommon.connectSuccess();
      return true;
    }
    if ((received.content == null) || !(received.content is String)) {
      logger.e("$TAG - _receivePing - content error - received:$received");
      return false;
    }
    String content = received.content as String;
    if (content == "ping") {
      logger.i("$TAG - _receivePing - receive pang - received:$received");
      await chatOutCommon.sendPing([received.from], false);
    } else if (content == "pong") {
      logger.i("$TAG - _receivePing - check resend - received:$received");
      if (!(received.isTopic || received.isPrivateGroup)) {
        chatCommon.checkMsgStatus(received.targetId, false); // await
      }
    } else {
      logger.e("$TAG - _receivePing - content content error - received:$received");
      return false;
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveReceipt(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out, just receive self msg)
    if ((received.content == null) || !(received.content is String)) return false;
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.content, MessageContentType.piece);
    if (exists == null || exists.targetId.isEmpty) {
      logger.w("$TAG - _receiveReceipt - target is empty - received:$received");
      return false;
    } else if ((exists.status == MessageStatus.SendReceipt) || (exists.status == MessageStatus.Read)) {
      logger.d("$TAG - receiveReceipt - duplicated - exists:$exists");
      return false;
    } else if ((exists.isTopic || exists.isPrivateGroup) && !((received.from == received.to) && (received.from == clientCommon.address))) {
      logger.d("$TAG - receiveReceipt - topic skip others - exists:$exists");
      return false;
    }

    // deviceInfo
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.queryLatest(received.from);
    bool readSupport = DeviceInfoCommon.isMsgReadEnable(deviceInfo?.platform, deviceInfo?.appVersion);

    // status
    if (exists.isTopic || exists.isPrivateGroup || (received.receiveAt != null) || !readSupport) {
      await chatCommon.updateMessageStatus(exists, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: true);
      // if (!exists.isTopic) {
      //   int reallySendAt = received.sendAt ?? 0;
      //   await chatCommon.readMessageBySide(received.targetId, received.topic, reallySendAt);
      // }
    } else {
      await chatCommon.updateMessageStatus(exists, MessageStatus.SendReceipt, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: true);
    }

    // topicInvitation
    if (exists.contentType == MessageContentType.topicInvitation) {
      await subscriberCommon.onInvitedReceipt(exists.content, received.from);
    }

    // check msgStatus
    if (!(exists.isTopic || exists.isPrivateGroup) && (received.from != received.to) && (received.from != clientCommon.address)) {
      chatCommon.checkMsgStatus(exists.targetId, false); // await
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveRead(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    String targetId = received.from;
    List? readIds = (received.content as List?);
    if (targetId.isEmpty || readIds == null || readIds.isEmpty) {
      logger.e("$TAG - _receiveRead - targetId or content type error - received:$received");
      return false;
    }

    // messages
    List<String> msgIds = readIds.map((e) => e?.toString() ?? "").toList();
    List<MessageSchema> msgList = await MessageStorage.instance.queryListByIdsNoContentType(msgIds, MessageContentType.piece);
    if (msgList.isEmpty) return true;

    // update
    for (var i = 0; i < msgList.length; i++) {
      MessageSchema message = msgList[i];
      int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
      await chatCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }

    // read history
    msgList.sort((prev, next) => (prev.sendAt ?? 0).compareTo(next.sendAt ?? 0));
    int reallySendAt = msgList[msgList.length - 1].sendAt ?? 0;
    await chatCommon.readMessageBySide(received.targetId, received.topic, reallySendAt);

    // check msgStatus
    // if (!exists.isTopic && (received.from != received.to) && (received.from != clientCommon.address)) {
    //   chatCommon.setMsgStatusCheckTimer(received.targetId, false, refresh: true, filterSec: 10); // await
    // }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveMsgStatus(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? requestType = data['requestType']?.toString();
    List messageIds = data['messageIds'] ?? [];
    if (messageIds.isEmpty) {
      logger.e("$TAG - _receiveMsgStatus - messageIds empty - requestType:$requestType - messageIds:$messageIds - received:$received");
      return false;
    }

    if (requestType == "ask") {
      // receive ask
      List<String> msgIds = messageIds.map((e) => e?.toString() ?? "").toList();
      List<MessageSchema> messageList = await MessageStorage.instance.queryListByIdsNoContentType(msgIds, MessageContentType.piece);
      List<String> msgStatusList = [];
      for (var i = 0; i < messageIds.length; i++) {
        String msgId = messageIds[i];
        if (msgId.isEmpty) continue;
        int findIndex = messageList.indexWhere((element) => element.msgId == msgId);
        MessageSchema? message = findIndex >= 0 ? messageList[findIndex] : null;
        if (message != null) {
          msgStatusList.add("$msgId:${message.status}");
        } else {
          msgStatusList.add("$msgId:${null}");
        }
      }
      // send reply
      logger.i("$TAG - _receiveMsgStatus - send reply - targetId:${received.from} - msgList:$msgStatusList");
      await chatOutCommon.sendMsgStatus(received.from, false, msgStatusList);
    } else if (requestType == "reply") {
      // receive reply
      for (var i = 0; i < messageIds.length; i++) {
        String combineId = messageIds[i];
        if (combineId.isEmpty) {
          logger.e("$TAG - _receiveMsgStatus - combineId is empty - received:$received");
          continue;
        }
        List<String> splits = combineId.split(":");
        String msgId = splits.length > 0 ? splits[0] : "";
        if (msgId.isEmpty) {
          logger.e("$TAG - _receiveMsgStatus - msgId is empty - received:$received");
          continue;
        }
        MessageSchema? message = await MessageStorage.instance.queryByIdNoContentType(msgId, MessageContentType.piece);
        if (message == null) {
          logger.e("$TAG - _receiveMsgStatus - message no exists - msgId:$msgId - received:$received");
          continue;
        }
        int? status = int.tryParse(splits[1]);
        if ((status == null) || (status == 0)) {
          // resend msg
          int? resendAt = MessageOptions.getResendMuteAt(message.options);
          int between = DateTime.now().millisecondsSinceEpoch - (resendAt ?? DateTime.now().millisecondsSinceEpoch);
          if ((resendAt != null) && (between < 5 * 60 * 1000)) {
            logger.i("$TAG - _receiveMsgStatus - resend just now - between:${between / 1000} - msgId:$msgId - received:$received");
            continue;
          }
          logger.i("$TAG - _receiveMsgStatus - msg resend - status:$status - between:${between / 1000} - received:$received");
          message.options = MessageOptions.setResendMuteAt(message.options, DateTime.now().millisecondsSinceEpoch);
          await MessageStorage.instance.updateOptions(msgId, message.options);
          chatOutCommon.resendMute(message); // await
        } else {
          // update status
          int reallyStatus = (status == MessageStatus.Read) ? MessageStatus.Read : MessageStatus.SendReceipt;
          int? receiveAt = ((reallyStatus == MessageStatus.Read) && (message.receiveAt == null)) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          logger.i("$TAG - _receiveMsgStatus - msg update status - status:$reallyStatus - receiveAt:$receiveAt - received:$received");
          await chatCommon.updateMessageStatus(message, reallyStatus, receiveAt: receiveAt, notify: true);
        }
      }
    } else {
      logger.e("$TAG - _receiveMsgStatus - requestType error - requestType:$requestType - messageIds:$messageIds - received:$received");
      return false;
    }
    return true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> _receiveContact(MessageSchema received, {ContactSchema? contact}) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? exist = contact ?? await received.getSender(emptyAdd: true);
    if (exist == null) {
      logger.e("$TAG - receiveContact - contact is empty - data:$data");
      return false;
    }
    // D-Chat NO RequestType.header
    String? requestType = data['requestType']?.toString();
    String? responseType = data['responseType']?.toString();
    String? version = data['version']?.toString();
    Map<String, dynamic>? content = data['content'];
    if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
      // need reply
      if (requestType == RequestType.header) {
        chatOutCommon.sendContactResponse(exist.clientAddress, RequestType.header); // await
      } else {
        chatOutCommon.sendContactResponse(exist.clientAddress, RequestType.full); // await
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
        if (responseType != RequestType.full && content == null) {
          chatOutCommon.sendContactRequest(exist.clientAddress, RequestType.full, exist.profileVersion); // await
        } else {
          if (content == null) {
            logger.e("$TAG - receiveContact - content is empty - data:$data");
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
              String? fileExt = content['avatar'] != null ? content['avatar']['ext'] : FileHelper.DEFAULT_IMAGE_EXT;
              if (fileExt == null || fileExt.isEmpty) fileExt = FileHelper.DEFAULT_IMAGE_EXT;
              avatar = await FileHelper.convertBase64toFile(avatarData, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: received.targetId, fileExt: ext ?? fileExt));
            }
          }
          // if (firstName.isEmpty || lastName.isEmpty || (avatar?.path ?? "").isEmpty) {
          //   logger.i("$TAG - receiveContact - setProfile - NULL");
          // } else {
          await contactCommon.setOtherProfile(exist, version, Path.convert2Local(avatar?.path), firstName, lastName, notify: true);
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
    // received.isTopic (limit in out)
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    // duplicated
    ContactSchema? existContact = contact ?? await received.getSender(emptyAdd: true);
    if (existContact == null) {
      logger.w("$TAG - _receiveContactOptions - empty - received:$received");
      return false;
    }
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
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
      logger.i("$TAG - _receiveContactOptions - setBurning - burningSeconds:$burningSeconds - updateAt:${DateTime.fromMillisecondsSinceEpoch(updateAt)} - data:$data");
      await contactCommon.setOptionsBurn(existContact, burningSeconds, updateAt, notify: true);
    } else if (optionsType == '1') {
      String deviceToken = content['deviceToken']?.toString() ?? "";
      logger.i("$TAG - _receiveContactOptions - setDeviceToken - deviceToken:$deviceToken - data:$data");
      await contactCommon.setDeviceToken(existContact.id, deviceToken, notify: true);
    } else {
      logger.e("$TAG - _receiveContactOptions - setNothing - data:$data");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceRequest(MessageSchema received, {ContactSchema? contact}) async {
    ContactSchema? exist = contact ?? await received.getSender(emptyAdd: true);
    if (exist == null) {
      logger.w("$TAG - _receiveDeviceRequest - contact - empty - received:$received");
      return false;
    }
    chatOutCommon.sendDeviceInfo(exist.clientAddress); // await
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceInfo(MessageSchema received, {ContactSchema? contact}) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
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
    logger.i("$TAG - _receiveDeviceInfo - addOrUpdate - message:$message - data:$data");
    await deviceInfoCommon.set(message);
    return true;
  }

  Future<bool> _receiveText(MessageSchema received) async {
    if (received.content == null) {
      logger.e("$TAG - receiveText - content null - message:$received");
      return false;
    }
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - receiveText - duplicated - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveIpfs(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveIpfs - duplicated - message:$exists");
      return false;
    }
    // content
    String? fileExt = MessageOptions.getFileExt(received.options);
    String subPath = Uri.encodeComponent(received.targetId);
    if (subPath != received.targetId) subPath = "common"; // FUTURE:GG encode
    String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: fileExt);
    received.content = File(savePath);
    // state
    received.options = MessageOptions.setIpfsState(received.options, MessageOptions.ipfsStateNo);
    String? ipfsThumbnailHash = MessageOptions.getIpfsThumbnailHash(received.options);
    if (ipfsThumbnailHash != null && ipfsThumbnailHash.isNotEmpty) {
      received.options = MessageOptions.setIpfsThumbnailState(received.options, MessageOptions.ipfsThumbnailStateNo);
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    // thumbnail
    if (ipfsThumbnailHash != null && ipfsThumbnailHash.isNotEmpty) {
      chatCommon.tryDownloadIpfsThumbnail(inserted); // await
    }
    return true;
  }

  Future<bool> _receiveImage(MessageSchema received) async {
    if (received.content == null) {
      logger.e("$TAG - _receiveImage - content null - message:$received");
      return false;
    }
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - receiveImage - duplicated - message:$exists");
      return false;
    }
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_IMAGE_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_IMAGE_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - receiveImage - content is null - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    bool isPieceCombine = received.options?[MessageOptions.KEY_FROM_PIECE] ?? false;
    if (isPieceCombine) _deletePieces(received.msgId); // await
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveAudio(MessageSchema received) async {
    if (received.content == null) {
      logger.e("$TAG - _receiveAudio - content null - message:$received");
      return false;
    }
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - receiveAudio - duplicated - message:$exists");
      return false;
    }
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_AUDIO_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_AUDIO_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - receiveAudio - content is null - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    bool isPieceCombine = received.options?[MessageOptions.KEY_FROM_PIECE] ?? false;
    if (isPieceCombine) _deletePieces(received.msgId); // await
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receivePiece(MessageSchema received) async {
    String? parentType = received.options?[MessageOptions.KEY_PIECE_PARENT_TYPE];
    int bytesLength = received.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH] ?? 0;
    int total = received.options?[MessageOptions.KEY_PIECE_TOTAL] ?? 1;
    int parity = received.options?[MessageOptions.KEY_PIECE_PARITY] ?? 1;
    int index = received.options?[MessageOptions.KEY_PIECE_INDEX] ?? 1;
    // combined duplicated
    List<MessageSchema> existsCombine = await MessageStorage.instance.queryListByIdContentType(received.msgId, parentType, 1);
    if (existsCombine.isNotEmpty) {
      logger.d("$TAG - receivePiece - combine exists - index:$index - message:$existsCombine");
      // if (!received.isTopic && index <= 1) chatOutCommon.sendReceipt(existsCombine[0]); // await
      return false;
    }
    // piece
    List<MessageSchema> pieces = await MessageStorage.instance.queryListByIdContentType(received.msgId, MessageContentType.piece, total + parity);
    MessageSchema? piece;
    for (var i = 0; i < pieces.length; i++) {
      int? insertIndex = pieces[i].options?[MessageOptions.KEY_PIECE_INDEX];
      if (insertIndex == index) {
        piece = pieces[i];
        break;
      }
    }
    // add
    if (piece != null) {
      logger.d("$TAG - receivePiece - piece duplicated - receive:$received - exist:$piece");
    } else {
      // received.status = MessageStatus.Read; // modify in before
      received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.cache, fileExt: ext ?? parentType));
      piece = await MessageStorage.instance.insert(received);
      if (piece != null) {
        pieces.add(piece);
      } else {
        logger.w("$TAG - receivePiece - piece added null - message:$received");
      }
    }
    logger.v("$TAG - receivePiece - progress:$total/${pieces.length}/${total + parity}");
    if (pieces.length < total || bytesLength <= 0) return false;
    logger.i("$TAG - receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    pieces.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    // combine
    String? base64String = await MessageSchema.combinePiecesData(pieces, total, parity, bytesLength);
    if ((base64String == null) || base64String.isEmpty) {
      if (pieces.length >= (total + parity)) {
        logger.e("$TAG - receivePiece - COMBINE:FAIL - base64String is empty and delete pieces");
        await _deletePieces(received.msgId); // delete wrong pieces
      } else {
        logger.e("$TAG - receivePiece - COMBINE:FAIL - base64String is empty");
      }
      return false;
    }
    MessageSchema? combine = MessageSchema.combinePiecesMsg(pieces, base64String);
    if (combine == null) {
      logger.e("$TAG - receivePiece - COMBINE:FAIL - message combine is empty");
      return false;
    }
    // combine.content - handle later
    logger.i("$TAG - receivePiece - COMBINE:SUCCESS - combine:$combine");
    onMessageReceive(combine, needFast: true); // await
    return true;
  }

  // NO single
  Future<bool> _receiveTopicSubscribe(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveTopicSubscribe - duplicated - message:$exists");
      return false;
    }
    // subscriber
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(received.topic, received.from);
    bool historySubscribed = _subscriber?.status == SubscriberStatus.Subscribed;
    topicCommon.onSubscribe(received.topic, received.from, maxTryTimes: 5).then((value) async {
      if (!historySubscribed && value != null) {
        // DB
        MessageSchema? inserted = await MessageStorage.instance.insert(received);
        if (inserted != null) {
          // display
          _onSavedSink.add(inserted);
        }
      }
    });
    return !historySubscribed;
  }

  // NO single
  Future<bool> _receiveTopicUnsubscribe(MessageSchema received) async {
    topicCommon.onUnsubscribe(received.topic, received.from, maxTryTimes: 5); // await
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveTopicInvitation(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveTopicInvitation - duplicated - message:$exists");
      return false;
    }
    // permission checked in message click
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO single
  Future<bool> _receiveTopicKickOut(MessageSchema received) async {
    if ((received.content == null) || !(received.content is String)) return false;
    topicCommon.onKickOut(received.topic, received.from, received.content, maxTryTimes: 5); // await
    return true;
  }

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupInvitation(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receivePrivateGroupInvitation - duplicated - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    _onSavedSink.add(inserted);
    return true;
  }

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupAccept(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String groupId = data['groupId']?.toString() ?? "";
    String invitee = data['invitee']?.toString() ?? "";
    if (groupId.isEmpty || invitee.isEmpty) return false;
    // item
    PrivateGroupItemSchema? newGroupItem = PrivateGroupItemSchema.fromRawData(data);
    if (newGroupItem == null) {
      logger.e('$TAG - _receivePrivateGroupAccept - invitee nil.');
      return false;
    }
    // insert (sync self)
    PrivateGroupSchema? groupSchema = await privateGroupCommon.insertInvitee(newGroupItem, notify: true);
    if (groupSchema == null) {
      logger.w('$TAG - _receivePrivateGroupAccept - Invitee accept fail.');
      return false;
    }
    // members
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    if (members.length <= 0) {
      logger.e('$TAG - _receivePrivateGroupAccept - has no this group info');
      return false;
    }
    // sync invitee
    chatOutCommon.sendPrivateGroupOptionResponse(newGroupItem.invitee, groupSchema); // await
    // for (int i = 0; i < members.length; i += 10) {
    //   List<PrivateGroupItemSchema> memberSplits = members.skip(i).take(10).toList();
    //   chatOutCommon.sendPrivateGroupMemberResponse(newGroupItem.invitee, groupSchema, memberSplits); // await
    // }
    // sync members
    members.forEach((m) {
      if ((m.invitee != clientCommon.address) && (m.invitee != newGroupItem.invitee)) {
        chatOutCommon.sendPrivateGroupMemberResponse(m.invitee, groupSchema, [newGroupItem]).then((value) {
          chatOutCommon.sendPrivateGroupOptionResponse(m.invitee, groupSchema); // await
        }); // await
      }
    });
    return true;
  }

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupOptionRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    return await privateGroupCommon.pushPrivateGroupOptions(received.from, groupId, version);
  }

  // NO group (1 to 1)
  Future _receivePrivateGroupOptionResponse(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String rawData = data['rawData'];
    String version = data['version'];
    int? count = int.tryParse(data['count']?.toString() ?? "");
    String signature = data['signature'];
    PrivateGroupSchema? group = await privateGroupCommon.updatePrivateGroupOptions(groupId, rawData, version, count, signature); // await
    if (group != null) {
      bool needRequestMembers = false;
      int nowAt = DateTime.now().millisecondsSinceEpoch;
      if (group.membersRequestedVersion != version) {
        logger.i('$TAG - _receivePrivateGroupOptionResponse - version diff - version1:${group.membersRequestedVersion} - version2:$version');
        needRequestMembers = true;
      } else {
        int timePast = nowAt - group.membersRequestAt;
        if (timePast > (5 * 60 * 1000)) {
          logger.i('$TAG - _receivePrivateGroupOptionResponse - members_request - time > 5m - past:$timePast');
          needRequestMembers = true;
        } else {
          logger.d('$TAG - _receivePrivateGroupOptionResponse - members_request - time < 5m - past:$timePast');
          needRequestMembers = false;
        }
      }
      if (needRequestMembers) {
        chatOutCommon.sendPrivateGroupMemberRequest(received.from, groupId).then((version) async {
          group.setMembersRequestAt(nowAt);
          group.setMembersRequestedVersion(version);
          await privateGroupCommon.updateGroupData(group.groupId, group.data);
        });
      }
    }
  }

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupMemberRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    return await privateGroupCommon.pushPrivateGroupMembers(received.from, groupId, version);
  }

  // NO group (1 to 1)
  Future _receivePrivateGroupMemberResponse(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    if ((data['membersData'] == null) || !(data['membersData'] is List)) return false;
    List membersData = data['membersData'];
    List<PrivateGroupItemSchema> members = [];
    for (int i = 0; i < membersData.length; i++) {
      var member = membersData[i];
      PrivateGroupItemSchema? item = PrivateGroupItemSchema.create(
        member['group_id'],
        permission: member['permission'],
        expiresAt: member['expires_at'],
        inviter: member['inviter'],
        invitee: member['invitee'],
        inviterRawData: member['inviter_raw_data'],
        inviteeRawData: member['invitee_raw_data'],
        inviterSignature: member['inviter_signature'],
        inviteeSignature: member['invitee_signature'],
      );
      if (item != null) members.add(item);
    }
    await privateGroupCommon.updatePrivateGroupMembers(received.to, received.from, groupId, version, members);
  }

  Future<int> _deletePieces(String msgId) async {
    int count = 0;
    List<MessageSchema> pieces = await MessageStorage.instance.queryListByIdContentType(msgId, MessageContentType.piece, MessageSchema.piecesMaxTotal + MessageSchema.piecesMaxParity);
    logger.i("$TAG - _deletePieces - delete pieces file - pieces_count:${pieces.length}");
    int result = await MessageStorage.instance.deleteByIdContentType(msgId, MessageContentType.piece);
    if (result > 0) {
      for (var i = 0; i < pieces.length; i++) {
        MessageSchema piece = pieces[i];
        if (piece.content is File) {
          if ((piece.content as File).existsSync()) {
            (piece.content as File).delete(); // await
            // logger.v("$TAG - _deletePieces - DELETE:PROGRESS - path:${(piece.content as File).path}");
            count++;
          } else {
            logger.w("$TAG - _deletePieces - DELETE:ERROR - NoExists - path:${(piece.content as File).path}");
          }
        } else {
          logger.w("$TAG - _deletePieces - DELETE:ERROR - empty:${piece.content?.toString()}");
        }
      }
      logger.i("$TAG - _deletePieces - DELETE:SUCCESS - count:${pieces.length}");
    } else {
      logger.w("$TAG - _deletePieces - DELETE:FAIL - empty - pieces:$pieces");
    }
    return count;
  }
}
