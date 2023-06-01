import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart' as Badge;
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class ChatCommon with Tag {
  ChatCommon();

  // checker
  // Map<String, Map<String, dynamic>> _checkersParams = Map();
  // ParallelQueue _checkQueue = ParallelQueue("checker_msg", parallel: 3, onLog: (log, error) => error ? logger.w(log) : null);

  Future reset(String walletAddress, {bool reset = true}) async {
    logger.i("$TAG - reset - reset:$reset - walletAddress:$walletAddress");
    // currentChatTargetId = null; // can not be reset
    // _checkersParams.clear();
    await resetMessageSending(ipfsReset: reset);
    if (reset) await resetIpfsDownloading(walletAddress, thumbnailAutoDownload: true);
  }

  Future startInitChecks({int? delay}) async {
    if ((delay ?? 0) > 0) await Future.delayed(Duration(milliseconds: delay ?? 0));
    // pings
    List<String> targetIds = [];
    final limit = Settings.maxCountPingSessions;
    for (int offset = 0; true; offset += limit) {
      List<SessionSchema> result = await sessionCommon.queryListRecent(offset: offset, limit: limit);
      bool lastTimeOK = true;
      result.forEach((element) {
        int interval = DateTime.now().millisecondsSinceEpoch - element.lastMessageAt;
        lastTimeOK = interval < Settings.timeoutPingSessionOnlineMs;
        if (element.isContact && lastTimeOK && !targetIds.contains(element.targetId)) {
          targetIds.add(element.targetId);
        }
      });
      if (!lastTimeOK || (result.length < limit) || (targetIds.length >= limit)) break;
    }
    int count = await chatOutCommon.sendPing(targetIds, true, gap: Settings.gapPingSessionsMs);
    logger.i("$TAG - startInitChecks - ping_count:$count/${targetIds.length} - targetIds:$targetIds");
    // receipts
    await chatInCommon.waitReceiveQueues("startInitChecks");
    List<MessageSchema> receiptList = await messageCommon.queryAllReceivedSuccess();
    for (var i = 0; i < receiptList.length; i++) {
      MessageSchema message = receiptList[i];
      await chatOutCommon.sendReceipt(message);
    }
    if (receiptList.length > 0) logger.i("$TAG - startInitChecks - receipt_count:${receiptList.length}");
  }

  Future<int> resetMessageSending({bool ipfsReset = false}) async {
    // sending list
    List<MessageSchema> sendingList = await messageCommon.queryAllSending();
    for (var i = 0; i < sendingList.length; i++) {
      MessageSchema message = sendingList[i];
      if (message.isDelete) {
        logger.w("$TAG - resetMessageSending - why is delete - targetId:${message.targetId} - message:${message.toStringSimple()}");
        await messageCommon.delete(message.msgId, message.contentType);
      } else if (message.canReceipt) {
        logger.i("$TAG - resetMessageSending - send err set - targetId:${message.targetId} - message:${message.toStringSimple()}");
        if (message.contentType == MessageContentType.ipfs) {
          if (!ipfsReset) continue;
          String? ipfsHash = MessageOptions.getIpfsHash(message.options);
          if ((ipfsHash == null) || ipfsHash.isEmpty) {
            message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
            message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
            await messageCommon.updateMessageOptions(message, message.options, notify: false);
          }
        }
        message = await messageCommon.updateMessageStatus(message, MessageStatus.Error, force: true);
      } else {
        // lost some msg, need resend
        logger.w("$TAG - resetMessageSending - send err delete - targetId:${message.targetId} - message:${message.toStringSimple()}");
        int count = await messageCommon.delete(message.msgId, message.contentType);
        if (count > 0) messageCommon.onDeleteSink.add(message.msgId);
      }
    }
    if (sendingList.length > 0) logger.i("$TAG - resetMessageSending - count:${sendingList.length}");
    return sendingList.length;
  }

  ///*********************************************************************************///
  ///************************************* Handle ************************************///
  ///*********************************************************************************///

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    String? clientAddress = message.isOutbound ? (message.isTargetContact ? message.targetId : null) : message.sender;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    if (message.contentType == MessageContentType.piece) return null;
    ContactSchema? exist = await contactCommon.query(clientAddress);
    if (message.isTargetSelf) return exist;
    // duplicated
    if (exist == null) {
      logger.i("$TAG - contactHandle - new - clientAddress:$clientAddress");
      int type = message.isTargetContact ? (message.canDisplay ? ContactType.stranger : ContactType.none) : ContactType.none;
      exist = await contactCommon.addByType(clientAddress, type, fetchWalletAddress: false, notify: true);
    } else {
      if (message.canDisplay && (exist.type == ContactType.none) && message.isTargetContact) {
        bool success = await contactCommon.setType(exist.address, ContactType.stranger, notify: true);
        if (success) exist.type = ContactType.stranger;
      }
    }
    if (exist == null) {
      logger.e("$TAG - contactHandle - exist is nil - clientAddress:$clientAddress");
      return null;
    }
    if (message.isOutbound) return exist;
    // profile
    String? profileVersion = MessageOptions.getProfileVersion(message.options);
    if ((profileVersion != null) && profileVersion.isNotEmpty) {
      if (!contactCommon.isProfileVersionSame(exist.profileVersion, profileVersion)) {
        logger.i("$TAG - contactHandle - profile need request - native:${exist.profileVersion} - remote:$profileVersion - clientAddress:$clientAddress");
        chatOutCommon.sendContactProfileRequest(exist.address, ContactRequestType.full, exist.profileVersion); // await
      }
    }
    // burning
    if (message.isTargetContact && message.canBurning) {
      int? existSeconds = exist.options.deleteAfterSeconds;
      int? existUpdateAt = exist.options.updateBurnAfterAt;
      int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
      int? updateBurnAfterAt = MessageOptions.getOptionsBurningUpdateAt(message.options);
      if (((burnAfterSeconds ?? 0) > 0) && (existSeconds != burnAfterSeconds)) {
        // no same with self
        if ((existUpdateAt == null) || ((updateBurnAfterAt ?? 0) >= existUpdateAt)) {
          logger.i("$TAG - contactHandle - burning be sync - remote:$burnAfterSeconds - native:$existSeconds - sender:${message.sender}");
          // side updated latest
          exist.options.deleteAfterSeconds = burnAfterSeconds;
          exist.options.updateBurnAfterAt = updateBurnAfterAt;
          var options = await contactCommon.setOptionsBurn(exist.address, burnAfterSeconds, updateBurnAfterAt, notify: true);
          if (options != null) exist.options = options;
        } else if (message.sendAt > existUpdateAt) {
          // mine updated latest
          logger.i("$TAG - contactHandle - burning to sync - native:$existSeconds - remote:$burnAfterSeconds - sender:${message.sender}");
          chatOutCommon.sendContactOptionsBurn(exist.address, (existSeconds ?? 0), existUpdateAt); // await
        }
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> deviceInfoHandle(MessageSchema message) async {
    String? clientAddress = message.isOutbound ? (message.isTargetContact ? message.targetId : null) : message.sender;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    if (message.contentType == MessageContentType.piece) return null;
    // exists
    DeviceInfoSchema? exists = await deviceInfoCommon.query(clientAddress, message.deviceId);
    if (message.isTargetSelf) return exists;
    // duplicated
    if ((exists == null) && message.deviceId.isNotEmpty) {
      // skip all messages need send contact request
      exists = await deviceInfoCommon.add(
        DeviceInfoSchema(
          contactAddress: clientAddress,
          deviceId: message.deviceId,
          onlineAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      logger.i("$TAG - deviceInfoHandle - new - request - clientAddress:$clientAddress - new:$exists");
      chatOutCommon.sendDeviceRequest(clientAddress); // await
    }
    if (exists == null) {
      if (message.deviceId.isNotEmpty) {
        logger.w("$TAG - deviceInfoHandle - exist is nil - clientAddress:$clientAddress");
      } else {
        logger.d("$TAG - deviceInfoHandle - exist is nil (deviceId isEmpty) - clientAddress:$clientAddress");
      }
      return null;
    }
    if (message.isOutbound) return exists;
    // data
    String? deviceProfile = MessageOptions.getDeviceProfile(message.options);
    if ((deviceProfile != null) && deviceProfile.isNotEmpty) {
      List<String> splits = deviceProfile.split(":");
      String? appName = splits.length > 0 ? splits[0] : null;
      String? appVersion = splits.length > 1 ? splits[1] : null;
      String? platform = splits.length > 2 ? splits[2] : null;
      String? platformVersion = splits.length > 3 ? splits[3] : null;
      Map<String, dynamic> newData = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
      String? deviceId = splits.length > 4 ? splits[4] : null;
      if (deviceId == null || deviceId.isEmpty) {
        logger.e("$TAG - deviceInfoHandle - deviceId is nil - sender:${message.sender} - newData:$newData");
      } else if (deviceId == exists.deviceId) {
        bool sameProfile = (appName == exists.appName) && (appVersion == exists.appVersion.toString()) && (platform == exists.platform) && (platformVersion == exists.platformVersion.toString());
        if (!sameProfile) {
          logger.i("$TAG - deviceInfoHandle - profile update - newData:$newData - oldData:${exists.data} - sender:${message.sender}");
          bool success = await deviceInfoCommon.setProfile(exists.contactAddress, exists.deviceId, newData);
          if (success) exists.data = newData;
        }
      } else {
        logger.i("$TAG - deviceInfoHandle - new add - new:$deviceId - old${exists.deviceId} - sender:${message.sender}");
        DeviceInfoSchema? _exist = await deviceInfoCommon.query(exists.contactAddress, deviceId);
        if (_exist != null) {
          bool sameProfile = (appName == _exist.appName) && (appVersion == _exist.appVersion.toString()) && (platform == _exist.platform) && (platformVersion == _exist.platformVersion.toString());
          if (!sameProfile) {
            bool success = await deviceInfoCommon.setProfile(_exist.contactAddress, _exist.deviceId, newData);
            if (success) _exist.data = newData;
          }
          exists = _exist;
        } else {
          DeviceInfoSchema _schema = DeviceInfoSchema(
            contactAddress: exists.contactAddress,
            deviceId: deviceId,
            onlineAt: DateTime.now().millisecondsSinceEpoch,
            data: newData,
          );
          exists = await deviceInfoCommon.add(_schema);
        }
      }
    }
    // device_token (empty updated on receiveDeviceInfo)
    String? deviceToken = MessageOptions.getDeviceToken(message.options);
    if ((exists?.deviceToken != deviceToken) && (deviceToken?.isNotEmpty == true)) {
      logger.i("$TAG - deviceInfoHandle - deviceToken update - new:$deviceToken - old${exists?.deviceToken} - sender:${message.sender}");
      bool success = await deviceInfoCommon.setDeviceToken(exists?.contactAddress, exists?.deviceId, deviceToken);
      if (success) exists?.deviceToken = deviceToken ?? "";
    }
    // online_at
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    bool success = await deviceInfoCommon.setOnlineAt(exists?.contactAddress, exists?.deviceId, onlineAt: nowAt);
    if (success) exists?.onlineAt = nowAt;
    // queue
    String? queueIds = MessageOptions.getMessageQueueIds(message.options);
    if (message.deviceId.isNotEmpty && (queueIds != null) && queueIds.isNotEmpty) {
      if (message.isTargetContact && !message.isTargetSelf) {
        logger.d("$TAG - deviceInfoHandle - message queue check - sender:${message.sender} - queueIds:$queueIds");
        List splits = deviceInfoCommon.splitQueueIds(queueIds);
        messageCommon.syncContactMessages(clientAddress, message.deviceId, splits[0], splits[1], splits[2]); // await
      } else {
        // nothing
      }
    }
    return exists;
  }

  Future<TopicSchema?> topicHandle(MessageSchema message) async {
    if (!message.isTargetTopic) return null;
    if (!message.canDisplay && !message.isTopicAction) return null; // topic action need topic
    if (message.contentType == MessageContentType.piece) return null;
    // duplicated
    TopicSchema? exists = await topicCommon.query(message.targetId);
    if (exists == null) {
      int expireHeight = await topicCommon.getSubscribeExpireAtFromNode(message.targetId, clientCommon.address);
      exists = await topicCommon.add(TopicSchema.create(message.targetId, expireHeight: expireHeight), notify: true);
      // expire + permission + subscribers
      if (exists != null) {
        logger.i("$TAG - topicHandle - new - expireHeight:$expireHeight - topic:$exists ");
        topicCommon.checkExpireAndSubscribe(exists.topicId, refreshSubscribers: true); // await
      } else {
        logger.w("$TAG - topicHandle - topic is empty - topic:${message.targetId} ");
      }
    }
    return exists;
  }

  Future<SubscriberSchema?> subscriberHandle(MessageSchema message, TopicSchema? topic) async {
    if (topic == null || topic.topicId.isEmpty) return null;
    if (!message.isTargetTopic) return null;
    if (message.isTopicAction) return null; // action users will handle in later
    if (message.contentType == MessageContentType.piece) return null;
    // duplicated
    SubscriberSchema? exist = await subscriberCommon.query(message.targetId, message.sender);
    if (exist == null) {
      if (!topic.isPrivate) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - public: add Subscribed - subscriber:$exist");
      } else if (topic.isOwner(message.sender)) {
        exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Subscribed, null));
        logger.i("$TAG - subscriberHandle - private: add Owner - subscriber:$exist");
      } else {
        // will go here when duration(TxPoolDelay) gone in new version
        List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic.topicId, message.sender);
        bool? acceptAll = permission[0];
        int? permPage = permission[1];
        bool? isAccept = permission[2];
        bool? isReject = permission[3];
        if (acceptAll == null) {
          logger.w("$TAG - subscriberHandle - error when findPermissionFromNode - subscriber:$exist");
        } else if (acceptAll == true) {
          logger.i("$TAG - subscriberHandle - acceptAll: add Subscribed - subscriber:$exist");
          exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Subscribed, permPage));
        } else {
          if (isReject == true) {
            logger.w("$TAG - subscriberHandle - reject: add Unsubscribed - sender:${message.sender} - permission:$permission - topic:$topic - subscriber:$exist");
            exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Unsubscribed, permPage));
          } else if (isAccept == true) {
            int expireHeight = await topicCommon.getSubscribeExpireAtFromNode(topic.topicId, message.sender);
            if (expireHeight <= 0) {
              logger.w("$TAG - subscriberHandle - accept: add invited - sender:${message.sender} - permission:$permission - topic:$topic - subscriber:$exist");
              exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.InvitedSend, permPage));
            } else {
              logger.w("$TAG - subscriberHandle - accept: add Subscribed - sender:${message.sender} - permission:$permission - topic:$topic - subscriber:$exist");
              exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Subscribed, permPage));
            }
            // some subscriber status wrong in new version need refresh
            // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
          } else {
            int expireHeight = await topicCommon.getSubscribeExpireAtFromNode(topic.topicId, message.sender);
            if (expireHeight <= 0) {
              logger.w("$TAG - subscriberHandle - none: add Unsubscribed - sender:${message.sender} - permission:$permission - topic:$topic - subscriber:$exist");
              exist = await subscriberCommon.add(SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.Unsubscribed, permPage));
            } else {
              logger.w("$TAG - subscriberHandle - none: just none - sender:${message.sender} - permission:$permission - topic:$topic - subscriber:$exist");
              exist = SubscriberSchema.create(message.targetId, message.sender, SubscriberStatus.None, permPage);
            }
            // some subscriber status wrong in new version need refresh
            // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
          }
        }
      }
    } else if (exist.status != SubscriberStatus.Subscribed) {
      logger.w("$TAG - subscriberHandle - some subscriber status wrong in new version - sender:${message.sender} - status:${exist.status} - topic:$topic");
      // subscriberCommon.refreshSubscribers(topic.topic, meta: topic.isPrivate == true); // await
    }
    return exist;
  }

  // TODO:GG test
  Future<PrivateGroupSchema?> privateGroupHandle(MessageSchema message) async {
    if (!message.isTargetGroup) return null;
    if (!message.canDisplay && !message.isGroupAction) return null; // group action need group
    if (message.contentType == MessageContentType.piece) return null;
    // duplicated
    PrivateGroupSchema? exists = await privateGroupCommon.queryGroup(message.targetId);
    if (exists == null) {
      PrivateGroupSchema? schema = PrivateGroupSchema.create(message.targetId, message.targetId);
      logger.w("$TAG - privateGroupHandle - add(wrong here) - message$message - group:$schema");
      exists = await privateGroupCommon.addPrivateGroup(schema, notify: true);
    }
    if (exists == null) return null;
    // sync
    if (!message.isOutbound) {
      if ((clientCommon.address != null) && !privateGroupCommon.isOwner(exists.ownerPublicKey, clientCommon.address)) {
        String? remoteVersion = MessageOptions.getPrivateGroupVersion(message.options) ?? "";
        int nativeCommits = privateGroupCommon.getPrivateGroupVersionCommits(exists.version) ?? 0;
        int remoteCommits = privateGroupCommon.getPrivateGroupVersionCommits(remoteVersion) ?? 0;
        if (nativeCommits < remoteCommits) {
          logger.i('$TAG - privateGroupHandle - commits diff - native:$nativeCommits - remote:$remoteCommits - sender:${message.sender}');
          // burning
          if (privateGroupCommon.isOwner(exists.ownerPublicKey, message.sender) && message.canBurning) {
            int? existSeconds = exists.options.deleteAfterSeconds;
            int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
            if (((burnAfterSeconds ?? 0) > 0) && (existSeconds != burnAfterSeconds)) {
              logger.i('$TAG - privateGroupHandle - burning diff - native:$existSeconds - remote:$burnAfterSeconds - sender:${message.sender}');
              var options = await privateGroupCommon.setGroupOptionsBurn(exists.groupId, burnAfterSeconds, notify: true);
              if (options != null) exists.options = options;
            }
          }
          // request
          if (exists.optionsRequestedVersion != remoteVersion) {
            logger.i('$TAG - privateGroupHandle - version requested diff - sender:${message.sender} - requested:${exists.optionsRequestedVersion} - remote:$remoteVersion');
          } else {
            logger.d('$TAG - privateGroupHandle - version requested same - sender:${message.sender} - version:$remoteVersion');
          }
          int gap = (exists.optionsRequestedVersion != remoteVersion) ? 0 : Settings.gapGroupRequestOptionsMs;
          chatOutCommon.sendPrivateGroupOptionRequest(message.sender, message.targetId, gap: gap).then((value) {
            if (value) privateGroupCommon.setGroupOptionsRequestInfo(exists?.groupId, remoteVersion, notify: true);
          }); // await
        }
      }
    }
    return exists;
  }

  // TODO:GG test
  Future sessionHandle(MessageSchema message) async {
    if (!message.canDisplay) return;
    if (message.targetId.isEmpty) return;
    // if (message.isTargetSelf) return null;
    // type
    int type = SessionType.CONTACT;
    if (message.isTargetTopic) {
      type = SessionType.TOPIC;
    } else if (message.isTargetGroup) {
      type = SessionType.PRIVATE_GROUP;
    }
    // badge
    Function badgeChange = () async {
      if (!message.isOutbound && message.canNotification) {
        if (!messageCommon.isTargetMessagePageVisible(message.targetId)) {
          await Badge.Badge.onCountUp(1);
        }
      }
    };
    // unreadCount
    int unreadCountUp = message.isOutbound ? 0 : (message.canNotification ? 1 : 0);
    // set
    SessionSchema? exist = await sessionCommon.query(message.targetId, type);
    if (exist == null) {
      sessionCommon.add(message.targetId, type, lastMsg: message, unReadCount: unreadCountUp).then((value) {
        if (value != null) badgeChange(); // await
      }); // await + queue
    } else {
      sessionCommon.update(message.targetId, type, lastMsg: message, unreadChange: unreadCountUp).then((value) {
        if (value != null) badgeChange(); // await
      }); // await + queue
    }
    return;
  }

  MessageSchema burningHandle(MessageSchema message, {bool notify = true}) {
    if (message.isTargetTopic) return message;
    if (!message.canBurning || message.isDelete) return message;
    if ((message.deleteAt != null) && ((message.deleteAt ?? 0) > 0)) return message;
    if (message.status < MessageStatus.Success) return message; // status_read maybe updating
    int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(message.options);
    if ((burnAfterSeconds == null) || (burnAfterSeconds <= 0)) return message;
    // set delete time
    message.deleteAt = DateTime.now().add(Duration(seconds: burnAfterSeconds)).millisecondsSinceEpoch;
    logger.v("$TAG - burningHandle - setDeleteAt - deleteAt:${message.deleteAt} - message:${message.toStringSimple()}");
    messageCommon.updateDeleteAt(message.msgId, message.deleteAt).then((success) {
      if (success && notify) messageCommon.onUpdateSink.add(message);
      // if (success && tick) burningTick(message);
    });
    return message;
  }

  MessageSchema burningTick(MessageSchema message, {Function? onTick}) {
    if ((message.deleteAt == null) || (message.deleteAt == 0)) return message;
    if ((message.deleteAt ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      String taskKey = "${TaskService.KEY_MSG_BURNING}:${message.targetType}_${message.targetId}:${message.msgId}";
      taskService.addTask(taskKey, 1, (String key) {
        if (key != taskKey) {
          taskService.removeTask(key, 1); // remove others client burning
          return;
        }
        if ((message.deleteAt == null) || ((message.deleteAt ?? 0) > DateTime.now().millisecondsSinceEpoch)) {
          // logger.v("$TAG - burningTick - tick - key:$key - msgId:${message.msgId} - deleteTime:${message.deleteAt?.toString()} - now:${DateTime.now()}");
          onTick?.call();
        } else {
          logger.v("$TAG - burningTick - delete(tick) - key:$key - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
          taskService.removeTask(key, 1);
          messageCommon.messageDelete(message, notify: true); // await
        }
      });
    } else {
      if (!message.isDelete) {
        logger.d("$TAG - burningTick - delete(now) - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
        messageCommon.messageDelete(message, notify: true); // await
      } else {
        logger.v("$TAG - burningTick - delete duplicated - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
      }
    }
    return message;
  }

  ///*********************************************************************************///
  ///************************************** Ipfs *************************************///
  ///*********************************************************************************///

  Future<MessageSchema?> startIpfsUpload(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    MessageSchema? message = await messageCommon.query(msgId);
    if (message == null) return null;
    logger.i("$TAG - startIpfsUpload - start - options${message.options}");
    // file_result
    String? fileHash = MessageOptions.getIpfsHash(message.options);
    if (fileHash != null && fileHash.isNotEmpty) {
      logger.i("$TAG - startIpfsUpload - history completed - hash:$fileHash - message:${message.toStringSimple()}");
      if (MessageOptions.getIpfsState(message.options) != MessageOptions.ipfsStateYes) {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await messageCommon.updateMessageOptions(message, message.options);
      }
      return message;
    }
    // file_exist
    if (!message.isContentFile) {
      logger.e("$TAG - startIpfsUpload - content is no file - message:${message.toStringSimple()}");
      return null;
    }
    File file = message.content as File;
    if (!file.existsSync()) {
      logger.e("$TAG - startIpfsUpload - file is no exists - message:${message.toStringSimple()}");
      return null;
    }
    // file_state
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateIng);
    await messageCommon.updateMessageOptions(message, message.options);
    // thumbnail
    MessageSchema? msg = await startIpfsThumbnailUpload(message);
    if (msg == null) {
      logger.w("$TAG - startIpfsUpload - thumbnail fail - message:${message.toStringSimple()}");
      message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
      await messageCommon.updateMessageOptions(message, message.options, notify: false);
      message = await messageCommon.updateMessageStatus(message, MessageStatus.Error, force: true);
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
        logger.i("$TAG - startIpfsUpload - success - result:$result - options${message?.options}");
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
        bool optionsOK = await messageCommon.updateMessageOptions(message, message?.options);
        success = optionsOK;
        if (!completer.isCompleted) completer.complete();
        // chatOutCommon.sendIpfs(message.msgId); // await
      },
      onError: (err) async {
        logger.e("$TAG - startIpfsUpload - fail - err:$err - options${message?.options}");
        Toast.show(err);
        message?.options = MessageOptions.setIpfsState(message?.options, MessageOptions.ipfsStateNo);
        await messageCommon.updateMessageOptions(message, message?.options, notify: false);
        message = await messageCommon.updateMessageStatus(message!, MessageStatus.Error, force: true);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return success ? message : null;
  }

  Future<MessageSchema?> startIpfsThumbnailUpload(MessageSchema? message, {int maxTryTimes = Settings.tryTimesIpfsThumbnailUpload}) async {
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
    logger.i("$TAG - _tryIpfsThumbnailUpload - start - options${message.options}");
    // check
    String? thumbnailHash = MessageOptions.getIpfsThumbnailHash(message.options);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailHash != null && thumbnailHash.isNotEmpty) {
      logger.i("$TAG - _tryIpfsThumbnailUpload - history completed - hash:$thumbnailHash - options${message.options}");
      if (MessageOptions.getIpfsThumbnailState(message.options) != MessageOptions.ipfsThumbnailStateYes) {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        await messageCommon.updateMessageOptions(message, message.options, notify: false);
      }
      return [message, true];
    } else if (thumbnailPath == null || thumbnailPath.isEmpty) {
      logger.d("$TAG - _tryIpfsThumbnailUpload - no thumbnail - options${message.options}");
      return [message, false];
    }
    // state
    message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
    await messageCommon.updateMessageOptions(message, message.options, notify: false);
    // ipfs
    bool success = false;
    Completer completer = Completer();
    ipfsHelper.uploadFile(
      message.msgId,
      thumbnailPath,
      encrypt: true,
      onSuccess: (result) async {
        logger.i("$TAG - _tryIpfsThumbnailUpload - success - result:$result - options${message.options}");
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
        bool optionsOK = await messageCommon.updateMessageOptions(message, message.options, notify: false);
        success = optionsOK;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        logger.e("$TAG - _tryIpfsThumbnailUpload - fail - err:$err - options${message.options}");
        Toast.show(err);
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
        await messageCommon.updateMessageOptions(message, message.options, notify: false);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return [success ? message : null, true];
  }

  Future<MessageSchema?> startIpfsDownload(MessageSchema message) async {
    String? walletAddress = (await walletCommon.getDefault())?.address;
    if (walletAddress == null || walletAddress.isEmpty) return null;
    logger.i("$TAG - startIpfsDownload - start - options${message.options}");
    // file_result
    String? ipfsHash = MessageOptions.getIpfsHash(message.options);
    if (ipfsHash == null || ipfsHash.isEmpty) {
      logger.e("$TAG - startIpfsDownload - ipfsHash is empty - message:${message.toStringSimple()}");
      return null;
    }
    // file_path
    String? savePath = (message.content as File?)?.absolute.path;
    if (savePath == null || savePath.isEmpty) return null;
    int? ipfsSize = MessageOptions.getFileSize(message.options) ?? -1;
    // file_state
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateIng);
    await messageCommon.updateMessageOptions(message, message.options);
    await _onIpfsDownload(walletAddress, message.msgId, "FILE", false);
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
        logger.i("$TAG - startIpfsDownload - success - options${message.options}");
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await messageCommon.updateMessageOptions(message, message.options);
        await _onIpfsDownload(walletAddress, message.msgId, "FILE", true);
        success = true;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        logger.e("$TAG - startIpfsDownload - fail - err:$err - options${message.options}");
        Toast.show(err);
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
        await messageCommon.updateMessageOptions(message, message.options);
        await _onIpfsDownload(walletAddress, message.msgId, "FILE", false);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    // thumbnail
    int? fileType = MessageOptions.getFileType(message.options);
    if (success && (fileType == MessageOptions.fileTypeImage || fileType == MessageOptions.fileTypeVideo)) {
      String? savePath = MessageOptions.getMediaThumbnailPath(message.options);
      if (savePath == null || savePath.isEmpty) {
        savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: message.targetId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      }
      File? file = message.content as File?;
      File thumbnail = File(savePath);
      if ((file != null) && file.existsSync() && !thumbnail.existsSync()) {
        logger.i("$TAG - startIpfsDownload - create thumbnail when no exist - message:${message.toStringSimple()}");
        Map<String, dynamic>? res = await MediaPicker.getVideoThumbnail(file.absolute.path, savePath);
        if (res != null && res.isNotEmpty) {
          message.options = MessageOptions.setMediaThumbnailPath(message.options, savePath);
          message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
          bool optionsOK = await messageCommon.updateMessageOptions(message, message.options);
          await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", optionsOK);
        }
      }
    }
    return success ? message : null;
  }

  Future<MessageSchema?> startIpfsThumbnailDownload(MessageSchema? message, {int maxTryTimes = Settings.tryTimesIpfsThumbnailDownload}) async {
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
    String? walletAddress = (await walletCommon.getDefault())?.address;
    if (walletAddress == null || walletAddress.isEmpty) return [null, false];
    logger.i("$TAG - _tryIpfsThumbnailDownload - start - options${message.options}");
    // result
    String? ipfsHash = MessageOptions.getIpfsThumbnailHash(message.options);
    if (ipfsHash == null || ipfsHash.isEmpty) {
      logger.w("$TAG - _tryIpfsThumbnailDownload - ipfsHash is empty - message:${message.toStringSimple()}");
      return [null, false];
    }
    // path
    String? savePath = MessageOptions.getMediaThumbnailPath(message.options);
    if (savePath == null || savePath.isEmpty) {
      savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: message.targetId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    }
    // state
    message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
    await messageCommon.updateMessageOptions(message, message.options, notify: false);
    await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", false);
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
        logger.i("$TAG - _tryIpfsThumbnailDownload - success - options${message.options}");
        message.options = MessageOptions.setMediaThumbnailPath(message.options, savePath);
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        bool optionsOK = await messageCommon.updateMessageOptions(message, message.options);
        await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", optionsOK);
        success = optionsOK;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (err) async {
        logger.w("$TAG - _tryIpfsThumbnailDownload - fail - err:$err - options${message.options}");
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
        await messageCommon.updateMessageOptions(message, message.options);
        await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", false);
        success = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    return [success ? message : null, true];
  }

  Future resetIpfsDownloading(String walletAddress, {bool thumbnailAutoDownload = false}) async {
    // file
    String fileDownloadKey = "IPFS_FILE_DOWNLOAD_PROGRESS_IDS_$walletAddress";
    List fileDownloadIds = (await SettingsStorage.getSettings(fileDownloadKey)) ?? [];
    List<String> fileIds = [];
    fileDownloadIds.forEach((element) => fileIds.add(element.toString()));
    if (fileIds.isEmpty) {
      logger.v("$TAG - resetIpfsDownloading - file - fileIds:${fileIds.toString()}");
    } else {
      logger.i("$TAG - resetIpfsDownloading - file - fileIds:${fileIds.toString()}");
    }
    List<MessageSchema> fileResults = await messageCommon.queryListByIds(fileIds);
    for (var j = 0; j < fileResults.length; j++) {
      MessageSchema message = fileResults[j];
      if (message.isOutbound || (message.contentType != MessageContentType.ipfs)) {
        logger.w("$TAG - resetIpfsDownloading - file wrong message - message$message");
        await _onIpfsDownload(walletAddress, message.msgId, "FILE", true);
      } else {
        if (MessageOptions.getIpfsState(message.options) == MessageOptions.ipfsStateIng) {
          logger.i("$TAG - resetIpfsDownloading - file is ing - message$message");
          message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
          await messageCommon.updateMessageOptions(message, message.options);
        } else {
          bool isComplete = MessageOptions.getIpfsState(message.options) == MessageOptions.ipfsStateYes;
          logger.d("$TAG - resetIpfsDownloading - file no ing - complete:$isComplete - message$message");
        }
      }
      await _onIpfsDownload(walletAddress, message.msgId, "FILE", true);
    }
    // thumbnail
    String thumbnailDownloadKey = "IPFS_THUMBNAIL_DOWNLOAD_PROGRESS_IDS_$walletAddress";
    List thumbnailDownloadIds = (await SettingsStorage.getSettings(thumbnailDownloadKey)) ?? [];
    List<String> thumbnailIds = [];
    thumbnailDownloadIds.forEach((element) => thumbnailIds.add(element.toString()));
    if (thumbnailIds.isEmpty) {
      logger.v("$TAG - resetIpfsDownloading - thumbnail - thumbnailIds:${thumbnailIds.toString()}");
    } else {
      logger.i("$TAG - resetIpfsDownloading - thumbnail - thumbnailIds:${thumbnailIds.toString()}");
    }
    List<MessageSchema> thumbnailResults = await messageCommon.queryListByIds(thumbnailIds);
    for (var j = 0; j < thumbnailResults.length; j++) {
      MessageSchema message = thumbnailResults[j];
      if (message.isOutbound || (message.contentType != MessageContentType.ipfs)) {
        logger.w("$TAG - resetIpfsDownloading - wrong thumbnail message - message$message");
        await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", true);
      } else {
        if (MessageOptions.getIpfsThumbnailState(message.options) == MessageOptions.ipfsThumbnailStateIng) {
          logger.i("$TAG - resetIpfsDownloading - thumbnail is ing - message$message");
          message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
          await messageCommon.updateMessageOptions(message, message.options);
        } else {
          bool isComplete = MessageOptions.getIpfsThumbnailState(message.options) == MessageOptions.ipfsThumbnailStateYes;
          logger.d("$TAG - resetIpfsDownloading - thumbnail no ing - complete:$isComplete - message$message");
          if (isComplete) await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", isComplete);
        }
      }
      // timeout + download
      int gap = DateTime.now().millisecondsSinceEpoch - (message.receiveAt ?? 0);
      if (gap > Settings.timeoutIpfsResetTimeoutMs) {
        logger.i("$TAG - resetIpfsDownloading - thumbnail reset timeout - message$message");
        await _onIpfsDownload(walletAddress, message.msgId, "THUMBNAIL", true);
      } else if (thumbnailAutoDownload && (gap < Settings.timeoutIpfsThumbnailAutoDownloadMs)) {
        logger.i("$TAG - resetIpfsDownloading - thumbnail auto download - message$message");
        startIpfsThumbnailDownload(message); // await
      } else {
        logger.i("$TAG - resetIpfsDownloading - thumbnail nothing - message$message");
      }
    }
  }

  Future<List<String>> _onIpfsDownload(String walletAddress, String? msgId, String type, bool completed) async {
    if (msgId == null || msgId.isEmpty) return [];
    String key = "IPFS_${type}_DOWNLOAD_PROGRESS_IDS_$walletAddress";
    List ids = (await SettingsStorage.getSettings(key)) ?? [];
    List<String> idsStr = ids.map((e) => e.toString()).toList();
    logger.v("$TAG - _onIpfsDownload - start - key:$key - ids:${idsStr.toString()}");
    if (completed) {
      idsStr.remove(msgId.trim());
    } else {
      int index = idsStr.indexOf(msgId.trim());
      if (index < 0) idsStr.add(msgId.trim());
    }
    await SettingsStorage.setSettings(key, idsStr);
    logger.v("$TAG - _onIpfsDownload - end - key:$key - ids:${idsStr.toString()}");
    return idsStr;
  }
}
