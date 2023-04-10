import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/contact/device_info.dart';
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
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';

class ChatInCommon with Tag {
  ChatInCommon();

  Map<String, ParallelQueue> _receiveQueues = Map();

  Future start({bool reset = true}) async {
    logger.i("$TAG - start - reset:$reset");
    if (reset) {
      _receiveQueues.clear();
    } else {
      _receiveQueues.forEach((key, queue) => queue.restart(clear: false));
    }
  }

  Future stop({bool reset = true}) async {
    logger.i("$TAG - stop - reset:$reset");
    _receiveQueues.forEach((key, queue) => queue.stop());
  }

  Future onMessageReceive(MessageSchema? message, {bool needFast = false}) async {
    if (message == null) {
      logger.e("$TAG - onMessageReceive - message is null");
      return;
    } else if (message.targetId.isEmpty) {
      logger.e("$TAG - onMessageReceive - targetId is empty - received:${message.toStringNoContent()}");
      return;
    } else if (message.contentType.isEmpty) {
      logger.e("$TAG - onMessageReceive - contentType is empty - received:${message.toStringNoContent()}");
      return;
    }
    // topic/group msg published callback can be used receipt
    if (message.isTopic || message.isPrivateGroup) {
      if ((message.from == message.to) || (message.from == clientCommon.address)) {
        if (!message.isOutbound && (message.contentType != MessageContentType.receipt)) {
          if (message.from.isEmpty) message.from = clientCommon.address ?? message.to;
          if (message.to.isEmpty) message.to = clientCommon.address ?? message.from;
          message.contentType = MessageContentType.receipt;
          message.content = message.msgId;
        }
      }
    }
    // status
    message.status = message.canReceipt ? message.status : MessageStatus.Read;
    // queue
    _receiveQueues[message.targetId] = _receiveQueues[message.targetId] ?? ParallelQueue("chat_receive_${message.targetId}", onLog: (log, error) => error ? logger.w(log) : null);
    _receiveQueues[message.targetId]?.add(() async {
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
    // deviceInfo
    DeviceInfoSchema? deviceInfo = await chatCommon.deviceInfoHandle(received);
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
        if (privateGroup.joined != true) {
          logger.w("$TAG - _handleMessage - group - deny message - me no joined - topic:$topic");
          return;
        }
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
    // message
    bool insertOk = false;
    switch (received.contentType) {
      case MessageContentType.ping:
        await _receivePing(received);
        break;
      case MessageContentType.receipt:
        await _receiveReceipt(received, deviceInfo);
        break;
      case MessageContentType.read:
        await _receiveRead(received);
        break;
      // case MessageContentType.msgStatus:
      //   await _receiveMsgStatus(received); // need interval
      //   break;
      case MessageContentType.contactProfile:
        await _receiveContact(received, contact, deviceInfo);
        break;
      case MessageContentType.contactOptions:
        insertOk = await _receiveContactOptions(received, contact, deviceInfo);
        break;
      case MessageContentType.deviceRequest:
        await _receiveDeviceRequest(received, contact);
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
    }
    // receipt
    if (insertOk && received.canReceipt) {
      if (received.isTopic) {
        // handle in send topic with self receipt
      } else if (received.isPrivateGroup) {
        // handle in send group with self receipt
      } else {
        chatOutCommon.sendReceipt(received); // await
      }
    }
    // session
    if (insertOk && received.canDisplay) {
      await chatCommon.sessionHandle(received);
    }
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receivePing(MessageSchema received) async {
    // if (received.isTopic) return; (limit in out)
    if ((received.from == received.to) || (received.from == clientCommon.address)) {
      logger.v("$TAG - _receivePing - ping self receive - received:$received");
      return true;
    }
    if ((received.content == null) || !(received.content is String)) {
      logger.e("$TAG - _receivePing - content error - from:${received.from} - received:$received");
      return false;
    }
    String content = received.content as String;
    if (content == "ping") {
      logger.i("$TAG - _receivePing - receive ping - from:${received.from}");
      chatOutCommon.sendPing([received.from], false, gap: Settings.gapPongPingMs); // await
    } else if (content == "pong") {
      logger.i("$TAG - _receivePing - receive pong - from:${received.from}");
      // nothing
    } else {
      logger.e("$TAG - _receivePing - content wrong - received:$received");
      return false;
    }
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  Future<bool> _receiveReceipt(MessageSchema received, DeviceInfoSchema? deviceInfo) async {
    // if (received.isTopic) return; (limit in out, just receive self msg)
    if ((received.content == null) || !(received.content is String)) return false;
    if (!received.canReceipt) return false;
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.content, MessageContentType.piece);
    if (exists == null || exists.targetId.isEmpty) {
      logger.w("$TAG - _receiveReceipt - target is empty - received:$received");
      return false;
    } else if (!exists.isOutbound || (exists.status == MessageStatus.Received)) {
      logger.w("$TAG - receiveReceipt - outbound error - exists:$exists");
      return false;
    } else if ((exists.status == MessageStatus.Receipt) || (exists.status == MessageStatus.Read)) {
      logger.v("$TAG - receiveReceipt - duplicated - exists:$exists");
      return false;
    } else if ((exists.isTopic || exists.isPrivateGroup) && !((received.from == received.to) && (received.from == clientCommon.address))) {
      logger.w("$TAG - receiveReceipt - group skip others - exists:$exists");
      return false;
    }
    // status
    bool readSupport = DeviceInfoCommon.isMsgReadEnable(deviceInfo?.platform, deviceInfo?.appVersion);
    if (exists.isTopic || exists.isPrivateGroup || !readSupport) {
      await messageCommon.updateMessageStatus(exists, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch);
    } else {
      await messageCommon.updateMessageStatus(exists, MessageStatus.Receipt, receiveAt: DateTime.now().millisecondsSinceEpoch);
    }
    // topicInvitation
    if (exists.contentType == MessageContentType.topicInvitation) {
      await subscriberCommon.onInvitedReceipt(exists.content, received.from);
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
    if (msgList.isEmpty) {
      logger.w("$TAG - _receiveRead - msgIds is nil - from:${received.from} - received:$received");
      return true;
    }
    logger.i("$TAG - _receiveRead - count:${msgList.length} - from:${received.from} - msgIds:$msgIds");
    // update
    for (var i = 0; i < msgList.length; i++) {
      MessageSchema message = msgList[i];
      int? receiveAt = (message.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
      await messageCommon.updateMessageStatus(message, MessageStatus.Read, receiveAt: receiveAt);
    }
    // FUTURE:GG msgStatus 会导致有的没发过去，但这里显示read，check时被遗漏，所以需要加吗？可以看看新版需要怎么做
    // read history
    // msgList.sort((prev, next) => (prev.sendAt ?? 0).compareTo(next.sendAt ?? 0));
    // int reallySendAt = msgList[msgList.length - 1].sendAt ?? 0;
    // await messageCommon.readMessageBySide(received.targetId, received.topic, received.groupId, reallySendAt);
    return true;
  }

  // NO DB NO display NO topic (1 to 1)
  /*Future<bool> _receiveMsgStatus(MessageSchema received) async {
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
          int gap = DateTime.now().millisecondsSinceEpoch - (resendAt ?? DateTime.now().millisecondsSinceEpoch);
          if ((resendAt != null) && (gap < 5 * 60 * 1000)) {
            logger.i("$TAG - _receiveMsgStatus - resend just now - gap:${gap / 1000} - msgId:$msgId - received:$received");
            continue;
          }
          logger.i("$TAG - _receiveMsgStatus - msg resend - status:$status - gap:${gap / 1000} - received:$received");
          message.options = MessageOptions.setResendMuteAt(message.options, DateTime.now().millisecondsSinceEpoch);
          await MessageStorage.instance.updateOptions(msgId, message.options);
          chatOutCommon.resendMute(message); // await
        } else {
          // update status
          int reallyStatus = (status == MessageStatus.Read) ? MessageStatus.Read : MessageStatus.SendReceipt;
          int? receiveAt = ((reallyStatus == MessageStatus.Read) && (message.receiveAt == null)) ? DateTime.now().millisecondsSinceEpoch : message.receiveAt;
          logger.i("$TAG - _receiveMsgStatus - msg update status - status:$reallyStatus - receiveAt:$receiveAt - received:$received");
          await messageCommon.updateMessageStatus(message, reallyStatus, receiveAt: receiveAt, notify: true);
        }
      }
    } else {
      logger.e("$TAG - _receiveMsgStatus - requestType error - requestType:$requestType - messageIds:$messageIds - received:$received");
      return false;
    }
    return true;
  }*/

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
      int gap;
      if ((version?.isNotEmpty == true) && (version != deviceInfo?.contactProfileResponseVersion)) {
        logger.i('$TAG - _receiveContact - version diff - from:${received.from} - requested:${deviceInfo?.contactProfileResponseVersion} - remote:$version');
        gap = 0;
      } else {
        logger.d('$TAG - _receiveContact - version same - from:${received.from} - requested:${deviceInfo?.contactProfileResponseVersion} - remote:$version');
        gap = Settings.gapContactProfileSyncMs;
      }
      if (requestType == ContactRequestType.header) {
        logger.i("$TAG - _receiveContact - response head - from:${received.from} - data:$data");
        chatOutCommon.sendContactProfileResponse(contact.clientAddress, ContactRequestType.header, deviceInfo: deviceInfo, gap: gap).then((value) {
          if (value) deviceInfoCommon.setContactProfileResponseInfo(contact.clientAddress, deviceInfo?.deviceId, version);
        }); // await
      } else {
        logger.i("$TAG - _receiveContact - response full - from:${received.from} - data:$data");
        chatOutCommon.sendContactProfileResponse(contact.clientAddress, ContactRequestType.full, deviceInfo: deviceInfo, gap: gap).then((value) {
          if (value) deviceInfoCommon.setContactProfileResponseInfo(contact.clientAddress, deviceInfo?.deviceId, version);
        }); // await
      }
    } else {
      // need request/save
      if (!contactCommon.isProfileVersionSame(contact.profileVersion, version)) {
        if ((responseType != ContactRequestType.full) && (content == null)) {
          logger.i("$TAG - _receiveContact - request full - from:${received.from} - data:$data");
          chatOutCommon.sendContactProfileRequest(contact.clientAddress, ContactRequestType.full, contact.profileVersion); // await
        } else {
          if (content == null) {
            logger.e("$TAG - _receiveContact - content is empty - data:$data - from:${received.from}");
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
              logger.w("$TAG - _receiveContact - avatar_data is empty - data:$data - from:${received.from}");
            }
          } else {
            logger.i("$TAG - _receiveContact - avatar_type is empty - data:$data - from:${received.from}");
          }
          // if (firstName.isEmpty || lastName.isEmpty || (avatar?.path ?? "").isEmpty) {
          //   logger.i("$TAG - receiveContact - setProfile - NULL");
          // } else {
          await contactCommon.setOtherProfile(contact, version, avatarPath, firstName, lastName, notify: true);
          logger.i("$TAG - _receiveContact - updateProfile - firstName:$firstName - lastName:$lastName - avatar:$avatarPath - version:$version - data:$data - from:${received.from}");
          // }
        }
      } else {
        logger.d("$TAG - _receiveContact - profile version same - from:${received.from} - data:$data");
      }
    }
    return true;
  }

  // NO topic (1 to 1)
  Future<bool> _receiveContactOptions(MessageSchema received, ContactSchema? contact, DeviceInfoSchema? deviceInfo) async {
    if (contact == null) return false;
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveContactOptions - duplicated - message:$exists");
      return false;
    }
    // options type / received.isTopic (limit in out)
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? optionsType = data['optionType']?.toString();
    Map<String, dynamic> content = data['content'] ?? Map();
    if (optionsType == null || optionsType.isEmpty) return false;
    if (optionsType == '0') {
      int burningSeconds = (content['deleteAfterSeconds'] as int?) ?? 0;
      int updateAt = (content['updateBurnAfterAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      logger.i("$TAG - _receiveContactOptions - setBurning - from:${received.from} - burningSeconds:$burningSeconds - updateAt:${DateTime.fromMillisecondsSinceEpoch(updateAt)}");
      bool success = await contactCommon.setOptionsBurn(contact, burningSeconds, updateAt, notify: true);
      if (!success) return false;
    } else if (optionsType == '1') {
      String deviceToken = content['deviceToken']?.toString() ?? "";
      if (deviceInfo?.deviceToken != deviceToken) {
        logger.i("$TAG - _receiveContactOptions - setDeviceToken - from:${received.from} - deviceToken:$deviceToken");
        bool success = await deviceInfoCommon.setDeviceToken(deviceInfo?.contactAddress, deviceInfo?.deviceId, deviceToken);
        if (!success) return false;
      } else {
        logger.w("$TAG - _receiveContactOptions - deviceToken same - from:${received.from} - data:$data");
      }
    } else {
      logger.e("$TAG - _receiveContactOptions - setNothing - data:$data - from:${received.from}");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // NO DB NO display
  Future<bool> _receiveDeviceRequest(MessageSchema received, ContactSchema? contact) async {
    if (contact == null) return false;
    bool notificationOpen = contact.options?.notificationOpen ?? false;
    DeviceInfoSchema? deviceInfo = await deviceInfoCommon.getMe(canAdd: true, fetchDeviceToken: notificationOpen);
    if (deviceInfo == null) return false;
    chatOutCommon.sendDeviceInfo(contact.clientAddress, deviceInfo, notificationOpen); // await
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
    // exist
    DeviceInfoSchema? exists = await deviceInfoCommon.queryByDeviceId(contact.clientAddress, data["deviceId"]);
    // add (wrong here)
    if (exists == null) {
      DeviceInfoSchema deviceInfo = DeviceInfoSchema(
        contactAddress: contact.clientAddress,
        deviceId: deviceId ?? "",
        deviceToken: deviceToken,
        onlineAt: DateTime.now().millisecondsSinceEpoch,
        data: newData,
      );
      exists = await deviceInfoCommon.add(deviceInfo);
      logger.w("$TAG - _receiveDeviceInfo - add(wrong here) - new:$exists - data:$data");
      return exists != null;
    }
    // update_data
    bool sameProfile = (appName == exists.appName) && (appVersion == exists.appVersion.toString()) && (platform == exists.platform) && (platformVersion == exists.platformVersion.toString());
    if (!sameProfile) {
      logger.i("$TAG - _receiveDeviceInfo - profile update - newData:$newData - oldData:${exists.data} - from:${received.from}");
      bool success = await deviceInfoCommon.setProfile(exists.contactAddress, exists.deviceId, newData);
      if (success) exists.data = newData;
    }
    // update_token
    if ((exists.deviceToken != deviceToken) && (deviceToken?.isNotEmpty == true)) {
      logger.i("$TAG - _receiveDeviceInfo - deviceToken update - new:$deviceToken - old${exists.deviceToken} - from:${received.from}");
      bool success = await deviceInfoCommon.setDeviceToken(exists.contactAddress, exists.deviceId, deviceToken);
      if (success) exists.deviceToken = deviceToken;
    }
    // update_online
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    bool success = await deviceInfoCommon.setOnlineAt(exists.contactAddress, exists.deviceId, onlineAt: nowAt);
    if (success) exists.onlineAt = nowAt;
    return true;
  }

  Future<bool> _receiveText(MessageSchema received) async {
    if (received.content == null) return false;
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveText - duplicated - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveIpfs(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receiveIpfs - duplicated - message:${exists.toStringNoContent()}");
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
    messageCommon.onSavedSink.add(inserted);
    // thumbnail
    if (ipfsThumbnailHash != null && ipfsThumbnailHash.isNotEmpty) {
      chatCommon.startIpfsThumbnailDownload(inserted); // await
    }
    return true;
  }

  Future<bool> _receiveImage(MessageSchema received) async {
    if (received.content == null) return false;
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - _receiveImage - duplicated - message:${exists.toStringNoContent()}");
      return false;
    }
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_IMAGE_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_IMAGE_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - _receiveImage - content is null - message:${received.toStringNoContent()}");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    bool isPieceCombine = received.options?[MessageOptions.KEY_FROM_PIECE] ?? false;
    if (isPieceCombine) _deletePieces(received.msgId); // await
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  Future<bool> _receiveAudio(MessageSchema received) async {
    if (received.content == null) return false;
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.queryByIdNoContentType(received.msgId, MessageContentType.piece);
    if (exists != null) {
      logger.d("$TAG - _receiveAudio - duplicated - message:${exists.toStringNoContent()}");
      return false;
    }
    // File
    String fileExt = MessageOptions.getFileExt(received.options) ?? FileHelper.DEFAULT_AUDIO_EXT;
    if (fileExt.isEmpty) fileExt = FileHelper.DEFAULT_AUDIO_EXT;
    received.content = await FileHelper.convertBase64toFile(received.content, (ext) => Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: received.targetId, fileExt: ext ?? fileExt));
    if (received.content == null) {
      logger.e("$TAG - _receiveAudio - content is null - message:${received.toStringNoContent()}");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
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
    int index = received.options?[MessageOptions.KEY_PIECE_INDEX] ?? 1;
    // combined duplicated
    List<MessageSchema> existsCombine = await MessageStorage.instance.queryListByIdContentType(received.msgId, parentType, limit: 1);
    if (existsCombine.isNotEmpty) {
      logger.d("$TAG - _receivePiece - combine exists - index:$index - message:${received.toStringNoContent()}");
      // if (!received.isTopic && index <= 1) chatOutCommon.sendReceipt(existsCombine[0]); // await
      return false;
    }
    // piece
    List<MessageSchema> pieces = await MessageStorage.instance.queryListByIdContentType(received.msgId, MessageContentType.piece, limit: total + parity);
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
      piece = await MessageStorage.instance.insert(received);
      if (piece != null) {
        pieces.add(piece);
      } else {
        logger.w("$TAG - _receivePiece - piece added null - message:${received.toStringNoContent()}");
      }
    }
    logger.d("$TAG - _receivePiece - progress:$total/${pieces.length}/${total + parity}");
    if (pieces.length < total || bytesLength <= 0) return false;
    logger.i("$TAG - _receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${Format.flowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    pieces.sort((prev, next) => (prev.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0).compareTo((next.options?[MessageOptions.KEY_PIECE_INDEX] ?? 0)));
    // combine
    String? base64String = await MessageSchema.combinePiecesData(pieces, total, parity, bytesLength);
    if ((base64String == null) || base64String.isEmpty) {
      if (pieces.length >= (total + parity)) {
        logger.e("$TAG - _receivePiece - COMBINE:FAIL - base64String is empty and delete pieces - message:${received.toStringNoContent()}");
        await _deletePieces(received.msgId); // delete wrong pieces
      } else {
        logger.e("$TAG - _receivePiece - COMBINE:FAIL - base64String is empty - message:${received.toStringNoContent()}");
      }
      return false;
    }
    MessageSchema? combine = MessageSchema.combinePiecesMsg(pieces, base64String);
    if (combine == null) {
      logger.e("$TAG - _receivePiece - COMBINE:FAIL - message combine is empty - message:${received.toStringNoContent()}");
      return false;
    }
    // combine.content - handle later
    logger.i("$TAG - _receivePiece - COMBINE:SUCCESS - combine:$combine");
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
    Function() syncSubscribe = () async {
      int tryTimes = 0;
      while (tryTimes < 10) {
        SubscriberSchema? _subscriber = await topicCommon.onSubscribe(received.topic, received.from);
        if (!historySubscribed && (_subscriber != null)) {
          MessageSchema? inserted = await MessageStorage.instance.insert(received);
          if (inserted != null) messageCommon.onSavedSink.add(inserted);
        }
        if (_subscriber != null) {
          logger.i("$TAG - _receiveTopicSubscribe - check subscribe success - tryTimes:$tryTimes - topic:${received.topic} - address:${received.from}");
          break;
        }
        logger.w("$TAG - _receiveTopicSubscribe - check subscribe continue(txPool) - tryTimes:$tryTimes - topic:${received.topic} - address:${received.from}");
        tryTimes++;
        await Future.delayed(Duration(seconds: 5));
      }
    };
    syncSubscribe(); // await
    return !historySubscribed;
  }

  // NO single
  Future<bool> _receiveTopicUnsubscribe(MessageSchema received) async {
    topicCommon.onUnsubscribe(received.topic, received.from); // await
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
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

  // NO single
  Future<bool> _receiveTopicKickOut(MessageSchema received) async {
    if ((received.content == null) || !(received.content is String)) return false;
    topicCommon.onKickOut(received.topic, received.from, received.content); // await
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
    messageCommon.onSavedSink.add(inserted);
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
      logger.e('$TAG - _receivePrivateGroupAccept - invitee nil - data:$data - from:${received.from}');
      return false;
    }
    // insert (sync self)
    PrivateGroupSchema? groupSchema = await privateGroupCommon.onInviteeAccept(newGroupItem, notify: true);
    if (groupSchema == null) {
      logger.w('$TAG - _receivePrivateGroupAccept - Invitee accept fail - data:$data - from:${received.from}');
      return false;
    }
    // members
    List<PrivateGroupItemSchema> members = await privateGroupCommon.getMembersAll(groupId);
    if (members.length <= 0) {
      logger.e('$TAG - _receivePrivateGroupAccept - has no this group info - data:$data - from:${received.from}');
      return false;
    }
    // sync invitee
    chatOutCommon.sendPrivateGroupOptionResponse([newGroupItem.invitee ?? ""], groupSchema).then((success) {
      if (!success) {
        logger.e('$TAG - _receivePrivateGroupAccept - sync inviter options fail - data:$data - from:${received.from}');
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

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupSubscribe(MessageSchema received) async {
    // duplicated
    MessageSchema? exists = await MessageStorage.instance.query(received.msgId);
    if (exists != null) {
      logger.d("$TAG - _receivePrivateGroupSubscribe - duplicated - message:$exists");
      return false;
    }
    // DB
    MessageSchema? inserted = await MessageStorage.instance.insert(received);
    if (inserted == null) return false;
    // display
    messageCommon.onSavedSink.add(inserted);
    return true;
  }

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

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupOptionRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    privateGroupCommon.pushPrivateGroupOptions(received.from, groupId, version); // await
    return true;
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
      if (group.membersRequestedVersion != version) {
        logger.i('$TAG - _receivePrivateGroupOptionResponse - version requested diff - from:${received.from} - requested:${group.membersRequestedVersion} - remote:$version');
      } else {
        logger.d('$TAG - _receivePrivateGroupOptionResponse - version requested same - from:${received.from} - version:$version');
      }
      int gap = (group.membersRequestedVersion != version) ? 0 : Settings.gapGroupRequestMembersMs;
      chatOutCommon.sendPrivateGroupMemberRequest(received.from, groupId, gap: gap).then((version) {
        if (version?.isNotEmpty == true) {
          privateGroupCommon.setGroupMembersRequestInfo(group, version, notify: true);
        }
      }); // await
    }
  }

  // NO group (1 to 1)
  Future<bool> _receivePrivateGroupMemberRequest(MessageSchema received) async {
    if ((received.content == null) || !(received.content is Map<String, dynamic>)) return false;
    Map<String, dynamic> data = received.content; // == data
    String? groupId = data['groupId']?.toString();
    String? version = data['version']?.toString();
    privateGroupCommon.pushPrivateGroupMembers(received.from, groupId, version); // await
    return true;
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
    int limit = 20;
    List<MessageSchema> pieces = [];
    for (int offset = 0; true; offset += limit) {
      var result = await MessageStorage.instance.queryListByIdContentType(msgId, MessageContentType.piece, offset: offset, limit: limit);
      pieces.addAll(result);
      if (result.length < limit) break;
    }
    logger.i("$TAG - _deletePieces - DELETE:START - pieces_count:${pieces.length}");
    int count = 0;
    int result = await MessageStorage.instance.deleteByIdContentType(msgId, MessageContentType.piece);
    if (result > 0) {
      for (var i = 0; i < pieces.length; i++) {
        MessageSchema piece = pieces[i];
        if (piece.content is File) {
          if ((piece.content as File).existsSync()) {
            await (piece.content as File).delete();
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
