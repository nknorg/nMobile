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
      await checkExpireAndSubscribe(topic.topic, subscribeFirst: false, emptyAdd: false);
      if (topic.isOwner(clientCommon.address)) {
        // TODO:GG 非群主/公有群能不能call，?能的话和refreshSubscriber有啥区别
        // await topicCommon.refreshSubscribersByOwner(topic.topic, allPermPage: true);
      }
    });
  }

  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  // caller = self
  Future<TopicSchema?> subscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;
    // subscribe/expire
    TopicSchema? _topic = await checkExpireAndSubscribe(topicName, subscribeFirst: true, emptyAdd: true);
    if (_topic == null) return null;

    // message_subscribe
    int subscribeAt = _topic.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
    if (_topic.joined && (DateTime.now().millisecondsSinceEpoch - subscribeAt).abs() < 1000 * 60) {
      await chatOutCommon.sendTopicSubscribe(topicName);
    }

    // subscribers_check (page used owner meta, not here)
    await subscriberCommon.onSubscribe(topicName, clientCommon.address);
    if (_topic.isPrivate) {
      await subscriberCommon.refreshSubscribers(topicName, meta: true);
    } else {
      await subscriberCommon.refreshSubscribers(topicName, meta: false);
    }

    await Future.delayed(Duration(seconds: 3));
    return _topic;
  }

  // caller = self
  Future<TopicSchema?> checkExpireAndSubscribe(String? topicName, {bool subscribeFirst = false, bool emptyAdd = false, double fee = 0}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;

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
      int expireHeight = await _getExpireAt(exists.topic, clientCommon.address);
      if (expireHeight > 0) {
        int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
        if ((DateTime.now().millisecondsSinceEpoch - createAt).abs() > Settings.txPoolDelayMs) {
          logger.d("$TAG - checkExpireAndSubscribe - DB expire but node not expire - topic:$exists");
          int subscribeAt = exists.subscribeAt ?? DateTime.now().millisecondsSinceEpoch;
          bool success = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireHeight, notify: true);
          if (success) {
            exists.joined = true;
            exists.subscribeAt = subscribeAt;
            exists.expireBlockHeight = expireHeight;
          }
        } else {
          logger.w("$TAG - checkExpireAndSubscribe - DB expire but node not expire, maybe in txPool - topic:$exists");
          return null;
        }
      } else {
        if (!subscribeFirst) {
          logger.i("$TAG - checkExpireAndSubscribe - can not subscribeFirst - topic:$exists");
          return null;
        } else {
          logger.d("$TAG - checkExpireAndSubscribe - no subscribe history - topic:$exists");
          noSubscribed = true;
        }
      }
    } else {
      int createAt = exists.createAt ?? DateTime.now().millisecondsSinceEpoch;
      int expireHeight = await _getExpireAt(exists.topic, clientCommon.address);
      if (expireHeight <= 0) {
        if (exists.joined && (DateTime.now().millisecondsSinceEpoch - createAt).abs() > Settings.txPoolDelayMs) {
          logger.i("$TAG - checkExpireAndSubscribe - db no expire but node expire - topic:$exists");
          bool success = await setJoined(exists.id, false, notify: true);
          if (success) exists.joined = false;
        } else {
          logger.d("$TAG - checkExpireAndSubscribe - DB not expire but node expire, maybe in txPool - topic:$exists");
        }
      } else {
        logger.d("$TAG - checkExpireAndSubscribe - OK OK OK OK OK - topic:$exists");
      }
    }

    // check expire
    int? globalHeight = await clientCommon.client?.getHeight();
    bool shouldResubscribe = await exists.shouldResubscribe(globalHeight: globalHeight);
    if (noSubscribed || shouldResubscribe) {
      // client subscribe
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: fee);
      if (!subscribeSuccess) {
        logger.w("$TAG - checkExpireAndSubscribe - _clientSubscribe fail - topic:$exists");
        return null;
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
      if (exists.isOwner(clientCommon.address)) {
        SubscriberSchema? _subscriberMe = await subscriberCommon.onSubscribe(topicName, clientCommon.address, permPage: 0);
        Map<String, dynamic> meta = await _getMeta(topicName, 0);
        meta = await _buildNewMeta(topicName, meta, _subscriberMe, 0);
        bool permissionSuccess = await _clientSubscribe(topicName, fee: fee, permissionPage: 0, meta: meta);
        if (!permissionSuccess) {
          logger.w("$TAG - checkExpireAndSubscribe - _clientPermission fail - topic:$exists");
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

  // caller = self
  Future<TopicSchema?> unsubscribe(String? topicName, {double fee = 0, int? permissionPage}) async {
    if (topicName == null || topicName.isEmpty || clientCommon.address == null || clientCommon.address!.isEmpty) return null;

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
    await delete(exists?.id, notify: true);
    await subscriberCommon.deleteByTopic(topicName);

    await Future.delayed(Duration(seconds: 3));
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
  /// ************************************************ members **************************************************
  /// ***********************************************************************************************************

  // caller = public / owner
  Future<SubscriberSchema?> invitee(String? topicName, String? clientAddress, bool isPrivate, bool isOwner) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) {
      Toast.show(S.of(Global.appContext).invite_yourself_error);
      return null;
    }
    if (isPrivate && !isOwner) {
      Toast.show(S.of(Global.appContext).member_no_auth_invite);
      return null;
    }

    // subscriber status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (_subscriber != null && _subscriber.status == SubscriberStatus.Subscribed) {
      Toast.show(S.of(Global.appContext).group_member_already);
      return null;
    }

    // send message
    MessageSchema? _msg = await chatOutCommon.sendTopicInvitee(clientAddress, topicName);
    if (_msg == null) return null;

    // subscriber update
    int? appendPermPage = isPrivate ? await subscriberCommon.queryMaxPermPageByTopic(topicName) : null;
    _subscriber = await subscriberCommon.onInvitedSend(topicName, clientAddress, appendPermPage);
    if (_subscriber == null) return null;

    // client subscribe
    if (isPrivate && appendPermPage != null) {
      Map<String, dynamic> meta = await _getMeta(topicName, appendPermPage);
      meta = await _buildNewMeta(topicName, meta, _subscriber, appendPermPage);
      bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: appendPermPage, meta: meta);
      if (subscribeSuccess) {
        Toast.show(S.of(Global.appContext).invitation_sent);
        return _subscriber;
      } else {
        logger.w("$TAG - invitee - clientSubscribe error - permPage:$appendPermPage - meta:$meta");
        await subscriberCommon.delete(_subscriber.id, notify: true);
        return null;
      }
    }
    return _subscriber;
  }

  // caller = owner
  Future<SubscriberSchema?> kick(String? topicName, String? clientAddress, bool isPrivate, bool isOwner) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    if (clientAddress == clientCommon.address) return null;
    if (!isPrivate || !isOwner) return null; // now just private owner

    // subscriber status
    SubscriberSchema? _subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (_subscriber == null) return null;
    if (_subscriber.canBeKick == false) return null;

    // send message
    // TODO:GG topic need new protocol(event:channelKick)

    // subscriber update TODO:GG topic kick
    _subscriber = await subscriberCommon.onKick(topicName, clientAddress);
    if (_subscriber == null) return null;

    // client subscribe (meta update)
    int? status = _subscriber.status;
    int? permPage = _subscriber.permPage ?? await _findMetaPermissionPage(topicName, clientAddress);
    Map<String, dynamic> meta = await _getMeta(topicName, permPage);
    meta = await _buildNewMeta(topicName, meta, _subscriber, permPage);
    bool subscribeSuccess = await _clientSubscribe(topicName, fee: 0, permissionPage: permPage, meta: meta);
    if (!subscribeSuccess) {
      logger.w("$TAG - kick - clientSubscribe error - permPage:$permPage - meta:$meta");
      _subscriber = SubscriberSchema.create(topicName, clientAddress, status);
      _subscriber?.permPage = permPage;
      await subscriberCommon.add(_subscriber);
      return null;
    }
    Toast.show("已提出"); // TODO:GG local kick
    return _subscriber;
  }

  // caller = everyone
  Future<Map<String, dynamic>> _buildNewMeta(String? topicName, Map<String, dynamic>? meta, SubscriberSchema? append, int permPage) async {
    if (topicName == null || topicName.isEmpty || meta == null || append == null) return Map();
    // append_permPage
    if (append.permPage != permPage) {
      bool success = await subscriberCommon.setPermPage(append.id, permPage, notify: true);
      if (success) append.permPage = permPage;
    }

    // node meta
    List<dynamic> acceptList = meta['accept'] ?? [];
    List<dynamic> rejectList = meta['reject'] ?? [];
    if (append.status == SubscriberStatus.InvitedSend || append.status == SubscriberStatus.InvitedReceipt || append.status == SubscriberStatus.Subscribed) {
      int removeIndex = -1;
      rejectList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          removeIndex = key;
        }
      });
      if (removeIndex >= 0) {
        rejectList.removeAt(removeIndex);
      }
      int addIndex = -1;
      acceptList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          addIndex = key;
        }
      });
      if (addIndex < 0) {
        acceptList.add({'addr': append.clientAddress});
      }
    } else {
      int removeIndex = -1;
      acceptList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          removeIndex = key;
        }
      });
      if (removeIndex >= 0) {
        acceptList.removeAt(removeIndex);
      }
      int addIndex = -1;
      rejectList.asMap().forEach((key, value) {
        if (value.toString().contains(append.clientAddress)) {
          addIndex = key;
        }
      });
      if (addIndex < 0) {
        rejectList.add({'addr': append.clientAddress});
      }
    }

    // DB meta
    List<SubscriberSchema> subscribers = await subscriberCommon.queryListByTopicPerm(topicName, permPage);
    subscribers.forEach((SubscriberSchema element) {
      int updateAt = element.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - updateAt).abs() < Settings.txPoolDelayMs) {
        logger.d("$TAG - _buildNewMeta - subscriber update just now - element:$element");
        if (append.status == SubscriberStatus.InvitedSend || append.status == SubscriberStatus.InvitedReceipt || append.status == SubscriberStatus.Subscribed) {
          int removeIndex = -1;
          rejectList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              removeIndex = key;
            }
          });
          if (removeIndex >= 0) {
            rejectList.removeAt(removeIndex);
          }
          int addIndex = -1;
          acceptList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              addIndex = key;
            }
          });
          if (addIndex < 0) {
            acceptList.add({'addr': append.clientAddress});
          }
        } else {
          int removeIndex = -1;
          acceptList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              removeIndex = key;
            }
          });
          if (removeIndex >= 0) {
            acceptList.removeAt(removeIndex);
          }
          int addIndex = -1;
          rejectList.asMap().forEach((key, value) {
            if (value.toString().contains(append.clientAddress)) {
              addIndex = key;
            }
          });
          if (addIndex < 0) {
            rejectList.add({'addr': append.clientAddress});
          }
        }
      }
    });

    // new meta
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;

    logger.d("$TAG - _buildNewMeta - meta:${meta.toString()}");
    return meta;
  }

  // caller = private + everyone
  Future<int> _findMetaPermissionPage(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return -1;
    Completer completer = Completer();
    int? permPage;
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
    await completer.future;
    if (permPage != null && permPage! >= 0) {
      logger.d("$TAG - _findMetaPermissionPage - permPage:$permPage");
    } else {
      logger.w("$TAG - _findMetaPermissionPage - permPage:$permPage");
    }
    permPage = permPage ?? await subscriberCommon.queryMaxPermPageByTopic(topicName);
    logger.w("$TAG - _findMetaPermissionPage - last - permPage:$permPage");
    return permPage!;
  }

  /// ***********************************************************************************************************
  /// ********************************************** subscription ***********************************************
  /// ***********************************************************************************************************

  // caller = everyone
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

  // caller = owner TODO:GG 还有用吗
  Future refreshSubscribersByOwner(String? topicName, {bool allPermPage = false, int permPage = 0, int? maxPage}) async {
    if (topicName == null || topicName.isEmpty) return;

    // meta
    Map<String, dynamic> meta = await _getMeta(topicName, permPage);
    maxPage = maxPage ?? await subscriberCommon.queryMaxPermPageByTopic(topicName);
    List<dynamic> accepts = meta["accept"] ?? [];
    List<dynamic> rejects = meta["reject"] ?? [];
    if (accepts.isEmpty && rejects.isEmpty) {
      logger.w("$TAG - refreshSubscribersByOwner - meta is null - meta:$meta");
      return;
    }

    // accept
    List<Future> futures = [];
    bool _acceptAll = false;
    for (dynamic accept in accepts) {
      if (accept is Map) {
        if (accept.isNotEmpty == true) {
          String? address = accept["addr"];
          if (address == null || address.isEmpty || address.length < 64 || address.contains(".__permission__.")) {
            logger.w("$TAG - refreshSubscribersByOwner - accept address is wrong - accept:$accept");
            continue;
          }
          futures.add(subscriberCommon.queryByTopicChatId(topicName, address).then((value) {
            if ((value?.status ?? SubscriberStatus.None) < SubscriberStatus.InvitedReceipt) {
              return subscriberCommon.onInvitedReceipt(topicName, address, permPage: permPage);
            } else if (value?.permPage != permPage) {
              return subscriberCommon.setPermPage(value?.id, permPage, notify: true);
            }
          }));
        } else {
          logger.w("$TAG - refreshSubscribersByOwner - accept is empty - accept:$accept");
        }
      } else if (accept is String) {
        if (accept.trim() == "*") {
          logger.i("$TAG - refreshSubscribersByOwner - accept all - accept:$accept");
          _acceptAll = true;
        } else {
          logger.w("$TAG - refreshSubscribersByOwner - accept content error - accept:$accept");
        }
      } else {
        logger.w("$TAG - refreshSubscribersByOwner - accept type error - accept:$accept");
      }
    }

    // reject
    for (dynamic reject in rejects) {
      if (reject is Map) {
        if (reject.isNotEmpty == true) {
          String? address = reject["addr"];
          if (address == null || address.isEmpty || address.length < 64 || address.contains(".__permission__.")) {
            logger.w("$TAG - refreshSubscribersByOwner - reject address is wrong - reject:$reject");
            continue;
          }
          futures.add(subscriberCommon.queryByTopicChatId(topicName, address).then((value) {
            if (value?.status == null || value?.status != SubscriberStatus.Unsubscribed) {
              return subscriberCommon.onUnsubscribe(topicName, address);
            } else if (value?.permPage != permPage) {
              return subscriberCommon.setPermPage(value?.id, permPage, notify: true);
            }
          }));
        } else {
          logger.w("$TAG - refreshSubscribersByOwner - reject is empty - reject:$reject");
        }
      } else {
        logger.w("$TAG - refreshSubscribersByOwner - reject type error - reject:$reject");
      }
    }
    await Future.wait(futures);

    // accept all
    if (_acceptAll) {
      subscriberCommon.setStatusAndPermPageByTopic(topicName, SubscriberStatus.Subscribed, null);
    }

    // loop
    if (allPermPage && ++permPage <= maxPage) {
      logger.d("$TAG - refreshSubscribersByOwner - loop - progress:$permPage/$maxPage");
      return refreshSubscribersByOwner(topicName, allPermPage: true, permPage: permPage, maxPage: maxPage);
    }
    logger.d("$TAG - refreshSubscribersByOwner - loop - progress:$permPage/$maxPage");
    return;
  }

  Future<int> _getExpireAt(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
    Map<String, dynamic> result = await _clientGetSubscription(topicName, pubKey);
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    return int.tryParse(expiresAt) ?? 0;
  }

  // TODO:GG meta只能群主获取？
  Future<Map<String, dynamic>> _getMeta(String? topicName, int permPage) async {
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
