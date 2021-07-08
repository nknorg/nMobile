import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/helpers/error.dart';
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

  Future<bool> clientSubscribe(String? topicName, {int? duration, int? permissionPage, Map<String, dynamic>? meta}) async {
    if (topicName == null || topicName.isEmpty) return false;
    String identifier = permissionPage != null ? '__${permissionPage}__.__permission__' : "";
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";

    String? topicHash = await clientCommon.client?.subscribe(
      topic: genTopicHash(topicName),
      duration: duration ?? Global.topicDefaultSubscribeDuration,
      identifier: identifier,
      meta: metaString,
    );
    if (topicHash != null && topicHash.isNotEmpty) {
      logger.d("$TAG - clientSubscribe - success - topicHash:$topicHash");
    } else {
      logger.e("$TAG - clientSubscribe - fail - topicHash:$topicHash");
    }
    return topicHash != null && topicHash.isNotEmpty;
  }

  Future<bool> subscribe(String topicName) async {
    try {
      TopicSchema? exists = await queryByTopic(topicName);
      if (exists == null) {
        exists = await add(TopicSchema.create(topicName), checkDuplicated: false);
        logger.d("$TAG - subscribe - new - schema:$exists");
        // TODO:GG subscriber insert
      }
      if (exists == null) return false;

      int currentBlockHeight = 0; // TODO:GG await NKNClientCaller.fetchBlockHeight();
      if (exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0 || (exists.expireBlockHeight! - currentBlockHeight > Global.topicWarnBlockExpireHeight)) {
        bool subSuccess = await clientSubscribe(topicName);
        if (!subSuccess) return false;
        var expireBlockHeight = currentBlockHeight + Global.topicDefaultSubscribeDuration;
        var subscribeAt = DateTime.now();
        bool setSuccess = await setExpireBlockHeight(exists.id, expireBlockHeight, subscribeAt: subscribeAt, notify: true);
        if (setSuccess) {
          exists.expireBlockHeight = expireBlockHeight;
          exists.subscribeAt = subscribeAt;
        } else {
          logger.e("$TAG - subscribe - setExpireBlockHeight:fail - exists:$exists");
        }
      }

      // TODO:GG subscriber get
      if (exists.isPrivate) {
        // await GroupDataCenter.pullPrivateSubscribers(topicName);
      } else {
        // await GroupDataCenter.pullSubscribersPublicChannel(topicName);
      }

      chatOutCommon.sendTopicSubscribe(topicName); // await
      return true;
    } catch (e) {
      if (e.toString().contains('duplicate subscription exist in block')) {
        logger.i("$TAG - subscribe - duplicate - error:${e.toString()}");

        TopicSchema? exists = await queryByTopic(topicName);
        if (exists == null) {
          exists = await add(TopicSchema.create(topicName), checkDuplicated: false);
          logger.d("$TAG - subscribe - new - schema:$exists");
          // TODO:GG subscriber insert
        }
        if (exists == null) return false;

        // just skip clientSubscribe

        // TODO:GG subscriber get
        if (exists.isPrivate) {
          // await GroupDataCenter.pullPrivateSubscribers(topicName);
        } else {
          // await GroupDataCenter.pullSubscribersPublicChannel(topicName);
        }

        chatOutCommon.sendTopicSubscribe(topicName); // await
        return true;
      } else {
        handleError(e);
        return false;
      }
    }
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

  Future<List<TopicSchema>> queryList({String? topicType, String? orderBy, int? offset, int? limit}) {
    return _topicStorage.queryList(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<TopicSchema?> queryByTopic(String? topicName) async {
    if (topicName == null || topicName.isEmpty) return null;
    return await _topicStorage.queryByTopic(topicName);
  }

  Future<bool> setExpireBlockHeight(int? topicId, int? expireBlockHeight, {DateTime? subscribeAt, bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setExpireBlockHeight(
      topicId,
      expireBlockHeight,
      subscribeAt: subscribeAt ?? DateTime.now(),
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

  Future<bool> setJoined(int? topicId, bool joined, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setJoined(topicId, joined);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setTop(int? topicId, bool top, {bool notify = false}) async {
    if (topicId == null || topicId == 0) return false;
    bool success = await _topicStorage.setTop(topicId, top);
    if (success && notify) queryAndNotify(topicId);
    return success;
  }

  Future<bool> setPermission(int? topicId, String? avatarLocalPath, {bool notify = false}) async {
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
