import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';

class ChatInCommon with Tag {
  ChatInCommon();

  Map<String, ParallelQueue> _receiveQueues = Map();

  Future run({bool reset = true}) async {
    logger.i("$TAG - run - reset:$reset");
    if (reset) {
      _receiveQueues.clear();
    } else {
      _receiveQueues.forEach((key, queue) => queue.run(clear: false));
    }
  }

  Future pause({bool reset = true}) async {
    logger.i("$TAG - pause - reset:$reset");
    _receiveQueues.forEach((key, queue) => queue.pause());
  }

  Future waitReceiveQueues(String key) async {
    List<Future> futures = [];
    _receiveQueues.forEach((targetId, queue) {
      futures.add(waitReceiveQueue(targetId, key));
    });
    logger.d("$TAG - waitReceiveQueues - waiting - count:${futures.length} - key:$key");
    await Future.wait(futures);
    logger.d("$TAG - waitReceiveQueues - complete - count:${futures.length} - key:$key");
  }

  Future<bool> waitReceiveQueue(String targetId, String keyPrefix, {bool duplicated = true}) async {
    ParallelQueue? receiveQueue = _receiveQueues[targetId];
    if (receiveQueue == null) return true;
    bool isOnComplete = receiveQueue.isOnComplete("$keyPrefix$targetId");
    if (isOnComplete && !duplicated) {
      logger.d("$TAG - waitReceiveQueue - progress refuse duplicated - keyPrefix:$keyPrefix - targetId:$targetId");
      return false;
    }
    logger.d("$TAG - waitReceiveQueue - waiting - keyPrefix:$keyPrefix - targetId:$targetId");
    await receiveQueue.onComplete("$keyPrefix$targetId");
    logger.d("$TAG - waitReceiveQueue - complete - keyPrefix:$keyPrefix - targetId:$targetId");
    return true;
  }

  Future onMessageReceive(MessageSchema? message, {bool priority = false, Function? onAdd}) async {
    if (message == null) {
      logger.e("$TAG - onMessageReceive - message is null");
      return;
    } else if (message.targetId.isEmpty) {
      logger.e("$TAG - onMessageReceive - targetId is empty - received:${message.toStringSimple()}");
      return;
    } else if (message.contentType.isEmpty) {
      logger.e("$TAG - onMessageReceive - contentType is empty - received:${message.toStringSimple()}");
      return;
    }
    // status
    message.status = message.canReceipt ? message.status : MessageStatus.Read;
    // queue
    _receiveQueues[message.targetId] = _receiveQueues[message.targetId] ?? ParallelQueue("chat_receive_${message.targetId}", onLog: (log, error) => error ? logger.w(log) : null);
    await onAdd?.call();
    _receiveQueues[message.targetId]?.add(() async {
      try {
        return await _handleMessage(message);
      } catch (e, st) {
        handleError(e, st);
      }
    }, id: message.msgId, priority: priority);
  }

  Future _handleMessage(MessageSchema received) async {
    // contact
    ContactSchema? contact = await chatCommon.contactHandle(received);
    // deviceInfo
    DeviceInfoSchema? deviceInfo = await chatCommon.deviceInfoHandle(received);
    // topic
    TopicSchema? topic = await chatCommon.topicHandle(received);
    if (topic != null) {
      if (topic.joined != true) {
        logger.w("$TAG - _handleMessage - topic - deny message - unsubscribe - topic:$topic");
        return;
      }
      SubscriberSchema? me = await subscriberCommon.query(topic.topicId, clientCommon.address);
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
    // TODO:GG test
    // group
    PrivateGroupSchema? privateGroup = await chatCommon.privateGroupHandle(received);
    if (privateGroup != null) {
      if (received.isGroupAction) {
        // nothing
      } else {
        if (privateGroup.joined != true) {
          logger.w("$TAG - _handleMessage - group - deny message - me no joined - topic:$topic");
          return;
        }
        PrivateGroupItemSchema? _me = await privateGroupCommon.queryGroupItem(privateGroup.groupId, clientCommon.address);
        if ((_me == null) || (_me.permission <= PrivateGroupItemPerm.none)) {
          logger.w("$TAG - _handleMessage - group - deny message - me no permission - me:$_me - group:$privateGroup");
          return;
        }
        PrivateGroupItemSchema? _sender = await privateGroupCommon.queryGroupItem(privateGroup.groupId, received.sender);
        if ((_sender == null) || (_sender.permission <= PrivateGroupItemPerm.none)) {
          logger.w("$TAG - _handleMessage - group - deny message - sender no permission - sender:$_sender - group:$privateGroup");
          return;
        }
      }
    }
    // duplicated
    bool duplicated = false;
    if (received.canDisplay) {
      if (await messageCommon.isMessageReceived(received)) {
        logger.d("$TAG - _handleMessage - duplicated - type:${received.contentType} - targetId:${received.targetId} - message:${received.toStringSimple()}");
        duplicated = true;
      }
    } else if (received.contentType == MessageContentType.piece) {
      if (await messageCommon.isMessageReceived(received)) {
        int? index = received.options?[MessageOptions.KEY_PIECE_INDEX];
        int? total = received.options?[MessageOptions.KEY_PIECE_TOTAL];
        int? parity = received.options?[MessageOptions.KEY_PIECE_PARITY];
        logger.v("$TAG - _handleMessage - duplicated(piece) - index:$index/$total+$parity - targetId:${received.targetId} - message:${received.toStringSimple()}");
        duplicated = true;
        if (index == 0) {
          MessageSchema? exists = await messageCommon.query(received.msgId);
          received = exists ?? received; // replace
        }
      }
    }
    // receive
    bool insertOk = false;
    if (!duplicated) {
      switch (received.contentType) {
        case MessageContentType.ping:
          await _receivePing(received);
          break;
        case MessageContentType.receipt:
          await _receiveReceipt(received);
          break;
        case MessageContentType.read:
          await _receiveRead(received);
          break;
        case MessageContentType.queue:
          await _receiveQueue(received);
          break;
        case MessageContentType.contactProfile:
          await _receiveContact(received, contact, deviceInfo);
          break;
        case MessageContentType.contactOptions:
          insertOk = await _receiveContactOptions(received, contact, deviceInfo);
          break;
        case MessageContentType.deviceRequest:
          await _receiveDeviceRequest(received, contact, deviceInfo);
          break;
        case MessageContentType.deviceInfo:
          await _receiveDeviceInfo(received, contact);
          break;
        case MessageContentType.text:
        case MessageContentType.textExtension:
          insertOk = await _receiveText(received);
          break;
        case MessageContentType.ipfs:
          insertOk = await _receiveIpfs(received);
          break;
        case MessageContentType.image:
          insertOk = await _receiveImage(received);
          break;
        case MessageContentType.audio:
          insertOk = await _receiveAudio(received);
          break;
        case MessageContentType.piece:
          insertOk = await _receivePiece(received);
          break;
        case MessageContentType.topicInvitation:
          insertOk = await _receiveTopicInvitation(received);
          break;
        case MessageContentType.topicSubscribe:
          insertOk = await _receiveTopicSubscribe(received);
          break;
        case MessageContentType.topicUnsubscribe:
          await _receiveTopicUnsubscribe(received);
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
        case MessageContentType.privateGroupSubscribe:
          insertOk = await _receivePrivateGroupSubscribe(received);
          break;
        case MessageContentType.privateGroupQuit:
          await _receivePrivateGroupQuit(received);
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
        case "msgStatus":
          break;
        default:
          logger.e("$TAG - _handleMessage - type error - type:${received.contentType} - targetId:${received.targetId} - message:${received.toStringSimple()}");
          break;
      }
    }
    // receipt
    if (received.canReceipt && (insertOk || duplicated)) {
      if (received.isTargetContact) {
        chatOutCommon.sendReceipt(received); // await
      } else {
        // handle in send topic/group with self receipt
      }
    }
    // session
    if (received.canDisplay && insertOk) {
      chatCommon.sessionHandle(received); // await
    }
    // queue
    if (received.canQueue && (insertOk || duplicated)) {
      if (received.isTargetContact && !received.isTargetSelf) {
        await messageCommon.onContactMessageQueueReceive(received); // await receiveQueue onComplete
      } else {
        logger.w("$TAG - _handleMessage - message queue wrong - sender:${received.sender} - received:$received");
      }
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receivePing(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    if (received.isTargetSelf) {
      logger.v("$TAG - _receivePing - ping self receive - received:$received");
      return true;
    }
    if ((received.content == null) || !(received.content is String)) {
      logger.e("$TAG - _receivePing - content error - sender:${received.sender} - received:$received");
      return false;
    }
    String content = received.content as String;
    if (content == "ping") {
      logger.i("$TAG - _receivePing - receive ping - sender:${received.sender} - options:${received.options}");
      chatOutCommon.sendPing([received.sender], false, gap: Settings.gapPongPingMs); // await
    } else if (content == "pong") {
      logger.i("$TAG - _receivePing - receive pong - sender:${received.sender} - options:${received.options}");
      // nothing
    } else {
      logger.e("$TAG - _receivePing - content wrong - received:$received - options:${received.options}");
      return false;
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveReceipt(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out, just receive self msg)
    if ((received.content == null) || !(received.content is String)) return false;
    MessageSchema? exists = await messageCommon.query(received.content);
    if (exists == null || exists.targetId.isEmpty) {
      logger.w("$TAG - _receiveReceipt - target is empty - received:$received");
      return false;
    } else if (!exists.canReceipt) {
      logger.d("$TAG - _receiveReceipt - contentType is error - received:$received");
    } else if (!exists.isOutbound || (exists.status == MessageStatus.Received)) {
      logger.w("$TAG - receiveReceipt - outbound error - exists:$exists");
      return false;
    } else if ((exists.status == MessageStatus.Receipt) || (exists.status == MessageStatus.Read)) {
      logger.v("$TAG - receiveReceipt - duplicated - exists:$exists");
      return false;
    } else if ((exists.isTargetTopic || exists.isTargetGroup) && (received.sender != clientCommon.address)) {
      logger.w("$TAG - receiveReceipt - group skip no_self - exists:$exists");
      return false;
    }
    // status
    if (exists.isTargetContact) {
      logger.i("$TAG - receiveReceipt - read enable - sender:${received.sender} - msgId:${received.content}");
      await messageCommon.updateMessageStatus(exists, MessageStatus.Receipt, receiveAt: DateTime.now().millisecondsSinceEpoch);
    } else {
      logger.i("$TAG - receiveReceipt - read disable - sender:${received.sender} - msgId:${received.content}");
      await messageCommon.updateMessageStatus(exists, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch);
    }
    // topicInvitation
    // if (exists.contentType == MessageContentType.topicInvitation) {
    //   await subscriberCommon.onInvitedReceipt(exists.content, received.sender);
    // }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveRead(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    List? readIds = (received.content as List?);
    if (readIds == null || readIds.isEmpty) {
      logger.e("$TAG - _receiveRead - targetId or content type error - received:$received");
      return false;
    }
    // messages
    List<String> msgIds = readIds.map((e) => e?.toString() ?? "").toList();
    List<MessageSchema> msgList = await messageCommon.queryListByIds(msgIds);
    if (msgList.isEmpty) {
      logger.i("$TAG - _receiveRead - msgIds is nil - sender:${received.sender} - received:$received");
      return true;
    }
    logger.i("$TAG - _receiveRead - count:${msgList.length} - sender:${received.sender} - msgIds:$msgIds");
    // update
    for (var i = 0; i < msgList.length; i++) {
      MessageSchema message = msgList[i];
      int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
      await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
    }
    // correct no read
    msgList.sort((prev, next) => prev.sendAt.compareTo(next.sendAt));
    int lastSendAt = msgList[msgList.length - 1].sendAt;
    messageCommon.correctMessageRead(received.targetId, received.targetType, lastSendAt); // await
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveQueue(MessageSchema received) async {
    String targetAddress = received.sender;
    String? queueIds = (received.content as String?);
    if (targetAddress.isEmpty || queueIds == null || queueIds.isEmpty) {
      logger.e("$TAG - _receiveQueue - targetId or content type error - received:$received");
      return false;
    }
    logger.i("$TAG - _receiveQueue - sender:$targetAddress - queueIds:$queueIds");
    // queueIds
    List splits = deviceInfoCommon.splitQueueIds(queueIds);
    String selfDeviceId = splits[3];
    if (selfDeviceId.trim() != Settings.deviceId.trim()) {
      logger.i("$TAG - _receiveQueue - target device diff - sender:$targetAddress - self:${Settings.deviceId} - queueIds:$queueIds");
      return false;
    }
    // sync_queue
    if (received.isTargetContact && !received.isTargetSelf) {
      messageCommon.syncContactMessages(targetAddress, received.deviceId, splits[0], splits[1], splits[2]); // await
    } else {
      // nothing
    }
    return true;
  }

  // NO DB NO display (1 to 1)
  Future<bool> _receiveContact(MessageSchema received, ContactSchema? contact, DeviceInfoSchema? deviceInfo) async {
    if (contact == null) return false;
    // D-Chat NO RequestType.header
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? requestType = data['requestType']?.toString();
    String? responseType = data['responseType']?.toString();
    String? version = data['version']?.toString();
    Map<String, dynamic>? content = data['content'];
    bool isDChatRequest = (requestType == null) && (responseType == null) && (version == null);
    if ((requestType?.isNotEmpty == true) || isDChatRequest) {
      // need reply
      ContactSchema? contactMe = await contactCommon.getMe();
      String? selfNativeVersion = contactMe?.profileVersion;
      String? lastResponseVersion = deviceInfo?.contactProfileResponseVersion;
      if (requestType == ContactRequestType.header) {
        logger.i("$TAG - _receiveContact - response head - sender:${received.sender} - native:$selfNativeVersion - response:$lastResponseVersion - remote:$version");
        chatOutCommon.sendContactProfileResponse(contact.address, contactMe, ContactRequestType.header); // await
      } else {
        int gap;
        if ((selfNativeVersion?.isNotEmpty == true) && (selfNativeVersion != lastResponseVersion)) {
          logger.i('$TAG - _receiveContact - response full - version diff (native != responsed ?? remote) - sender:${received.sender} - native:$selfNativeVersion - response:$lastResponseVersion - remote:$version');
          gap = 0;
        } else if ((selfNativeVersion?.isNotEmpty == true) && (selfNativeVersion != version)) {
          logger.i('$TAG - _receiveContact - response full - version diff (native == responsed != remote) - sender:${received.sender} - native:$selfNativeVersion - response:$lastResponseVersion - remote:$version');
          gap = Settings.gapContactProfileSyncMs;
        } else {
          logger.d('$TAG - _receiveContact - response full - version same (native == remote == responsed) - sender:${received.sender} - native:$selfNativeVersion - response:$lastResponseVersion - remote:$version');
          gap = Settings.gapContactProfileSyncMs;
        }
        chatOutCommon.sendContactProfileResponse(contact.address, contactMe, ContactRequestType.full, deviceInfo: deviceInfo, gap: gap).then((value) {
          if (value) deviceInfoCommon.setContactProfileResponseInfo(contact.address, deviceInfo?.deviceId, selfNativeVersion);
        }); // await
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(contact.profileVersion, version)) {
        if ((responseType != ContactRequestType.full) && (content == null)) {
          logger.i("$TAG - _receiveContact - request full - sender:${received.sender} - data:$data");
          chatOutCommon.sendContactProfileRequest(contact.address, ContactRequestType.full, contact.profileVersion); // await
        } else {
          if (content == null) {
            logger.e("$TAG - _receiveContact - content is empty - data:$data - sender:${received.sender}");
            return false;
          }
          String? firstName = content['first_name'] ?? content['name'];
          String? lastName = content['last_name'];
          String? avatarPath;
          String? avatarType = content['avatar'] != null ? content['avatar']['type'] : null;
          if (avatarType?.isNotEmpty == true) {
            String? avatarData = content['avatar'] != null ? content['avatar']['data'] : null;
            if (avatarData?.isNotEmpty == true) {
              if (avatarData.toString().split(",").length != 1) {
                avatarData = avatarData.toString().split(",")[1];
              }
              String? fileExt = content['avatar'] != null ? content['avatar']['ext'] : FileHelper.DEFAULT_IMAGE_EXT;
              if (fileExt == null || fileExt.isEmpty) fileExt = FileHelper.DEFAULT_IMAGE_EXT;
              File? avatar = await FileHelper.convertBase64toFile(avatarData, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.profile, subPath: received.targetId, fileExt: ext ?? fileExt));
              avatarPath = Path.convert2Local(avatar?.path);
            } else {
              logger.w("$TAG - _receiveContact - avatar_data is empty - data:$data - sender:${received.sender}");
            }
          } else {
            logger.i("$TAG - _receiveContact - avatar_type is empty - data:$data - sender:${received.sender}");
          }
          // if (firstName.isEmpty || lastName.isEmpty || (avatar?.path ?? "").isEmpty) {
          //   logger.i("$TAG - receiveContact - setProfile - NULL");
          // } else {
          await contactCommon.setOtherAvatar(contact.address, version, avatarPath, notify: false);
          await contactCommon.setOtherFullName(contact.address, version, firstName, lastName, notify: true);
          logger.i("$TAG - _receiveContact - updateProfile - firstName:$firstName - lastName:$lastName - avatar:$avatarPath - version:$version - data:$data - sender:${received.sender}");
          // }
        }
      } else {
        logger.d("$TAG - _receiveContact - profile version same - sender:${received.sender} - data:$data");
      }
    }
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveContactOptions(MessageSchema received, ContactSchema? contact, DeviceInfoSchema? deviceInfo) async {
    if (contact == null) return false;
    // options type / received.isTopic (limit in out)
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? optionsType = data['optionType']?.toString();
    Map<String, dynamic> content = data['content'] ?? Map();
    if (optionsType == null || optionsType.isEmpty) return false;
    if (optionsType == '0') {
      int burningSeconds = (content['deleteAfterSeconds'] as int?) ?? 0;
      int updateAt = (content['updateBurnAfterAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      logger.i("$TAG - _receiveContactOptions - setBurning - sender:${received.sender} - burningSeconds:$burningSeconds - updateAt:${DateTime.fromMillisecondsSinceEpoch(updateAt)}");
      var options = await contactCommon.setOptionsBurn(contact.address, burningSeconds, updateAt, notify: true);
      if (options != null) contact.options = options;
      return options != null;
    } else if (optionsType == '1') {
      String deviceToken = content['deviceToken']?.toString() ?? "";
      if (deviceInfo == null) {
        logger.w("$TAG - _receiveContactOptions - deviceToken no_deviceInfo - sender:${received.sender} - new:$deviceToken - deviceId:${received.deviceId}");
        return false;
      } else if (deviceInfo.deviceToken != deviceToken) {
        logger.i("$TAG - _receiveContactOptions - deviceToken set - sender:${received.sender} - new:$deviceToken - deviceInfo:$deviceInfo");
        bool success = await deviceInfoCommon.setDeviceToken(deviceInfo.contactAddress, deviceInfo.deviceId, deviceToken);
        if (!success) return false;
      } else {
        logger.i("$TAG - _receiveContactOptions - deviceToken same - sender:${received.sender} - new:$deviceToken - deviceInfo:$deviceInfo");
      }
    } else {
      logger.e("$TAG - _receiveContactOptions - setNothing - data:$data - sender:${received.sender}");
      return false;
    }
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceRequest(MessageSchema received, ContactSchema? contact, DeviceInfoSchema? targetDeviceInfo) async {
    if (contact == null) return false;
    bool notificationOpen = contact.options.notificationOpen;
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.getMe(canAdd: true, fetchDeviceToken: notificationOpen);
    logger.i("$TAG - _receiveDeviceRequest - sender:${received.sender} - self:$deviceInfo");
    if (deviceInfo == null) return false;
    chatOutCommon.sendDeviceInfo(contact.address, deviceInfo, notificationOpen, targetDeviceInfo: targetDeviceInfo, gap: Settings.gapDeviceInfoSyncMs).then((value) {
      if (value) deviceInfoCommon.setDeviceInfoResponse(targetDeviceInfo?.contactAddress, targetDeviceInfo?.deviceId);
    }); // await
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceInfo(MessageSchema received, ContactSchema? contact) async {
    if (contact == null) return false;
    // data
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? deviceId = data["deviceId"]?.toString();
    String? deviceToken = data["deviceToken"]?.toString();
    String? appName = data["appName"]?.toString();
    String? appVersion = data["appVersion"]?.toString();
    String? platform = data["platform"]?.toString();
    String? platformVersion = data["platformVersion"]?.toString();
    Map<String, dynamic> newData = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
    logger.i("$TAG - _receiveDeviceInfo - sender:${received.sender} - newData:$newData");
    // exist
    DeviceInfoSchema? exists = await deviceInfoCommon.query(contact.address, deviceId);
    // add (wrong here)
    if (exists == null) {
      DeviceInfoSchema deviceInfo = DeviceInfoSchema(
        contactAddress: contact.address,
        deviceId: deviceId ?? "",
        deviceToken: deviceToken ?? "",
        onlineAt: DateTime.now().millisecondsSinceEpoch,
        data: newData,
      );
      exists = await deviceInfoCommon.add(deviceInfo);
      logger.i("$TAG - _receiveDeviceInfo - new add - new:$exists - data:$data");
      return exists != null;
    }
    // update_data
    bool sameProfile = (appName == exists.appName) && (appVersion == exists.appVersion.toString()) && (platform == exists.platform) && (platformVersion == exists.platformVersion.toString());
    if (!sameProfile) {
      logger.i("$TAG - _receiveDeviceInfo - profile update - newData:$newData - oldData:${exists.data} - sender:${received.sender}");
      bool success = await deviceInfoCommon.setProfile(exists.contactAddress, exists.deviceId, newData);
      if (success) exists.data = newData;
    }
    // update_token
    if ((exists.deviceToken != deviceToken) && (deviceToken?.isNotEmpty == true)) {
      logger.i("$TAG - _receiveDeviceInfo - deviceToken update - new:$deviceToken - old${exists.deviceToken} - sender:${received.sender}");
      bool success = await deviceInfoCommon.setDeviceToken(exists.contactAddress, exists.deviceId, deviceToken);
      if (success) exists.deviceToken = deviceToken ?? "";
    }
    // update_online
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    bool success = await deviceInfoCommon.setOnlineAt(exists.contactAddress, exists.deviceId, onlineAt: nowAt);
    if (success) exists.onlineAt = nowAt;
    return true;
  }

  Future<bool> _receiveText(MessageSchema received) async {
    if (received.content == null) return false;
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveIpfs(MessageSchema received) async {
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
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    // thumbnail
    if (ipfsThumbnailHash != null && ipfsThumbnailHash.isNotEmpty) {
      chatCommon.startIpfsThumbnailDownload(inserted); // await
    }
    return true;
  }

  Future<bool> _receiveImage(MessageSchema received) async {
    if (received.content == null) return false;
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_IMAGE_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_IMAGE_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - _receiveImage - content is null - message:${received.toStringSimple()}");
      return false;
    }
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    bool isPieceCombine = received.options?[MessageOptions.KEY_FROM_PIECE] ?? false;
    if (isPieceCombine) _deletePieces(received.msgId); // await
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveAudio(MessageSchema received) async {
    if (received.content == null) return false;
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_AUDIO_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_AUDIO_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - _receiveAudio - content is null - message:${received.toStringSimple()}");
      return false;
    }
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    bool isPieceCombine = received.options?[MessageOptions.KEY_FROM_PIECE] ?? false;
    if (isPieceCombine) _deletePieces(received.msgId); // await
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receivePiece(MessageSchema received) async {
    String? parentType = received.options?[MessageOptions.KEY_PIECE_PARENT_TYPE];
    int bytesLength = received.options?[MessageOptions.KEY_PIECE_BYTES_LENGTH] ?? 0;
    int total = received.options?[MessageOptions.KEY_PIECE_TOTAL] ?? 1;
    int parity = received.options?[MessageOptions.KEY_PIECE_PARITY] ?? 1;
    int? index = received.options?[MessageOptions.KEY_PIECE_INDEX];
    if (index == null || index < 0) return false;
    // piece
    List<MessageSchema> pieces = await messageCommon.queryPieceList(received.msgId, limit: total + parity);
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
      logger.d("$TAG - _receivePiece - piece duplicated - receive:$received - exist:$piece");
    } else {
      // received.status = MessageStatus.Read; // modify in before
      received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.cache, fileExt: ext ?? parentType));
      piece = await messageCommon.insert(received);
      if (piece != null) {
        pieces.add(piece);
      } else {
        logger.w("$TAG - _receivePiece - piece added null - message:${received.toStringSimple()}");
      }
    }
    logger.d("$TAG - _receivePiece - progress:${pieces.length}/$total+$parity");
    if (pieces.length < total || bytesLength <= 0) return false;
    logger.i("$TAG - _receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    pieces.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    // combine
    String? base64String = await MessageSchema.combinePiecesData(pieces, total, parity, bytesLength);
    if ((base64String == null) || base64String.isEmpty) {
      if (pieces.length >= (total + parity)) {
        logger.e("$TAG - _receivePiece - COMBINE:FAIL - base64String is empty and delete pieces - message:${received.toStringSimple()}");
        await _deletePieces(received.msgId); // delete wrong pieces
      } else {
        logger.e("$TAG - _receivePiece - COMBINE:FAIL - base64String is empty - message:${received.toStringSimple()}");
      }
      return false;
    }
    MessageSchema? combine = MessageSchema.combinePiecesMsg(pieces, base64String);
    if (combine == null) {
      logger.e("$TAG - _receivePiece - COMBINE:FAIL - message combine is empty - message:${received.toStringSimple()}");
      return false;
    }
    // combine.content - handle later
    logger.i("$TAG - _receivePiece - COMBINE:SUCCESS - combine:$combine");
    onMessageReceive(combine, priority: true, onAdd: () {
      _receiveQueues[combine.targetId]?.delete(combine.msgId); // delete pieces in queue
    }); // await
    return true;
  }

  // NO single
  Future<bool> _receiveTopicSubscribe(MessageSchema received) async {
    SubscriberSchema? _subscriber = await subscriberCommon.query(received.targetId, received.sender);
    bool historySubscribed = _subscriber?.status == SubscriberStatus.Subscribed;
    Function() syncSubscribe = () async {
      int tryTimes = 0;
      while (tryTimes < 30) {
        SubscriberSchema? _subscriber = await topicCommon.onSubscribe(received.targetId, received.sender);
        if (_subscriber != null) {
          if (!historySubscribed) {
            MessageSchema? inserted = await messageCommon.insert(received);
            if (inserted != null) messageCommon.onSavedSink.add(inserted);
          }
          logger.i("$TAG - _receiveTopicSubscribe - check subscribe success - tryTimes:$tryTimes - historySubscribed:$historySubscribed - topic:${received.targetId} - address:${received.sender}");
          break;
        }
        logger.w("$TAG - _receiveTopicSubscribe - check subscribe continue(txPool) - tryTimes:$tryTimes - historySubscribed:$historySubscribed - topic:${received.targetId} - address:${received.sender}");
        tryTimes++;
        await Future.delayed(Duration(seconds: 2));
      }
    };
    syncSubscribe(); // await
    return !historySubscribed;
  }

  // NO single
  Future<bool> _receiveTopicUnsubscribe(MessageSchema received) async {
    topicCommon.onUnsubscribe(received.targetId, received.sender); // await
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveTopicInvitation(MessageSchema received) async {
    // permission checked in message click
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // NO single
  Future<bool> _receiveTopicKickOut(MessageSchema received) async {
    if ((received.content == null) || !(received.content is String)) return false;
    topicCommon.onKickOut(received.targetId, received.sender, received.content); // await
    return true;
  }

  // TODO:GG test
  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupInvitation(MessageSchema received) async {
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // TODO:GG test
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
      logger.e('$TAG - _receivePrivateGroupAccept - invitee nil - data:$data - sender:${received.sender}');
      return false;
    }
    // insert (sync self)
    PrivateGroupSchema? groupSchema = await privateGroupCommon.onInviteeAccept(newGroupItem, notify: true);
    if (groupSchema == null) {
      logger.w('$TAG - _receivePrivateGroupAccept - Invitee accept fail - data:$data - sender:${received.sender}');
      return false;
    }
    // members
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    if (members.length <= 0) {
      logger.e('$TAG - _receivePrivateGroupAccept - has no this group info - data:$data - sender:${received.sender}');
      return false;
    }
    // sync invitee
    chatOutCommon.sendPrivateGroupOptionResponse([newGroupItem.invitee ?? ""], groupSchema).then((success) {
      if (!success) {
        logger.e('$TAG - _receivePrivateGroupAccept - sync inviter options fail - data:$data - sender:${received.sender}');
      }
    }); // await
    // for (int i = 0; i < members.length; i += 10) {
    //   List<PrivateGroupItemSchema> memberSplits = members.skip(i).take(10).toList();
    //   chatOutCommon.sendPrivateGroupMemberResponse(newGroupItem.invitee, groupSchema, memberSplits); // await
    // }
    // sync members
    members.removeWhere((m) => (m.invitee == clientCommon.address) || (m.invitee == newGroupItem.invitee));
    List<String> addressList = members.map((e) => e.invitee ?? "").toList()..removeWhere((element) => element.isEmpty);
    chatOutCommon.sendPrivateGroupMemberResponse(addressList, groupSchema, [newGroupItem]).then((success) async {
      if (success) {
        success = await chatOutCommon.sendPrivateGroupOptionResponse(addressList, groupSchema);
        if (success) {
          logger.i('$TAG - _receivePrivateGroupAccept - success - accept:$newGroupItem - group:$groupSchema');
        } else {
          logger.w('$TAG - _receivePrivateGroupAccept - sync members member fail - accept:$newGroupItem - group:$groupSchema');
        }
      } else if (addressList.isNotEmpty) {
        logger.w('$TAG - _receivePrivateGroupAccept - sync members options fail - accept:$newGroupItem - group:$groupSchema');
      }
    }); // await
    return true;
  }

  // TODO:GG test
  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupSubscribe(MessageSchema received) async {
    // DB
    MessageSchema? inserted = await messageCommon.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // TODO:GG test
  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupQuit(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String groupId = data['groupId']?.toString() ?? "";
    String invitee = data['invitee']?.toString() ?? "";
    if (groupId.isEmpty || invitee.isEmpty) return false;
    // item
    PrivateGroupItemSchema? newGroupItem = PrivateGroupItemSchema.fromRawData(data);
    if (newGroupItem == null) {
      logger.e('$TAG - _receivePrivateGroupQuit - invitee nil - data:$data');
      return false;
    }
    return await privateGroupCommon.onMemberQuit(newGroupItem, notify: true);
  }

  // TODO:GG test
  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupOptionRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    privateGroupCommon.pushPrivateGroupOptions(received.sender, groupId, version); // await
    return true;
  }

  // TODO:GG test
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
      if (group.membersRequestedVersion != version) {
        logger.i('$TAG - _receivePrivateGroupOptionResponse - version requested diff - sender:${received.sender} - requested:${group.membersRequestedVersion} - remote:$version');
      } else {
        logger.d('$TAG - _receivePrivateGroupOptionResponse - version requested same - sender:${received.sender} - version:$version');
      }
      int gap = (group.membersRequestedVersion != version) ? 0 : Settings.gapGroupRequestMembersMs;
      chatOutCommon.sendPrivateGroupMemberRequest(received.sender, groupId, gap: gap).then((value) {
        if (value) privateGroupCommon.setGroupMembersRequestInfo(group.groupId, version, notify: true);
      }); // await
    }
  }

  // TODO:GG test
  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupMemberRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    privateGroupCommon.pushPrivateGroupMembers(received.sender, groupId, version); // await
    return true;
  }

  // TODO:GG test
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
    await privateGroupCommon.updatePrivateGroupMembers(received.targetId, received.sender, groupId, version, members);
  }

  // TODO:GG test
  Future<int> _deletePieces(String msgId) async {
    int limit = 20;
    List<MessageSchema> pieces = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await messageCommon.queryPieceList(msgId, offset: offset, limit: limit);
      pieces.addAll(result);
      if (result.length < limit) break;
    }
    logger.i("$TAG - _deletePieces - DELETE:START - pieces_count:${pieces.length}");
    int count = 0;
    int result = await messageCommon.delete(msgId, MessageContentType.piece);
    if (result > 0) {
      for (var i = 0; i < pieces.length; i++) {
        MessageSchema piece = pieces[i];
        if (piece.isContentFile) {
          File file = piece.content as File;
          if (file.existsSync()) {
            await file.delete();
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
