import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class TopicCommon with Tag {
  TopicStorage _topicStorage = TopicStorage();

  StreamController<TopicSchema> _addController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _addSink => _addController.sink;
  Stream<TopicSchema> get addStream => _addController.stream;

  // StreamController<String> _deleteController = StreamController<String>.broadcast();
  // StreamSink<String> get _deleteSink => _deleteController.sink;
  // Stream<String> get deleteStream => _deleteController.stream;

  StreamController<TopicSchema> _updateController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _updateSink => _updateController.sink;
  Stream<TopicSchema> get updateStream => _updateController.stream;

  TopicCommon();

  close() {
    _addController.close();
    // _deleteController.close();
    _updateController.close();
  }

  Future checkAllTopics({bool refreshSubscribers = true, bool enablePublic = true, bool enablePrivate = true}) async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty) return;
    List<TopicSchema> topics = await queryList();
    List<Future> futures = [];
    topics.forEach((TopicSchema topic) {
      if (!topic.isPrivate && enablePublic) {
        futures.add(checkExpireAndSubscribe(topic.topic, refreshSubscribers: refreshSubscribers && topic.joined));
      } else if (topic.isPrivate && enablePrivate) {
        futures.add(checkExpireAndSubscribe(topic.topic, refreshSubscribers: refreshSubscribers && topic.joined));
      }
    });
    await Future.wait(futures);
  }

  // Future checkAllTopics({
  //   bool refreshSubscribers = true,
  //   bool enablePublic = true,
  //   bool enablePrivate = true,
  //   int intervalMs = 0,
  //   List<TopicSchema>? topics,
  //   int index = 0,
  // }) async {
  //   if (clientCommon.address == null || clientCommon.address!.isEmpty) return;
  //   topics = topics ?? await queryList();
  //   if (topics.isEmpty || (index >= topics.length && index >= 0)) {
  //     logger.i("$TAG - checkAllTopics - check all over - count:${topics.length}");
  //     return;
  //   } else {
  //     logger.i("$TAG - checkAllTopics - check progress - progress:${index + 1}/${topics.length} - topic:${topics[index].topic}");
  //   }
  //   TopicSchema topic = topics[index];
  //   await Future.delayed(Duration(milliseconds: intervalMs ~/ 2));
  //   if (!topic.isPrivate && enablePublic) {
  //     await checkExpireAndSubscribe(topic.topic, refreshSubscribers: refreshSubscribers);
  //   } else if (topic.isPrivate && enablePrivate) {
  //     await checkExpireAndSubscribe(topic.topic, refreshSubscribers: refreshSubscribers);
  //   }
  //   await Future.delayed(Duration(milliseconds: intervalMs ~/ 2));
  //   // loop
  //   checkAllTopics(
  //     intervalMs: intervalMs,
  //     refreshSubscribers: refreshSubscribers,
  //     enablePublic: enablePublic,
  //     enablePrivate: enablePrivate,
  //     topics: topics,
  //     index: ++index,
  //   );
  // }

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = self(owner/normal)
  Future<TopicSchema?> subscribe(String? topicName, {bool skipPermission = false, double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;

    // topic exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null) {
      int expireHeight = await getExpireAtByNode(topicName, clientCommon.address);
      exists = await add(TopicSchema.create(topicName, expireHeight: expireHeight), notify: true, checkDuplicated: false);
      logger.d("$TAG - subscribe - new - expireHeight:$expireHeight - schema:$exists");
      // refreshSubscribers later
    }
    if (exists == null) {
      logger.w("$TAG - subscribe - null - topicName:$topicName");
      return null;
    }

    // subscriber me
    SubscriberSchema? _subscriberMe = await subscriberCommon.queryByTopicChatId(topicName, clientCommon.address);
    if (_subscriberMe?.status == SubscriberStatus.Unsubscribed) {
      int updateAt = _subscriberMe?.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - updateAt) < Global.txPoolDelayMs) {
        Toast.show(S.of(Global.appContext).left_group_tip);
        return null;
      }
    }

    // permission(private + normal)
    int? permPage;
    if (exists.isPrivate && !exists.isOwner(clientCommon.address)) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicName, exists.isPrivate, clientCommon.address);
      permPage = permission[0];
      bool? acceptAll = permission[1];
      bool? isAccept = permission[2];
      bool? isReject = permission[3];
      if (skipPermission) {
        logger.d("$TAG - subscribe - skipPermission - schema:$exists");
      } else {
        if ((acceptAll != true)) {
          if (isReject == true) {
            Toast.show(S.of(Global.appContext).removed_group_tip);
            return null;
          } else if (isAccept != true) {
            Toast.show(S.of(Global.appContext).contact_invite_group_tip);
            return null;
          } else {
            logger.d("$TAG - subscribe - is_accept ok - schema:$exists");
          }
        } else {
          logger.d("$TAG - subscribe - accept all - schema:$exists");
        }
      }
    }

    // check expire + pull subscribers
    bool historyJoined = exists.joined;
    exists = await checkExpireAndSubscribe(topicName, enableFirst: true, forceSubscribe: true, refreshSubscribers: true, fee: fee);
    if (exists == null) {
      Toast.show(S.of(Global.appContext).failure);
      return null;
    }
    await Future.delayed(Duration(seconds: 1));

    // status + permission
    if (exists.isPrivate && exists.isOwner(clientCommon.address)) {
      // private + owner
      _subscriberMe = await subscriberCommon.onSubscribe(topicName, clientCommon.address, 0);
      Map<String, dynamic> meta = await _getMetaByNodePage(topicName, 0);
      meta = await _buildMetaByAppend(topicName, meta, _subscriberMe);
      bool permissionSuccess = await _clientSubscribe(topicName, fee: fee, permissionPage: 0, meta: meta, toast: true);
      if (!permissionSuccess) {
        logger.w("$TAG - subscribe - owner subscribe permission fail - topic:$exists");
        // await subscriberCommon.deleteByTopic(exists.topic);
        if (!historyJoined) {
          // need delete by subscribed first when permission push
          await delete(exists.id, notify: true);
        }
        return null;
      }
    } else {
      // public / private + normal
      _subscriberMe = await subscriberCommon.onSubscribe(topicName, clientCommon.address, permPage);
    }
    await Future.delayed(Duration(seconds: 1));

    // send messages
    await chatOutCommon.sendTopicSubscribe(topicName);
    await setCount(exists.id, (exists.count ?? 0) + 1, notify: true);
    return exists;
  }

  // caller = self(owner/normal)
  Future<TopicSchema?> checkExpireAndSubscribe(
    String? topicName, {
    bool refreshSubscribers = false,
    bool forceSubscribe = false,
    bool enableFirst = false,
    double fee = 0,
    int tryCount = 1,
  }) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;

    // topic exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null) {
      logger.w("$TAG - checkExpireAndSubscribe - null - topicName:$topicName");
      return null;
    }

    // check expire
    bool noSubscribed;
    int expireHeight = await getExpireAtByNode(exists.topic, clientCommon.address);
    if (!exists.joined || exists.subscribeAt == null || exists.subscribeAt! <= 0 || exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0) {
      if (expireHeight > 0) {
        // DB no joined + node is joined
        noSubscribed = false;
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if ((DateTime.now().millisecondsSinceEpoch - createAt) > Global.txPoolDelayMs) {
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
        noSubscribed = true;
        logger.i("$TAG - checkExpireAndSubscribe - no subscribe history - topic:$exists");
      }
    } else {
      if (expireHeight <= 0) {
        // DB is joined + node no joined
        noSubscribed = true;
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if (exists.joined && (DateTime.now().millisecondsSinceEpoch - createAt) > Global.txPoolDelayMs) {
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
    int? globalHeight = await clientCommon.client?.getHeight();
    bool shouldResubscribe = await exists.shouldResubscribe(globalHeight: globalHeight);
    if (forceSubscribe || (noSubscribed && enableFirst) || (exists.joined && shouldResubscribe)) {
      // client subscribe
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: fee);
      if (!subscribeSuccess) {
        if (tryCount >= (Global.txPoolDelayMs / (5 * 1000))) {
          logger.e("$TAG - checkExpireAndSubscribe - _clientSubscribe fail - topic:$exists");
          return null;
        }
        logger.w("$TAG - checkExpireAndSubscribe - _clientSubscribe fail - topic:$exists - tryCount:$tryCount");
        await Future.delayed(Duration(seconds: 5));
        return checkExpireAndSubscribe(topicName, refreshSubscribers: refreshSubscribers, forceSubscribe: forceSubscribe, enableFirst: enableFirst, fee: fee, tryCount: ++tryCount);
      }

      // db update
      var subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      var expireHeight = (globalHeight ?? exists.expireBlockHeight ?? 0) + Global.topicDefaultSubscribeHeight;
      bool setSuccess = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
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
      await subscriberCommon.refreshSubscribers(topicName, meta: exists.isPrivate);
    }
    return exists;
  }

  // publish(meta = null) / private(meta != null)(owner_create / invitee / kick)
  Future<bool> _clientSubscribe(String? topicName, {double fee = 0, int? permissionPage, Map<String, dynamic>? meta, int? nonce, bool toast = false}) async {
    if (topicName == null || topicName.isEmpty) return false;
    String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";
    nonce = nonce ?? await Global.getNonce();

    bool success;
    try {
      String? topicHash = await clientCommon.client?.subscribe(
        topic: genTopicHash(topicName),
        duration: Global.topicDefaultSubscribeHeight,
        fee: fee.toString(),
        identifier: identifier,
        meta: metaString,
        nonce: nonce,
      );
      if (topicHash != null && topicHash.isNotEmpty) {
        logger.d("$TAG - _clientSubscribe - success - topicName:$topicName - nonce:$nonce - topicHash:$topicHash - identifier:$identifier - metaString:$metaString");
      } else {
        logger.e("$TAG - _clientSubscribe - fail - topicName:$topicName - nonce:$nonce - identifier:$identifier - metaString:$metaString");
      }
      success = (topicHash != null) && (topicHash.isNotEmpty);
    } catch (e) {
      if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        int? nonce = await Global.getNonce(forceFetch: true);
        return _clientSubscribe(topicName, fee: fee, permissionPage: permissionPage, meta: meta, nonce: nonce, toast: toast);
      } else {
        await Global.refreshNonce();
        if (e.toString().contains('duplicate subscription exist in block')) {
          // can not append tx to txpool: duplicate subscription exist in block
          logger.i("$TAG - _clientSubscribe - duplicated - nonce:$nonce - identifier:$identifier - metaString:$metaString");
          if (toast) Toast.show(S.of(Global.appContext).request_processed);
        } else {
          handleError(e);
        }
        success = false;
      }
    }
    return success;
  }

  /// ***********************************************************************************************************
  /// ********************************************** unsubscribe ************************************************
  /// ***********************************************************************************************************

  // caller = self
  Future<TopicSchema?> unsubscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    // permission modify in owners message received by owner

    // client unsubscribe
    bool exitSuccess = await _clientUnsubscribe(topicName, fee: fee, toast: true);
    if (!exitSuccess) return null;
    await Future.delayed(Duration(seconds: 1));

    // topic update
    TopicSchema? exists = await queryByTopic(topicName);
    bool setSuccess = await setJoined(exists?.id, false, notify: true);
    if (setSuccess) {
      exists?.joined = false;
      exists?.subscribeAt = 0;
      exists?.expireBlockHeight = 0;
    }
    // setSuccess = await setCount(exists?.id, (exists?.count ?? 1) - 1, notify: true);
    // if (setSuccess) exists?.count = (exists.count ?? 1) - 1;

    // DB(topic+subscriber) delete
    await subscriberCommon.onUnsubscribe(topicName, clientCommon.address);
    // await subscriberCommon.deleteByTopic(topicName); // stay is useful
    // await delete(exists?.id, notify: true); // replace by setJoined

    // send message
    await chatOutCommon.sendTopicUnSubscribe(topicName);
    await Future.delayed(Duration(seconds: 1));
    return exists;
  }

  Future<bool> _clientUnsubscribe(String? topicName, {double fee = 0, int? nonce, bool toast = false}) async {
    if (topicName == null || topicName.isEmpty) return false;
    // String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";
    nonce = nonce ?? await Global.getNonce();

    bool success;
    try {
      String? topicHash = await clientCommon.client?.unsubscribe(
        topic: genTopicHash(topicName),
        identifier: "", // no used (maybe will be used by owner later)
        fee: fee.toString(),
        nonce: nonce,
      );
      if (topicHash != null && topicHash.isNotEmpty) {
        logger.d("$TAG - _clientUnsubscribe - success - topicName:$topicName - nonce:$nonce - topicHash:$topicHash");
      } else {
        logger.e("$TAG - _clientUnsubscribe - fail - topicName:$topicName - nonce:$nonce - topicHash:$topicHash");
      }
      success = (topicHash != null) && (topicHash.isNotEmpty);
    } catch (e) {
      if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        int? nonce = await Global.getNonce(forceFetch: true);
        return _clientUnsubscribe(topicName, fee: fee, nonce: nonce, toast: toast);
      } else {
        await Global.refreshNonce();
        if (e.toString().contains('duplicate subscription exist in block')) {
          // can not append tx to txpool: duplicate subscription exist in block
          logger.i("$TAG - _clientUnsubscribe - duplicated - nonce:$nonce");
          if (toast) Toast.show(S.of(Global.appContext).request_processed);
        } else {
          handleError(e);
        }
        success = false;
      }
    }
    return success;
  }

  /// ***********************************************************************************************************
  /// ********************************************** subscription ***********************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<bool> isJoined(String? topicName, String? clientAddress, {int? globalHeight}) async {
    if (topicName == null || topicName.isEmpty) return false;
    TopicSchema? exists = await queryByTopic(topicName);
    int createAt = exists?.createAt ?? DateTime.now().millisecondsSinceEpoch;
    if (exists != null && (DateTime.now().millisecondsSinceEpoch - createAt) < Global.txPoolDelayMs) {
      logger.i("$TAG - isJoined - createAt just now, maybe in txPool - topicName:$topicName - clientAddress:$clientAddress");
      return exists.joined; // maybe in txPool
    }
    int expireHeight = await getExpireAtByNode(exists?.topic, clientAddress);
    if (expireHeight <= 0) {
      logger.i("$TAG - isJoined - expireHeight <= 0 - topicName:$topicName - clientAddress:$clientAddress");
      return false;
    }
    globalHeight = globalHeight ?? await clientCommon.client?.getHeight();
    if (globalHeight == null || globalHeight <= 0) {
      logger.w("$TAG - isJoined - globalHeight <= 0 - topicName:$topicName");
      return false;
    }
    return expireHeight >= globalHeight;
  }

  Future<int> getExpireAtByNode(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
    Map<String, dynamic> result = await _clientGetSubscription(topicName, pubKey);
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    return int.tryParse(expiresAt) ?? 0;
  }

  Future<Map<String, dynamic>> _getMetaByNodePage(String? topicName, int permPage) async {
    if (topicName == null || topicName.isEmpty) return Map();
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topicName);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic> result = await _clientGetSubscription(topicName, indexWithPubKey);
    if (result['meta']?.toString().isNotEmpty == true) {
      Map<String, dynamic> meta = jsonFormat(result['meta']) ?? Map();
      logger.d("$TAG - _getMetaByNodePage - meta:$meta");
      return meta;
    }
    logger.d("$TAG - _getMetaByNodePage - meta is null");
    return Map();
  }

  Future<Map<String, dynamic>> _clientGetSubscription(String? topicName, String? subscriber) async {
    if (topicName == null || topicName.isEmpty || subscriber == null || subscriber.isEmpty) return Map();
    Map<String, dynamic>? result = await clientCommon.client?.getSubscription(
      topic: genTopicHash(topicName),
      subscriber: subscriber,
    );
    if (result?.isNotEmpty == true) {
      logger.d("$TAG - _clientGetSubscription - success - topicName:$topicName - subscriber:$subscriber - result:$result");
    } else {
      logger.w("$TAG - _clientGetSubscription - fail - topicName:$topicName - subscriber:$subscriber");
    }
    return result ?? Map();
  }

  /// ***********************************************************************************************************
  /// ************************************************ action ***************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> invitee(String? topicName, bool isPrivate, bool isOwner, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    if (clientAddress == clientCommon.address) {
      Toast.show(S.of(Global.appContext).invite_yourself_error);
      return null;
    }
    if (isPrivate && !isOwner) {
      Toast.show(S.of(Global.appContext).member_no_auth_invite);
      return null;
    }

    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (_subscriber != null && _subscriber.status == SubscriberStatus.Subscribed) {
      Toast.show(S.of(Global.appContext).group_member_already);
      return null;
    }

    // check permission
    int? appendPermPage;
    bool? acceptAll = false;
    if (isPrivate) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicName, isPrivate, clientAddress);
      appendPermPage = permission[0] ?? (await subscriberCommon.queryMaxPermPageByTopic(topicName));
      acceptAll = permission[1];
      bool? isReject = permission[3];
      if ((acceptAll != true) && !isOwner && (isReject == true)) {
        // just owner can invitee reject item
        Toast.show(S.of(Global.appContext).blocked_user_disallow_invite);
        return null;
      }
    }

    // update DB
    _subscriber = await subscriberCommon.onInvitedSend(topicName, clientAddress, appendPermPage);
    if (_subscriber == null) return null;

    // update meta (private + owner + no_accept_all)
    if (isPrivate && isOwner && (acceptAll != true) && (appendPermPage != null)) {
      Map<String, dynamic> meta = await _getMetaByNodePage(topicName, appendPermPage);
      meta = await _buildMetaByAppend(topicName, meta, _subscriber);
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: appendPermPage, meta: meta, toast: true);
      if (!subscribeSuccess) {
        logger.w("$TAG - invitee - clientSubscribe error - permPage:$appendPermPage - meta:$meta");
        await subscriberCommon.delete(_subscriber.id, notify: true);
        return null;
      }
    }

    // send message
    MessageSchema? _msg = await chatOutCommon.sendTopicInvitee(clientAddress, topicName);
    if (_msg == null) return null;
    Toast.show(S.of(Global.appContext).invitation_sent);
    return _subscriber;
  }

  // caller = private + owner
  Future<SubscriberSchema?> kick(String? topicName, bool isPrivate, bool isOwner, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    if (clientAddress == clientCommon.address) return null;
    if (!isPrivate || !isOwner) return null; // enable just private + owner

    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    int? oldStatus = _subscriber?.status;
    if (_subscriber == null) return null;
    if (_subscriber.canBeKick == false) return null; // checked in UI

    // check permission
    List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicName, isPrivate, clientAddress);
    int? permPage = permission[0] ?? _subscriber.permPage;
    bool? acceptAll = permission[1];
    if (permPage == null) {
      Toast.show(S.of(Global.appContext).failure);
      return null;
    }

    // update DB
    _subscriber = await subscriberCommon.onKickOut(topicName, clientAddress, permPage: permPage);
    if (_subscriber == null) return null;

    // update meta (private + owner + no_accept_all)
    if (acceptAll != true) {
      Map<String, dynamic> meta = await _getMetaByNodePage(topicName, permPage);
      meta = await _buildMetaByAppend(topicName, meta, _subscriber);
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: permPage, meta: meta, toast: true);
      if (!subscribeSuccess) {
        logger.w("$TAG - kick - clientSubscribe error - permPage:$permPage - meta:$meta");
        _subscriber.status = oldStatus;
        await subscriberCommon.setStatus(_subscriber.id, _subscriber.status, notify: true);
        return null;
      }
    }

    // send message
    await chatOutCommon.sendTopicKickOut(topicName, clientAddress);
    Toast.show(S.of(Global.appContext).rejected);
    return _subscriber;
  }

  Future<Map<String, dynamic>> _buildMetaByAppend(String? topicName, Map<String, dynamic> meta, SubscriberSchema? append) async {
    if (topicName == null || topicName.isEmpty || append == null) return Map();
    // permPage
    if ((append.permPage ?? -1) <= 0) {
      append.permPage = (await subscriberCommon.findPermissionFromNode(topicName, true, append.clientAddress))[0] ?? 0;
    }

    // node meta
    List<dynamic> acceptList = meta['accept'] ?? [];
    List<dynamic> rejectList = meta['reject'] ?? [];
    if (append.status == SubscriberStatus.InvitedSend || append.status == SubscriberStatus.InvitedReceipt || append.status == SubscriberStatus.Subscribed) {
      // add to accepts
      rejectList = rejectList.where((element) => !element.toString().contains(append.clientAddress)).toList();
      if (acceptList.where((element) => element.toString().contains(append.clientAddress)).toList().isEmpty) {
        acceptList.add({'addr': append.clientAddress});
      }
    } else if (append.status == SubscriberStatus.Unsubscribed) {
      // add to rejects
      acceptList = acceptList.where((element) => !element.toString().contains(append.clientAddress)).toList();
      if (rejectList.where((element) => element.toString().contains(append.clientAddress)).toList().isEmpty) {
        rejectList.add({'addr': append.clientAddress});
      }
    } else {
      // remove from all
      acceptList = acceptList.where((element) => !element.toString().contains(append.clientAddress)).toList();
      rejectList = rejectList.where((element) => !element.toString().contains(append.clientAddress)).toList();
    }

    // DB meta (maybe in txPool)
    List<SubscriberSchema> subscribers = await subscriberCommon.queryListByTopicPerm(topicName, append.permPage);
    subscribers.forEach((SubscriberSchema element) {
      if (element.clientAddress.isNotEmpty == true && element.clientAddress != append.clientAddress) {
        int updateAt = element.updateAt ?? DateTime.now().millisecondsSinceEpoch;
        if ((DateTime.now().millisecondsSinceEpoch - updateAt) < Global.txPoolDelayMs) {
          logger.i("$TAG - _buildMetaByAppend - subscriber update just now, maybe in txPool - element:$element");
          if (element.status == SubscriberStatus.InvitedSend || element.status == SubscriberStatus.InvitedReceipt || element.status == SubscriberStatus.Subscribed) {
            // add to accepts
            rejectList = rejectList.where((e) => !e.toString().contains(element.clientAddress)).toList();
            if (acceptList.where((e) => e.toString().contains(element.clientAddress)).toList().isEmpty) {
              acceptList.add({'addr': element.clientAddress});
            }
          } else if (element.status == SubscriberStatus.Unsubscribed) {
            // add to rejects
            acceptList = acceptList.where((e) => !e.toString().contains(element.clientAddress)).toList();
            if (rejectList.where((e) => e.toString().contains(element.clientAddress)).toList().isEmpty) {
              rejectList.add({'addr': element.clientAddress});
            }
          } else {
            // remove from all
            acceptList = acceptList.where((e) => !e.toString().contains(element.clientAddress)).toList();
            rejectList = rejectList.where((e) => !e.toString().contains(element.clientAddress)).toList();
          }
        } else {
          var betweenS = (DateTime.now().millisecondsSinceEpoch - updateAt) / 1000;
          logger.d("$TAG - _buildMetaByAppend - subscriber update to long - between:${betweenS}s - subscriber:$element");
        }
      }
    });

    // new meta
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;
    logger.d("$TAG - _buildMetaByAppend - permPage:${append.permPage} - meta:${meta.toString()}");
    return meta;
  }

  /// ***********************************************************************************************************
  /// *********************************************** callback **************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> onSubscribe(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // topic exist
    TopicSchema? _topic = await queryByTopic(topicName);
    if (_topic == null) {
      logger.w("$TAG - onSubscribe - null - topicName:$topicName");
      return null;
    }

    // TODO:GG 防止别人跳过permission订阅？但是老版本怎么办，暂时没好办法，因为缓存权限都在masters那里，node权限具有延迟性，没法参考

    // permission modify in invitee action by owner

    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onSubscribe(topicName, clientAddress, null);
    if (_subscriber == null) return null;

    // subscribers sync
    Future.delayed(Duration(seconds: 1), () {
      subscriberCommon.refreshSubscribers(topicName, meta: _topic.isPrivate);
    });
    return _subscriber;
  }

  // caller = everyone
  Future<SubscriberSchema?> onUnsubscribe(String? topicName, String? clientAddress, {int tryCount = 1}) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null; // || clientCommon.address == null || clientCommon.address!.isEmpty
    // topic exist
    TopicSchema? _topic = await topicCommon.queryByTopic(topicName);
    if (_topic == null) {
      logger.w("$TAG - onUnsubscribe - null - topicName:$topicName");
      return null;
    }

    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onUnsubscribe(topicName, clientAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onUnsubscribe - subscriber is null - topicName:$topicName - clientAddress:$clientAddress");
      return null;
    }

    // private + owner
    if (_topic.isPrivate && _topic.isOwner(clientCommon.address) && clientCommon.address != clientAddress) {
      List<dynamic> permission = await subscriberCommon.findPermissionFromNode(topicName, _topic.isPrivate, clientAddress);
      int? permPage = permission[0] ?? _subscriber.permPage;
      bool? acceptAll = permission[1];
      if (acceptAll == true) {
        // do nothing
      } else {
        if (permPage == null) {
          logger.w("$TAG - onUnsubscribe - permPage is null - permission:$permission");
          return null;
        } else {
          if (_subscriber.permPage != permPage) {
            await subscriberCommon.setPermPage(_subscriber.id, permPage, notify: true);
            _subscriber.permPage = permPage; // if (success)
          }
        }
        // meta update
        Map<String, dynamic> meta = await _getMetaByNodePage(topicName, permPage);
        _subscriber.status = SubscriberStatus.None;
        meta = await _buildMetaByAppend(topicName, meta, _subscriber);
        _subscriber.status = SubscriberStatus.Unsubscribed;
        bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: permPage, meta: meta);
        if (!subscribeSuccess) {
          if (tryCount >= (Global.txPoolDelayMs / (5 * 1000))) {
            logger.e("$TAG - onUnsubscribe - clientSubscribe error - permPage:$permPage - meta:$meta");
            return null;
          }
          logger.w("$TAG - onUnsubscribe - clientSubscribe error - permPage:$permPage - meta:$meta - tryCount:$tryCount");
          await Future.delayed(Duration(seconds: 5));
          return onUnsubscribe(topicName, clientAddress, tryCount: ++tryCount);
        }
      }
    }

    // owner unsubscribe
    if (_topic.isPrivate && _topic.isOwner(clientAddress)) {
      // do nothing now
    }

    // DB update (just node sync can delete)
    bool setSuccess = await setCount(_topic.id, (_topic.count ?? 1) - 1, notify: true);
    if (setSuccess) _topic.count = (_topic.count ?? 1) - 1;
    // await subscriberCommon.delete(_subscriber.id, notify: true);

    // subscribers sync
    Future.delayed(Duration(seconds: 1), () {
      subscriberCommon.refreshSubscribers(topicName, meta: _topic.isPrivate);
    });
    return _subscriber;
  }

  // caller = everyone
  Future<SubscriberSchema?> onKickOut(String? topicName, String? senderAddress, String? clientAddress, {int tryCount = 1}) async {
    if (topicName == null || topicName.isEmpty || senderAddress == null || senderAddress.isEmpty || clientAddress == null || clientAddress.isEmpty) return null; // || clientCommon.address == null || clientCommon.address!.isEmpty
    // topic exist
    TopicSchema? _topic = await topicCommon.queryByTopic(topicName);
    if (_topic == null) {
      logger.w("$TAG - onKickOut - null - topicName:$topicName");
      return null;
    } else if (!_topic.isOwner(senderAddress)) {
      logger.w("$TAG - onKickOut - sender error - topicName:$topicName - senderAddress:$senderAddress");
      return null;
    }

    // subscriber update
    SubscriberSchema? _subscriber = await subscriberCommon.onKickOut(topicName, clientAddress);
    if (_subscriber == null) {
      logger.w("$TAG - onKickOut - subscriber is null - topicName:$topicName - clientAddress:$clientAddress");
      return null;
    }

    // permission modify in kick action by owner

    // self unsubscribe
    if (clientAddress == clientCommon.address) {
      bool exitSuccess = await _clientUnsubscribe(topicName, fee: 0);
      if (!exitSuccess) {
        if (tryCount >= (Global.txPoolDelayMs / (5 * 1000))) {
          logger.e("$TAG - onKickOut - clientUnsubscribe error - topicName:$topicName - subscriber:$_subscriber");
          return null;
        }
        logger.w("$TAG - onKickOut - clientUnsubscribe error - topicName:$topicName - subscriber:$_subscriber - tryCount:$tryCount");
        await Future.delayed(Duration(seconds: 5));
        return onKickOut(topicName, senderAddress, clientAddress, tryCount: ++tryCount);
      }
      bool setSuccess = await setJoined(_topic.id, false, notify: true);
      if (setSuccess) {
        _topic.joined = false;
        _topic.subscribeAt = 0;
        _topic.expireBlockHeight = 0;
      }
      // DB update (just node sync can delete)
      // await subscriberCommon.deleteByTopic(topicName); // stay is useful
      // await delete(_topic.id, notify: true); // replace by setJoined
    } else {
      bool setSuccess = await setCount(_topic.id, (_topic.count ?? 1) - 1, notify: true);
      if (setSuccess) _topic.count = (_topic.count ?? 1) - 1;
      // await subscriberCommon.delete(_subscriber.id, notify: true);

      // subscribers sync
      Future.delayed(Duration(seconds: 1), () {
        subscriberCommon.refreshSubscribers(topicName, meta: _topic.isPrivate);
      });
    }
    return _subscriber;
  }

  /// ***********************************************************************************************************
  /// ************************************************* common **************************************************
  /// ***********************************************************************************************************

  Future<TopicSchema?> add(TopicSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.topic.isEmpty) return null;
    schema.type = schema.type ?? (isPrivateTopicReg(schema.topic) ? TopicType.privateTopic : TopicType.publicTopic);
    if (checkDuplicated) {
      TopicSchema? exist = await queryByTopic(schema.topic);
      if (exist != null) {
        logger.i("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    TopicSchema? added = await _topicStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  Future<bool> delete(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    TopicSchema? topic = await query(topicId);
    if (topic == null) return false;
    bool success = await _topicStorage.delete(topicId);
    // if (success && notify) _deleteSink.add(topic.topic);
    return success;
  }

  Future<TopicSchema?> query(int? topicId) {
    return _topicStorage.query(topicId);
  }

  Future<TopicSchema?> queryByTopic(String? topicName) async {
    if (topicName == null || topicName.isEmpty) return null;
    return await _topicStorage.queryByTopic(topicName);
  }

  Future<List<TopicSchema>> queryList({String? topicType, String? orderBy, int? offset, int? limit}) {
    return _topicStorage.queryList(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<List<TopicSchema>> queryListJoined({String? topicType, String? orderBy, int? offset, int? limit}) {
    return _topicStorage.queryListJoined(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<bool> setJoined(int? topicId, bool joined, {int? subscribeAt, int? expireBlockHeight, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setJoined(
      topicId,
      joined,
      subscribeAt: subscribeAt,
      expireBlockHeight: expireBlockHeight,
      createAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setAvatar(int? topicId, String? avatarLocalPath, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setAvatar(topicId, avatarLocalPath);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setCount(int? topicId, int? count, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setCount(topicId, count ?? 0);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setTop(int? topicId, bool top, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setTop(topicId, top);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future queryAndNotify(int? topicId) async {
    if (topicId == null || topicId == 0) return;
    TopicSchema? updated = await query(topicId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
