import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';

class TopicCommon with Tag {
  // ignore: close_sinks
  StreamController<TopicSchema> _addController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _addSink => _addController.sink;
  Stream<TopicSchema> get addStream => _addController.stream;

  // ignore: close_sinks
  // StreamController<String> _deleteController = StreamController<String>.broadcast();
  // StreamSink<String> get _deleteSink => _deleteController.sink;
  // Stream<String> get deleteStream => _deleteController.stream;

  // ignore: close_sinks
  StreamController<TopicSchema> _updateController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _updateSink => _updateController.sink;
  Stream<TopicSchema> get updateStream => _updateController.stream;

  TopicCommon();

  /// ***********************************************************************************************************
  /// ************************************************* check ***************************************************
  /// ***********************************************************************************************************

  Future getTopicSubscribeFee(BuildContext context) async {
    double? fee = 0.0;
    var isAuto = await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_SUBSCRIBE_SPEED_ENABLE);
    if ((isAuto != null) && ((isAuto.toString() == "true") || (isAuto == true))) {
      fee = double.tryParse((await SettingsStorage.getSettings(SettingsStorage.DEFAULT_FEE)) ?? "0") ?? 0;
      if (fee <= 0) fee = Settings.feeTopicSubscribeDefault;
      fee = await BottomDialog.of(context).showTransactionSpeedUp(fee: fee);
    }
    return fee;
  }

  Future getTopicReSubscribeFee() async {
    double fee = 0;
    var isAuto = await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_RESUBSCRIBE_SPEED_ENABLE);
    if ((isAuto != null) && ((isAuto.toString() == "true") || (isAuto == true))) {
      fee = double.tryParse((await SettingsStorage.getSettings(SettingsStorage.DEFAULT_FEE)) ?? "0") ?? 0;
      if (fee <= 0) fee = Settings.feeTopicSubscribeDefault;
    }
    return fee;
  }

  Future checkAndTryAllSubscribe() async {
    if (!(await clientCommon.waitClientOk())) return;
    final limit = 20;
    List<TopicSchema> topicsWithReSubscribe = [];
    List<TopicSchema> topicsWithReUnSubscribe = [];
    List<TopicSchema> topicsWithSubscribeExpire = [];
    // query
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await queryList(offset: offset, limit: limit);
      result.forEach((element) {
        if (element.isSubscribeProgress()) {
          logger.i("$TAG - checkAndTryAllSubscribe - topic is subscribe progress - topicId:${element.topicId} - topic:$element");
          topicsWithReSubscribe.add(element);
        } else if (element.isUnSubscribeProgress()) {
          logger.i("$TAG - checkAndTryAllSubscribe - topic is unsubscribe progress - topicId:${element.topicId} - topic:$element");
          topicsWithReUnSubscribe.add(element);
        } else {
          int lastCheckAt = element.lastCheckSubscribeAt();
          int interval = DateTime.now().millisecondsSinceEpoch - lastCheckAt;
          if (element.joined && (interval > Settings.gapTopicSubscribeCheckMs)) {
            logger.i("$TAG - checkAndTryAllSubscribe - topic subscribe expire - gap ok - gap:$interval>${Settings.gapTopicSubscribeCheckMs} - topicId:${element.topicId} - topic:$element");
            topicsWithSubscribeExpire.add(element);
          } else if (interval <= Settings.gapTopicSubscribeCheckMs) {
            logger.d("$TAG - checkAndTryAllSubscribe - topic subscribe expire - gap small - gap:$interval<${Settings.gapTopicSubscribeCheckMs} - topicId:${element.topicId} - topic:$element");
          } else {
            logger.v("$TAG - checkAndTryAllSubscribe - topic subscribe expire - no_joined - joined:${element.joined} - topicId:${element.topicId} - topic:$element");
          }
        }
      });
      if (result.length < limit) break;
    }
    if ((topicsWithReSubscribe.length > 0) || (topicsWithReUnSubscribe.length > 0) || (topicsWithSubscribeExpire.length > 0)) {
      logger.i("$TAG - checkAndTryAllSubscribe - topic subscribe resubscribe - count_subscribe:${topicsWithReSubscribe.length} - count_unsubscribe:${topicsWithReUnSubscribe.length} - expire_count:${topicsWithSubscribeExpire.length}");
    } else {
      logger.d("$TAG - checkAndTryAllSubscribe - topic subscribe resubscribe - count == 0");
    }
    // check + try
    for (var i = 0; i < topicsWithReSubscribe.length; i++) {
      TopicSchema topic = topicsWithReSubscribe[i];
      await _checkAndTrySubscribe(topic, true);
    }
    for (var i = 0; i < topicsWithReUnSubscribe.length; i++) {
      TopicSchema topic = topicsWithReUnSubscribe[i];
      await _checkAndTrySubscribe(topic, false);
    }
    if (topicsWithSubscribeExpire.isNotEmpty) {
      double fee = await getTopicReSubscribeFee();
      for (var i = 0; i < topicsWithSubscribeExpire.length; i++) {
        TopicSchema topic = topicsWithSubscribeExpire[i];
        var result = await checkExpireAndSubscribe(topic.topicId, fee: fee); // no nonce
        if (result != null) await setLastCheckSubscribeAt(topic.topicId);
      }
    }
  }

  Future<bool> _checkAndTrySubscribe(TopicSchema? topic, bool subscribed) async {
    if (topic == null) return false;
    if (!(await clientCommon.waitClientOk())) return false;
    // expireHeight
    int expireHeight = await getSubscribeExpireAtFromNode(topic.topicId, clientCommon.address);
    // fee
    topic = await query(topic.topicId) ?? topic;
    double fee = topic.getProgressSubscribeFee();
    int? nonce = topic.getProgressSubscribeNonce();
    // resubscribe
    if (subscribed) {
      if (expireHeight <= 0) {
        logger.i("$TAG - _checkAndTrySubscribe - topic try subscribe - nonce:$nonce - fee:$fee - subscribe:$subscribed - topicId:${topic.topicId} - topic:$topic");
        final result = await checkExpireAndSubscribe(topic.topicId, refreshSubscribers: false, forceSubscribe: true, enableFirst: true, nonce: nonce, fee: fee);
        if (result != null) await subscriberCommon.onSubscribe(topic.topicId, clientCommon.address, null);
      } else {
        logger.i("$TAG - _checkAndTrySubscribe - topic subscribe OK - nonce:$nonce - fee:$fee - subscribe:$subscribed - topicId:${topic.topicId} - topic:$topic");
        await setStatusProgressEnd(topic.topicId, notify: true);
      }
    } else {
      if (expireHeight >= 0) {
        logger.i("$TAG - _checkAndTrySubscribe - topic try unsubscribe - nonce:$nonce - fee:$fee - subscribe:$subscribed - topicId:${topic.topicId} - topic:$topic");
        await unsubscribe(topic.topicId, nonce: nonce, fee: fee);
      } else {
        logger.i("$TAG - _checkAndTrySubscribe - topic unsubscribe OK - nonce:$nonce - fee:$fee - subscribe:$subscribed - topicId:${topic.topicId} - topic:$topic");
        await setStatusProgressEnd(topic.topicId, notify: true);
      }
    }
    return true;
  }

  @Deprecated('Replace by PrivateGroup')
  Future checkAndTryAllPermission() async {
    if (!(await clientCommon.waitClientOk())) return;
    final limit = 20;
    List<TopicSchema> privateTopics = [];
    List<TopicSchema> permissionTopics = [];
    // topic permission resubscribe
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await queryList(type: TopicType.private, offset: offset, limit: limit);
      result.forEach((element) {
        if (element.isOwner(clientCommon.address)) {
          privateTopics.add(element);
          int lastCheckAt = element.lastCheckPermissionsAt();
          int interval = DateTime.now().millisecondsSinceEpoch - lastCheckAt;
          if (interval > Settings.gapTopicPermissionCheckMs) {
            logger.i("$TAG - checkAndTryAllPermission - topic permission resubscribe - gap ok - gap:$interval>${Settings.gapTopicPermissionCheckMs} - topicId:${element.topicId} - topic:$element");
            permissionTopics.add(element);
          } else {
            logger.d("$TAG - checkAndTryAllPermission - topic permission resubscribe - gap small - gap:$interval<${Settings.gapTopicPermissionCheckMs} - topicId:${element.topicId} - topic:$element");
          }
        }
      });
      if (result.length < limit) break;
    }
    if (permissionTopics.length > 0) {
      logger.i("$TAG - checkAndTryAllPermission - topic permission resubscribe - count:${permissionTopics.length}");
    } else {
      logger.d("$TAG - checkAndTryAllPermission - topic permission resubscribe - count == 0");
    }
    if (permissionTopics.isNotEmpty) {
      int? globalHeight = await RPC.getBlockHeight();
      if ((globalHeight != null) && (globalHeight > 0)) {
        double fee = await getTopicReSubscribeFee();
        for (var i = 0; i < permissionTopics.length; i++) {
          TopicSchema topic = permissionTopics[i];
          bool success = await _checkAndTryPermissionExpire(topic, globalHeight, fee);
          if (success) await setLastCheckPermissionAt(topic.topicId);
        }
      }
    }
    // subscribers permission upload
    List<SubscriberSchema> subscribers = [];
    for (var i = 0; i < privateTopics.length; i++) {
      TopicSchema topic = privateTopics[i];
      for (int offset = 0; true; offset += limit) {
        List<SubscriberSchema> result = await subscriberCommon.queryListByTopicId(topic.topicId, offset: offset, limit: limit);
        result.forEach((element) {
          if (element.isPermissionProgress() != null) {
            logger.i("$TAG - checkAndTryAllPermission - subscribers permission upload - progress:${element.isPermissionProgress()} - topicId:${element.topicId} - contactAddress:${element.contactAddress} - subscriber:$element");
            subscribers.add(element);
          }
        });
        if (result.length < limit) break;
      }
    }
    if (subscribers.length > 0) {
      logger.i("$TAG - checkAndTryAllPermission - subscribers permission upload - count:${subscribers.length}");
    } else {
      logger.d("$TAG - checkAndTryAllPermission - subscribers permission upload - count == 0");
    }
    for (var i = 0; i < subscribers.length; i++) {
      SubscriberSchema subscribe = subscribers[i];
      await _checkAndTryPermissionSet(subscribe);
    }
  }

  @Deprecated('Replace by PrivateGroup')
  Future<bool> _checkAndTryPermissionExpire(TopicSchema? topic, int globalHeight, double fee) async {
    if (topic == null) return false;
    if (!(await clientCommon.waitClientOk())) return false;
    int maxPermPage = await subscriberCommon.queryMaxPermPageByTopicId(topic.topicId);
    for (var i = 0; i <= maxPermPage; i++) {
      // perm_page
      List? result = await _getPermissionExpireAtByPageFromNode(topic.topicId, i);
      Map<String, dynamic>? meta = result?[0];
      int? expireHeight = result?[1];
      if ((meta == null) || (expireHeight == null)) {
        logger.w("$TAG - _checkAndTryPermissionExpire - error when _getPermissionExpireAtByPageFromNode - topicId:${topic.topicId} - fee:$fee - expireHeight:$expireHeight - meta:$result");
        return false;
      }
      // subscribe
      if ((expireHeight > 0) && ((expireHeight - globalHeight) < Settings.blockHeightTopicWarnBlockExpire)) {
        logger.i("$TAG - _checkAndTryPermissionExpire - resubscribe permission - topicId:${topic.topicId} - fee:$fee - expireHeight:$expireHeight - meta:$result");
        return await RPC.subscribeWithPermission(topic.topicId, fee: fee, permPage: i, meta: meta, toast: false); // no nonce
      } else {
        logger.d("$TAG - _checkAndTryPermissionExpire - permission OK - topicId:${topic.topicId} - fee:$fee - expireHeight:$expireHeight - meta:$result");
      }
    }
    return true;
  }

  @Deprecated('Replace by PrivateGroup')
  Future<bool> _checkAndTryPermissionSet(SubscriberSchema? subscriber) async {
    int? status = subscriber?.isPermissionProgress();
    if (subscriber == null || status == null) return false;
    if (!(await clientCommon.waitClientOk())) return false;
    bool needAccept = (status == SubscriberStatus.InvitedSend) || (status == SubscriberStatus.InvitedReceipt) || (status == SubscriberStatus.Subscribed);
    bool needReject = status == SubscriberStatus.Unsubscribed;
    bool needNoPermission = status == SubscriberStatus.None;
    // permission(txPool=false)
    List<dynamic> permission = await subscriberCommon.findPermissionFromNode(subscriber.topicId, subscriber.contactAddress, txPool: false);
    bool? acceptAll = permission[0];
    // int? permPage = permission[1];
    bool? isAccept = permission[2];
    bool? isReject = permission[3];
    if (acceptAll == null) {
      logger.w("$TAG - _checkAndTryPermissionSet - error when findPermissionFromNode - status:$status - permission:$permission - topicId:${subscriber.topicId} - subscriber:$subscriber");
      return false;
    }
    // fee
    subscriber = await subscriberCommon.query(subscriber.topicId, subscriber.contactAddress);
    if (subscriber == null) return false;
    double fee = subscriber.getProgressPermissionFee();
    int? nonce = subscriber.getProgressPermissionNonce();
    // check
    if (needAccept) {
      if (isAccept == true) {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber permission(accept) OK - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.topicId, subscriber.contactAddress);
      } else {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber try invitee - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await invitee(subscriber.topicId, true, true, subscriber.contactAddress, nonce: nonce, fee: fee);
      }
    } else if (needReject) {
      if (isReject == true) {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber permission(reject) OK - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.topicId, subscriber.contactAddress);
      } else {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber try kick - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await kick(subscriber.topicId, true, true, subscriber.contactAddress, nonce: nonce, fee: fee);
      }
    } else if (needNoPermission) {
      if ((isAccept != true) && (isReject != true)) {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber permission(none) OK - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.topicId, subscriber.contactAddress);
      } else {
        logger.i("$TAG - _checkAndTryPermissionSet - subscriber try unsubscribe - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
        await onUnsubscribe(subscriber.topicId, subscriber.contactAddress); // no nonce
      }
    } else {
      logger.w("$TAG - _checkAndTryPermissionSet - subscriber permission none - status:$status - nonce:$nonce - fee:$fee - topicId:${subscriber.topicId} - subscribe:$subscriber");
      await subscriberCommon.setStatusProgressEnd(subscriber.topicId, subscriber.contactAddress);
    }
    return true;
  }

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = self(owner/normal)
  Future<TopicSchema?> subscribe(String? topicId, {bool fetchSubscribers = false, bool justNow = false, double fee = 0}) async {
    if (topicId == null || topicId.isEmpty) return null;
    if (!(await clientCommon.waitClientOk())) return null;
    // topic exist
    TopicSchema? topic = await query(topicId);
    if (topic == null) {
      int expireHeight = await getSubscribeExpireAtFromNode(topicId, clientCommon.address);
      topic = await add(TopicSchema.create(topicId, expireHeight: expireHeight), notify: true);
      logger.i("$TAG - subscribe - new - expireHeight:$expireHeight - topic:$topic");
      // refreshSubscribers later
    }
    if (topic == null) {
      logger.w("$TAG - subscribe - topic is null - topicId:$topicId");
      return null;
    }
    // permission(private + normal)
    int? permPage;
    if (topic.isPrivate && !topic.isOwner(clientCommon.address)) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicId, clientCommon.address);
      bool? acceptAll = permission[0];
      permPage = permission[1];
      bool? isAccept = permission[2];
      bool? isReject = permission[3];
      if (acceptAll == null) {
        logger.w("$TAG - subscribe - error when findPermissionFromNode - topicId:$topicId - permission:$permission");
        return null;
      } else if (acceptAll == true) {
        logger.d("$TAG - subscribe - accept all - topic:$topic");
      } else if (isReject == true) {
        if (justNow) {
          Toast.show(Settings.locale((s) => s.no_permission_join_group));
        } else {
          Toast.show(Settings.locale((s) => s.removed_group_tip));
        }
        return null;
      } else if (isAccept != true) {
        if (justNow) {
          Toast.show(Settings.locale((s) => s.no_permission_join_group));
        } else {
          Toast.show(Settings.locale((s) => s.contact_invite_group_tip));
        }
        return null;
      } else {
        logger.i("$TAG - subscribe - is_accept ok - topic:$topic");
      }
    } else {
      logger.d("$TAG - subscribe - skip permission check - topic:$topic");
    }
    // check expire + pull subscribers
    topic = await checkExpireAndSubscribe(topicId, refreshSubscribers: fetchSubscribers, forceSubscribe: true, enableFirst: true, fee: fee, toast: true);
    if (topic == null) return null;
    await Future.delayed(Duration(milliseconds: 250));
    // permission(owner default all permission)
    // status
    await subscriberCommon.onSubscribe(topicId, clientCommon.address, permPage);
    await Future.delayed(Duration(milliseconds: 250));
    // send messages
    await chatOutCommon.sendTopicSubscribe(topicId);
    // subscribersInfo
    // subscriberCommon.fetchSubscribersInfo(topic); // await
    return topic;
  }

  // caller = self(owner/normal)
  Future<TopicSchema?> checkExpireAndSubscribe(
    String? topicId, {
    bool refreshSubscribers = false,
    bool forceSubscribe = false,
    bool enableFirst = false,
    int? nonce,
    double fee = 0,
    bool toast = false,
  }) async {
    if (topicId == null || topicId.isEmpty) return null;
    if (!(await clientCommon.waitClientOk())) return null;
    // topic exist
    TopicSchema? topic = await query(topicId);
    if (topic == null) {
      logger.w("$TAG - checkExpireAndSubscribe - topic is null - topicId:$topicId");
      return null;
    }
    // check expire
    bool noSubscribed;
    int expireHeight = await getSubscribeExpireAtFromNode(topic.topicId, clientCommon.address);
    if (!topic.joined || (topic.subscribeAt ?? 0) <= 0 || (topic.expireBlockHeight ?? 0) <= 0) {
      // DB no joined
      if (expireHeight > 0) {
        // node is joined
        noSubscribed = false;
        int gap = DateTime.now().millisecondsSinceEpoch - topic.createAt;
        if (gap > Settings.gapTxPoolUpdateDelayMs) {
          logger.d("$TAG - checkExpireAndSubscribe - DB expire but node not expire - gap:$gap>${Settings.gapTxPoolUpdateDelayMs} - topic:$topic");
          int subscribeAt = topic.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
          bool success = await setJoined(
            topicId,
            true,
            subscribeAt: subscribeAt,
            expireBlockHeight: expireHeight,
            notify: true,
          );
          if (success) {
            topic.joined = true;
            topic.subscribeAt = subscribeAt;
            topic.expireBlockHeight = expireHeight;
          }
        } else {
          logger.i("$TAG - checkExpireAndSubscribe - DB expire but node not expire, maybe in txPool, just return - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - topic:$topic");
        }
      } else {
        // node no joined
        logger.i("$TAG - checkExpireAndSubscribe - no subscribe history - topic:$topic");
        noSubscribed = true;
      }
    } else {
      // DB is joined
      if (expireHeight <= 0) {
        // node no joined
        noSubscribed = true;
        int gap = DateTime.now().millisecondsSinceEpoch - topic.createAt;
        if (topic.joined && (gap > Settings.gapTxPoolUpdateDelayMs)) {
          logger.i("$TAG - checkExpireAndSubscribe - DB no expire but node expire - gap:$gap>${Settings.gapTxPoolUpdateDelayMs} - topic:$topic");
          bool success = await setJoined(
            topicId,
            false,
            subscribeAt: null,
            expireBlockHeight: 0,
            notify: true,
          );
          if (success) {
            topic.joined = false;
            topic.subscribeAt = null;
            topic.expireBlockHeight = 0;
          }
        } else {
          logger.i("$TAG - checkExpireAndSubscribe - DB not expire but node expire, maybe in txPool, just run - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - topic:$topic");
        }
      } else {
        // node is joined
        logger.d("$TAG - checkExpireAndSubscribe - OK OK OK OK OK - topic:$topic");
        noSubscribed = false;
      }
    }
    // subscribe
    int? globalHeight = await RPC.getBlockHeight();
    bool shouldResubscribe = await topic.shouldResubscribe(globalHeight);
    if (forceSubscribe || (noSubscribed && enableFirst) || (topic.joined && shouldResubscribe)) {
      // client subscribe
      bool subscribeSuccess = await RPC.subscribeWithJoin(topicId, true, nonce: nonce, fee: fee, toast: toast);
      if (!subscribeSuccess) {
        logger.w("$TAG - checkExpireAndSubscribe - _clientSubscribe fail - topicId:$topicId - nonce:$nonce - fee:$fee - topic:$topic");
        return null;
      }
      // db update
      var subscribeAt = topic.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      var expireHeight = (globalHeight ?? topic.expireBlockHeight ?? 0) + Settings.blockHeightTopicSubscribeDefault;
      bool setSuccess = await setJoined(
        topicId,
        true,
        subscribeAt: subscribeAt,
        expireBlockHeight: expireHeight,
        refreshCreateAt: true,
        notify: true,
      );
      if (setSuccess) {
        topic.joined = true;
        topic.subscribeAt = subscribeAt;
        topic.expireBlockHeight = expireHeight;
      }
      logger.i("$TAG - checkExpireAndSubscribe - _clientSubscribe success - topicId:$topicId - nonce:$nonce - fee:$fee - topic:$topic");
    } else {
      logger.d("$TAG - checkExpireAndSubscribe - _clientSubscribe no need subscribe - topic:$topic");
    }
    // subscribers
    if (refreshSubscribers) {
      await subscriberCommon.refreshSubscribers(topicId, topic.ownerPubKey, meta: topic.isPrivate);
      await setLastRefreshSubscribersAt(topicId, notify: true);
      int count = await subscriberCommon.getSubscribersCount(topicId, topic.isPrivate);
      if (topic.count != count) {
        bool success = await setCount(topicId, count, notify: true);
        if (success) topic.count = count;
      }
    }
    return topic;
  }

  /// ***********************************************************************************************************
  /// ************************************************ action ***************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> invitee(String? topicId, bool isPrivate, bool isOwner, String? inviteeAddress, {int? nonce, double fee = 0, bool toast = false, bool sendMsg = false}) async {
    if (topicId == null || topicId.isEmpty || inviteeAddress == null || inviteeAddress.isEmpty) return null;
    if (!(await clientCommon.waitClientOk())) return null;
    if (isPrivate && !isOwner) {
      if (toast) Toast.show(Settings.locale((s) => s.member_no_auth_invite));
      return null;
    } else if (inviteeAddress == clientCommon.address) {
      if (toast) Toast.show(Settings.locale((s) => s.invite_yourself_error));
      return null;
    }
    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.query(topicId, inviteeAddress);
    if ((_subscriber != null) && (_subscriber.status == SubscriberStatus.Subscribed)) {
      if (toast) Toast.show(Settings.locale((s) => s.group_member_already));
      return null;
    }
    int oldStatus = _subscriber?.status ?? SubscriberStatus.None;
    // if (isPrivate && toast) Toast.show(Settings.locale((s) => s.inviting));
    // check permission
    int? appendPermPage;
    if (isPrivate) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicId, inviteeAddress);
      bool? acceptAll = permission[0];
      appendPermPage = permission[1] ?? (await subscriberCommon.queryNextPermPageByTopicId(topicId));
      bool? isReject = permission[3];
      if (acceptAll == null) {
        logger.w("$TAG - invitee - error when findPermissionFromNode - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
        return null;
      } else if (!isOwner && (acceptAll != true) && (isReject == true)) {
        // just owner can invitee reject item
        if (toast) Toast.show(Settings.locale((s) => s.blocked_user_disallow_invite));
        return null;
      }
      // update DB
      _subscriber = await subscriberCommon.onInvitedSend(topicId, inviteeAddress, appendPermPage);
      // update meta (private + owner + no_accept_all)
      if (acceptAll == true) {
        logger.i("$TAG - invitee - acceptAll == true - topicId:$topicId - invitee:$inviteeAddress - permission:$permission");
      } else {
        if (appendPermPage == null) {
          logger.e("$TAG - invitee - permPage is null - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        logger.i("$TAG - invitee - push permission by me(==owner) - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
        Map<String, dynamic>? meta = await _getMetaByPageFromNode(topicId, appendPermPage);
        if (meta == null) {
          logger.w("$TAG - invitee - meta is null by _getMetaFromNodeByPage - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        meta = await _buildPageMetaByAppend(topicId, meta, _subscriber);
        if (meta == null) {
          logger.w("$TAG - invitee - meta is null by _buildPageMetaByAppend - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        bool subscribeSuccess = await RPC.subscribeWithPermission(topicId, nonce: nonce, fee: fee, permPage: appendPermPage, meta: meta, toast: toast, contactAddress: inviteeAddress, newStatus: SubscriberStatus.InvitedSend, oldStatus: oldStatus);
        if (!subscribeSuccess) {
          logger.w("$TAG - invitee - rpc error - topicId:$topicId - nonce_$nonce - fee:$fee - permPage:$appendPermPage - meta:$meta");
          _subscriber?.status = oldStatus;
          return null;
        }
      }
    } else {
      // update DB
      logger.d("$TAG - invitee - no permission by me(public) - topicId:$topicId - subscriber:$_subscriber");
      _subscriber = await subscriberCommon.onInvitedSend(topicId, inviteeAddress, null);
    }
    // send message
    if (sendMsg) {
      MessageSchema? _msg = await chatOutCommon.sendTopicInvitee(topicId, inviteeAddress);
      if (_msg == null) {
        if (toast) Toast.show(Settings.locale((s) => s.failure));
        return null;
      }
    } else if (oldStatus == SubscriberStatus.InvitedReceipt) {
      await subscriberCommon.setStatus(_subscriber?.topicId, _subscriber?.contactAddress, SubscriberStatus.InvitedReceipt, notify: true);
    }
    if (toast) Toast.show(Settings.locale((s) => s.invitation_sent));
    return _subscriber;
  }

  // caller = self
  Future<TopicSchema?> unsubscribe(String? topicId, {int? nonce, double fee = 0, bool toast = false}) async {
    if (topicId == null || topicId.isEmpty) return null;
    if (!(await clientCommon.waitClientOk())) return null;
    // permission modify in owners message received by owner
    TopicSchema? topic = await query(topicId);
    // client unsubscribe
    bool unsubscribeSuccess = await RPC.subscribeWithJoin(topicId, false, nonce: nonce, fee: fee, toast: toast);
    if (!unsubscribeSuccess) {
      logger.w("$TAG - unsubscribe - rpc error - topicId:$topicId - nonce$nonce - fee:$fee - topic:$topic");
      return null;
    }
    logger.i("$TAG - unsubscribe - rpc success - topicId:$topicId - nonce$nonce - fee:$fee - topic:$topic");
    await Future.delayed(Duration(milliseconds: 250));
    // topic update
    bool setSuccess = await setJoined(
      topicId,
      false,
      subscribeAt: null,
      expireBlockHeight: 0,
      refreshCreateAt: true,
      notify: true,
    );
    if (setSuccess) {
      topic?.joined = false;
      topic?.subscribeAt = null;
      topic?.expireBlockHeight = 0;
    }
    // setSuccess = await setCount(topic?.id, (topic?.count ?? 1) - 1, notify: true);
    // if (setSuccess) topic?.count = (topic.count ?? 1) - 1;
    // DB(topic+subscriber) delete
    await subscriberCommon.onUnsubscribe(topicId, clientCommon.address);
    // await subscriberCommon.deleteByTopic(topic); // stay is useful
    // await delete(topic?.id, notify: true); // replace by setJoined
    // send message
    await chatOutCommon.sendTopicUnSubscribe(topicId);
    await Future.delayed(Duration(milliseconds: 250));
    return topic;
  }

  // caller = private + owner
  @Deprecated('Replace by PrivateGroup')
  Future<SubscriberSchema?> kick(String? topicId, bool isPrivate, bool isOwner, String? kickAddress, {int? nonce, double fee = 0, bool toast = false}) async {
    if (topicId == null || topicId.isEmpty || kickAddress == null || kickAddress.isEmpty) return null;
    if (!(await clientCommon.waitClientOk())) return null;
    if (kickAddress == clientCommon.address) return null;
    if (!isPrivate || !isOwner) return null; // enable just private + owner
    // topic exist
    TopicSchema? _topic = await query(topicId);
    if (_topic == null) {
      logger.e("$TAG - kick - topic is null - topicId:$topicId");
      return null;
    }
    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.query(topicId, kickAddress);
    if (_subscriber == null) return null;
    // if (_subscriber.canBeKick == false) return null; // checked in UI
    int oldStatus = _subscriber.status;
    // check permission
    List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicId, kickAddress);
    bool? acceptAll = permission[0];
    int? permPage = permission[1] ?? _subscriber.permPage;
    if (acceptAll == null) {
      logger.w("$TAG - kick - error when findPermissionFromNode - topicId:$topicId - kickAddress:$kickAddress");
      return null;
    } else if ((acceptAll == true) || (permPage == null)) {
      logger.w("$TAG - kick - permPage is null(maybe accept all) - topicId:$topicId - kickAddress:$kickAddress");
      if (toast) Toast.show(Settings.locale((s) => s.failure));
      return null;
    }
    // update DB
    _subscriber = await subscriberCommon.onKickOut(topicId, kickAddress, permPage: permPage);
    // update meta (private + owner + no_accept_all)
    Map<String, dynamic>? meta = await _getMetaByPageFromNode(topicId, permPage);
    if (meta == null) {
      logger.w("$TAG - kick - meta is null by _getMetaFromNodeByPage - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
      return null;
    }
    meta = await _buildPageMetaByAppend(topicId, meta, _subscriber);
    if (meta == null) {
      logger.w("$TAG - kick - meta is null by _buildPageMetaByAppend - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
      return null;
    }
    bool subscribeSuccess = await RPC.subscribeWithPermission(topicId, nonce: nonce, fee: fee, permPage: permPage, meta: meta, toast: toast, contactAddress: kickAddress, newStatus: SubscriberStatus.Unsubscribed, oldStatus: oldStatus);
    if (!subscribeSuccess) {
      logger.w("$TAG - kick - rpc error - topicId:$topicId - nonce:$nonce - fee:$fee - permission:$permission - meta:$meta - subscriber:$_subscriber");
      _subscriber?.status = oldStatus;
      return null;
    }
    logger.i("$TAG - kick - rpc success - topicId:$topicId - nonce:$nonce - fee:$fee - permission:$permission - meta:$meta - subscriber:$_subscriber");
    if (oldStatus == SubscriberStatus.Subscribed) {
      bool setSuccess = await setCount(topicId, _topic.count - 1, notify: true);
      if (setSuccess) _topic.count = _topic.count - 1;
    }
    // send message
    await chatOutCommon.sendTopicKickOut(topicId, kickAddress);
    if (toast) Toast.show(Settings.locale((s) => s.rejected));
    return _subscriber;
  }

  /// ***********************************************************************************************************
  /// *********************************************** callback **************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> onSubscribe(String? topicId, String? subAddress) async {
    if (topicId == null || topicId.isEmpty || subAddress == null || subAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _topic = await query(topicId);
    if (_topic == null) {
      logger.e("$TAG - onSubscribe - topic is null - topicId:$topicId");
      return null;
    }
    // subscriber exist
    SubscriberSchema? _subscriber = await subscriberCommon.query(topicId, subAddress);
    int oldStatus = _subscriber?.status ?? SubscriberStatus.None;
    // permission check
    int? permPage;
    if (_topic.isPrivate && !_topic.isOwner(subAddress)) {
      logger.i("$TAG - onSubscribe - sync permission by me(no owner) - topicId:$topicId - subAddress:$subAddress - topic:$_topic");
      List permission = await subscriberCommon.findPermissionFromNode(topicId, subAddress);
      bool? acceptAll = permission[0];
      permPage = permission[1];
      bool? isAccept = permission[2];
      bool? isReject = permission[3];
      if (acceptAll == null) {
        logger.w("$TAG - onSubscribe - error when findPermissionFromNode - topic:$_topic - subAddress:$subAddress - permission:$permission");
        return null;
      } else if (acceptAll == true) {
        logger.i("$TAG - onSubscribe - acceptAll == true - topic:$_topic - subAddress:$subAddress - permission:$permission");
      } else if ((isReject == true) || (isAccept != true)) {
        logger.w("$TAG - onSubscribe - subscriber permission is not ok (maybe in txPool) - topic:$_topic - subAddress:$subAddress - permission:$permission");
        return null;
      } else {
        logger.i("$TAG - onSubscribe - subscriber permission is ok - topic:$_topic - subAddress:$subAddress - permission:$permission");
      }
    } else {
      logger.d("$TAG - onSubscribe - no permission action by me - topicId:$topicId - subAddress:$subAddress - topic:$_topic");
    }
    // permission modify in invitee action by owner
    // subscriber update
    _subscriber = await subscriberCommon.onSubscribe(topicId, subAddress, permPage);
    if (_subscriber == null) {
      logger.w("$TAG - onSubscribe - subscriber is null - topicId:$topicId - subAddress:$subAddress - permPage:$permPage");
      return null;
    }
    if (oldStatus != SubscriberStatus.Subscribed) {
      bool setSuccess = await setCount(topicId, _topic.count + 1, notify: true);
      if (setSuccess) _topic.count = _topic.count + 1;
    }
    // subscribers sync
    // if (_topic.isPrivate) {
    //   Future.delayed(Duration(seconds: 1), () {
    //     subscriberCommon.refreshSubscribers(topic, meta: _topic.isPrivate);
    //   });
    // }
    return _subscriber;
  }

  // caller = everyone
  Future<SubscriberSchema?> onUnsubscribe(String? topicId, String? unSubAddress) async {
    if (topicId == null || topicId.isEmpty || unSubAddress == null || unSubAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _topic = await query(topicId);
    if (_topic == null) {
      logger.e("$TAG - onUnsubscribe - topic is null - topicId:$topicId");
      return null;
    }
    // subscriber exist
    SubscriberSchema? _subscriber = await subscriberCommon.query(topicId, unSubAddress);
    int oldStatus = _subscriber?.status ?? SubscriberStatus.None;
    // subscriber update
    _subscriber = await subscriberCommon.onUnsubscribe(topicId, unSubAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onUnsubscribe - subscriber is null - topicId:$topicId - unSubAddress:$unSubAddress");
      return null;
    }
    // private + owner
    if (_topic.isPrivate && _topic.isOwner(clientCommon.address) && (clientCommon.address != unSubAddress)) {
      logger.i("$TAG - onUnsubscribe - sync permission by me(==owner) - topicId:$topicId - subscriber:$_subscriber - topic:$_topic");
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicId, unSubAddress);
      bool? acceptAll = permission[0];
      int? permPage = permission[1] ?? _subscriber.permPage;
      if (acceptAll == null) {
        logger.w("$TAG - onUnsubscribe - error when findPermissionFromNode - topicId:$topicId - permission:$permission - subscriber:$_subscriber - topic:$_topic");
        return null;
      } else if (acceptAll == true) {
        logger.i("$TAG - onUnsubscribe - acceptAll == true - topicId:$topicId - permission:$permission - subscriber:$_subscriber - topic:$_topic");
      } else {
        if (permPage == null) {
          logger.e("$TAG - onUnsubscribe - permPage is null - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
          return null;
        } else if (_subscriber.permPage != permPage) {
          logger.w("$TAG - onUnsubscribe - permPage is diff - topicId:$topicId - permission:$permission - subscriber:$_subscriber");
          bool success = await subscriberCommon.setPermPage(_subscriber.topicId, _subscriber.contactAddress, permPage, notify: true);
          if (success) _subscriber.permPage = permPage; // if (success)
        }
        // meta update
        Map<String, dynamic>? meta = await _getMetaByPageFromNode(topicId, permPage);
        if (meta == null) {
          logger.w("$TAG - onUnsubscribe - meta is null by _getMetaFromNodeByPage - topicId:$topicId - permission:$permission - subscriber:$_subscriber - topic:$_topic");
          return null;
        }
        _subscriber.status = SubscriberStatus.None; // temp for build meta
        meta = await _buildPageMetaByAppend(topicId, meta, _subscriber);
        _subscriber.status = SubscriberStatus.Unsubscribed;
        if (meta == null) {
          logger.w("$TAG - onUnsubscribe - meta is null by _buildPageMetaByAppend - topicId:$topicId - permission:$permission - subscriber:$_subscriber - topic:$_topic");
          return null;
        }
        bool subscribeSuccess = await RPC.subscribeWithPermission(topicId, permPage: permPage, meta: meta, contactAddress: unSubAddress, newStatus: SubscriberStatus.Unsubscribed, oldStatus: oldStatus);
        if (!subscribeSuccess) {
          logger.w("$TAG - onUnsubscribe - rpc error - topicId:$topicId - permission:$permission - meta:$meta - subscriber:$_subscriber - topic:$_topic");
          _subscriber.status = oldStatus;
          return null;
        }
      }
    } else {
      logger.d("$TAG - onUnsubscribe - no permission action by me - topicId:$topicId - subscriber:$_subscriber - topic:$_topic");
    }
    // owner unsubscribe
    if (_topic.isPrivate && _topic.isOwner(unSubAddress) && (clientCommon.address == unSubAddress)) {
      // do nothing now
    }
    // DB update (just node sync can delete)
    if (oldStatus == SubscriberStatus.Subscribed) {
      bool setSuccess = await setCount(topicId, _topic.count - 1, notify: true);
      if (setSuccess) _topic.count = _topic.count - 1;
    }
    // await subscriberCommon.delete(_subscriber.id, notify: true);
    // subscribers sync
    // if (_topic.isPrivate) {
    //   Future.delayed(Duration(seconds: 1), () {
    //     subscriberCommon.refreshSubscribers(topic, meta: _topic.isPrivate);
    //   });
    // }
    return _subscriber;
  }

  // caller = everyone
  @Deprecated('Replace by PrivateGroup')
  Future<SubscriberSchema?> onKickOut(String? topicId, String? adminAddress, String? blackAddress) async {
    if (topicId == null || topicId.isEmpty || adminAddress == null || adminAddress.isEmpty || blackAddress == null || blackAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _exist = await query(topicId);
    if (_exist == null) {
      logger.e("$TAG - onKickOut - topic is null - topicId:$topicId");
      return null;
    } else if (!_exist.isOwner(adminAddress)) {
      logger.e("$TAG - onKickOut - sender is not owner - topicId:$topicId - adminAddress:$adminAddress");
      return null;
    }
    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onKickOut(topicId, blackAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onKickOut - subscriber is null - topicId:$topicId - blackAddress:$blackAddress - topic:$_exist");
      return null;
    }
    // permission modify in kick action by owner
    // self unsubscribe
    if (blackAddress == clientCommon.address) {
      logger.i("$TAG - onKickOut - kick self - topicId:$topicId - subscriber:$_subscriber - topic:$_exist");
      bool unsubscribeSuccess = await RPC.subscribeWithJoin(topicId, false);
      if (!unsubscribeSuccess) {
        logger.w("$TAG - onKickOut - rpc error - topicId:$topicId - subscriber:$_subscriber");
        return null;
      }
      bool setSuccess = await setJoined(
        topicId,
        false,
        subscribeAt: null,
        expireBlockHeight: 0,
        refreshCreateAt: true,
        notify: true,
      );
      if (setSuccess) {
        _exist.joined = false;
        _exist.subscribeAt = null;
        _exist.expireBlockHeight = 0;
      }
      // DB update (just node sync can delete)
      // await subscriberCommon.deleteByTopic(topic); // stay is useful
      // await delete(_topic.id, notify: true); // replace by setJoined
    } else {
      logger.i("$TAG - onKickOut - kick other - topicId:$topicId - subscriber:$_subscriber - topic:$_exist");
      bool setSuccess = await setCount(topicId, _exist.count - 1, notify: true);
      if (setSuccess) _exist.count = _exist.count - 1;
      // await subscriberCommon.delete(_subscriber.id, notify: true);
      // subscribers sync
      // if (_topic.isPrivate) {
      //   Future.delayed(Duration(seconds: 1), () {
      //     subscriberCommon.refreshSubscribers(topic, meta: _topic.isPrivate);
      //   });
      // }
    }
    return _subscriber;
  }

  /// ***********************************************************************************************************
  /// ********************************************** subscription ***********************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<bool?> isSubscribed(String? topicId, String? contactAddress, {int? globalHeight}) async {
    if (topicId == null || topicId.isEmpty) return null;
    TopicSchema? exists = await query(topicId);
    int gap = DateTime.now().millisecondsSinceEpoch - (exists?.createAt ?? DateTime.now().millisecondsSinceEpoch);
    if ((exists != null) && (gap < Settings.gapTxPoolUpdateDelayMs)) {
      logger.i("$TAG - isSubscribed - createAt just now, maybe in txPool - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - topicId:$topicId - contactAddress:$contactAddress");
      return exists.joined; // maybe in txPool
    }
    int expireHeight = await getSubscribeExpireAtFromNode(exists?.topicId, contactAddress);
    if (expireHeight <= 0) {
      logger.i("$TAG - isSubscribed - expireHeight <= 0 - topicId:$topicId - contactAddress:$contactAddress");
      return false;
    }
    globalHeight = globalHeight ?? (await RPC.getBlockHeight());
    if (globalHeight == null || globalHeight <= 0) {
      logger.w("$TAG - isSubscribed - globalHeight <= 0 - topicId:$topicId");
      return null;
    }
    logger.d("$TAG - isSubscribed - joined:${expireHeight >= globalHeight} - topicId:$topicId");
    return expireHeight >= globalHeight;
  }

  Future<int> getSubscribeExpireAtFromNode(String? topicId, String? contactAddress) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(contactAddress);
    Map<String, dynamic>? result = await RPC.getSubscription(topicId, pubKey);
    if (result == null) {
      logger.w("$TAG - getSubscribeExpireAtFromNode - meta is null - topicId:$topicId - address:$contactAddress");
      return 0;
    }
    int expireSec = int.tryParse(result['expiresAt']?.toString() ?? "0") ?? 0;
    logger.d("$TAG - getSubscribeExpireAtFromNode - topicId:$topicId - contactAddress:$contactAddress - expireSec:$expireSec");
    return expireSec;
  }

  @Deprecated('Replace by PrivateGroup')
  Future<List?> _getPermissionExpireAtByPageFromNode(String? topicId, int permPage) async {
    if (topicId == null || topicId.isEmpty) return [null, null];
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topicId);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic>? result = await RPC.getSubscription(topicId, indexWithPubKey);
    if (result == null) {
      logger.w("$TAG - _getPermissionExpireAtByPageFromNode - meta is null - topicId:$topicId - permPage:$permPage");
      return [null, null];
    }
    Map<String, dynamic> meta = Map();
    if (result['meta']?.toString().isNotEmpty == true) {
      meta = Util.jsonFormatMap(result['meta']) ?? Map();
    }
    int expireSec = int.tryParse(result['expiresAt']?.toString() ?? "0") ?? 0;
    logger.d("$TAG - _getPermissionExpireAtByPageFromNode - topicId:$topicId - permPage:$permPage - expireSec:$expireSec - meta:$meta");
    return [meta, expireSec];
  }

  @Deprecated('Replace by PrivateGroup')
  Future<Map<String, dynamic>?> _getMetaByPageFromNode(String? topicId, int permPage) async {
    if (topicId == null || topicId.isEmpty) return null;
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topicId);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic>? result = await RPC.getSubscription(topicId, indexWithPubKey);
    if (result == null) {
      logger.w("$TAG - _getMetaByPageFromNode - meta is null - topicId:$topicId - permPage:$permPage");
      return null;
    }
    Map<String, dynamic> meta = Map();
    if (result['meta']?.toString().isNotEmpty == true) {
      meta = Util.jsonFormatMap(result['meta']) ?? Map();
    }
    logger.d("$TAG - _getMetaByPageFromNode- topicId:$topicId - permPage:$permPage - meta:$meta");
    return meta;
  }

  @Deprecated('Replace by PrivateGroup')
  Future<Map<String, dynamic>?> _buildPageMetaByAppend(String? topicId, Map<String, dynamic> meta, SubscriberSchema? append) async {
    if (topicId == null || topicId.isEmpty || append == null || append.contactAddress.isEmpty) return null;
    // permPage
    if ((append.permPage ?? -1) <= 0) {
      append.permPage = (await subscriberCommon.findPermissionFromNode(topicId, append.contactAddress))[1] ?? 0;
    }
    // func
    Function whereList = (bool equal, List<dynamic> permList, String contactAddress) {
      return permList.where((element) {
        String address;
        if (element is Map) {
          address = element["addr"] ?? "";
        } else {
          address = element.toString();
        }
        return equal ? (address == contactAddress) : (address != contactAddress);
      }).toList();
    };
    // node meta
    List<dynamic> acceptList = meta['accept'] ?? [];
    List<dynamic> rejectList = meta['reject'] ?? [];
    if ((append.status == SubscriberStatus.InvitedSend) || (append.status == SubscriberStatus.InvitedReceipt) || (append.status == SubscriberStatus.Subscribed)) {
      // add to accepts
      rejectList = whereList(false, rejectList, append.contactAddress);
      if (whereList(true, acceptList, append.contactAddress).isEmpty) {
        logger.d("$TAG - _buildPageMetaByAppend - add to accepts - status:${append.status} - topicId:$topicId - address:${append.contactAddress}");
        acceptList.add({'addr': append.contactAddress});
      }
    } else if (append.status == SubscriberStatus.Unsubscribed) {
      // add to rejects
      logger.d("$TAG - _buildPageMetaByAppend - add to rejects - status:${append.status} - topicId:$topicId - address:${append.contactAddress}");
      acceptList = whereList(false, acceptList, append.contactAddress);
      if (whereList(true, rejectList, append.contactAddress).isEmpty) {
        rejectList.add({'addr': append.contactAddress});
      }
    } else {
      // remove from all
      logger.d("$TAG - _buildPageMetaByAppend - remove from all - status:${append.status} - topicId:$topicId - address:${append.contactAddress}");
      acceptList = whereList(false, acceptList, append.contactAddress);
      rejectList = whereList(false, rejectList, append.contactAddress);
    }
    // DB meta (maybe in txPool)
    List<SubscriberSchema> subscribers = await subscriberCommon.queryListByTopicIdPerm(topicId, append.permPage, SubscriberSchema.PermPageSize * 2);
    subscribers.forEach((SubscriberSchema dbItem) {
      if ((dbItem.contactAddress.isNotEmpty == true) && (dbItem.contactAddress != append.contactAddress)) {
        int gap = DateTime.now().millisecondsSinceEpoch - dbItem.updateAt;
        if (gap < Settings.gapTxPoolUpdateDelayMs) {
          if ((dbItem.status == SubscriberStatus.InvitedSend) || (dbItem.status == SubscriberStatus.InvitedReceipt) || (dbItem.status == SubscriberStatus.Subscribed)) {
            // add to accepts
            logger.i("$TAG - _buildPageMetaByAppend - add to accepts (txPool) - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - topicId:$topicId - address:${append.contactAddress}");
            rejectList = whereList(false, rejectList, dbItem.contactAddress);
            if (whereList(true, acceptList, dbItem.contactAddress).isEmpty) {
              acceptList.add({'addr': dbItem.contactAddress});
            }
          } else if (dbItem.status == SubscriberStatus.Unsubscribed) {
            // add to rejects
            logger.i("$TAG - _buildPageMetaByAppend - add to rejects (txPool) - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - topicId:$topicId - address:${append.contactAddress}");
            acceptList = whereList(false, acceptList, dbItem.contactAddress);
            if (whereList(true, rejectList, dbItem.contactAddress).isEmpty) {
              rejectList.add({'addr': dbItem.contactAddress});
            }
          } else {
            // remove from all
            logger.d("$TAG - _buildPageMetaByAppend - remove from all (txPool) - gap:$gap<${Settings.gapTxPoolUpdateDelayMs} - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - topicId:$topicId - address:${append.contactAddress}");
            acceptList = whereList(false, acceptList, dbItem.contactAddress);
            rejectList = whereList(false, rejectList, dbItem.contactAddress);
          }
        }
      }
    });
    // new meta
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;
    logger.d("$TAG - _buildPageMetaByAppend - topicId:$topicId - permPage:${append.permPage} - accept:$acceptList - reject:$rejectList");
    return meta;
  }

  /// ***********************************************************************************************************
  /// ************************************************* common **************************************************
  /// ***********************************************************************************************************

  Future<TopicSchema?> add(TopicSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.topicId.isEmpty) return null;
    TopicSchema? added = await TopicStorage.instance.insert(schema);
    if ((added != null) && notify) _addSink.add(added);
    return added;
  }

  /*Future<bool> delete(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    TopicSchema? topic = await query(topicId);
    if (topic == null) return false;
    bool success = await TopicStorage.instance.delete(topicId);
    // if (success && notify) _deleteSink.add(topic.topic);
    return success;
  }*/

  Future<TopicSchema?> query(String? topic) async {
    if (topic == null || topic.isEmpty) return null;
    return await TopicStorage.instance.query(topic);
  }

  Future<List<TopicSchema>> queryList({int? type, bool orderDesc = true, int offset = 0, final limit = 20}) {
    return TopicStorage.instance.queryList(type: type, orderDesc: orderDesc, offset: offset, limit: limit);
  }

  Future<List<TopicSchema>> queryListJoined({int? type, bool orderDesc = true, int offset = 0, final limit = 20}) {
    return TopicStorage.instance.queryListByJoined(true, type: type, orderDesc: orderDesc, offset: offset, limit: limit);
  }

  Future<bool> setJoined(
    String? topicId,
    bool joined, {
    int? subscribeAt,
    int? expireBlockHeight,
    bool refreshCreateAt = false,
    bool notify = false,
  }) async {
    if (topicId == null || topicId.isEmpty) return false;
    bool success = await TopicStorage.instance.setJoined(
      topicId,
      joined,
      subscribeAt: subscribeAt,
      expireBlockHeight: expireBlockHeight,
      createAt: refreshCreateAt ? DateTime.now().millisecondsSinceEpoch : null,
    );
    logger.d("$TAG - setJoined - success:$success - joined:$joined - topicId:$topicId - subscribeAt:$subscribeAt - expireBlockHeight:$expireBlockHeight - refreshCreateAt:$refreshCreateAt");
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setAvatar(String? topicId, String? avatarLocalPath, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    bool success = await TopicStorage.instance.setAvatar(topicId, avatarLocalPath);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setCount(String? topicId, int? count, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    if ((count == null) || (count < 0)) count = 0;
    bool success = await TopicStorage.instance.setCount(topicId, count);
    logger.d("$TAG - setCount - success:$success - topicId:$topicId - topicId:$topicId");
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setTop(String? topicId, bool top, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    bool success = await TopicStorage.instance.setTop(topicId, top);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setLastCheckSubscribeAt(String? topicId, {int? timeAt, bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    var data = await TopicStorage.instance.setData(topicId, {
      "last_check_subscribe_at": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setLastCheckSubscribeAt - success:${data != null} - timeAt:$timeAt - data:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future<bool> setLastCheckPermissionAt(String? topicId, {int? timeAt, bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    var data = await TopicStorage.instance.setData(topicId, {
      "last_check_permissions_at": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setLastCheckPermissionAt - success:${data != null} - timeAt:$timeAt - data:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future<bool> setLastRefreshSubscribersAt(String? topicId, {int? timeAt, bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    var data = await TopicStorage.instance.setData(topicId, {
      "last_refresh_subscribers_at": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setLastRefreshSubscribersAt - success:${data != null} - timeAt:$timeAt - data:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future<bool> setStatusProgressStart(String? topicId, bool subscribe, int? nonce, double fee, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    var added = subscribe
        ? {
            "subscribe_progress": true,
            "progress_subscribe_nonce": nonce,
            "progress_subscribe_fee": fee,
          }
        : {
            "unsubscribe_progress": true,
            "progress_subscribe_nonce": nonce,
            "progress_subscribe_fee": fee,
          };
    List<String> removeKeys = subscribe ? ["unsubscribe_progress"] : ["subscribe_progress"];
    var data = await TopicStorage.instance.setData(topicId, added, removeKeys: removeKeys);
    logger.d("$TAG - setStatusProgressStart - success:${data != null} - added:$added - data:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future<bool> setStatusProgressEnd(String? topicId, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty) return false;
    var data = await TopicStorage.instance.setData(topicId, null, removeKeys: [
      "subscribe_progress",
      "unsubscribe_progress",
      "progress_subscribe_nonce",
      "progress_subscribe_fee",
    ]);
    logger.d("$TAG - setStatusProgressEnd - success:${data != null} - data:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future queryAndNotify(String? topicId) async {
    if (topicId == null || topicId.isEmpty) return;
    TopicSchema? updated = await query(topicId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
