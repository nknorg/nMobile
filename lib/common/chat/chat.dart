import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class ChatCommon with Tag {
  ChatCommon();

  // current page
  String? currentChatTargetId;

  // checker
  // Map<String, Map<String, dynamic>> _checkersParams = Map();
  // ParallelQueue _checkQueue = ParallelQueue("checker_msg", parallel: 3, onLog: (log, error) => error ? logger.w(log) : null);

  void reset({bool reClient = false, bool netError = false}) {
    // currentChatTargetId = null; // can not be reset
    // _checkersParams.clear();
    // TODO:GG reClient和netError 是否会导致msg和ipfs的中断????
    resetMessageSending(); // await
    if (!reClient || netError) resetIpfsDownloadIng(thumbnailAutoDownload: true); // await
  }

  // TODO:GG 再看看
  /*Future checkMsgStatus(String? targetId, bool isTopic, bool isGroup, {bool refresh = false, int filterSec = 10}) async {
    if (targetId == null || targetId.isEmpty) return;
    // delay
    if (_checkersParams[targetId] == null) _checkersParams[targetId] = Map();
    int initDelay = 2; // 2s
    int maxDelay = 10; // 10s
    int? delay = _checkersParams[targetId]?["delay"];
    if (refresh || (delay == null) || (delay == 0)) {
      _checkersParams[targetId]?["delay"] = initDelay;
      logger.v("$TAG - checkMsgStatus - delay init - delay:${_checkersParams[targetId]?["delay"]} - targetId:$targetId");
    } else if (!_checkQueue.contains(targetId)) {
      _checkersParams[targetId]?["delay"] = ((delay * 2) >= maxDelay) ? maxDelay : (delay * 2);
      logger.v("$TAG - checkMsgStatus - delay * 2 - delay:${_checkersParams[targetId]?["delay"]} - targetId:$targetId");
    } else {
      logger.v("$TAG - checkMsgStatus - delay same - delay:${_checkersParams[targetId]?["delay"]} - targetId:$targetId");
    }
    // queue
    if (_checkQueue.contains(targetId)) {
      logger.d("$TAG - checkMsgStatus - cancel old - delay:${_checkersParams[targetId]?["delay"]} - targetId:$targetId");
      _checkQueue.deleteDelays(targetId);
    }
    await _checkQueue.add(() async {
      try {
        logger.i("$TAG - checkMsgStatus - start - delay:${_checkersParams[targetId]?["delay"]} - targetId:$targetId");
        final count = await _checkMsgStatus(targetId, isTopic, isGroup, filterSec: filterSec);
        logger.i("$TAG - checkMsgStatus - end - count:$count - targetId:$targetId");
        _checkersParams[targetId]?["delay"] = 0;
      } catch (e, st) {
        handleError(e, st);
      }
    }, id: targetId, delay: Duration(seconds: _checkersParams[targetId]?["delay"] ?? initDelay));
  }

  Future<int> _checkMsgStatus(String? targetId, bool isTopic, bool isGroup, {bool forceResend = false, int filterSec = 10}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return 0;
    if (targetId == null || targetId.isEmpty) return 0;

    int limit = 20;
    int maxCount = 20;
    List<MessageSchema> checkList = [];

    // noAck
    for (int offset = 0; true; offset += limit) {
      final result = await MessageStorage.instance.queryListByStatus(MessageStatus.SendSuccess, targetId: targetId, topic: isTopic ? targetId : "", groupId: isGroup ? targetId : "", offset: offset, limit: limit);
      final canReceipts = result.where((element) => element.canReceipt).toList();
      checkList.addAll(canReceipts);
      logger.d("$TAG - _checkMsgStatus - noAck - offset:$offset - current_len:${canReceipts.length} - total_len:${checkList.length}");
      if (result.length < limit) break;
      if ((offset + limit) >= maxCount) break;
    }

    // noRead
    // for (int offset = 0; true; offset += limit) {
    //   final result = await MessageStorage.instance.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, topic: isTopic ? targetId : "", offset: offset, limit: limit);
    //   final canReceipts = result.where((element) => element.canReceipt).toList();
    //   checkList.addAll(canReceipts);
    //   logger.d("$TAG - _checkMsgStatus - noRead - offset:$offset - current_len:${canReceipts.length} - total_len:${checkList.length}");
    //   if (result.length < limit) break;
    //   if ((offset + limit) >= maxCount) break;
    // }

    // filter
    checkList = checkList.where((element) {
      int msgSendAt = MessageOptions.getOutAt(element.options) ?? 0;
      int between = DateTime.now().millisecondsSinceEpoch - msgSendAt;
      int filter = element.canTryPiece ? (filterSec + 10) : filterSec;
      if (between < (filter * 1000)) {
        logger.d("$TAG - _checkMsgStatus - sendAt justNow - targetId:$targetId - message:$element");
        return false;
      }
      return true;
    }).toList();

    if (checkList.isEmpty) {
      logger.d("$TAG - _checkMsgStatus - OK OK OK - targetId:$targetId - isTopic:$isTopic - isGroup:$isGroup");
      return 0;
    }

    // resend
    if (isTopic || isGroup || forceResend) {
      for (var i = 0; i < checkList.length; i++) {
        MessageSchema element = checkList[i];
        chatOutCommon.resendMute(element);
      }
    } else {
      List<String> msgIds = [];
      checkList.forEach((element) {
        if (element.msgId.isNotEmpty) {
          msgIds.add(element.msgId);
        }
      });
      chatOutCommon.sendMsgStatus(targetId, true, msgIds); // await
    }
    return checkList.length;
  }*/

  Future sendPings2LatestSessions() async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    int max = 20;
    int limit = 20;
    List<String> targetIds = [];
    // sessions
    for (int offset = 0; true; offset += limit) {
      List<SessionSchema> result = await sessionCommon.queryListRecent(offset: offset, limit: limit);
      bool lastTimeOK = true;
      result.forEach((element) {
        int between = DateTime.now().millisecondsSinceEpoch - (element.lastMessageAt ?? 0);
        lastTimeOK = between < Settings.gapPingSessionOnlineMs;
        if (element.isContact && lastTimeOK) {
          targetIds.add(element.targetId);
        }
      });
      logger.d("$TAG - sendPings2LatestSessions - offset:$offset - current_len:${result.length} - total_len:${targetIds.length}");
      if (!lastTimeOK || (result.length < limit) || (targetIds.length >= max)) break;
    }
    // send
    await chatOutCommon.sendPing(targetIds, true, gap: Settings.gapPingSessionsMs);
  }

  Future<int> resetMessageSending({int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;
    // sending list
    List<MessageSchema> sendingList = [];
    int limit = 20;
    for (int offset = 0; true; offset += limit) {
      final result = await MessageStorage.instance.queryListByStatus(MessageStatus.Sending, offset: offset, limit: limit);
      sendingList.addAll(result);
      logger.d("$TAG - resetMessageSending - offset:$offset - current_len:${result.length} - total_len:${sendingList.length}");
      if (result.length < limit) break;
    }
    // update status
    for (var i = 0; i < sendingList.length; i++) {
      MessageSchema message = sendingList[i];
      logger.i("$TAG - resetMessageSending - sendFail add - targetId:${message.targetId} - message:$message");
      if (message.canResend) {
        message = await messageCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
        if (message.contentType == MessageContentType.ipfs) {
          message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
          await MessageStorage.instance.updateOptions(message.msgId, message.options);
        }
      } else {
        // lost some msg, need resend
        int count = await MessageStorage.instance.deleteByIdContentType(message.msgId, message.contentType);
        if (count > 0) messageCommon.onDeleteSink.add(message.msgId);
      }
    }
    logger.i("$TAG - resetMessageSending - checkCount:${sendingList.length}");
    return sendingList.length;
  }

  Future resetIpfsDownloadIng({bool thumbnailAutoDownload = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;
    // file
    String fileDownloadKey = "IPFS_FILE_DOWNLOAD_PROGRESS_IDS_${clientCommon.address}";
    List fileDownloadIds = (await SettingsStorage.getSettings(fileDownloadKey)) ?? [];
    List<String> fileIds = [];
    fileDownloadIds.forEach((element) => fileIds.add(element.toString()));
    logger.i("$TAG - resetIpfsDownloadIng - file - fileIds:${fileIds.toString()}");
    List<MessageSchema> fileResults = await MessageStorage.instance.queryListByIds(fileIds);
    for (var j = 0; j < fileResults.length; j++) {
      MessageSchema message = fileResults[j];
      if (message.contentType != MessageContentType.ipfs) {
        await _onIpfsDownload(message.msgId, "FILE", true);
        continue;
      } else if (MessageOptions.getIpfsState(message.options) != MessageOptions.ipfsStateIng) {
        await _onIpfsDownload(message.msgId, "FILE", MessageOptions.getIpfsState(message.options) == MessageOptions.ipfsStateYes);
        continue;
      }
      message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      message.status = message.isOutbound ? MessageStatus.SendFail : message.status;
      messageCommon.onUpdateSink.add(message);
    }
    // thumbnail
    String thumbnailDownloadKey = "IPFS_THUMBNAIL_DOWNLOAD_PROGRESS_IDS_${clientCommon.address}";
    List thumbnailDownloadIds = (await SettingsStorage.getSettings(thumbnailDownloadKey)) ?? [];
    List<String> thumbnailIds = [];
    thumbnailDownloadIds.forEach((element) => thumbnailIds.add(element.toString()));
    logger.i("$TAG - resetIpfsDownloadIng - thumbnail - thumbnailIds:${thumbnailIds.toString()}");
    List<MessageSchema> thumbnailResults = await MessageStorage.instance.queryListByIds(thumbnailIds);
    for (var j = 0; j < thumbnailResults.length; j++) {
      MessageSchema message = thumbnailResults[j];
      if (message.contentType != MessageContentType.ipfs) {
        await _onIpfsDownload(message.msgId, "THUMBNAIL", true);
        continue;
      } else if (MessageOptions.getIpfsThumbnailState(message.options) == MessageOptions.ipfsThumbnailStateYes) {
        await _onIpfsDownload(message.msgId, "THUMBNAIL", true);
        continue;
      }
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      // messageCommon.onUpdateSink.add(message);
      // try download TODO:GG 为什么要有时间限制？
      int gap = 3 * 24 * 60 * 60 * 1000; // 3d
      int between = DateTime.now().millisecondsSinceEpoch - (message.receiveAt ?? 0);
      if ((between < gap) && thumbnailAutoDownload) {
        startIpfsThumbnailDownload(message); // await
      } else {
        await _onIpfsDownload(message.msgId, "THUMBNAIL", true);
      }
    }
  }

  ///*********************************************************************************///
  ///************************************* Handle ************************************///
  ///*********************************************************************************///

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    String? clientAddress = message.isOutbound ? ((message.isTopic || message.isPrivateGroup) ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    if (message.from == message.to) return exist;
    // duplicated
    if (exist == null) {
      logger.i("$TAG - contactHandle - new - clientAddress:$clientAddress");
      int type = (message.isTopic || message.isPrivateGroup) ? ContactType.none : (message.canDisplay ? ContactType.stranger : ContactType.none);
      exist = await contactCommon.addByType(clientAddress, type, notify: true, checkDuplicated: false);
    } else {
      if (message.canDisplay && (exist.type == ContactType.none) && !((message.isTopic || message.isPrivateGroup))) {
        bool success = await contactCommon.setType(exist.id, ContactType.stranger, notify: true);
        if (success) exist.type = ContactType.stranger;
      }
    }
    if (exist == null) {
      logger.e("$TAG - contactHandle - exist is nil - clientAddress:$clientAddress");
      return null;
    }
    if (message.isOutbound) return exist;
    // profile
    if (!message.isTopic && !message.isPrivateGroup) {
      String? profileVersion = MessageOptions.getProfileVersion(message.options);
      if (profileVersion != null && profileVersion.isNotEmpty) {
        if (!contactCommon.isProfileVersionSame(exist.profileVersion, profileVersion)) {
          chatOutCommon.sendContactProfileRequest(exist.clientAddress, ContactRequestType.full, exist.profileVersion); // await
        }
      }
    }
    // burning
    if (!message.isTopic && !message.isPrivateGroup && message.canBurning) {
      int? existSeconds = exist.options?.deleteAfterSeconds;
      int? existUpdateAt = exist.options?.updateBurnAfterAt;
      int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
      int? updateBurnAfterAt = MessageOptions.getOptionsBurningUpdateAt(message.options);
      if (((burnAfterSeconds ?? 0) > 0) && (existSeconds != burnAfterSeconds)) {
        // no same with self
        if ((existUpdateAt == null) || ((updateBurnAfterAt ?? 0) >= existUpdateAt)) {
          // side updated latest
          exist.options?.deleteAfterSeconds = burnAfterSeconds;
          exist.options?.updateBurnAfterAt = updateBurnAfterAt;
          await contactCommon.setOptionsBurn(exist, burnAfterSeconds, updateBurnAfterAt, notify: true);
        } else {
          // mine updated latest
          if ((message.sendAt ?? 0) > existUpdateAt) {
            DeviceInfoSchema? deviceInfo;
            String? deviceId = MessageOptions.getDeviceId(message.options);
            if (deviceId?.isNotEmpty == true) {
              deviceInfo = await deviceInfoCommon.queryByDeviceId(clientAddress, deviceId);
            } else {
              deviceInfo = await deviceInfoCommon.queryLatest(clientAddress);
            }
            if (DeviceInfoCommon.isBurningUpdateAtEnable(deviceInfo?.platform, deviceInfo?.appVersion)) {
              chatOutCommon.sendContactOptionsBurn(exist.clientAddress, (existSeconds ?? 0), existUpdateAt); // await
            }
          }
        }
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> deviceInfoHandle(MessageSchema message) async {
    String? clientAddress = message.isOutbound ? ((message.isTopic || message.isPrivateGroup) ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    // latest
    DeviceInfoSchema? latest;
    String? deviceId = MessageOptions.getDeviceId(message.options);
    if (!message.isOutbound && (deviceId?.isNotEmpty == true)) {
      latest = await deviceInfoCommon.queryByDeviceId(clientAddress, deviceId);
    } else {
      latest = await deviceInfoCommon.queryLatest(clientAddress);
    }
    if (message.from == message.to) return latest;
    // duplicated
    if (latest == null) {
      logger.i("$TAG - deviceInfoHandle - new - request - clientAddress:$clientAddress");
      // skip all messages need send contact request
      latest = await deviceInfoCommon.add(
        DeviceInfoSchema(
          contactAddress: clientAddress,
          deviceId: deviceId ?? "",
          onlineAt: DateTime.now().millisecondsSinceEpoch,
        ),
        checkDuplicated: false,
      );
      chatOutCommon.sendDeviceRequest(clientAddress); // await
    }
    if (latest == null) {
      logger.e("$TAG - deviceInfoHandle - exist is nil - clientAddress:$clientAddress");
      return null;
    }
    if (message.isOutbound) return latest;
    // data
    String? deviceProfile = MessageOptions.getDeviceProfile(message.options);
    if (deviceProfile != null && deviceProfile.isNotEmpty) {
      List<String> splits = deviceProfile.split(":");
      String? appName = splits.length > 0 ? splits[0] : null;
      String? appVersion = splits.length > 1 ? splits[1] : null;
      String? platform = splits.length > 2 ? splits[2] : null;
      String? platformVersion = splits.length > 3 ? splits[3] : null;
      Map<String, dynamic> newData = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
      String? deviceId = splits.length > 4 ? splits[4] : null;
      if (deviceId == null || deviceId.isEmpty) {
        // nothing
      } else if (deviceId == latest.deviceId) {
        // right here
        bool sameProfile = (appName == latest.appName) && (appVersion == latest.appVersion.toString()) && (platform == latest.platform) && (platformVersion == latest.platformVersion.toString());
        if (!sameProfile) {
          bool success = await deviceInfoCommon.setData(latest.contactAddress, latest.deviceId, newData);
          if (success) latest.data = newData;
        }
      } else {
        // wrong here
        DeviceInfoSchema? _exist = await deviceInfoCommon.queryByDeviceId(latest.contactAddress, deviceId);
        if (_exist != null) {
          bool sameProfile = (appName == _exist.appName) && (appVersion == _exist.appVersion.toString()) && (platform == _exist.platform) && (platformVersion == _exist.platformVersion.toString());
          if (!sameProfile) {
            bool success = await deviceInfoCommon.setData(_exist.contactAddress, _exist.deviceId, newData);
            if (success) _exist.data = newData;
          }
          latest = _exist;
        } else {
          DeviceInfoSchema _schema = DeviceInfoSchema(
            contactAddress: latest.contactAddress,
            deviceId: deviceId,
            onlineAt: DateTime.now().millisecondsSinceEpoch,
            data: newData,
          );
          latest = await deviceInfoCommon.add(_schema);
        }
      }
    }
    // device_token (empty updated on receiveDeviceInfo)
    String? deviceToken = MessageOptions.getDeviceToken(message.options);
    if ((deviceToken != null) && (deviceToken.length > 1)) {
      if (latest?.deviceToken != deviceToken) {
        bool success = await deviceInfoCommon.setDeviceToken(latest?.contactAddress, latest?.deviceId, deviceToken);
        if (success) latest?.deviceToken = deviceToken;
      }
    }
    // online_at
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    bool success = await deviceInfoCommon.setOnlineAt(latest?.contactAddress, latest?.deviceId, onlineAt: nowAt);
    if (success) latest?.onlineAt = nowAt;
    return latest;
  }

  Future<TopicSchema?> topicHandle(MessageSchema message) async {
    if (!message.isTopic) return null;
    if (!message.canDisplay && !message.isTopicAction) return null; // topic action need topic
    // duplicated
    TopicSchema? exists = await topicCommon.queryByTopic(message.topic);
    if (exists == null) {
      int expireHeight = await topicCommon.getSubscribeExpireAtByNode(message.topic, clientCommon.address);
      exists = await topicCommon.add(TopicSchema.create(message.topic, expireHeight: expireHeight), notify: true, checkDuplicated: false);
      // expire + permission + subscribers
      if (exists != null) {
        logger.i("$TAG - topicHandle - new - expireHeight:$expireHeight - topic:$exists ");
        topicCommon.checkExpireAndSubscribe(exists.topic, refreshSubscribers: true); // await
      } else {
        logger.w("$TAG - topicHandle - topic is empty - topic:${message.topic} ");
      }
    }
    return exists;
  }

  Future<SubscriberSchema?> subscriberHandle(MessageSchema message, TopicSchema? topic) async {
    if (topic == null || topic.id == null || topic.id == 0) return null;
    if (!message.isTopic) return null;
    if (message.isTopicAction) return null; // action users will handle in later
    // duplicated
    SubscriberSchema? exist = await subscriberCommon.queryByTopicChatId(message.topic, message.from);
    if (exist == null) {
      if (!topic.isPrivate) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - public: add Subscribed - subscriber:$exist");
      } else if (topic.isOwner(message.from)) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - private: add Owner - subscriber:$exist");
      } else {
        // will go here when duration(TxPoolDelay) gone in new version
        List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic.topic, message.from);
        int? permPage = permission[0];
        bool? acceptAll = permission[1];
        bool? isAccept = permission[2];
        bool? isReject = permission[3];
        if (acceptAll == true) {
          exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
          logger.i("$TAG - subscriberHandle - acceptAll: add Subscribed - subscriber:$exist");
        } else {
          if (isReject == true) {
            exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Unsubscribed, permPage));
            logger.w("$TAG - subscriberHandle - reject: add Unsubscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
          } else if (isAccept == true) {
            int expireHeight = await topicCommon.getSubscribeExpireAtByNode(topic.topic, message.from);
            if (expireHeight <= 0) {
              exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.InvitedSend, permPage));
              logger.w("$TAG - subscriberHandle - accept: add invited - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            } else {
              exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Subscribed, permPage));
              logger.w("$TAG - subscriberHandle - accept: add Subscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            }
            // some subscriber status wrong in new version need refresh
            // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
          } else {
            int expireHeight = await topicCommon.getSubscribeExpireAtByNode(topic.topic, message.from);
            if (expireHeight <= 0) {
              exist = await subscriberCommon.add(SubscriberSchema.create(message.topic, message.from, SubscriberStatus.Unsubscribed, permPage));
              logger.w("$TAG - subscriberHandle - none: add Unsubscribed - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            } else {
              exist = SubscriberSchema.create(message.topic, message.from, SubscriberStatus.None, permPage);
              logger.w("$TAG - subscriberHandle - none: just none - from:${message.from} - permission:$permission - topic:$topic - subscriber:$exist");
            }
            // some subscriber status wrong in new version need refresh
            // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
          }
        }
      }
    } else if (exist.status != SubscriberStatus.Subscribed) {
      logger.w("$TAG - subscriberHandle - some subscriber status wrong in new version - from:${message.from} - status:${exist.status} - topic:$topic");
      // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
    }
    return exist;
  }

  Future<PrivateGroupSchema?> privateGroupHandle(MessageSchema message) async {
    if (!message.isPrivateGroup) return null;
    if (!message.canDisplay && !message.isGroupAction) return null; // group action need group
    // duplicated
    PrivateGroupSchema? exists = await privateGroupCommon.queryGroup(message.groupId);
    if (message.from == message.to) return exists;
    if (exists == null) {
      PrivateGroupSchema? schema = PrivateGroupSchema.create(message.groupId, message.groupId);
      exists = await privateGroupCommon.addPrivateGroup(schema, notify: true, checkDuplicated: false);
    }
    if (exists == null) return null;
    if (message.isOutbound) return exists;
    // sync
    if ((clientCommon.address != null) && !privateGroupCommon.isOwner(exists.ownerPublicKey, clientCommon.address)) {
      String? remoteVersion = MessageOptions.getPrivateGroupVersion(message.options) ?? "";
      int nativeCommits = privateGroupCommon.getPrivateGroupVersionCommits(exists.version) ?? 0;
      int remoteCommits = privateGroupCommon.getPrivateGroupVersionCommits(remoteVersion) ?? 0;
      if (nativeCommits < remoteCommits) {
        // burning
        if (privateGroupCommon.isOwner(exists.ownerPublicKey, message.from) && message.canBurning) {
          int? existSeconds = exists.options?.deleteAfterSeconds;
          int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
          if (((burnAfterSeconds ?? 0) > 0) && (existSeconds != burnAfterSeconds)) {
            logger.i('$TAG - privateGroupHandle - burning diff - native:$existSeconds - remote:$burnAfterSeconds');
            exists.options?.deleteAfterSeconds = burnAfterSeconds;
            await privateGroupCommon.setGroupOptionsBurn(exists, burnAfterSeconds, notify: true);
          }
        }
        // request
        if (exists.optionsRequestedVersion != remoteVersion) {
          logger.i('$TAG - privateGroupHandle - version diff - native:${exists.optionsRequestedVersion} - remote:$remoteVersion');
          chatOutCommon.sendPrivateGroupOptionRequest(message.from, message.groupId, gap: Settings.gapRequestGroupOptionsMs).then((version) async {
            if (version?.isNotEmpty == true) {
              exists?.setOptionsRequestAt(DateTime.now().millisecondsSinceEpoch);
              exists?.setOptionsRequestedVersion(version);
              await privateGroupCommon.updateGroupData(exists?.groupId, exists?.data, notify: true);
            }
          }); // await
        }
      }
    }
    return exists;
  }

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    if (message.targetId.isEmpty) return null;
    if (message.from == message.to) return null;
    // type
    int type = SessionType.CONTACT;
    if (message.isTopic) {
      type = SessionType.TOPIC;
    } else if (message.isPrivateGroup) {
      type = SessionType.PRIVATE_GROUP;
    }
    // unreadCount
    bool inSessionPage = chatCommon.currentChatTargetId == message.targetId;
    int unreadCountUp = message.isOutbound ? 0 : (message.canNotification ? 1 : 0);
    unreadCountUp = inSessionPage ? 0 : unreadCountUp;
    // set
    SessionSchema? exist = await sessionCommon.query(message.targetId, type);
    if (exist == null) {
      exist = await sessionCommon.add(message.targetId, type, lastMsg: message, unReadCount: unreadCountUp, checkDuplicated: false);
    } else {
      exist = await sessionCommon.update(message.targetId, type, lastMsg: message, unreadChange: unreadCountUp);
    }
    // badge
    if ((exist != null) && !message.isOutbound && message.canNotification) {
      if (!inSessionPage || (application.appLifecycleState != AppLifecycleState.resumed)) {
        Badge.onCountUp(1); // await
      }
    }
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message, {bool notify = true}) {
    if (message.isTopic) return message; // message.isPrivateGroup
    if (!message.canBurning || message.isDelete) return message;
    if ((message.deleteAt != null) && ((message.deleteAt ?? 0) > 0)) return message;
    if ((message.status == MessageStatus.Sending) || (message.status == MessageStatus.SendFail)) return message; // status_read maybe updating
    int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
    if ((burnAfterSeconds == null) || (burnAfterSeconds <= 0)) return message;
    // set delete time
    message.deleteAt = DateTime.now().add(Duration(seconds: burnAfterSeconds)).millisecondsSinceEpoch;
    logger.v("$TAG - burningHandle - deleteAt - deleteAt:${message.deleteAt}");
    MessageStorage.instance.updateDeleteAt(message.msgId, message.deleteAt).then((success) {
      if (success && notify) messageCommon.onUpdateSink.add(message);
      // if (success && tick) burningTick(message);
    });
    return message;
  }

  MessageSchema burningTick(MessageSchema message, String keyPrefix, {Function? onTick}) {
    if ((message.deleteAt == null) || (message.deleteAt == 0)) return message;
    if ((message.deleteAt ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      String senderKey = message.isOutbound ? message.from : (message.isTopic ? message.topic : (message.isPrivateGroup ? message.groupId : message.to));
      if (senderKey.isEmpty) return message;
      String taskKey = "${TaskService.KEY_MSG_BURNING + keyPrefix}:$senderKey:${message.msgId}";
      taskService.addTask1(taskKey, (String key) {
        if (key != taskKey) {
          // remove others client burning
          taskService.removeTask1(key);
          return;
        }
        if ((message.deleteAt == null) || ((message.deleteAt ?? 0) > DateTime.now().millisecondsSinceEpoch)) {
          // logger.v("$TAG - burningTick - tick - key:$key - msgId:${message.msgId} - deleteTime:${message.deleteAt?.toString()} - now:${DateTime.now()}");
          onTick?.call();
        } else {
          logger.v("$TAG - burningTick - delete(tick) - key:$key - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
          // onTick?.call();
          messageCommon.messageDelete(message, notify: true); // await
          taskService.removeTask1(key);
        }
      });
    } else {
      logger.i("$TAG - burningTick - delete(now) - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
      if (!message.isDelete) {
        message.isDelete = true;
        messageCommon.messageDelete(message, notify: true); // await
      }
      // onTick?.call(); // will dead loop
    }
    return message;
  }

  ///*********************************************************************************///
  ///************************************** Ipfs *************************************///
  ///*********************************************************************************///

  Future<MessageSchema?> startIpfsUpload(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    // file_check
    String? fileHash = MessageOptions.getIpfsHash(message.options);
    if (fileHash != null && fileHash.isNotEmpty) {
      if (MessageOptions.getIpfsState(message.options) != MessageOptions.ipfsStateYes) {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
      }
      return message;
    }
    if (!(message.content is File)) {
      logger.e("$TAG - startIpfsUpload - content is no file - message:$message");
      return null;
    }
    File file = message.content as File;
    if (!file.existsSync()) {
      logger.e("$TAG - startIpfsUpload - file is no exists - message:$message");
      return null;
    }
    // file_state
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    messageCommon.onUpdateSink.add(message);
    // thumbnail
    MessageSchema? msg = await startIpfsThumbnailUpload(message);
    if (msg == null) {
      message = await messageCommon.updateMessageStatus(message, MessageStatus.SendFail, reQuery: true, force: true, notify: true);
      message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      messageCommon.onUpdateSink.add(message);
      return null;
    }
    message = msg;
    // ipfs
    bool success = false;
    Completer completer = Completer();
    ipfsHelper.uploadFile(
      message.msgId,
      file.absolute.path,
      encrypt: true,
      onProgress: (percent) {
        messageCommon.onProgressSink.add({"msg_id": message?.msgId, "percent": percent});
      },
      onSuccess: (result) async {
        message?.options = MessageOptions.setIpfsResult(
          message?.options,
          result[IpfsHelper.KEY_IP],
          result[IpfsHelper.KEY_HASH],
          result[IpfsHelper.KEY_ENCRYPT],
          result[IpfsHelper.KEY_ENCRYPT_ALGORITHM],
          result[IpfsHelper.KEY_ENCRYPT_KEY_BYTES],
          result[IpfsHelper.KEY_ENCRYPT_NONCE_SIZE],
        );
        message?.options = MessageOptions.setIpfsState(message?.options, MessageOptions.ipfsStateYes);
        await MessageStorage.instance.updateOptions(message?.msgId, message?.options);
        success = true;
        if (!completer.isCompleted) completer.complete();
        // chatOutCommon.sendIpfs(message.msgId); // await
      },
      onError: (err) async {
        message = await messageCommon.updateMessageStatus(message!, MessageStatus.SendFail, reQuery: true, force: true, notify: true);
        message?.options = MessageOptions.setIpfsState(message?.options, MessageOptions.ipfsStateNo);
        await MessageStorage.instance.updateOptions(message?.msgId, message?.options);
        messageCommon.onUpdateSink.add(message!);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return success ? message : null;
  }

  Future<MessageSchema?> startIpfsDownload(MessageSchema message) async {
    String? ipfsHash = MessageOptions.getIpfsHash(message.options);
    if (ipfsHash == null || ipfsHash.isEmpty) {
      logger.e("$TAG - startIpfsDownload - ipfsHash is empty - message:$message");
      return null;
    }
    // path
    String? savePath = (message.content as File?)?.absolute.path;
    if (savePath == null || savePath.isEmpty) return null;
    int? ipfsSize = MessageOptions.getFileSize(message.options) ?? -1;
    // state
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    messageCommon.onUpdateSink.add(message);
    await _onIpfsDownload(message.msgId, "FILE", false);
    // ipfs
    bool success = false;
    Completer completer = Completer();
    ipfsHelper.downloadFile(
      message.msgId,
      ipfsHash,
      ipfsSize,
      savePath,
      ipAddress: MessageOptions.getIpfsIp(message.options),
      decrypt: MessageOptions.getIpfsEncrypt(message.options),
      decryptParams: {
        IpfsHelper.KEY_ENCRYPT_ALGORITHM: MessageOptions.getIpfsEncryptAlgorithm(message.options),
        IpfsHelper.KEY_ENCRYPT_KEY_BYTES: MessageOptions.getIpfsEncryptKeyBytes(message.options),
        IpfsHelper.KEY_ENCRYPT_NONCE_SIZE: MessageOptions.getIpfsEncryptNonceSize(message.options),
      },
      onProgress: (percent) {
        messageCommon.onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      },
      onSuccess: () async {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        messageCommon.onUpdateSink.add(message);
        await _onIpfsDownload(message.msgId, "FILE", true);
        success = true;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        messageCommon.onUpdateSink.add(message);
        await _onIpfsDownload(message.msgId, "FILE", false);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return success ? message : null;
  }

  Future<MessageSchema?> startIpfsThumbnailUpload(MessageSchema? message, {int maxTryTimes = 3}) async {
    int tryTimes = 0;
    MessageSchema? msg;
    while (tryTimes < maxTryTimes) {
      List<dynamic> result = await _tryIpfsThumbnailUpload(message);
      msg = result[0];
      bool canTry = result[1];
      if (msg != null) {
        break;
      } else if (canTry) {
        tryTimes++;
      } else {
        break;
      }
    }
    return msg;
  }

  Future<List<dynamic>> _tryIpfsThumbnailUpload(MessageSchema? message) async {
    if (message == null) return [null, false];
    // check
    String? thumbnailHash = MessageOptions.getIpfsThumbnailHash(message.options);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailHash != null && thumbnailHash.isNotEmpty) {
      // success
      if (MessageOptions.getIpfsThumbnailState(message.options) != MessageOptions.ipfsThumbnailStateYes) {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
      }
      return [message, true];
    } else if (thumbnailPath == null || thumbnailPath.isEmpty) {
      // no native thumbnail file
      return [null, false];
    }
    // state
    message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    // ipfs
    bool success = false;
    Completer completer = Completer();
    ipfsHelper.uploadFile(
      message.msgId,
      thumbnailPath,
      encrypt: true,
      onSuccess: (result) async {
        message.options = MessageOptions.setIpfsResultThumbnail(
          message.options,
          result[IpfsHelper.KEY_IP],
          result[IpfsHelper.KEY_HASH],
          result[IpfsHelper.KEY_ENCRYPT],
          result[IpfsHelper.KEY_ENCRYPT_ALGORITHM],
          result[IpfsHelper.KEY_ENCRYPT_KEY_BYTES],
          result[IpfsHelper.KEY_ENCRYPT_NONCE_SIZE],
        );
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        success = true;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return [success ? message : null, true];
  }

  Future<MessageSchema?> startIpfsThumbnailDownload(MessageSchema? message, {int maxTryTimes = 3}) async {
    int tryTimes = 0;
    MessageSchema? msg;
    while (tryTimes < maxTryTimes) {
      List<dynamic> result = await _tryIpfsThumbnailDownload(message);
      msg = result[0];
      bool canTry = result[1];
      if (msg != null) {
        break;
      } else if (canTry) {
        tryTimes++;
      } else {
        break;
      }
    }
    return msg;
  }

  Future<List<dynamic>> _tryIpfsThumbnailDownload(MessageSchema? message) async {
    if (message == null) return [null, false];
    String? ipfsHash = MessageOptions.getIpfsThumbnailHash(message.options);
    if (ipfsHash == null || ipfsHash.isEmpty) {
      logger.e("$TAG - _tryIpfsThumbnailDownload - ipfsHash is empty - message:$message");
      return [null, false];
    }
    // path
    String? savePath = MessageOptions.getMediaThumbnailPath(message.options);
    if (savePath == null || savePath.isEmpty) {
      savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: message.targetId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    }
    // state
    message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    messageCommon.onUpdateSink.add(message);
    await _onIpfsDownload(message.msgId, "THUMBNAIL", false);
    // ipfs
    bool success = false;
    Completer completer = Completer();
    ipfsHelper.downloadFile(
      message.msgId,
      ipfsHash,
      -1,
      savePath,
      ipAddress: MessageOptions.getIpfsIp(message.options),
      decrypt: MessageOptions.getIpfsEncrypt(message.options),
      decryptParams: {
        IpfsHelper.KEY_ENCRYPT_ALGORITHM: MessageOptions.getIpfsThumbnailEncryptAlgorithm(message.options),
        IpfsHelper.KEY_ENCRYPT_KEY_BYTES: MessageOptions.getIpfsThumbnailEncryptKeyBytes(message.options),
        IpfsHelper.KEY_ENCRYPT_NONCE_SIZE: MessageOptions.getIpfsThumbnailEncryptNonceSize(message.options),
      },
      onSuccess: () async {
        message.options = MessageOptions.setMediaThumbnailPath(message.options, savePath);
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        messageCommon.onUpdateSink.add(message);
        await _onIpfsDownload(message.msgId, "THUMBNAIL", true);
        success = true;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        messageCommon.onUpdateSink.add(message);
        await _onIpfsDownload(message.msgId, "THUMBNAIL", false);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return [success ? message : null, true];
  }

  Future<List<String>> _onIpfsDownload(String? msgId, String type, bool completed) async {
    if (msgId == null || msgId.isEmpty) return [];
    String key = "IPFS_${type}_DOWNLOAD_PROGRESS_IDS_${clientCommon.address}";
    List ids = (await SettingsStorage.getSettings(key)) ?? [];
    List<String> idsStr = ids.map((e) => e.toString()).toList();
    logger.i("$TAG - _onIpfsUpOrDownload - start - key:$key - ids:${idsStr.toString()}");
    if (completed) {
      idsStr.remove(msgId.trim());
    } else {
      int index = idsStr.indexOf(msgId.trim());
      if (index < 0) idsStr.add(msgId.trim());
    }
    await SettingsStorage.setSettings(key, idsStr);
    logger.i("$TAG - _onIpfsUpOrDownload - end - key:$key - ids:${idsStr.toString()}");
    return idsStr;
  }
}
