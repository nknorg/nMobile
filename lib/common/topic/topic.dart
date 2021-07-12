import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
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

  // TODO:GG call in invitee
  Future<TopicSchema?> subscribe(String? topicName, {double fee = 0}) async {
    if (topicName == null || topicName.isEmpty) return null;

    // db exist
    TopicSchema? exists = await queryByTopic(topicName);
    if (exists == null) {
      exists = await add(TopicSchema.create(topicName), checkDuplicated: false);
      logger.d("$TAG - subscribe - new - schema:$exists");
      // TODO:GG subers insert
    }
    if (exists == null) return null;

    // client subscribe
    int currentBlockHeight = 0; // TODO:GG await NKNClientCaller.fetchBlockHeight();
    if (exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0 || (exists.expireBlockHeight! - currentBlockHeight > Global.topicWarnBlockExpireHeight)) {
      bool joinSuccess = await _clientSubscribe(topicName); // TODO:GG topic params
      if (!joinSuccess) return null;

      // schema refresh
      var subscribeAt = DateTime.now();
      var expireBlockHeight = currentBlockHeight + Global.topicDefaultSubscribeDuration;
      bool setSuccess = await setJoined(exists.id, true, subscribeAt: subscribeAt, expireBlockHeight: expireBlockHeight, notify: true);
      if (setSuccess) {
        exists.subscribeAt = subscribeAt;
        exists.expireBlockHeight = expireBlockHeight;
        exists.joined = true;
      } else {
        logger.e("$TAG - subscribe - setExpireBlockHeight:fail - exists:$exists");
      }
    }

    // TODO:GG subers get
    if (exists.isPrivate) {
      // await GroupDataCenter.pullPrivateSubscribers(topicName);
      // TODO:GG topic permissions
    } else {
      // await GroupDataCenter.pullSubscribersPublicChannel(topicName);
    }

    // message
    await chatOutCommon.sendTopicSubscribe(topicName);
    return exists;
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
    await chatOutCommon.sendTopicUnSubscribe(topicName);

    // TODO:GG subers del

    // db delete
    if (deleteDB) await delete(exists?.id, notify: true);
    return exists;
  }

  Future<bool> _clientSubscribe(
    String? topicName, {
    int? permissionPage,
    Map<String, dynamic>? meta,
    int? duration,
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
        duration: duration ?? Global.topicDefaultSubscribeDuration,
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

  // TODO:GG topic detail [meta, expiresAt, ...]
  Future _clientGetSubscription(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return false;
    Map<String, dynamic>? result = await clientCommon.client?.getSubscription(
      topic: genTopicHash(topicName),
      subscriber: clientAddress,
    );
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
    if (added != null) _addSink.add(added);
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

  Future<bool> setJoined(int? topicId, bool joined, {DateTime? subscribeAt, int? expireBlockHeight, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setJoined(
      topicId,
      joined,
      subscribeAt: subscribeAt ?? DateTime.now(),
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

  // TODO:GG call
  Future<bool> setCount(int? topicId, int? count, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setCount(topicId, count ?? 0);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  // TODO:GG call
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
