import 'dart:async';
import 'dart:typed_data';

import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../locator.dart';

class SubscriberCommon with Tag {
  SubscriberStorage _subscriberStorage = SubscriberStorage();

  StreamController<SubscriberSchema> _addController = StreamController<SubscriberSchema>.broadcast();
  StreamSink<SubscriberSchema> get _addSink => _addController.sink;
  Stream<SubscriberSchema> get addStream => _addController.stream;

  StreamController<int> _deleteController = StreamController<int>.broadcast();
  StreamSink<int> get _deleteSink => _deleteController.sink;
  Stream<int> get deleteStream => _deleteController.stream;

  StreamController<SubscriberSchema> _updateController = StreamController<SubscriberSchema>.broadcast();
  StreamSink<SubscriberSchema> get _updateSink => _updateController.sink;
  Stream<SubscriberSchema> get updateStream => _updateController.stream;

  SubscriberCommon();

  close() {
    _addController.close();
    _deleteController.close();
    _updateController.close();
  }

  Future<List<SubscriberSchema>> _clientGetSubscribers(
    String? topicName, {
    int offset = 0,
    int limit = 1000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topicName == null || topicName.isEmpty) return [];
    List<SubscriberSchema> subscribers = [];
    try {
      Map<String, dynamic>? results = await clientCommon.client?.getSubscribers(
        topic: genTopicHash(topicName),
        offset: offset,
        limit: limit,
        meta: meta,
        txPool: txPool,
        subscriberHashPrefix: subscriberHashPrefix,
      );
      logger.d("$TAG - _clientGetSubscribers - results:$results");
      // TODO:GG 转化
      logger.d("$TAG - _clientGetSubscribers - subscribers:$subscribers");
    } catch (e) {
      handleError(e);
    }
    return subscribers;
  }

  Future<int> _clientGetSubscribersCount(String? topicName, {Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    int? count;
    try {
      count = await clientCommon.client?.getSubscribersCount(
        topic: genTopicHash(topicName),
        subscriberHashPrefix: subscriberHashPrefix,
      );
      logger.d("$TAG - _clientGetSubscribersCount - count:$count");
    } catch (e) {
      handleError(e);
    }
    return count ?? 0;
  }

  // Future<SubscriberSchema?> subscribe(String? topicName) async {
  //   if (topicName == null || topicName.isEmpty) return null;
  //
  //   // db exist
  //   SubscriberSchema? exists = await queryByTopic(topicName);
  //   if (exists == null) {
  //     exists = await add(SubscriberSchema.create(topicName), checkDuplicated: false);
  //     logger.d("$TAG - subscribe - new - schema:$exists");
  //     // TODO:GG subers insert
  //   }
  //   if (exists == null) return null;
  //
  //   // client subscribe
  //   int currentBlockHeight = 0; // TODO:GG await NKNClientCaller.fetchBlockHeight();
  //   if (exists.expireBlockHeight == null || exists.expireBlockHeight! <= 0 || (exists.expireBlockHeight! - currentBlockHeight > Global.topicWarnBlockExpireHeight)) {
  //     bool joinSuccess = await clientSubscribe(topicName); // TODO:GG topic params
  //     if (!joinSuccess) return null;
  //
  //     // schema refresh
  //     var subscribeAt = DateTime.now();
  //     var expireBlockHeight = currentBlockHeight + Global.topicDefaultSubscribeDuration;
  //     bool setSuccess = await setJoined(exists.id, true, expireBlockHeight: expireBlockHeight, subscribeAt: subscribeAt, notify: true);
  //     if (setSuccess) {
  //       exists.subscribeAt = subscribeAt;
  //       exists.expireBlockHeight = expireBlockHeight;
  //       exists.joined = true;
  //     } else {
  //       logger.e("$TAG - subscribe - setExpireBlockHeight:fail - exists:$exists");
  //     }
  //   }
  //
  //   // TODO:GG subers get
  //   if (exists.isPrivate) {
  //     // await GroupDataCenter.pullPrivateSubscribers(topicName);
  //     // TODO:GG topic permissions
  //   } else {
  //     // await GroupDataCenter.pullSubscribersPublicChannel(topicName);
  //   }
  //
  //   // message
  //   await chatOutCommon.sendTopicSubscribe(topicName);
  //   return exists;
  // }
  //
  // Future<SubscriberSchema?> unsubscribe(String? topicName, {bool deleteDB = false}) async {
  //   if (topicName == null || topicName.isEmpty) return null;
  //
  //   // client unsubscribe
  //   bool exitSuccess = await clientUnsubscribe(topicName); // TODO:GG topic params
  //   if (!exitSuccess) return null;
  //
  //   // schema refresh
  //   SubscriberSchema? exists = await topicCommon.queryByTopic(topicName);
  //   bool setSuccess = await setJoined(exists?.id, false, notify: true);
  //   if (setSuccess) {
  //     exists?.joined = false;
  //   } else {
  //     logger.e("$TAG - unsubscribe - setJoined:fail - exists:$exists");
  //   }
  //
  //   // message
  //   await chatOutCommon.sendTopicUnSubscribe(topicName);
  //
  //   // TODO:GG subers del
  //
  //   // db delete
  //   if (deleteDB) await delete(exists?.id, notify: true);
  //   return exists;
  // }
  //
  // Future<SubscriberSchema?> add(SubscriberSchema? schema, {bool checkDuplicated = true}) async {
  //   if (schema == null || schema.topic.isEmpty) return null;
  //   schema.type = schema.type ?? (isPrivateTopicReg(schema.topic) ? TopicType.privateTopic : TopicType.publicTopic);
  //   if (checkDuplicated) {
  //     SubscriberSchema? exist = await queryByTopic(schema.topic);
  //     if (exist != null) {
  //       logger.d("$TAG - add - duplicated - schema:$exist");
  //       return null;
  //     }
  //   }
  //   SubscriberSchema? added = await _subscriberStorage.insert(schema);
  //   if (added != null) _addSink.add(added);
  //   return added;
  // }
  //
  // Future<bool> delete(int? subscriberId, {bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   bool deleted = await _subscriberStorage.delete(subscriberId);
  //   if (deleted) _deleteSink.add(subscriberId);
  //   return deleted;
  // }
  //
  // Future<SubscriberSchema?> query(int? subscriberId) {
  //   return _subscriberStorage.query(subscriberId);
  // }
  //
  // Future<List<SubscriberSchema>> queryList({String? topicType, String? orderBy, int? offset, int? limit}) {
  //   return _subscriberStorage.queryList(topicType: topicType, orderBy: orderBy, offset: offset, limit: limit);
  // }
  //
  // Future<SubscriberSchema?> queryByTopic(String? topicName) async {
  //   if (topicName == null || topicName.isEmpty) return null;
  //   return await _subscriberStorage.queryByTopic(topicName);
  // }
  //
  // Future<bool> setAvatar(int? subscriberId, String? avatarLocalPath, {bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   bool success = await _subscriberStorage.setAvatar(subscriberId, avatarLocalPath);
  //   if (success && notify) queryAndNotify(subscriberId);
  //   return success;
  // }
  //
  // Future<bool> setJoined(int? subscriberId, bool joined, {DateTime? subscribeAt, int? expireBlockHeight, bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   bool success = await _subscriberStorage.setJoined(
  //     subscriberId,
  //     joined,
  //     subscribeAt: subscribeAt ?? DateTime.now(),
  //     expireBlockHeight: expireBlockHeight,
  //   );
  //   if (success && notify) queryAndNotify(subscriberId);
  //   return success;
  // }
  //
  // Future<bool> setTop(int? subscriberId, bool top, {bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   bool success = await _subscriberStorage.setTop(subscriberId, top);
  //   if (success && notify) queryAndNotify(subscriberId);
  //   return success;
  // }
  //
  // Future<bool> setPermission(int? subscriberId, String? avatarLocalPath, {bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   Map<String, dynamic> newData = {
  //     'permissions': "",
  //   }; // TODO:GG topic data load
  //   bool success = await _subscriberStorage.setData(subscriberId, newData);
  //   if (success && notify) queryAndNotify(subscriberId);
  //   return success;
  // }
  //
  // Future queryAndNotify(int? subscriberId) async {
  //   if (subscriberId == null || subscriberId == 0) return;
  //   SubscriberSchema? updated = await _subscriberStorage.query(subscriberId);
  //   if (updated != null) {
  //     _updateSink.add(updated);
  //   }
  // }
}
