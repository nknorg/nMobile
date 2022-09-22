import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
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
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/time.dart';

class ChatCommon with Tag {
  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get _onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<String> _onDeleteController = StreamController<String>.broadcast();
  StreamSink<String> get onDeleteSink => _onDeleteController.sink;
  Stream<String> get onDeleteStream => _onDeleteController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onProgressController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get onProgressSink => _onProgressController.sink;
  Stream<Map<String, dynamic>> get onProgressStream => _onProgressController.stream.distinct((prev, next) => (next['msg_id'] == prev['msg_id']) && (next['percent'] < prev['percent']));

  // current page
  String? currentChatTargetId;

  // checker
  Map<String, Map<String, dynamic>> _checkersParams = Map();
  ParallelQueue _checkQueue = ParallelQueue("checker_msg", parallel: 3, onLog: (log, error) => error ? logger.w(log) : null);

  ChatCommon();

  void clear() {
    // currentChatTargetId = null; // can not be reset
    _checkersParams.clear();
    checkSendingWithFail(force: true); // await
    checkIpfsStateIng(fileNotify: true, thumbnailNotify: false, thumbnailAutoDownload: true); // await
  }

  Future checkMsgStatus(String? targetId, bool isTopic, {bool refresh = false, int filterSec = 10}) async {
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
        final count = await _checkMsgStatus(targetId, isTopic, filterSec: filterSec);
        logger.i("$TAG - checkMsgStatus - end - count:$count - targetId:$targetId");
        _checkersParams[targetId]?["delay"] = 0;
      } catch (e, st) {
        handleError(e, st);
      }
    }, id: targetId, delay: Duration(seconds: _checkersParams[targetId]?["delay"] ?? initDelay));
  }

  Future<int> _checkMsgStatus(String? targetId, bool isTopic, {bool forceResend = false, int filterSec = 10}) async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return 0;
    if (targetId == null || targetId.isEmpty) return 0;

    int limit = 20;
    int maxCount = 20;
    List<MessageSchema> checkList = [];

    // noAck
    for (int offset = 0; true; offset += limit) {
      final result = await MessageStorage.instance.queryListByStatus(MessageStatus.SendSuccess, targetId: targetId, topic: isTopic ? targetId : "", offset: offset, limit: limit);
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
      logger.d("$TAG - _checkMsgStatus - OK OK OK - targetId:$targetId - isTopic:$isTopic");
      return 0;
    }

    // resend
    if (isTopic || forceResend) {
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
  }

  Future<ContactSchema?> contactHandle(MessageSchema message) async {
    String? clientAddress = message.isOutbound ? ((message.isTopic || message.isPrivateGroup) ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(clientAddress);
    // duplicated
    if (message.canDisplay) {
      if (exist == null) {
        logger.i("$TAG - contactHandle - new - clientAddress:$clientAddress");
        int type = (message.isTopic || message.isPrivateGroup) ? ContactType.none : ContactType.stranger;
        exist = await contactCommon.addByType(clientAddress, type, notify: true, checkDuplicated: false);
      } else {
        if ((exist.type == ContactType.none) && !((message.isTopic || message.isPrivateGroup))) {
          bool success = await contactCommon.setType(exist.id, ContactType.stranger, notify: true);
          if (success) exist.type = ContactType.stranger;
        }
      }
    }
    if (exist == null) return null;
    // profile
    if ((message.from != message.to) && !message.isTopic && !message.isPrivateGroup && !message.isOutbound) {
      String? profileVersion = MessageOptions.getProfileVersion(message.options);
      if (profileVersion != null && profileVersion.isNotEmpty) {
        if (!contactCommon.isProfileVersionSame(exist.profileVersion, profileVersion)) {
          chatOutCommon.sendContactRequest(exist.clientAddress, RequestType.full, exist.profileVersion); // await
        }
      }
    }
    // burning
    if (!(message.isTopic || message.isPrivateGroup) && message.canBurning) {
      int? existSeconds = exist.options?.deleteAfterSeconds;
      int? existUpdateAt = exist.options?.updateBurnAfterAt;
      int? burnAfterSeconds = MessageOptions.getContactBurningDeleteSec(message.options);
      int? updateBurnAfterAt = MessageOptions.getContactBurningUpdateAt(message.options);
      if (burnAfterSeconds != null && (burnAfterSeconds > 0) && (existSeconds != burnAfterSeconds)) {
        // no same with self
        if ((existUpdateAt == null) || ((updateBurnAfterAt ?? 0) >= existUpdateAt)) {
          // side updated latest
          exist.options?.deleteAfterSeconds = burnAfterSeconds;
          exist.options?.updateBurnAfterAt = updateBurnAfterAt;
          await contactCommon.setOptionsBurn(exist, burnAfterSeconds, updateBurnAfterAt, notify: true);
        } else {
          // mine updated latest
          if ((message.sendAt ?? 0) > existUpdateAt) {
            deviceInfoCommon.queryLatest(exist.clientAddress).then((deviceInfo) {
              if (exist == null) return;
              if (!DeviceInfoCommon.isBurningUpdateAtEnable(deviceInfo?.platform, deviceInfo?.appVersion)) return;
              chatOutCommon.sendContactOptionsBurn(exist.clientAddress, (existSeconds ?? 0), existUpdateAt); // await
            });
          }
        }
      }
    }
    return exist;
  }

  Future<DeviceInfoSchema?> deviceInfoHandle(MessageSchema message) async {
    if ((message.contentType == MessageContentType.deviceRequest) || (message.contentType == MessageContentType.deviceResponse)) return null;
    String? clientAddress = message.isOutbound ? ((message.isTopic || message.isPrivateGroup) ? null : message.to) : message.from;
    if (clientAddress == null || clientAddress.isEmpty) return null;
    DeviceInfoSchema? latest = await deviceInfoCommon.queryLatest(clientAddress);
    // duplicated
    if (latest == null) {
      ContactSchema? _contact = await contactCommon.queryByClientAddress(clientAddress);
      if (_contact != null) {
        logger.i("$TAG - deviceInfoHandle - new - request - clientAddress:$clientAddress");
        // skip all messages need send contact request
        latest = await deviceInfoCommon.set(DeviceInfoSchema(contactAddress: clientAddress));
        chatOutCommon.sendDeviceRequest(clientAddress); // await
      }
    }
    if (latest == null) return null;
    // profile (no send client msg so can contains topic)
    if ((message.from != message.to) && !message.isOutbound) {
      String? deviceProfile = MessageOptions.getDeviceProfile(message.options);
      if (deviceProfile != null && deviceProfile.isNotEmpty) {
        List<String> splits = deviceProfile.split(":");
        String? appName = splits.length > 0 ? splits[0] : null;
        String? appVersion = splits.length > 1 ? splits[1] : null;
        String? platform = splits.length > 2 ? splits[2] : null;
        String? platformVersion = splits.length > 3 ? splits[3] : null;
        String? deviceId = splits.length > 4 ? splits[4] : null;
        if (deviceId == null || deviceId.isEmpty) {
          // nothing
        } else if (deviceId == latest.deviceId) {
          bool sameProfile = (latest.appName == appName) && (appVersion == latest.appVersion.toString()) && (platform == latest.platform) && (platformVersion == latest.platformVersion.toString());
          if (!sameProfile) {
            latest.data = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
            latest = await deviceInfoCommon.set(latest);
          }
        } else {
          DeviceInfoSchema? _exist = await deviceInfoCommon.queryByDeviceId(latest.contactAddress, deviceId);
          if (_exist != null) {
            bool success = await deviceInfoCommon.updateLatest(latest.contactAddress, deviceId); // await
            if (success) latest = _exist;
            bool sameProfile = (appName == latest.appName) && (appVersion == latest.appVersion.toString()) && (platform == latest.platform) && (platformVersion == latest.platformVersion.toString());
            if (!sameProfile) {
              latest.data = {'appName': appName, 'appVersion': appVersion, 'platform': platform, 'platformVersion': platformVersion};
              latest = await deviceInfoCommon.set(latest);
            }
          } else {
            DeviceInfoSchema _schema = DeviceInfoSchema(contactAddress: latest.contactAddress, deviceId: deviceId, data: {
              'appName': appName,
              'appVersion': appVersion,
              'platform': platform,
              'platformVersion': platformVersion,
            });
            latest = await deviceInfoCommon.set(_schema); // await
          }
        }
      }
    }
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

  Future<PrivateGroupSchema?> privateGroupHandle(MessageSchema message) async {
    if (!message.isPrivateGroup) return null;
    if (!message.canDisplay && !message.isGroupAction) return null; // topic action need topic
    // duplicated
    PrivateGroupSchema? exists = await privateGroupCommon.queryGroup(message.groupId);
    if (exists == null) {
      PrivateGroupSchema? schema = PrivateGroupSchema.create(message.groupId, message.groupId);
      exists = await privateGroupCommon.addPrivateGroup(schema, false, notify: true, checkDuplicated: false);
    }
    if (exists == null) return null;
    // sync
    if ((clientCommon.address != null) && (message.from != message.to) && !message.isOutbound) {
      if (!privateGroupCommon.isOwner(exists.ownerPublicKey, clientCommon.address)) {
        String? remoteVersion = MessageOptions.getPrivateGroupVersion(message.options) ?? "";
        if (remoteVersion != exists.version) {
          int nowAt = DateTime.now().millisecondsSinceEpoch;
          bool needRequestOptions = false;
          if (exists.optionsRequestedVersion != remoteVersion) {
            logger.i('$TAG - privateGroupHandle - version diff - version1:${exists.optionsRequestedVersion} - version2:$remoteVersion');
            needRequestOptions = true;
          } else {
            int timePast = nowAt - exists.optionsRequestAt;
            if (timePast > (5 * 60 * 1000)) {
              logger.i('$TAG - pushPrivateGroupOptions - time > 5m - past:$timePast');
              needRequestOptions = true;
            } else {
              logger.d('$TAG - pushPrivateGroupOptions - time < 5m - past:$timePast');
              needRequestOptions = false;
            }
          }
          if (needRequestOptions) {
            chatOutCommon.sendPrivateGroupOptionRequest(message.from, message.groupId).then((version) async {
              exists?.setOptionsRequestAt(nowAt);
              exists?.setOptionsRequestedVersion(version);
              await privateGroupCommon.updateGroupData(exists?.groupId, exists?.data);
            }); // await
          }
        }
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

  Future<SessionSchema?> sessionHandle(MessageSchema message) async {
    if (!message.canDisplay) return null;
    // duplicated
    if (message.targetId.isEmpty) return null;

    // type
    int type = SessionType.CONTACT;
    if (message.isTopic) {
      type = SessionType.TOPIC;
    } else if (message.isPrivateGroup) {
      type = SessionType.PRIVATE_GROUP;
    }

    SessionSchema? exist = await sessionCommon.query(message.targetId, type);
    if (exist == null) {
      SessionSchema? added = SessionSchema(targetId: message.targetId, type: SessionSchema.getTypeByMessage(message));
      added = await sessionCommon.add(added, message, notify: true);
      logger.i("$TAG - sessionHandle - new - targetId:${message.targetId} - added:$added");
      return added;
    }
    // update
    var unreadCount = message.isOutbound ? exist.unReadCount : (message.canNotification ? (exist.unReadCount + 1) : exist.unReadCount);
    exist.unReadCount = (chatCommon.currentChatTargetId == exist.targetId) ? 0 : unreadCount;
    int newLastMessageAt = message.sendAt ?? MessageOptions.getInAt(message.options) ?? DateTime.now().millisecondsSinceEpoch;
    if ((exist.lastMessageAt == null) || (exist.lastMessageAt! <= newLastMessageAt)) {
      exist.lastMessageAt = newLastMessageAt;
      exist.lastMessageOptions = message.toMap();
      await sessionCommon.setLastMessageAndUnReadCount(exist.targetId, exist.type, message, exist.unReadCount, notify: true); // must await
    } else {
      await sessionCommon.setUnReadCount(exist.targetId, exist.type, exist.unReadCount, notify: true); // must await
    }
    return exist;
  }

  MessageSchema burningHandle(MessageSchema message, {bool notify = true}) {
    if (message.isTopic || message.isPrivateGroup) return message;
    if (!message.canBurning || message.isDelete) return message;
    if ((message.deleteAt != null) && ((message.deleteAt ?? 0) > 0)) return message;
    if ((message.status == MessageStatus.Sending) || (message.status == MessageStatus.SendFail)) return message; // status_read maybe updating
    int? burnAfterSeconds = MessageOptions.getContactBurningDeleteSec(message.options);
    if ((burnAfterSeconds == null) || (burnAfterSeconds <= 0)) return message;
    // set delete time
    message.deleteAt = DateTime.now().add(Duration(seconds: burnAfterSeconds)).millisecondsSinceEpoch;
    logger.v("$TAG - burningHandle - deleteAt - deleteAt:${message.deleteAt}");
    MessageStorage.instance.updateDeleteAt(message.msgId, message.deleteAt).then((success) {
      if (success && notify) _onUpdateSink.add(message);
      // if (success && tick) burningTick(message);
    });
    return message;
  }

  MessageSchema burningTick(MessageSchema message, {Function? onTick}) {
    message = burningHandle(message);
    if ((message.deleteAt == null) || (message.deleteAt == 0)) return message;
    if ((message.deleteAt ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      String senderKey = message.isOutbound ? message.from : (message.isTopic ? message.topic : (message.isPrivateGroup ? message.groupId : message.to));
      if (senderKey.isEmpty) return message;
      String taskKey = "${TaskService.KEY_MSG_BURNING}:$senderKey:${message.msgId}";
      taskService.addTask1(taskKey, (String key) {
        if (key != taskKey) {
          // remove others client burning
          taskService.removeTask1(key);
          return;
        }
        if (message.deleteAt == null || (message.deleteAt! > DateTime.now().millisecondsSinceEpoch)) {
          // logger.v("$TAG - burningTick - tick - key:$key - msgId:${message.msgId} - deleteTime:${message.deleteAt?.toString()} - now:${DateTime.now()}");
          onTick?.call();
        } else {
          logger.v("$TAG - burningTick - delete(tick) - key:$key - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
          // onTick?.call();
          chatCommon.messageDelete(message, notify: true); // await
          taskService.removeTask1(key);
        }
      });
    } else {
      logger.i("$TAG - burningTick - delete(now) - msgId:${message.msgId} - deleteAt:${message.deleteAt} - now:${DateTime.now()}");
      if (!message.isDelete) {
        message.isDelete = true;
        chatCommon.messageDelete(message, notify: true); // await
      }
      // onTick?.call(); // will dead loop
    }
    return message;
  }

  Future<int> unreadCount() {
    return MessageStorage.instance.unReadCount();
  }

  Future<int> unReadCountByTargetId(String? targetId, String? topic, String? groupId) {
    return MessageStorage.instance.unReadCountByTargetId(targetId, topic, groupId);
  }

  Future<List<MessageSchema>> queryMessagesByTargetIdVisible(String? targetId, String? topic, String? groupId, {int offset = 0, int limit = 20}) {
    return MessageStorage.instance.queryListByTargetIdWithNotDeleteAndPiece(targetId, topic, groupId, offset: offset, limit: limit);
  }

  Future<bool> deleteByTargetId(String? targetId, String? topic, String? groupId) async {
    await MessageStorage.instance.deleteByTargetIdContentType(targetId, topic, groupId, MessageContentType.piece);
    return MessageStorage.instance.updateIsDeleteByTargetId(targetId, topic, groupId, true, clearContent: true);
  }

  Future<bool> messageDelete(MessageSchema? message, {bool notify = false}) async {
    if (message == null || message.msgId.isEmpty) return false;
    bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Read)) : true;
    bool success = await MessageStorage.instance.updateIsDelete(message.msgId, true, clearContent: clearContent);
    if (notify) onDeleteSink.add(message.msgId); // no need success
    // delete file
    if (clearContent && (message.content is File)) {
      (message.content as File).exists().then((exist) {
        if (exist) {
          (message.content as File).delete(); // await
          logger.d("$TAG - messageDelete - content file delete success - path:${(message.content as File).path}");
        } else {
          logger.w("$TAG - messageDelete - content file no Exists - path:${(message.content as File).path}");
        }
      });
    }
    // delete thumbnail
    String? mediaThumbnail = MessageOptions.getMediaThumbnailPath(message.options);
    if (clearContent && (mediaThumbnail != null) && mediaThumbnail.isNotEmpty) {
      File(mediaThumbnail).exists().then((exist) {
        if (exist) {
          File(mediaThumbnail).delete(); // await
          logger.d("$TAG - messageDelete - video_thumbnail delete success - path:$mediaThumbnail");
        } else {
          logger.w("$TAG - messageDelete - video_thumbnail no Exists - path:$mediaThumbnail");
        }
      });
    }
    return success;
  }

  Future<MessageSchema> updateMessageStatus(MessageSchema message, int status, {bool reQuery = false, int? receiveAt, bool force = false, bool notify = false}) async {
    if (reQuery) {
      MessageSchema? _latest = await MessageStorage.instance.query(message.msgId);
      if (_latest != null) message = _latest;
    }
    if ((status <= message.status) && !force) {
      if (status == message.status) return message;
      logger.w("$TAG - updateMessageStatus - status is wrong - new:$status - old:${message.status} - msgId:${message.msgId}");
      return message;
    }
    // update
    message.status = status;
    bool success = await MessageStorage.instance.updateStatus(message.msgId, status, receiveAt: receiveAt, noType: MessageContentType.piece);
    if (status == MessageStatus.SendSuccess) {
      message.options = MessageOptions.setOutAt(message.options, DateTime.now().millisecondsSinceEpoch);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
    }
    if (success && notify) _onUpdateSink.add(message);
    // delete later
    if (message.isDelete && (message.content != null)) {
      bool clearContent = message.isOutbound ? ((message.status == MessageStatus.SendReceipt) || (message.status == MessageStatus.Read)) : true;
      if (clearContent) {
        messageDelete(message, notify: false); // await
      } else {
        logger.i("$TAG - updateMessageStatus - delete later no - message:$message");
      }
    }
    return message;
  }

  Future readMessagesBySelf(String? targetId, String? topic, String? groupId, String? clientAddress) async {
    if (targetId == null || targetId.isEmpty) return;
    // update messages
    int limit = 20;

    List<MessageSchema> unreadList = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> result = await MessageStorage.instance.queryListByTargetIdWithUnRead(targetId, topic, groupId, offset: offset, limit: limit);
      unreadList.addAll(result);
      if (result.length < limit) break;
    }

    List<String> msgIds = [];
    for (var i = 0; i < unreadList.length; i++) {
      MessageSchema element = unreadList[i];
      msgIds.add(element.msgId);
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: DateTime.now().millisecondsSinceEpoch, notify: false);
    }
    // send messages
    if ((clientAddress?.isNotEmpty == true) && msgIds.isNotEmpty) {
      await chatOutCommon.sendRead(clientAddress, msgIds);
    }
  }

  Future<int> readMessageBySide(String? targetId, String? topic, int? sendAt, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty || sendAt == null || sendAt == 0) return 0;
    // noReads
    List<MessageSchema> noReads = await MessageStorage.instance.queryListByStatus(MessageStatus.SendReceipt, targetId: targetId, topic: topic, offset: offset, limit: limit);
    List<MessageSchema> shouldReads = noReads.where((element) => (element.sendAt ?? 0) <= sendAt).toList();
    // read
    for (var i = 0; i < shouldReads.length; i++) {
      MessageSchema element = shouldReads[i];
      int? receiveAt = (element.receiveAt == null) ? DateTime.now().millisecondsSinceEpoch : element.receiveAt;
      await updateMessageStatus(element, MessageStatus.Read, receiveAt: receiveAt, notify: true);
    }
    // loop
    if (noReads.length >= limit) return readMessageBySide(targetId, topic, sendAt, offset: offset + limit, limit: limit);
    logger.i("$TAG - readMessageBySide - readCount:${offset + noReads.length} - reallySendAt:${Time.formatTime(DateTime.fromMillisecondsSinceEpoch(sendAt))}");
    return offset + noReads.length;
  }

  Future<int> checkSendingWithFail({bool force = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;

    List<MessageSchema> sendingList = await MessageStorage.instance.queryListByStatus(MessageStatus.Sending, offset: 0, limit: 20);

    for (var i = 0; i < sendingList.length; i++) {
      MessageSchema message = sendingList[i];
      bool isFail = false;
      if (force) {
        isFail = true;
      } else {
        int singleWaitSec = 3 * 60; // 3m
        int topicWaitSec = singleWaitSec * 2; // 6m
        int topicMediaWaitSec = topicWaitSec * 2; // 12m
        int msgSendAt = message.sendAt ?? DateTime.now().millisecondsSinceEpoch;
        if (!(message.isTopic || message.isPrivateGroup) && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (singleWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by single - targetId:${message.targetId} - message:$message");
        } else if ((message.isTopic || message.isPrivateGroup) && !(message.content is File) && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (topicWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by topic/group - targetId:${message.targetId} - message:$message");
        } else if ((message.isTopic || message.isPrivateGroup) && (message.content is File) && ((DateTime.now().millisecondsSinceEpoch - msgSendAt) < (topicMediaWaitSec * 1000))) {
          logger.d("$TAG - checkSending - sendAt justNow by topic/group media - targetId:${message.targetId} - message:$message");
        } else {
          isFail = true;
        }
      }
      if (isFail) {
        logger.d("$TAG - checkSending - sendFail add - targetId:${message.targetId} - message:$message");
        if (message.canResend) {
          await chatCommon.updateMessageStatus(message, MessageStatus.SendFail, force: true, notify: true);
        } else {
          int count = await MessageStorage.instance.deleteByIdContentType(message.msgId, message.contentType);
          if (count > 0) chatCommon.onDeleteSink.add(message.msgId);
        }
      }
    }

    logger.i("$TAG - checkSending - checkCount:${sendingList.length}");
    return sendingList.length;
  }

  Future sendPang2SessionsContact() async {
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;

    int max = 20;
    int limit = 20;
    int filterDay = 10; // 10 days filter
    List<String> targetIds = [];

    // sessions
    for (int offset = 0; true; offset += limit) {
      List<SessionSchema> result = await sessionCommon.queryListRecent(offset: offset, limit: limit);
      result.forEach((element) {
        int between = DateTime.now().millisecondsSinceEpoch - (element.lastMessageAt ?? 0);
        if (element.isContact && (between < (filterDay * 24 * 60 * 60 * 1000))) {
          targetIds.add(element.targetId);
        }
      });
      logger.d("$TAG - sendPang2SessionsContact - offset:$offset - current_len:${result.length} - total_len:${targetIds.length}");
      if ((result.length < limit) || (targetIds.length >= max)) break;
    }

    // send
    await chatOutCommon.sendPing(targetIds, false);
  }

  Future<MessageSchema?> startIpfsUpload(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return null;
    MessageSchema? message = await MessageStorage.instance.query(msgId);
    if (message == null) return null;
    // file
    if (!(message.content is File)) {
      logger.e("$TAG - startIpfsUpload - content is no file - message:$message");
      return null;
    }
    File file = message.content as File;
    if (!file.existsSync()) {
      logger.e("$TAG - startIpfsUpload - file is no exists - message:$message");
      return null;
    }
    // state
    message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    _onUpdateSink.add(message);
    // thumbnail
    String? thumbnailHash = MessageOptions.getIpfsThumbnailHash(message.options);
    String? thumbnailPath = MessageOptions.getMediaThumbnailPath(message.options);
    if (thumbnailHash != null && thumbnailHash.isNotEmpty) {
      if (MessageOptions.getIpfsThumbnailState(message.options) != MessageOptions.ipfsThumbnailStateYes) {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", true, true); // await
      }
    } else if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      // state
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", true, false); // await
      // ipfs
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
          if (!completer.isCompleted) completer.complete();
          _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", true, true); // await
        },
        onError: (err) async {
          if (!completer.isCompleted) completer.complete();
          message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
          await MessageStorage.instance.updateOptions(message.msgId, message.options);
          _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", true, false); // await
        },
      );
      await completer.future;
    }
    // ipfs
    _onIpfsUpOrDownload(msgId, "FILE", true, false); // await
    ipfsHelper.uploadFile(
      message.msgId,
      file.absolute.path,
      encrypt: true,
      onProgress: (percent) {
        onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      },
      onSuccess: (result) async {
        message.options = MessageOptions.setIpfsResult(
          message.options,
          result[IpfsHelper.KEY_IP],
          result[IpfsHelper.KEY_HASH],
          result[IpfsHelper.KEY_ENCRYPT],
          result[IpfsHelper.KEY_ENCRYPT_ALGORITHM],
          result[IpfsHelper.KEY_ENCRYPT_KEY_BYTES],
          result[IpfsHelper.KEY_ENCRYPT_NONCE_SIZE],
        );
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        _onIpfsUpOrDownload(message.msgId, "FILE", true, true); // await
        await chatOutCommon.sendIpfs(message.msgId);
      },
      onError: (err) async {
        MessageSchema _msg = await updateMessageStatus(message, MessageStatus.SendFail, reQuery: true, force: true, notify: true);
        _msg.options = MessageOptions.setIpfsState(_msg.options, MessageOptions.ipfsStateNo);
        await MessageStorage.instance.updateOptions(_msg.msgId, _msg.options);
        _onUpdateSink.add(_msg);
        _onIpfsUpOrDownload(_msg.msgId, "FILE", true, false); // await
      },
    );
    return message;
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
    _onUpdateSink.add(message);
    _onIpfsUpOrDownload(message.msgId, "FILE", false, false); // await
    // ipfs
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
        onProgressSink.add({"msg_id": message.msgId, "percent": percent});
      },
      onSuccess: () async {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateYes);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        _onUpdateSink.add(message);
        _onIpfsUpOrDownload(message.msgId, "FILE", false, true); // await
      },
      onError: (err) async {
        message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        _onUpdateSink.add(message);
        _onIpfsUpOrDownload(message.msgId, "FILE", false, false); // await
      },
    );
    return message;
  }

  Future<MessageSchema?> tryDownloadIpfsThumbnail(MessageSchema message) async {
    String? ipfsHash = MessageOptions.getIpfsThumbnailHash(message.options);
    if (ipfsHash == null || ipfsHash.isEmpty) {
      logger.e("$TAG - tryDownloadIpfsThumbnail - ipfsHash is empty - message:$message");
      return null;
    }
    // path
    String? savePath = MessageOptions.getMediaThumbnailPath(message.options);
    if (savePath == null || savePath.isEmpty) {
      savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: message.targetId, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
    }
    // state
    message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateIng);
    await MessageStorage.instance.updateOptions(message.msgId, message.options);
    _onUpdateSink.add(message);
    _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", false, false); // await
    // ipfs
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
        _onUpdateSink.add(message);
        _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", false, true); // await
      },
      onError: (err) async {
        message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
        await MessageStorage.instance.updateOptions(message.msgId, message.options);
        _onUpdateSink.add(message);
        _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", false, false); // await
      },
    );
    return message;
  }

  Future<List<String>> _onIpfsUpOrDownload(String msgId, String type, bool upload, bool completed) async {
    String key = "IPFS_${type}_${upload ? "UPLOAD" : "DOWNLOAD"}_PROGRESS_IDS";
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

  Future checkIpfsStateIng({
    bool fileNotify = false,
    bool thumbnailNotify = false,
    bool thumbnailAutoDownload = false,
    int? delayMs,
  }) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;

    // file
    String fileUploadKey = "IPFS_FILE_UPLOAD_PROGRESS_IDS";
    String fileDownloadKey = "IPFS_FILE_DOWNLOAD_PROGRESS_IDS";
    List fileUploadIds = (await SettingsStorage.getSettings(fileUploadKey)) ?? [];
    List fileDownloadIds = (await SettingsStorage.getSettings(fileDownloadKey)) ?? [];
    List<String> fileIds = [];
    fileUploadIds.forEach((element) => fileIds.add(element.toString()));
    fileDownloadIds.forEach((element) => fileIds.add(element.toString()));
    logger.i("$TAG - checkIpfsStateIng - start_file - fileIds:${fileIds.toString()}");
    List<MessageSchema> fileResults = await MessageStorage.instance.queryListByIds(fileIds);
    for (var j = 0; j < fileResults.length; j++) {
      MessageSchema message = fileResults[j];
      if (message.contentType != MessageContentType.ipfs) {
        await _onIpfsUpOrDownload(message.msgId, "FILE", message.isOutbound, true);
        continue;
      } else if (MessageOptions.getIpfsState(message.options) != MessageOptions.ipfsStateIng) {
        await _onIpfsUpOrDownload(message.msgId, "FILE", message.isOutbound, MessageOptions.getIpfsState(message.options) == MessageOptions.ipfsStateYes);
        continue;
      }
      message.options = MessageOptions.setIpfsState(message.options, MessageOptions.ipfsStateNo);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      message.status = message.isOutbound ? MessageStatus.SendFail : message.status;
      if (fileNotify) _onUpdateSink.add(message);
    }

    // video_thumbnail
    String thumbnailUploadKey = "IPFS_THUMBNAIL_UPLOAD_PROGRESS_IDS";
    String thumbnailDownloadKey = "IPFS_THUMBNAIL_DOWNLOAD_PROGRESS_IDS";
    List thumbnailUploadIds = (await SettingsStorage.getSettings(thumbnailUploadKey)) ?? [];
    List thumbnailDownloadIds = (await SettingsStorage.getSettings(thumbnailDownloadKey)) ?? [];
    List<String> thumbnailIds = [];
    thumbnailUploadIds.forEach((element) => thumbnailIds.add(element.toString()));
    thumbnailDownloadIds.forEach((element) => thumbnailIds.add(element.toString()));
    logger.i("$TAG - checkIpfsStateIng - start_thumbnail - thumbnailIds:${thumbnailIds.toString()}");
    List<MessageSchema> thumbnailResults = await MessageStorage.instance.queryListByIds(thumbnailIds);
    for (var j = 0; j < thumbnailResults.length; j++) {
      MessageSchema message = thumbnailResults[j];
      if (message.contentType != MessageContentType.ipfs) {
        await _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", message.isOutbound, true);
        continue;
      } else if (MessageOptions.getIpfsThumbnailState(message.options) == MessageOptions.ipfsThumbnailStateYes) {
        await _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", message.isOutbound, true);
        continue;
      }
      message.options = MessageOptions.setIpfsThumbnailState(message.options, MessageOptions.ipfsThumbnailStateNo);
      await MessageStorage.instance.updateOptions(message.msgId, message.options);
      if (thumbnailNotify) _onUpdateSink.add(message);
      int between = DateTime.now().millisecondsSinceEpoch - (message.receiveAt ?? 0);
      if ((between < 3 * 60 * 60 * 1000) && thumbnailAutoDownload && !message.isOutbound) {
        tryDownloadIpfsThumbnail(message); // await
      } else {
        await _onIpfsUpOrDownload(message.msgId, "THUMBNAIL", message.isOutbound, true);
      }
    }
  }
}
