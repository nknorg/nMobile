import 'dart:async';

import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';

// TODO:GG 检查所有caller和params
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

  /*Future checkAllTopics({bool refreshSubscribers = true, bool enablePublic = true, bool enablePrivate = true}) async {
    if (!clientCommon.isClientOK) return;

    int limit = 20;
    List<TopicSchema> topics = [];
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await queryList(offset: offset, limit: limit);
      topics.addAll(result);
      if (result.length < limit) break;
    }
    // if (refreshSubscribers) {
    for (var i = 0; i < topics.length; i++) {
      TopicSchema topic = topics[i];
      bool check = (!topic.isPrivate && enablePublic) || (topic.isPrivate && enablePrivate);
      bool longTimeNoRefresh;
      bool needUpdateRefreshAt = false;
      int lastRefreshAt = topic.lastRefreshSubscribersAt();
      if (lastRefreshAt == 0) {
        longTimeNoRefresh = false;
        needUpdateRefreshAt = true;
      } else {
        longTimeNoRefresh = topic.shouldRefreshSubscribers(lastRefreshAt, topic.count ?? 0);
        needUpdateRefreshAt = longTimeNoRefresh;
      }
      bool refresh = (refreshSubscribers || longTimeNoRefresh) && topic.joined;
      double fee = 0;
      if (topic.isSubscribeProgress() || topic.isUnSubscribeProgress()) {
        fee = topic.getProgressSubscribeFee();
      }
      if (check) await checkExpireAndSubscribe(topic.topic, refreshSubscribers: refresh, fee: fee);
      if (refresh || needUpdateRefreshAt) {
        Map<String, dynamic> newData = topic.newDataByLastRefreshSubscribersAt(DateTime.now().millisecondsSinceEpoch);
        await setData(topic.id, newData);
      }
    }
    // } else {
    //   List<Future> futures = [];
    //   topics.forEach((TopicSchema topic) {
    //     bool check = (!topic.isPrivate && enablePublic) || (topic.isPrivate && enablePrivate);
    //     if (check) futures.add(checkExpireAndSubscribe(topic.topic, refreshSubscribers: refreshSubscribers && topic.joined));
    //   });
    //   await Future.wait(futures);
    // }
  }

  Future checkAndTryAllSubscribe({bool txPool = true}) async {
    if (!clientCommon.isClientOK) return;

    int max = 10;
    int limit = 20;
    List<TopicSchema> topicsWithSubscribe = [];
    List<TopicSchema> topicsWithUnSubscribe = [];

    // query
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await queryList(offset: offset, limit: limit);
      result.forEach((element) {
        if (element.isSubscribeProgress()) {
          logger.i("$TAG - checkAndTryAllSubscribe - topic is subscribe progress - topic:$element");
          topicsWithSubscribe.add(element);
        } else if (element.isUnSubscribeProgress()) {
          logger.i("$TAG - checkAndTryAllSubscribe - topic is unsubscribe progress - topic:$element");
          topicsWithUnSubscribe.add(element);
        } else {
          logger.v("$TAG - checkAndTryAllSubscribe - topic is over - topic:$element");
        }
      });
      if ((result.length < limit) || ((topicsWithSubscribe.length + topicsWithUnSubscribe.length) >= max)) break;
    }
    // check + try
    for (var i = 0; i < topicsWithSubscribe.length; i++) {
      TopicSchema topic = topicsWithSubscribe[i];
      await _checkAndTrySubscribe(topic, true);
    }
    for (var i = 0; i < topicsWithUnSubscribe.length; i++) {
      TopicSchema topic = topicsWithUnSubscribe[i];
      await _checkAndTrySubscribe(topic, false);
    }
  }

  Future<bool> _checkAndTrySubscribe(TopicSchema? topic, bool subscribed) async {
    if (topic == null || !clientCommon.isClientOK) return false;

    int expireHeight = await getSubscribeExpireAtByPageFromNode(topic.topic, clientCommon.address);

    topic = await query(topic.id);
    if (topic == null) return false;
    double fee = topic.getProgressSubscribeFee();

    if (subscribed) {
      if (expireHeight <= 0) {
        logger.i("$TAG - checkAndTrySubscribe - topic try subscribe - fee:$fee - trySubscribe:$subscribed - topic:$topic");
        final result = await checkExpireAndSubscribe(topic.topic, enableFirst: true, forceSubscribe: true, refreshSubscribers: false, fee: fee, toast: false);
        if (result != null) await subscriberCommon.onSubscribe(topic.topic, clientCommon.address, null);
      } else {
        logger.i("$TAG - checkAndTrySubscribe - topic subscribe OK - fee:$fee - topic:$topic");
        Map<String, dynamic> newData = topic.newDataByAppendSubscribe(true, false, null, 0);
        await setData(topic.id, newData);
        return true;
      }
    } else {
      if (expireHeight >= 0) {
        logger.i("$TAG - checkAndTrySubscribe - topic try unsubscribe - fee:$fee - trySubscribe:$subscribed - topic:$topic");
        await unsubscribe(topic.topic, fee: fee);
      } else {
        logger.i("$TAG - checkAndTrySubscribe - topic unsubscribe OK - fee:$fee - topic:$topic");
        Map<String, dynamic> newData = topic.newDataByAppendSubscribe(false, false, null, 0);
        await setData(topic.id, newData);
        return true;
      }
    }
    return false;
  }

  @Deprecated('Replace by PrivateGroup')
  Future checkAndTryAllPermission() async {
    if (!clientCommon.isClientOK) return;

    int topicMax = 10;
    int subscriberMax = 20;
    int limit = 20;
    List<TopicSchema> topics = [];
    List<SubscriberSchema> subscribers = [];

    // topic permission
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await queryList(topicType: TopicType.privateTopic, offset: offset, limit: limit);
      result.forEach((element) {
        if (element.isOwner(clientCommon.address)) {
          topics.add(element);
        }
      });
      if ((result.length < limit) || (topics.length >= topicMax)) break;
    }
    int? globalHeight = await RPC.getBlockHeight();
    if (globalHeight != null && globalHeight > 0) {
      double fee = 0;
      var isAuto = await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_RESUBSCRIBE_SPEED_ENABLE);
      if ((isAuto != null) && (isAuto.toString() == "true" || isAuto == true)) {
        fee = double.tryParse((await SettingsStorage.getSettings(SettingsStorage.DEFAULT_FEE)) ?? "0") ?? 0;
        if (fee <= 0) fee = Settings.feeTopicSubscribeDefault;
      }
      for (var i = 0; i < topics.length; i++) {
        TopicSchema topic = topics[i];
        await _checkAndTryPermissionExpire(topic, globalHeight, fee);
      }
    }
    // subscribers permission
    for (var i = 0; i < topics.length; i++) {
      TopicSchema topic = topics[i];
      for (int offset = 0; true; offset += limit) {
        List<SubscriberSchema> result = await subscriberCommon.queryListByTopic(topic.topic, offset: offset, limit: limit);
        result.forEach((element) {
          if (element.isPermissionProgress() != null) {
            logger.i("$TAG - checkAndTryAllPermission - topic permission progress - topic:$topic");
            subscribers.add(element);
          }
        });
        if ((result.length < limit) || (subscribers.length >= subscriberMax)) break;
      }
      if (subscribers.length >= subscriberMax) break;
    }
    for (var i = 0; i < subscribers.length; i++) {
      SubscriberSchema subscribe = subscribers[i];
      int? progressStatus = subscribe.isPermissionProgress();
      await _checkAndTryPermission(subscribe, progressStatus);
    }
  }

  Future _checkAndTryPermissionExpire(TopicSchema? topic, int globalHeight, double fee, {int? nonce}) async {
    if (topic == null || !clientCommon.isClientOK) return;

    int maxPermPage = await subscriberCommon.queryMaxPermPageByTopic(topic.topic);
    for (var i = 0; i <= maxPermPage; i++) {
      List? result = await _getPermissionExpireAtByPageFromNode(topic.topic, i);
      if (result == null) {
        return;
      }
      Map<String, dynamic>? meta = result[0]; // TODO:GG check
      int expireHeight = result[1] ?? 0;
      if ((expireHeight > 0) && ((expireHeight - globalHeight) < Settings.blockHeightTopicWarnBlockExpire)) {
        await RPC.subscribeWithPermission(topic.topic, nonce: nonce, fee: fee, permPage: i, meta: meta, toast: false);
      }
    }
  }

  Future<bool> _checkAndTryPermission(SubscriberSchema? subscriber, int? status, {bool txPool = false}) async {
    if (subscriber == null || status == null || !clientCommon.isClientOK) return false;

    bool needAccept = (status == SubscriberStatus.InvitedSend) || (status == SubscriberStatus.InvitedReceipt) || (status == SubscriberStatus.Subscribed);
    bool needReject = status == SubscriberStatus.Unsubscribed;
    bool needNoPermission = status == SubscriberStatus.None;

    List<dynamic> permission = await subscriberCommon.findPermissionFromNode(subscriber.topic, subscriber.clientAddress, txPool: txPool);
    if (acceptAll == null) {
      // TODO:GG
    }
    // bool? acceptAll = permission[0];
    // int? permPage = permission[1];
    bool? isAccept = permission[2];
    bool? isReject = permission[3];

    subscriber = await subscriberCommon.query(subscriber.id);
    if (subscriber == null) return false;
    double fee = subscriber.getProgressPermissionFee();

    if (needAccept) {
      if (isAccept == true) {
        logger.i("$TAG - checkAndTryPermission - subscriber permission(accept) OK - fee:$fee - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.id, notify: true);
        return true;
      } else {
        logger.i("$TAG - checkAndTryPermission - subscriber try invitee - fee:$fee - tryStatus:$status - subscribe:$subscriber");
        await invitee(subscriber.topic, true, true, subscriber.clientAddress, fee: fee);
      }
    } else if (needReject) {
      if (isReject == true) {
        logger.i("$TAG - checkAndTryPermission - subscriber permission(reject) OK - fee:$fee - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.id, notify: true);
        return true;
      } else {
        logger.i("$TAG - checkAndTryPermission - subscriber try kick - fee:$fee - tryStatus:$status - subscribe:$subscriber");
        await kick(subscriber.topic, true, true, subscriber.clientAddress, fee: fee);
      }
    } else if (needNoPermission) {
      if (isAccept != true && isReject != true) {
        logger.i("$TAG - checkAndTryPermission - subscriber permission(none) OK - fee:$fee - subscribe:$subscriber");
        await subscriberCommon.setStatusProgressEnd(subscriber.id, notify: true);
        return true;
      } else {
        logger.i("$TAG - checkAndTryPermission - subscriber try kick - fee:$fee - tryStatus:$status - subscribe:$subscriber");
        await onUnsubscribe(subscriber.topic, subscriber.clientAddress);
      }
    } else {
      logger.w("$TAG - checkAndTryPermission - subscriber permission none - fee:$fee - tryStatus:$status - subscribe:$subscriber");
      await subscriberCommon.setStatusProgressEnd(subscriber.id, notify: true);
      return true;
    }
    return false;
  }*/

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = self(owner/normal)
  Future<TopicSchema?> subscribe(String? topic, {bool fetchSubscribers = false, bool justNow = false, double fee = 0}) async {
    if (topic == null || topic.isEmpty || !clientCommon.isClientOK) return null;
    // topic exist
    TopicSchema? exists = await queryByTopic(topic);
    if (exists == null) {
      int expireHeight = await getSubscribeExpireAtByPageFromNode(topic, clientCommon.address);
      exists = await add(TopicSchema.create(topic, expireHeight: expireHeight), notify: true);
      logger.i("$TAG - subscribe - new - expireHeight:$expireHeight - schema:$exists");
      // refreshSubscribers later
    }
    if (exists == null) {
      logger.w("$TAG - subscribe - topic is null - topic:$topic");
      return null;
    }
    // permission(private + normal)
    int? permPage;
    if (exists.isPrivate && !exists.isOwner(clientCommon.address)) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic, clientCommon.address);
      bool? acceptAll = permission[0];
      permPage = permission[1];
      bool? isAccept = permission[2];
      bool? isReject = permission[3];
      if (acceptAll == null) {
        logger.w("$TAG - subscribe - error when findPermissionFromNode - topic:$topic - permission:$permission");
        return null;
      } else if (acceptAll == true) {
        logger.d("$TAG - subscribe - accept all - schema:$exists");
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
        logger.i("$TAG - subscribe - is_accept ok - schema:$exists");
      }
    } else {
      logger.d("$TAG - subscribe - skip permission check - schema:$exists");
    }
    // check expire + pull subscribers
    exists = await checkExpireAndSubscribe(topic, enableFirst: true, forceSubscribe: true, refreshSubscribers: fetchSubscribers, fee: fee, toast: true);
    if (exists == null) return null;
    await Future.delayed(Duration(milliseconds: 250));
    // permission(owner default all permission)
    // status
    await subscriberCommon.onSubscribe(topic, clientCommon.address, permPage);
    await Future.delayed(Duration(milliseconds: 250));
    // send messages
    await chatOutCommon.sendTopicSubscribe(topic);
    // subscribersInfo
    // subscriberCommon.fetchSubscribersInfo(topic); // await
    return exists;
  }

  // caller = self(owner/normal)
  Future<TopicSchema?> checkExpireAndSubscribe(
    String? topic, {
    bool refreshSubscribers = false,
    bool forceSubscribe = false,
    bool enableFirst = false,
    double fee = 0,
    bool toast = false,
  }) async {
    if (topic == null || topic.isEmpty || !clientCommon.isClientOK) return null;
    // topic exist
    TopicSchema? exists = await queryByTopic(topic);
    if (exists == null) {
      logger.w("$TAG - checkExpireAndSubscribe - topic is null - topic:$topic");
      return null;
    }
    // check expire
    bool noSubscribed;
    int expireHeight = await getSubscribeExpireAtByPageFromNode(exists.topic, clientCommon.address);
    if (!exists.joined || (exists.subscribeAt ?? 0) <= 0 || (exists.expireBlockHeight ?? 0) <= 0) {
      if (expireHeight > 0) {
        // DB no joined + node is joined
        noSubscribed = false;
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if ((DateTime.now().millisecondsSinceEpoch - createAt) > Settings.gapTxPoolUpdateDelayMs) {
          logger.d("$TAG - checkExpireAndSubscribe - DB expire but node not expire - topic:$exists");
          int subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
          bool success = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
          if (success) {
            exists.joined = true;
            exists.subscribeAt = subscribeAt;
            exists.expireBlockHeight = expireHeight;
          }
        } else {
          var betweenS = (DateTime.now().millisecondsSinceEpoch - createAt) / 1000;
          logger.i("$TAG - checkExpireAndSubscribe - DB expire but node not expire, maybe in txPool, just return - between:${betweenS}s - topic:$exists");
        }
      } else {
        // DB no joined + node no joined
        logger.i("$TAG - checkExpireAndSubscribe - no subscribe history - topic:$exists");
        noSubscribed = true;
      }
    } else {
      if (expireHeight <= 0) {
        // DB is joined + node no joined
        noSubscribed = true;
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if (exists.joined && (DateTime.now().millisecondsSinceEpoch - createAt) > Settings.gapTxPoolUpdateDelayMs) {
          logger.i("$TAG - checkExpireAndSubscribe - DB no expire but node expire - topic:$exists");
          bool success = await setJoined(exists.id, false, notify: true);
          if (success) {
            exists.joined = false;
            exists.subscribeAt = 0;
            exists.expireBlockHeight = 0;
          }
        } else {
          var betweenS = (DateTime.now().millisecondsSinceEpoch - createAt) / 1000;
          logger.i("$TAG - checkExpireAndSubscribe - DB not expire but node expire, maybe in txPool, just run - between:${betweenS}s - topic:$exists");
        }
      } else {
        // DB is joined + node is joined
        logger.d("$TAG - checkExpireAndSubscribe - OK OK OK OK OK - topic:$exists");
        noSubscribed = false;
      }
    }
    // subscribe
    int? globalHeight = await RPC.getBlockHeight();
    bool shouldResubscribe = await exists.shouldResubscribe(globalHeight);
    if (forceSubscribe || (noSubscribed && enableFirst) || (exists.joined && shouldResubscribe)) {
      // subscribe fee
      if ((exists.joined && shouldResubscribe) && (fee <= 0)) {
        var isAuto = await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_RESUBSCRIBE_SPEED_ENABLE);
        if ((isAuto != null) && ((isAuto.toString() == "true") || (isAuto == true))) {
          fee = double.tryParse((await SettingsStorage.getSettings(SettingsStorage.DEFAULT_FEE)) ?? "0") ?? 0;
          if (fee <= 0) fee = Settings.feeTopicSubscribeDefault;
        }
      }
      // client subscribe
      int? _nonce = exists.getProgressSubscribeNonce();
      bool subscribeSuccess = await RPC.subscribeWithJoin(topic, true, nonce: _nonce, fee: fee, toast: toast);
      if (!subscribeSuccess) {
        logger.w("$TAG - checkExpireAndSubscribe - _clientSubscribe fail - topic:$topic - nonce:$_nonce - fee:$fee - topic:$exists");
        return null;
      }
      // db update
      var subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      var expireHeight = (globalHeight ?? exists.expireBlockHeight ?? 0) + Settings.blockHeightTopicSubscribeDefault;
      bool setSuccess = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, refreshCreateAt: true, notify: true);
      if (setSuccess) {
        exists.joined = true;
        exists.subscribeAt = subscribeAt;
        exists.expireBlockHeight = expireHeight;
      }
      logger.i("$TAG - checkExpireAndSubscribe - _clientSubscribe success - topic:$exists");
    } else {
      logger.d("$TAG - checkExpireAndSubscribe - _clientSubscribe no need subscribe - topic:$exists");
    }
    // subscribers
    if (refreshSubscribers) {
      await subscriberCommon.refreshSubscribers(topic, exists.ownerPubKey, meta: exists.isPrivate);
      await setLastRefreshSubscribersAt(exists.id, notify: true);
      int count = await subscriberCommon.getSubscribersCount(topic, exists.isPrivate);
      if (exists.count != count) {
        bool success = await topicCommon.setCount(exists.id, count, notify: true);
        if (success) exists.count = count;
      }
    }
    return exists;
  }

  /// ***********************************************************************************************************
  /// ************************************************ action ***************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> invitee(String? topic, bool isPrivate, bool isOwner, String? inviteeAddress, {double fee = 0, bool toast = false, bool sendMsg = false}) async {
    if (topic == null || topic.isEmpty || inviteeAddress == null || inviteeAddress.isEmpty) return null;
    if (!clientCommon.isClientOK) return null;
    if (isPrivate && !isOwner) {
      if (toast) Toast.show(Settings.locale((s) => s.member_no_auth_invite));
      return null;
    } else if (inviteeAddress == clientCommon.address) {
      if (toast) Toast.show(Settings.locale((s) => s.invite_yourself_error));
      return null;
    }
    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topic, inviteeAddress);
    if ((_subscriber != null) && (_subscriber.status == SubscriberStatus.Subscribed)) {
      if (toast) Toast.show(Settings.locale((s) => s.group_member_already));
      return null;
    }
    int? oldStatus = _subscriber?.status;
    // if (isPrivate && toast) Toast.show(Settings.locale((s) => s.inviting));
    // check permission
    int? appendPermPage;
    if (isPrivate) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic, inviteeAddress);
      bool? acceptAll = permission[0];
      appendPermPage = permission[1] ?? (await subscriberCommon.queryNextPermPageByTopic(topic));
      bool? isReject = permission[3];
      if (acceptAll == null) {
        logger.w("$TAG - invitee - error when findPermissionFromNode - topic:$topic - permission:$permission - subscriber:$_subscriber");
        return null;
      } else if (!isOwner && (acceptAll != true) && (isReject == true)) {
        // just owner can invitee reject item
        if (toast) Toast.show(Settings.locale((s) => s.blocked_user_disallow_invite));
        return null;
      }
      // update DB
      _subscriber = await subscriberCommon.onInvitedSend(topic, inviteeAddress, appendPermPage);
      // update meta (private + owner + no_accept_all)
      if (acceptAll == true) {
        logger.i("$TAG - invitee - acceptAll == true - topic:$topic - invitee:$inviteeAddress - permission:$permission");
      } else {
        if (appendPermPage == null) {
          logger.e("$TAG - invitee - permPage is null - topic:$topic - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        logger.i("$TAG - invitee - push permission by me(==owner) - topic:$topic - permission:$permission - subscriber:$_subscriber");
        Map<String, dynamic>? meta = await _getMetaByPageFromNode(topic, appendPermPage);
        if (meta == null) {
          logger.w("$TAG - invitee - meta is null by _getMetaFromNodeByPage - topic:$topic - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        meta = await _buildPageMetaByAppend(topic, meta, _subscriber);
        if (meta == null) {
          logger.w("$TAG - invitee - meta is null by _buildPageMetaByAppend - topic:$topic - permission:$permission - subscriber:$_subscriber");
          return null;
        }
        int? _nonce = _subscriber?.getProgressPermissionNonce();
        bool subscribeSuccess = await RPC.subscribeWithPermission(topic, nonce: _nonce, fee: fee, permPage: appendPermPage, meta: meta, toast: toast, clientAddress: inviteeAddress, newStatus: SubscriberStatus.InvitedSend, oldStatus: oldStatus);
        if (!subscribeSuccess) {
          logger.w("$TAG - invitee - rpc error - topic:$topic - nonce_$_nonce - fee:$fee - permPage:$appendPermPage - meta:$meta");
          _subscriber?.status = oldStatus;
          return null;
        }
      }
    } else {
      // update DB
      logger.d("$TAG - invitee - no permission by me(public) - topic:$topic - subscriber:$_subscriber");
      _subscriber = await subscriberCommon.onInvitedSend(topic, inviteeAddress, null);
    }
    // send message
    if (sendMsg) {
      MessageSchema? _msg = await chatOutCommon.sendTopicInvitee(inviteeAddress, topic);
      if (_msg == null) {
        if (toast) Toast.show(Settings.locale((s) => s.failure));
        return null;
      }
    } else if (oldStatus == SubscriberStatus.InvitedReceipt) {
      await subscriberCommon.setStatus(_subscriber?.id, SubscriberStatus.InvitedReceipt, notify: true);
    }
    if (toast) Toast.show(Settings.locale((s) => s.invitation_sent));
    return _subscriber;
  }

  // caller = self
  Future<TopicSchema?> unsubscribe(String? topic, {double fee = 0, bool toast = false}) async {
    if (topic == null || topic.isEmpty) return null;
    if (!clientCommon.isClientOK) return null;
    // permission modify in owners message received by owner
    TopicSchema? exists = await queryByTopic(topic);
    // client unsubscribe
    int? _nonce = exists?.getProgressSubscribeNonce();
    bool unsubscribeSuccess = await RPC.subscribeWithJoin(topic, false, nonce: _nonce, fee: fee, toast: toast);
    if (!unsubscribeSuccess) {
      logger.w("$TAG - unsubscribe - rpc error - topic:$topic - nonce$_nonce - fee:$fee - topic:$exists");
      return null;
    }
    logger.i("$TAG - unsubscribe - rpc success - topic:$topic - nonce$_nonce - fee:$fee - topic:$exists");
    await Future.delayed(Duration(milliseconds: 250));
    // topic update
    bool setSuccess = await setJoined(exists?.id, false, refreshCreateAt: true, notify: true);
    if (setSuccess) {
      exists?.joined = false;
      exists?.subscribeAt = 0;
      exists?.expireBlockHeight = 0;
    }
    // setSuccess = await setCount(exists?.id, (exists?.count ?? 1) - 1, notify: true);
    // if (setSuccess) exists?.count = (exists.count ?? 1) - 1;
    // DB(topic+subscriber) delete
    await subscriberCommon.onUnsubscribe(topic, clientCommon.address);
    // await subscriberCommon.deleteByTopic(topic); // stay is useful
    // await delete(exists?.id, notify: true); // replace by setJoined
    // send message
    await chatOutCommon.sendTopicUnSubscribe(topic);
    await Future.delayed(Duration(milliseconds: 250));
    return exists;
  }

  // caller = private + owner
  @Deprecated('Replace by PrivateGroup')
  Future<SubscriberSchema?> kick(String? topic, bool isPrivate, bool isOwner, String? kickAddress, {double fee = 0, bool toast = false}) async {
    if (topic == null || topic.isEmpty || kickAddress == null || kickAddress.isEmpty) return null;
    if (!clientCommon.isClientOK) return null;
    if (kickAddress == clientCommon.address) return null;
    if (!isPrivate || !isOwner) return null; // enable just private + owner
    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topic, kickAddress);
    if (_subscriber == null) return null;
    if (_subscriber.canBeKick == false) return null; // checked in UI
    int? oldStatus = _subscriber.status;
    // check permission
    List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic, kickAddress);
    bool? acceptAll = permission[0];
    int? permPage = permission[1] ?? _subscriber.permPage;
    if (acceptAll == null) {
      logger.w("$TAG - kick - error when findPermissionFromNode - topic:$topic - kickAddress:$kickAddress");
      return null;
    } else if ((acceptAll == true) || (permPage == null)) {
      logger.w("$TAG - kick - permPage is null(maybe accept all) - topic:$topic - kickAddress:$kickAddress");
      if (toast) Toast.show(Settings.locale((s) => s.failure));
      return null;
    }
    // update DB
    _subscriber = await subscriberCommon.onKickOut(topic, kickAddress, permPage: permPage);
    // update meta (private + owner + no_accept_all)
    Map<String, dynamic>? meta = await _getMetaByPageFromNode(topic, permPage);
    if (meta == null) {
      logger.w("$TAG - kick - meta is null by _getMetaFromNodeByPage - topic:$topic - permission:$permission - subscriber:$_subscriber");
      return null;
    }
    meta = await _buildPageMetaByAppend(topic, meta, _subscriber);
    if (meta == null) {
      logger.w("$TAG - kick - meta is null by _buildPageMetaByAppend - topic:$topic - permission:$permission - subscriber:$_subscriber");
      return null;
    }
    int? _nonce = _subscriber?.getProgressPermissionNonce();
    bool subscribeSuccess = await RPC.subscribeWithPermission(topic, nonce: _nonce, fee: fee, permPage: permPage, meta: meta, toast: toast, clientAddress: kickAddress, newStatus: SubscriberStatus.Unsubscribed, oldStatus: oldStatus);
    if (!subscribeSuccess) {
      logger.w("$TAG - kick - rpc error - topic:$topic - nonce:$_nonce - fee:$fee - permission:$permission - meta:$meta - subscriber:$_subscriber");
      _subscriber?.status = oldStatus;
      return null;
    }
    logger.i("$TAG - kick - rpc success - topic:$topic - nonce:$_nonce - fee:$fee - permission:$permission - meta:$meta - subscriber:$_subscriber");
    // send message
    await chatOutCommon.sendTopicKickOut(topic, kickAddress);
    if (toast) Toast.show(Settings.locale((s) => s.rejected));
    return _subscriber;
  }

  /// ***********************************************************************************************************
  /// *********************************************** callback **************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> onSubscribe(String? topic, String? subAddress) async {
    if (topic == null || topic.isEmpty || subAddress == null || subAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _topic = await queryByTopic(topic);
    if (_topic == null) {
      logger.e("$TAG - onSubscribe - topic is null - topic:$topic");
      return null;
    }
    // permission check
    int? permPage;
    if (_topic.isPrivate && !_topic.isOwner(subAddress)) {
      logger.i("$TAG - onSubscribe - sync permission by me(no owner) - topic:$topic - subAddress:$subAddress - topic:$_topic");
      List permission = await subscriberCommon.findPermissionFromNode(topic, subAddress);
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
      logger.d("$TAG - onSubscribe - no permission action by me - topic:$topic - subAddress:$subAddress - topic:$_topic");
    }
    // permission modify in invitee action by owner
    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onSubscribe(topic, subAddress, permPage);
    if (_subscriber == null) {
      logger.w("$TAG - onSubscribe - subscriber is null - topic:$topic - subAddress:$subAddress - permPage:$permPage");
      return null;
    }
    bool setSuccess = await setCount(_topic.id, (_topic.count ?? 1) + 1, notify: true);
    if (setSuccess) _topic.count = (_topic.count ?? 1) + 1;
    // subscribers sync
    // if (_topic.isPrivate) {
    //   Future.delayed(Duration(seconds: 1), () {
    //     subscriberCommon.refreshSubscribers(topic, meta: _topic.isPrivate);
    //   });
    // }
    return _subscriber;
  }

  // caller = everyone
  Future<SubscriberSchema?> onUnsubscribe(String? topic, String? unSubAddress) async {
    if (topic == null || topic.isEmpty || unSubAddress == null || unSubAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _topic = await topicCommon.queryByTopic(topic);
    if (_topic == null) {
      logger.e("$TAG - onUnsubscribe - topic is null - topic:$topic");
      return null;
    }
    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onUnsubscribe(topic, unSubAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onUnsubscribe - subscriber is null - topic:$topic - unSubAddress:$unSubAddress");
      return null;
    }
    int? oldStatus = _subscriber.status;
    // private + owner
    if (_topic.isPrivate && _topic.isOwner(clientCommon.address) && (clientCommon.address != unSubAddress)) {
      logger.i("$TAG - onUnsubscribe - sync permission by me(==owner) - topic:$topic - subscriber:$_subscriber - topic:$_topic");
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topic, unSubAddress);
      bool? acceptAll = permission[0];
      int? permPage = permission[1] ?? _subscriber.permPage;
      if (acceptAll == null) {
        logger.w("$TAG - onUnsubscribe - error when findPermissionFromNode - topic:$topic - permission:$permission - subscriber:$_subscriber - topic:$_topic");
        return null;
      } else if (acceptAll == true) {
        logger.i("$TAG - onUnsubscribe - acceptAll == true - topic:$topic - permission:$permission - subscriber:$_subscriber - topic:$_topic");
      } else {
        if (permPage == null) {
          logger.e("$TAG - onUnsubscribe - permPage is null - topic:$topic - permission:$permission - subscriber:$_subscriber");
          return null;
        } else if (_subscriber.permPage != permPage) {
          logger.w("$TAG - onUnsubscribe - permPage is diff - topic:$topic - permission:$permission - subscriber:$_subscriber");
          bool success = await subscriberCommon.setPermPage(_subscriber.id, permPage, notify: true);
          if (success) _subscriber.permPage = permPage; // if (success)
        }
        // meta update
        Map<String, dynamic>? meta = await _getMetaByPageFromNode(topic, permPage);
        if (meta == null) {
          logger.w("$TAG - onUnsubscribe - meta is null by _getMetaFromNodeByPage - topic:$topic - permission:$permission - subscriber:$_subscriber - topic:$_topic");
          return null;
        }
        _subscriber.status = SubscriberStatus.None; // temp for build meta
        meta = await _buildPageMetaByAppend(topic, meta, _subscriber);
        _subscriber.status = SubscriberStatus.Unsubscribed;
        if (meta == null) {
          logger.w("$TAG - onUnsubscribe - meta is null by _buildPageMetaByAppend - topic:$topic - permission:$permission - subscriber:$_subscriber - topic:$_topic");
          return null;
        }
        bool subscribeSuccess = await RPC.subscribeWithPermission(topic, permPage: permPage, meta: meta, clientAddress: unSubAddress, newStatus: SubscriberStatus.Unsubscribed, oldStatus: oldStatus);
        if (!subscribeSuccess) {
          logger.w("$TAG - onUnsubscribe - rpc error - topic:$topic - permission:$permission - meta:$meta - subscriber:$_subscriber - topic:$_topic");
          _subscriber.status = oldStatus;
          return null;
        }
      }
    } else {
      logger.d("$TAG - onUnsubscribe - no permission action by me - topic:$topic - subscriber:$_subscriber - topic:$_topic");
    }
    // owner unsubscribe
    if (_topic.isPrivate && _topic.isOwner(unSubAddress) && (clientCommon.address == unSubAddress)) {
      // do nothing now
    }
    // DB update (just node sync can delete)
    bool setSuccess = await setCount(_topic.id, (_topic.count ?? 1) - 1, notify: true);
    if (setSuccess) _topic.count = (_topic.count ?? 1) - 1;
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
  Future<SubscriberSchema?> onKickOut(String? topic, String? adminAddress, String? blackAddress) async {
    if (topic == null || topic.isEmpty || adminAddress == null || adminAddress.isEmpty || blackAddress == null || blackAddress.isEmpty) return null;
    // no client check, has progress
    // topic exist
    TopicSchema? _exist = await topicCommon.queryByTopic(topic);
    if (_exist == null) {
      logger.e("$TAG - onKickOut - topic is null - topic:$topic");
      return null;
    } else if (!_exist.isOwner(adminAddress)) {
      logger.e("$TAG - onKickOut - sender is not owner - topic:$topic - adminAddress:$adminAddress");
      return null;
    }
    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onKickOut(topic, blackAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onKickOut - subscriber is null - topic:$topic - blackAddress:$blackAddress - topic:$_exist");
      return null;
    }
    // permission modify in kick action by owner
    // self unsubscribe
    if (blackAddress == clientCommon.address) {
      logger.i("$TAG - onKickOut - kick self - topic:$topic - subscriber:$_subscriber - topic:$_exist");
      bool unsubscribeSuccess = await RPC.subscribeWithJoin(topic, false);
      if (!unsubscribeSuccess) {
        logger.w("$TAG - onKickOut - rpc error - topic:$topic - subscriber:$_subscriber");
        return null;
      }
      bool setSuccess = await setJoined(_exist.id, false, refreshCreateAt: true, notify: true);
      if (setSuccess) {
        _exist.joined = false;
        _exist.subscribeAt = 0;
        _exist.expireBlockHeight = 0;
      }
      // DB update (just node sync can delete)
      // await subscriberCommon.deleteByTopic(topic); // stay is useful
      // await delete(_topic.id, notify: true); // replace by setJoined
    } else {
      logger.i("$TAG - onKickOut - kick other - topic:$topic - subscriber:$_subscriber - topic:$_exist");
      bool setSuccess = await setCount(_exist.id, (_exist.count ?? 1) - 1, notify: true);
      if (setSuccess) _exist.count = (_exist.count ?? 1) - 1;
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
  Future<bool> isSubscribed(String? topic, String? clientAddress, {int? globalHeight}) async {
    if (topic == null || topic.isEmpty) return false;
    TopicSchema? exists = await queryByTopic(topic);
    int createAt = exists?.createAt ?? DateTime.now().millisecondsSinceEpoch;
    if ((exists != null) && (DateTime.now().millisecondsSinceEpoch - createAt) < Settings.gapTxPoolUpdateDelayMs) {
      logger.i("$TAG - isJoined - createAt just now, maybe in txPool - topic:$topic - clientAddress:$clientAddress");
      return exists.joined; // maybe in txPool
    }
    int expireHeight = await getSubscribeExpireAtByPageFromNode(exists?.topic, clientAddress);
    if (expireHeight <= 0) {
      logger.i("$TAG - isJoined - expireHeight <= 0 - topic:$topic - clientAddress:$clientAddress");
      return false;
    }
    globalHeight = globalHeight ?? (await RPC.getBlockHeight());
    if (globalHeight == null || globalHeight <= 0) {
      logger.w("$TAG - isJoined - globalHeight <= 0 - topic:$topic");
      return false;
    }
    return expireHeight >= globalHeight;
  }

  // TODO:GG call
  Future<int> getSubscribeExpireAtByPageFromNode(String? topic, String? clientAddress) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
    Map<String, dynamic>? result = await RPC.getSubscription(topic, pubKey);
    if (result == null) {
      logger.w("$TAG - getSubscribeExpireAtByPageFromNode - meta is null - topic:$topic - address:$clientAddress");
      return 0;
    }
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    int expireSec = int.tryParse(expiresAt) ?? 0;
    logger.d("$TAG - getSubscribeExpireAtByPageFromNode - topic:$topic - clientAddress:$clientAddress - expireSec:$expireSec");
    return expireSec;
  }

  // TODO:GG call
  @Deprecated('Replace by PrivateGroup')
  Future<List?> _getPermissionExpireAtByPageFromNode(String? topic, int permPage) async {
    if (topic == null || topic.isEmpty) return [null, null];
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topic);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic>? result = await RPC.getSubscription(topic, indexWithPubKey);
    if (result == null) {
      logger.w("$TAG - _getPermissionExpireAtByPageFromNode - meta is null - topic:$topic - permPage:$permPage");
      return [null, null];
    }
    Map<String, dynamic> meta = Map();
    if (result['meta']?.toString().isNotEmpty == true) {
      meta = Util.jsonFormatMap(result['meta']) ?? Map();
    }
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    int expireSec = int.tryParse(expiresAt) ?? 0;
    logger.d("$TAG - _getPermissionExpireAtByPageFromNode - topic:$topic - permPage:$permPage - expireSec:$expireSec - meta:$meta");
    return [meta, expireSec];
  }

  @Deprecated('Replace by PrivateGroup')
  Future<Map<String, dynamic>?> _getMetaByPageFromNode(String? topic, int permPage) async {
    if (topic == null || topic.isEmpty) return null;
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topic);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic>? result = await RPC.getSubscription(topic, indexWithPubKey);
    if (result == null) {
      logger.w("$TAG - _getMetaByPageFromNode - meta is null - topic:$topic - permPage:$permPage");
      return null;
    }
    Map<String, dynamic>? meta = Map();
    if (result['meta']?.toString().isNotEmpty == true) {
      meta = Util.jsonFormatMap(result['meta']) ?? Map();
    }
    logger.d("$TAG - _getMetaByPageFromNode- topic:$topic - permPage:$permPage - meta:$meta");
    return meta;
  }

  @Deprecated('Replace by PrivateGroup')
  Future<Map<String, dynamic>?> _buildPageMetaByAppend(String? topic, Map<String, dynamic> meta, SubscriberSchema? append) async {
    if (topic == null || topic.isEmpty || append == null || append.clientAddress.isEmpty) return null;
    // permPage
    if ((append.permPage ?? -1) <= 0) {
      append.permPage = (await subscriberCommon.findPermissionFromNode(topic, append.clientAddress))[1] ?? 0;
    }
    // func
    Function whereList = (bool equal, List<dynamic> permList, String clientAddress) {
      return permList.where((element) {
        String address;
        if (element is Map) {
          address = element["addr"] ?? "";
        } else {
          address = element.toString();
        }
        return equal ? (address == clientAddress) : (address != clientAddress);
      }).toList();
    };
    // node meta
    List<dynamic> acceptList = meta['accept'] ?? [];
    List<dynamic> rejectList = meta['reject'] ?? [];
    if ((append.status == SubscriberStatus.InvitedSend) || (append.status == SubscriberStatus.InvitedReceipt) || (append.status == SubscriberStatus.Subscribed)) {
      // add to accepts
      rejectList = whereList(false, rejectList, append.clientAddress);
      if (whereList(true, acceptList, append.clientAddress).isEmpty) {
        logger.d("$TAG - _buildPageMetaByAppend - add to accepts - status:${append.status} - topic:$topic - address:${append.clientAddress}");
        acceptList.add({'addr': append.clientAddress});
      }
    } else if (append.status == SubscriberStatus.Unsubscribed) {
      // add to rejects
      logger.d("$TAG - _buildPageMetaByAppend - add to rejects - status:${append.status} - topic:$topic - address:${append.clientAddress}");
      acceptList = whereList(false, acceptList, append.clientAddress);
      if (whereList(true, rejectList, append.clientAddress).isEmpty) {
        rejectList.add({'addr': append.clientAddress});
      }
    } else {
      // remove from all
      logger.d("$TAG - _buildPageMetaByAppend - remove from all - status:${append.status} - topic:$topic - address:${append.clientAddress}");
      acceptList = whereList(false, acceptList, append.clientAddress);
      rejectList = whereList(false, rejectList, append.clientAddress);
    }
    // DB meta (maybe in txPool)
    List<SubscriberSchema> subscribers = await subscriberCommon.queryListByTopicPerm(topic, append.permPage, SubscriberSchema.PermPageSize * 2);
    subscribers.forEach((SubscriberSchema dbItem) {
      if ((dbItem.clientAddress.isNotEmpty == true) && (dbItem.clientAddress != append.clientAddress)) {
        int interval = DateTime.now().millisecondsSinceEpoch - (dbItem.updateAt ?? 0);
        if (interval < Settings.gapTxPoolUpdateDelayMs) {
          if ((dbItem.status == SubscriberStatus.InvitedSend) || (dbItem.status == SubscriberStatus.InvitedReceipt) || (dbItem.status == SubscriberStatus.Subscribed)) {
            // add to accepts
            logger.i("$TAG - _buildPageMetaByAppend - add to accepts (txPool) - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - gap:$interval - topic:$topic - address:${append.clientAddress}");
            rejectList = whereList(false, rejectList, dbItem.clientAddress);
            if (whereList(true, acceptList, dbItem.clientAddress).isEmpty) {
              acceptList.add({'addr': dbItem.clientAddress});
            }
          } else if (dbItem.status == SubscriberStatus.Unsubscribed) {
            // add to rejects
            logger.i("$TAG - _buildPageMetaByAppend - add to rejects (txPool) - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - gap:$interval - topic:$topic - address:${append.clientAddress}");
            acceptList = whereList(false, acceptList, dbItem.clientAddress);
            if (whereList(true, rejectList, dbItem.clientAddress).isEmpty) {
              rejectList.add({'addr': dbItem.clientAddress});
            }
          } else {
            // remove from all
            logger.d("$TAG - _buildPageMetaByAppend - remove from all (txPool) - status:${append.status} - progress_status:${dbItem.isPermissionProgress()} - gap:$interval - topic:$topic - address:${append.clientAddress}");
            acceptList = whereList(false, acceptList, dbItem.clientAddress);
            rejectList = whereList(false, rejectList, dbItem.clientAddress);
          }
        }
      }
    });
    // new meta
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;
    logger.d("$TAG - _buildPageMetaByAppend - permPage:${append.permPage} - accept:$acceptList - reject:$rejectList");
    return meta;
  }

  /// ***********************************************************************************************************
  /// ************************************************* common **************************************************
  /// ***********************************************************************************************************

  Future<TopicSchema?> add(TopicSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.topic.isEmpty) return null;
    schema.type = schema.type ?? (Validate.isPrivateTopicOk(schema.topic) ? TopicType.privateTopic : TopicType.publicTopic);
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

  Future<TopicSchema?> query(int? topicId) {
    return TopicStorage.instance.query(topicId);
  }

  Future<TopicSchema?> queryByTopic(String? topic) async {
    if (topic == null || topic.isEmpty) return null;
    return await TopicStorage.instance.queryByTopic(topic);
  }

  Future<List<TopicSchema>> queryList({int? topicType, String? orderBy, int offset = 0, int limit = 20}) {
    return TopicStorage.instance.queryList(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<List<TopicSchema>> queryListJoined({int? topicType, String? orderBy, int offset = 0, int limit = 20}) {
    return TopicStorage.instance.queryListJoined(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<bool> setJoined(int? topicId, bool joined, {int? subscribeAt, int? expireBlockHeight, bool refreshCreateAt = false, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await TopicStorage.instance.setJoined(
      topicId,
      joined,
      subscribeAt: subscribeAt,
      expireBlockHeight: expireBlockHeight,
      createAt: refreshCreateAt ? DateTime.now().millisecondsSinceEpoch : null,
    );
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setAvatar(int? topicId, String? avatarLocalPath, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await TopicStorage.instance.setAvatar(topicId, avatarLocalPath);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setCount(int? topicId, int? count, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await TopicStorage.instance.setCount(topicId, count ?? 0);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setTop(int? topicId, bool top, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await TopicStorage.instance.setTop(topicId, top);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  // TODO:GG call
  Future<bool> setLastCheckSubscribeAt(int? topicId, {int? timeAt, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    var data = await TopicStorage.instance.setData(topicId, {
      "last_check_subscribe_at": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setLastCheckSubscribeAt - timeAt:$timeAt - new:$data - topicId:$topicId");
    return data != null;
  }

  // TODO:GG call
  Future<bool> setLastRefreshSubscribersAt(int? topicId, {int? timeAt, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    var data = await TopicStorage.instance.setData(topicId, {
      "last_refresh_subscribers_at": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    logger.d("$TAG - setLastRefreshSubscribersAt - timeAt:$timeAt - new:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  // TODO:GG call
  Future<bool> setStatusProgressStart(int? topicId, bool subscribe, int? nonce, double fee, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
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
    logger.d("$TAG - setStatusProgressStart - added:$added - removeKeys:$removeKeys - new:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  // TODO:GG call
  Future<bool> setStatusProgressEnd(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    var data = await TopicStorage.instance.setData(topicId, null, removeKeys: [
      "subscribe_progress",
      "unsubscribe_progress",
      "progress_subscribe_nonce",
      "progress_subscribe_fee",
    ]);
    logger.d("$TAG - setStatusProgressEnd - removeKeys:${["subscribe_progress", "unsubscribe_progress", "progress_subscribe_nonce", "progress_subscribe_fee"]} - new:$data - topicId:$topicId");
    if ((data != null) && notify) queryAndNotify(topicId);
    return data != null;
  }

  Future queryAndNotify(int? topicId) async {
    if (topicId == null || topicId == 0) return;
    TopicSchema? updated = await query(topicId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
