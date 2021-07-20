import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../locator.dart';

class TopicCommon with Tag {
  TopicStorage _topicStorage = TopicStorage();

  StreamController<TopicSchema> _addController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _addSink => _addController.sink;
  Stream<TopicSchema> get addStream => _addController.stream;

  StreamController<int> _deleteController = StreamController<int>.broadcast();
  StreamSink<int> get _deleteSink => _deleteController.sink;
  Stream<int> get deleteStream => _deleteController.stream;

  StreamController<TopicSchema> _updateController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _updateSink => _updateController.sink;
  Stream<TopicSchema> get updateStream => _updateController.stream;

  TopicCommon();

  close() {
    _addController.close();
    _deleteController.close();
    _updateController.close();
  }

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<TopicSchema?> subscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return null;
    // subscribe/expire
    TopicSchema? _topic = await checkExpireAndSubscribe(topicName, subscribeFirst: true, emptyAdd: true);
    if (_topic == null) return null;

    // message_subscribe
    int subscribeAt = _topic.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
    if (_topic.joined && (DateTime.now().millisecondsSinceEpoch - subscribeAt).abs() < 1000 * 60) {
      await chatOutCommon.sendTopicSubscribe(topicName);
    }

    // subscribers_check
    await subscriberCommon.onSubscribe(topicName, clientCommon.address);
    if (_topic.isPrivate) {
      await subscriberCommon.refreshSubscribers(topicName, meta: true);
    } else {
      await subscriberCommon.refreshSubscribers(topicName, meta: false);
    }

    await Future.delayed(Duration(seconds: 2));
    return _topic;
  }

  // caller = everyone
  Future<TopicSchema?> checkExpireAndSubscribe(String? topicName, {bool subscribeFirst = false, bool emptyAdd = false, double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // topic exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null && emptyAdd) {
      logger.d("$TAG - checkExpireAndSubscribe - new - schema:$exists");
      exists = await add(TopicSchema.create(topicName), notify: true, checkDuplicated: false);
    }
    if (exists == null) {
      logger.w("$TAG - checkExpireAndSubscribe - null - topicName:$topicName");
      return null;
    }

    // empty height
    bool noSubscribed = false;
    if (!exists.joined || exists.subscribeAt == null || exists.subscribeAt! <= 0 || exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0) {
      if (exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0) {
        if (!subscribeFirst) {
          logger.i("$TAG - checkExpireAndSubscribe - can not subscribeFirst - topic:$exists");
          return null;
        }
      }
      int subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      int expireHeight = await _getExpireAt(topicName, clientCommon.address);
      if (expireHeight > 0) {
        // sync node info
        bool success = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
        if (success) {
          exists.joined = true;
          exists.subscribeAt = subscribeAt;
          exists.expireBlockHeight = expireHeight;
        }
      } else {
        // no subscribe history
        noSubscribed = true;
      }
    }

    // check expire
    int? globalHeight = await clientCommon.client?.getHeight();
    if (noSubscribed || (await exists.shouldResubscribe(globalHeight: globalHeight))) {
      bool subscribeSuccess;
      if (exists.isOwner(clientCommon.address)) {
        // private + owner
        SubscriberSchema? _subscriberMe = await subscriberCommon.onSubscribe(topicName, clientCommon.address, permPage: 0);
        Map<String, dynamic> meta = await subscriberCommon.getPermissionsMetaByPage(topicName, _subscriberMe, appendPermPage: 0);
        subscribeSuccess = await clientSubscribe(
          topicName,
          height: Global.topicDefaultSubscribeHeight,
          fee: fee,
          permissionPage: 0,
          meta: meta,
        );
      } else {
        // publish / private normal member
        subscribeSuccess = await clientSubscribe(
          topicName,
          height: Global.topicDefaultSubscribeHeight,
          fee: fee,
        );
      }
      if (!subscribeSuccess) return null;

      // db update
      var subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
      var expireHeight = (globalHeight ?? exists.expireBlockHeight ?? 0) + Global.topicDefaultSubscribeHeight;
      bool setSuccess = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
      if (setSuccess) {
        exists.joined = true;
        exists.subscribeAt = subscribeAt;
        exists.expireBlockHeight = expireHeight;
      }
    }
    return exists;
  }

  Future<bool> clientSubscribe(String? topicName, {int? height, double fee = 0, int? permissionPage, Map<String, dynamic>? meta}) async {
    if (topicName == null || topicName.isEmpty) return false;
    String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";

    bool success;
    try {
      String? topicHash = await clientCommon.client?.subscribe(
        topic: genTopicHash(topicName),
        duration: height ?? Global.topicDefaultSubscribeHeight,
        fee: fee.toString(),
        identifier: identifier,
        meta: metaString,
      );
      if (topicHash != null && topicHash.isNotEmpty) {
        logger.d("$TAG - _clientSubscribe - success - topicHash:$topicHash");
      } else {
        logger.e("$TAG - _clientSubscribe - fail - topicHash:$topicHash");
      }
      success = (topicHash != null) && (topicHash.isNotEmpty);
    } catch (e) {
      if (e.toString().contains('duplicate subscription exist in block')) {
        success = true;
      } else {
        success = false;
      }
    }
    return success;
  }

  /// ***********************************************************************************************************
  /// ************************************************ members **************************************************
  /// ***********************************************************************************************************

  // caller = owner
  Future<SubscriberSchema?> invitee(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) {
      Toast.show(S.of(Global.appContext).invite_yourself_error);
      return null;
    }

    // topic owner
    TopicSchema? _topic = await queryByTopic(topicName);
    if (_topic == null) return null;
    if (_topic.isOwner(clientCommon.address) != true) {
      Toast.show(S.of(Global.appContext).member_no_auth_invite);
      return null;
    }

    // subscriber status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (_subscriber != null && _subscriber.isSubscribed == true) {
      Toast.show(S.of(Global.appContext).group_member_already);
      return null;
    }

    // send message
    MessageSchema? _msg = await chatOutCommon.sendTopicInvitee(clientAddress, topicName);
    if (_msg == null) return null;

    // subscriber update
    int appendPermPage = await subscriberCommon.queryMaxPermPageByTopic(topicName);
    _subscriber = await subscriberCommon.onInvitedSend(topicName, clientAddress, permPage: appendPermPage);
    if (_subscriber == null) return null;

    // client subscribe
    Map<String, dynamic> meta = await subscriberCommon.getPermissionsMetaByPage(topicName, _subscriber, appendPermPage: appendPermPage);
    bool subscribeSuccess = await clientSubscribe(
      topicName,
      height: Global.topicDefaultSubscribeHeight,
      fee: 0,
      permissionPage: appendPermPage,
      meta: meta,
    );
    if (subscribeSuccess) {
      Toast.show(S.of(Global.appContext).invitation_sent);
      return _subscriber;
    } else {
      await subscriberCommon.delete(_subscriber.id, notify: true);
      return null;
    }
  }

  // caller = owner
  Future<SubscriberSchema?> kick(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) return null;

    // topic owner
    TopicSchema? _topic = await queryByTopic(topicName);
    if (_topic == null) return null;
    if (_topic.isOwner(clientCommon.address) != true) return null;

    // subscriber status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (_subscriber == null) return null;
    if (_subscriber.canBeKick == false) return null;

    // permPage find
    int? permPage = _subscriber.permPage;
    Completer completer = Completer();
    if (permPage == null || permPage < 0) {
      int maxPermPage = await subscriberCommon.queryMaxPermPageByTopic(topicName);
      for (int i = 0; i <= maxPermPage; i++) {
        Map<String, dynamic> meta = await _getMeta(topicName, i);
        // find in accepts
        List<dynamic> accepts = meta["accept"] ?? [];
        accepts.forEach((element) {
          if (permPage == null || permPage! <= 0) {
            if (element.toString().contains(clientAddress)) {
              permPage = i;
              if (!completer.isCompleted) completer.complete();
            }
          }
        });
        // find in rejects
        List<dynamic> rejects = meta["reject"] ?? [];
        rejects.forEach((element) {
          if (permPage == null || permPage! <= 0) {
            if (element.toString().contains(clientAddress)) {
              permPage = i;
              if (!completer.isCompleted) completer.complete();
            }
          }
        });
      }
    }
    await completer.future;

    // meta update
    if (permPage != null) {
      Map<String, dynamic> meta = await _getMeta(topicName, permPage!);
      // remove at accept
      int? findAcceptIndex;
      List<dynamic> accepts = meta["accept"] ?? [];
      accepts.asMap().forEach((key, value) {
        if (findAcceptIndex == null) {
          if (value.toString().contains(clientAddress)) {
            findAcceptIndex = key;
          }
        }
      });
      if (findAcceptIndex != null) accepts.removeAt(findAcceptIndex!);
      // add in reject
      int? findRejectIndex;
      List<dynamic> rejects = meta["reject"] ?? [];
      rejects.asMap().forEach((key, value) {
        if (findRejectIndex == null) {
          if (value.toString().contains(clientAddress)) {
            findRejectIndex = key;
          }
        }
      });
      if (findRejectIndex == null) rejects.add({'addr': clientAddress});

      meta["accept"] = accepts;
      meta["reject"] = rejects;
      bool subscribeSuccess = await clientSubscribe(
        topicName,
        height: Global.topicDefaultSubscribeHeight,
        fee: 0,
        permissionPage: permPage,
        meta: meta,
      );
      if (!subscribeSuccess) {
        logger.w("$TAG - kick - clientSubscribe error - permPage:$permPage - meta:$meta");
        return null;
      }
    }

    // subscriber update
    return await subscriberCommon.onUnsubscribe(topicName, clientAddress, permPage: _subscriber.permPage);
  }

  /// ***********************************************************************************************************
  /// ********************************************** unsubscribe ************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<TopicSchema?> unsubscribe(String? topicName, {double fee = 0, int? permissionPage, bool deleteDB = false}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // client unsubscribe
    bool exitSuccess = await _clientUnsubscribe(topicName, fee: fee, permissionPage: permissionPage);
    if (!exitSuccess) return null;

    // message unsubscribe
    await chatOutCommon.sendTopicUnSubscribe(topicName);

    // schema refresh
    TopicSchema? exists = await queryByTopic(topicName);
    bool setSuccess = await setJoined(exists?.id, false, notify: true);
    if (setSuccess) exists?.joined = false;

    // DB delete
    if (deleteDB) await delete(exists?.id, notify: true);
    if (deleteDB) await subscriberCommon.deleteByTopic(topicName);

    await Future.delayed(Duration(seconds: 2));
    return exists;
  }

  Future<bool> _clientUnsubscribe(String? topicName, {double fee = 0, int? permissionPage}) async {
    if (topicName == null || topicName.isEmpty) return false;
    String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";

    bool success;
    try {
      String? topicHash = await clientCommon.client?.unsubscribe(
        topic: genTopicHash(topicName),
        identifier: identifier,
        fee: fee.toString(),
      );
      if (topicHash != null && topicHash.isNotEmpty) {
        logger.d("$TAG - _clientUnsubscribe - success - topicHash:$topicHash");
      } else {
        logger.e("$TAG - _clientUnsubscribe - fail - topicHash:$topicHash");
      }
      success = (topicHash != null) && (topicHash.isNotEmpty);
    } catch (e) {
      if (e.toString().contains('duplicate subscription exist in block') || e.toString().contains('can not append tx to txpool')) {
        success = true;
      } else {
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
    int expireHeight = await _getExpireAt(topicName, clientAddress);
    if (expireHeight <= 0) return false;
    globalHeight = globalHeight ?? await clientCommon.client?.getHeight();
    if (globalHeight == null || globalHeight <= 0) return false;
    // TODO:GG perm??? 踢出去之后怎么保证她不能加进来
    // TODO:GG (owner更新permission，node会自动处理subscribe？，然后所有的subscribers都走client，而不是DB)
    return expireHeight >= globalHeight;
  }

  // caller = owner
  Future refreshSubscribersByOwner(String? topicName, {bool allPermPage = false, int permPage = 0, int? maxPage}) async {
    if (topicName == null || topicName.isEmpty) return;
    Map<String, dynamic> meta = await _getMeta(topicName, permPage);
    maxPage = maxPage ?? await subscriberCommon.queryMaxPermPageByTopic(topicName);
    await subscriberCommon.refreshSubscribersByMeta(topicName, meta, permPage: permPage);
    if (allPermPage && permPage <= maxPage) {
      return refreshSubscribersByOwner(topicName, allPermPage: true, permPage: permPage++, maxPage: maxPage);
    }
    return;
  }

  Future<int> _getExpireAt(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
    Map<String, dynamic> result = await _clientGetSubscription(topicName, pubKey);
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    return int.tryParse(expiresAt) ?? 0;
  }

  Future<Map<String, dynamic>> _getMeta(String? topicName, int permPage) async {
    if (topicName == null || topicName.isEmpty) return Map();
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topicName);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic> result = await _clientGetSubscription(topicName, indexWithPubKey);
    if (result['meta']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? meta = jsonFormat(result['meta']);
      return meta ?? Map();
    }
    return Map();
  }

  Future<Map<String, dynamic>> _clientGetSubscription(String? topicName, String? subscriber) async {
    if (topicName == null || topicName.isEmpty || subscriber == null || subscriber.isEmpty) return Map();
    Map<String, dynamic>? result = await clientCommon.client?.getSubscription(
      topic: genTopicHash(topicName),
      subscriber: subscriber,
    );
    if (result?.isNotEmpty == true) {
      logger.d("$TAG - _clientGetSubscription - success - topicName:$topicName - subscriber:$subscriber - result:$result}");
    } else {
      logger.w("$TAG - _clientGetSubscription - fail - topicName:$topicName - subscriber:$subscriber");
    }
    return result ?? Map();
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
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    TopicSchema? added = await _topicStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  Future<bool> delete(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.delete(topicId);
    if (success && notify) _deleteSink.add(topicId);
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

  Future<bool> setJoined(int? topicId, bool joined, {int? subscribeAt, int? expireBlockHeight, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setJoined(
      topicId,
      joined,
      subscribeAt: subscribeAt ?? DateTime.now().millisecondsSinceEpoch,
      expireBlockHeight: expireBlockHeight,
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
