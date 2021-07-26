import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
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

  StreamController<String> _deleteController = StreamController<String>.broadcast();
  StreamSink<String> get _deleteSink => _deleteController.sink;
  Stream<String> get deleteStream => _deleteController.stream;

  StreamController<TopicSchema> _updateController = StreamController<TopicSchema>.broadcast();
  StreamSink<TopicSchema> get _updateSink => _updateController.sink;
  Stream<TopicSchema> get updateStream => _updateController.stream;

  TopicCommon();

  close() {
    _addController.close();
    _deleteController.close();
    _updateController.close();
  }

  checkAllTopics() async {
    if (clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    List<TopicSchema> topics = await queryList();
    topics.forEach((TopicSchema topic) async {
      // TODO:GG 测试续订
      await checkExpireAndPermission(topic.topic, subscribeFirst: false, emptyAdd: false);
    });
  }

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = self TODO:GG refactor
  Future<TopicSchema?> subscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    // check
    List<dynamic> info = await _findPermissionByMeta(topicName, clientCommon.address);
    int? permPage = info[0];
    bool? accept = info[1];
    if (accept == null || permPage == null) {
      Toast.show("无效的邀请"); // TODO:GG local invited
      return null;
    } else if (accept == false) {
      Toast.show("已被拒绝进入此群"); // TODO:GG local kick
      return null;
    }

    // subscribe/expire
    TopicSchema? _topic = await checkExpireAndPermission(topicName, enableFirst: true, emptyAdd: true);
    if (_topic == null) return null;

    // message_subscribe
    int subscribeAt = _topic.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
    if (_topic.joined && (DateTime.now().millisecondsSinceEpoch - subscribeAt).abs() < 1000 * 60) {
      await chatOutCommon.sendTopicSubscribe(topicName);
    }

    // subscribers_check (page used owner meta, not here)
    await subscriberCommon.onSubscribe(topicName, clientCommon.address, permPage);
    if (_topic.isPrivate) {
      await subscriberCommon.refreshSubscribers(topicName, meta: true);
    } else {
      await subscriberCommon.refreshSubscribers(topicName, meta: false);
    }

    await Future.delayed(Duration(seconds: 2));
    return _topic;
  }

  // caller = self TODO:GG refactor
  Future<List<dynamic>> checkExpireAndPermission(String? topicName, {bool enableFirst = false, bool emptyAdd = false, double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return [null, null];

    // topic exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null && emptyAdd) {
      logger.d("$TAG - checkExpireAndPermission - new - schema:$exists");
      exists = await add(TopicSchema.create(topicName), notify: true, checkDuplicated: false);
    }
    if (exists == null) {
      logger.w("$TAG - checkExpireAndPermission - null - topicName:$topicName");
      return [null, null];
    }

    // empty height
    bool noSubscribed;
    if (!exists.joined || exists.subscribeAt == null || exists.subscribeAt! <= 0 || exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0) {
      int expireHeight = await _getExpireAt(exists.topic, clientCommon.address);
      if (expireHeight > 0) {
        noSubscribed = false;
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if ((DateTime.now().millisecondsSinceEpoch - createAt).abs() > Settings.txPoolDelayMs) {
          logger.d("$TAG - checkExpireAndPermission - DB expire but node not expire - topic:$exists");
          int subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
          bool success = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
          if (success) {
            exists.joined = true;
            exists.subscribeAt = subscribeAt;
            exists.expireBlockHeight = expireHeight;
          }
        } else {
          logger.w("$TAG - checkExpireAndPermission - DB expire but node not expire, maybe in txPool - topic:$exists");
          return [null, false];
        }
      } else {
        noSubscribed = true;
        if (!enableFirst) {
          logger.i("$TAG - checkExpireAndPermission - enableFirst is false - topic:$exists");
          return [null, noSubscribed];
        } else {
          logger.d("$TAG - checkExpireAndPermission - no subscribe history - topic:$exists");
        }
      }
    } else {
      int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
      int expireHeight = await _getExpireAt(exists.topic, clientCommon.address);
      if (expireHeight <= 0) {
        noSubscribed = true;
        if (exists.joined && (DateTime.now().millisecondsSinceEpoch - createAt).abs() > Settings.txPoolDelayMs) {
          logger.i("$TAG - checkExpireAndPermission - db no expire but node expire - topic:$exists");
          bool success = await setJoined(exists.id, false, notify: true);
          if (success) exists.joined = false;
        } else {
          logger.d("$TAG - checkExpireAndPermission - DB not expire but node expire, maybe in txPool - topic:$exists");
        }
      } else {
        noSubscribed = false;
        logger.d("$TAG - checkExpireAndPermission - OK OK OK OK OK - topic:$exists");
      }
    }

    // check expire
    int? globalHeight = await clientCommon.client?.getHeight();
    bool shouldResubscribe = await exists.shouldResubscribe(globalHeight: globalHeight);
    if (noSubscribed || shouldResubscribe) {
      // client subscribe
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: fee);
      if (!subscribeSuccess) {
        logger.w("$TAG - checkExpireAndPermission - _clientSubscribe fail - topic:$exists");
        return [null, noSubscribed];
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

      // private + owner
      // TODO:GG check page++???
      if (exists.isOwner(clientCommon.address)) {
        SubscriberSchema? _subscriberMe = await subscriberCommon.onSubscribe(topicName, clientCommon.address, 0);
        Map<String, dynamic> meta = await _getMetaByPage(topicName, 0);
        meta = await _buildMetaByAppend(topicName, meta, _subscriberMe);
        bool permissionSuccess = await _clientSubscribe(topicName, fee: fee, permissionPage: 0, meta: meta);
        if (!permissionSuccess) {
          logger.w("$TAG - checkExpireAndPermission - _clientPermission fail - topic:$exists");
          return null;
        }
      }
    }
    return exists;
  }

  // publish(meta = null) / private(meta != null)(owner_create / invitee / kick)
  Future<bool> _clientSubscribe(String? topicName, {int? height, double fee = 0, int? permissionPage, Map<String, dynamic>? meta}) async {
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
  /// ********************************************** unsubscribe ************************************************
  /// ***********************************************************************************************************

  // caller = self TODO:GG refactor
  Future<TopicSchema?> unsubscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    // message unsubscribe (before client unsubscribe)
    await chatOutCommon.sendTopicUnSubscribe(topicName);
    await Future.delayed(Duration(seconds: 2));

    // TODO:GG 如果是群主，则需要把所有人的权限都清空

    // client unsubscribe
    bool exitSuccess = await _clientUnsubscribe(topicName, fee: fee);
    await Future.delayed(Duration(seconds: 1));
    if (!exitSuccess) return null;

    // schema refresh
    TopicSchema? exists = await queryByTopic(topicName);
    bool setSuccess = await setJoined(exists?.id, false, notify: true);
    if (setSuccess) exists?.joined = false;

    // DB delete
    await delete(exists?.id, notify: true);
    await subscriberCommon.deleteByTopic(topicName);
    return exists;
  }

  Future<bool> _clientUnsubscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return false;
    // String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";

    bool success;
    try {
      String? topicHash = await clientCommon.client?.unsubscribe(
        topic: genTopicHash(topicName),
        identifier: "", // no used (maybe will be used by owner later)
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

  // caller = everyone TODO:GG refactor
  Future<bool> isJoined(String? topicName, String? clientAddress, {int? globalHeight}) async {
    if (topicName == null || topicName.isEmpty) return false;
    TopicSchema? exists = await queryByTopic(topicName);
    int createAt = exists?.createAt ?? DateTime.now().millisecondsSinceEpoch;
    if (exists != null && (DateTime.now().millisecondsSinceEpoch - createAt).abs() < Settings.txPoolDelayMs) {
      logger.i("$TAG - isJoined - createAt just now, maybe in txPool - topicName:$topicName - clientAddress:$clientAddress");
      return exists.joined; // maybe in txPool
    }
    int expireHeight = await _getExpireAt(exists?.topic, clientAddress);
    if (expireHeight <= 0) {
      logger.d("$TAG - isJoined - expireHeight <= 0 - topicName:$topicName - clientAddress:$clientAddress");
      return false;
    }
    globalHeight = globalHeight ?? await clientCommon.client?.getHeight();
    if (globalHeight == null || globalHeight <= 0) {
      logger.w("$TAG - isJoined - globalHeight <= 0 - topicName:$topicName");
      return false;
    }
    return expireHeight >= globalHeight;
  }

  Future<int> _getExpireAt(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
    Map<String, dynamic> result = await _clientGetSubscription(topicName, pubKey);
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    return int.tryParse(expiresAt) ?? 0;
  }

  Future<Map<String, dynamic>> _getMetaByPage(String? topicName, int permPage) async {
    if (topicName == null || topicName.isEmpty) return Map();
    String? ownerPubKey = getPubKeyFromTopicOrChatId(topicName);
    String indexWithPubKey = '__${permPage}__.__permission__.$ownerPubKey';
    Map<String, dynamic> result = await _clientGetSubscription(topicName, indexWithPubKey);
    if (result['meta']?.toString().isNotEmpty == true) {
      return jsonFormat(result['meta']) ?? Map();
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
  /// ************************************************ action ***************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<SubscriberSchema?> invitee(String? topicName, bool isPrivate, bool isOwner, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) {
      Toast.show(S.of(Global.appContext).invite_yourself_error);
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
    bool acceptAll = false;
    if (isPrivate) {
      List<dynamic> result = await subscriberCommon.findPermissionFromNode(topicName, isPrivate, clientAddress);
      appendPermPage = result[0] ?? (await subscriberCommon.queryMaxPermPageByTopic(topicName));
      acceptAll = result[1];
      bool? isReject = result[3];
      if (!acceptAll && !isOwner && isReject == true) {
        // just owner can invitee reject item
        Toast.show("此人已经被拉黑，不允许普通成员邀请"); // TODO:GG locale invitee
        return null;
      }
    }

    // update DB
    _subscriber = await subscriberCommon.onInvitedSend(topicName, clientAddress, appendPermPage);
    if (_subscriber == null) return null;

    // update meta (private + owner + no_accept_all)
    if (isPrivate && isOwner && !acceptAll && (appendPermPage != null)) {
      Map<String, dynamic> meta = await _getMetaByPage(topicName, appendPermPage);
      meta = await _buildMetaByAppend(topicName, meta, _subscriber);
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: appendPermPage, meta: meta);
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
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) return null;
    if (!isPrivate || !isOwner) return null; // enable just private + owner

    // check status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    int? oldStatus = _subscriber?.status;
    if (_subscriber == null) return null;
    if (_subscriber.canBeKick == false) return null; // checked in UI

    // check permission
    List<dynamic> result = await subscriberCommon.findPermissionFromNode(topicName, isPrivate, clientAddress);
    bool acceptAll = result[1];
    int? permPage = _subscriber.permPage ?? result[0];

    // update DB
    _subscriber = await subscriberCommon.onKickOut(topicName, clientAddress, permPage: permPage);
    if (_subscriber == null) return null;

    // update meta (private + owner + no_accept_all)
    if (!acceptAll && permPage != null) {
      Map<String, dynamic> meta = await _getMetaByPage(topicName, permPage);
      meta = await _buildMetaByAppend(topicName, meta, _subscriber);
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: permPage, meta: meta);
      if (!subscribeSuccess) {
        logger.w("$TAG - kick - clientSubscribe error - permPage:$permPage - meta:$meta");
        _subscriber.status = oldStatus;
        _subscriber.permPage = permPage;
        await subscriberCommon.add(_subscriber);
        return null;
      }
    }

    // send message
    // TODO:GG topic  need new protocol(event:channelKick)
    Toast.show("已提出"); // TODO:GG local kick
    return _subscriber;
  }

  Future<Map<String, dynamic>> _buildMetaByAppend(String? topicName, Map<String, dynamic> meta, SubscriberSchema? append) async {
    if (topicName == null || topicName.isEmpty || append == null) return Map();
    // permPage
    if ((append.permPage ?? -1) <= 0) {
      append.permPage = (await subscriberCommon.findPermissionFromNode(topicName, true, append.clientAddress))[0];
    }

    // node meta
    List<dynamic> acceptList = meta['accept'] ?? [];
    List<dynamic> rejectList = meta['reject'] ?? [];
    if (append.status == SubscriberStatus.InvitedSend || append.status == SubscriberStatus.InvitedReceipt || append.status == SubscriberStatus.Subscribed) {
      // add to accepts
      int removeIndex = -1;
      rejectList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          removeIndex = key;
        }
      });
      if (removeIndex >= 0) {
        rejectList.removeAt(removeIndex);
      }
      int existIndex = -1;
      acceptList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          existIndex = key;
        }
      });
      if (existIndex < 0) {
        acceptList.add({'addr': append.clientAddress});
      }
    } else {
      // add to rejects
      int removeIndex = -1;
      acceptList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          removeIndex = key;
        }
      });
      if (removeIndex >= 0) {
        acceptList.removeAt(removeIndex);
      }
      int existIndex = -1;
      rejectList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          existIndex = key;
        }
      });
      if (existIndex < 0) {
        rejectList.add({'addr': append.clientAddress});
      }
    }

    // DB meta (maybe in txPool)
    List<SubscriberSchema> subscribers = await subscriberCommon.queryListByTopicPerm(topicName, append.permPage);
    subscribers.forEach((SubscriberSchema element) {
      int updateAt = element.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - updateAt).abs() < Settings.txPoolDelayMs) {
        logger.i("$TAG - _buildMetaByAppend - subscriber update just now, maybe in txPool - element:$element");
        if (append.status == SubscriberStatus.InvitedSend || append.status == SubscriberStatus.InvitedReceipt || append.status == SubscriberStatus.Subscribed) {
          // add to accepts
          int removeIndex = -1;
          rejectList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              removeIndex = key;
            }
          });
          if (removeIndex >= 0) {
            rejectList.removeAt(removeIndex);
          }
          int existIndex = -1;
          acceptList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              existIndex = key;
            }
          });
          if (existIndex < 0) {
            acceptList.add({'addr': append.clientAddress});
          }
        } else {
          // add to rejects
          int removeIndex = -1;
          acceptList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              removeIndex = key;
            }
          });
          if (removeIndex >= 0) {
            acceptList.removeAt(removeIndex);
          }
          int existIndex = -1;
          rejectList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              existIndex = key;
            }
          });
          if (existIndex < 0) {
            rejectList.add({'addr': append.clientAddress});
          }
        }
      }
    });

    // new meta
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;
    logger.d("$TAG - _buildMetaByAppend - append:$append - meta:${meta.toString()}");
    return meta;
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
    TopicSchema? topic = await query(topicId);
    if (topic == null) return false;
    bool success = await _topicStorage.delete(topicId);
    if (success && notify) _deleteSink.add(topic.topic);
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
