import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
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

  Future<TopicSchema?> subscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // subscribe
    TopicSchema? _topic = await checkExpireAndSubscribe(topicName);
    if (_topic == null) return null;

    // subscriber
    SubscriberSchema? subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientCommon.address);
    if (subscriber == null) {
      SubscriberSchema? subscriber = SubscriberSchema.create(topicName, clientCommon.address, SubscriberStatus.Subscribed);
      subscriberCommon.add(subscriber); // await
    } else {
      if (subscriber.status != SubscriberStatus.Subscribed) {
        bool success = await subscriberCommon.setStatus(subscriber.id, SubscriberStatus.Subscribed);
        if (success) subscriber.status = SubscriberStatus.Subscribed;
      }
    }

    // subscribers
    if (_topic.isPrivate) {
      // await GroupDataCenter.pullPrivateSubscribers(topicName);
      // TODO:GG subers get + topic permissions
    } else {
      subscriberCommon.getSubscribers(topicName); // await
    }

    // message
    chatOutCommon.sendTopicSubscribe(topicName); // await
    return _topic;
  }

  Future<TopicSchema?> unsubscribe(String? topicName, {bool deleteDB = false}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // client unsubscribe
    bool exitSuccess = await _clientUnsubscribe(topicName); // TODO:GG topic params
    if (!exitSuccess) return null;

    // schema refresh
    TopicSchema? exists = await topicCommon.queryByTopic(topicName);
    bool setSuccess = await setJoined(exists?.id, false, notify: true);
    if (setSuccess) {
      exists?.joined = false;
    } else {
      logger.e("$TAG - unsubscribe - setJoined:fail - exists:$exists");
    }

    // message
    chatOutCommon.sendTopicUnSubscribe(topicName); // await

    // TODO:GG subers del

    // db delete
    if (deleteDB) await delete(exists?.id, notify: true);
    return exists;
  }

  Future<TopicSchema?> checkExpireAndSubscribe(String? topicName, {bool emptyAdd = true, double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // db exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null && emptyAdd) {
      logger.d("$TAG - checkExpireAndSubscribe - new - schema:$exists");
      exists = await add(TopicSchema.create(topicName), checkDuplicated: false);
    }
    if (exists == null) return null;

    // empty height
    bool noSubscribed = false;
    if (!exists.joined || exists.subscribeAt == null || exists.subscribeAt! <= 0 || exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0) {
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
      bool joinSuccess = await _clientSubscribe(
        topicName,
        height: Global.topicDefaultSubscribeHeight,
        // meta: , // TODO:GG topic params
        // permissionPage: , // TODO:GG topic params
        fee: fee,
      );
      if (!joinSuccess) return null;

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

  Future<bool> isJoined(String? topicName, String? clientAddress, {int? globalHeight}) async {
    int expireHeight = await _getExpireAt(topicName, clientCommon.address);
    if (expireHeight <= 0) return false;
    globalHeight = globalHeight ?? await clientCommon.client?.getHeight();
    if (globalHeight == null || globalHeight <= 0) return false;
    return expireHeight >= globalHeight;
  }

  Future<bool> _clientSubscribe(
    String? topicName, {
    int? permissionPage,
    Map<String, dynamic>? meta,
    int? height,
    double fee = 0,
  }) async {
    if (topicName == null || topicName.isEmpty) return false;
    String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";

    bool success;
    try {
      String? topicHash = await clientCommon.client?.subscribe(
        topic: genTopicHash(topicName),
        identifier: identifier,
        meta: metaString,
        duration: height ?? Global.topicDefaultSubscribeHeight,
        fee: fee.toString(),
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

  Future<bool> _clientUnsubscribe(
    String? topicName, {
    int? permissionPage,
    double fee = 0,
  }) async {
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

  // TODO:GG call
  Future<Map<String, dynamic>> getMeta(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return Map();
    Map<String, dynamic> result = await _clientGetSubscription(topicName, clientAddress);
    var meta = result['meta']; // TODO:GG 转化成map
    return Map();
  }

  Future<int> _getExpireAt(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return 0;
    Map<String, dynamic> result = await _clientGetSubscription(topicName, clientAddress);
    String? expiresAt = result['expiresAt']?.toString() ?? "0";
    return int.parse(expiresAt);
  }

  Future<Map<String, dynamic>> _clientGetSubscription(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return Map();
    Map<String, dynamic>? result = await clientCommon.client?.getSubscription(
      topic: genTopicHash(topicName),
      subscriber: clientAddress,
    );
    if (result?.isNotEmpty == true) {
      logger.d("$TAG - _clientGetSubscription - success - topicName:$topicName - clientAddress:$clientAddress - result:$result}");
    } else {
      logger.w("$TAG - _clientGetSubscription - fail - topicName:$topicName - clientAddress:$clientAddress");
    }
    return result ?? Map();
  }

  Future<TopicSchema?> add(TopicSchema? schema, {bool checkDuplicated = true}) async {
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
    if (added != null) {
      _addSink.add(added);
    }
    return added;
  }

  Future<bool> delete(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool deleted = await _topicStorage.delete(topicId);
    if (deleted) _deleteSink.add(topicId);
    return deleted;
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

  // TODO:GG call
  Future<bool> setPermission(int? topicId, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    Map<String, dynamic> newData = {
      'permissions': "",
    }; // TODO:GG topic data load
    bool success = await _topicStorage.setData(topicId, newData);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future queryAndNotify(int? topicId) async {
    if (topicId == null || topicId == 0) return;
    TopicSchema? updated = await _topicStorage.query(topicId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
