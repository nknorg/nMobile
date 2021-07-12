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

  // TODO:GG call
  Future getSubscribers() async {
    // TODO:GG 根据subscribers表的成员来校准？
  }

  // TODO:GG call
  Future getSubscribersCount() async {
    // TODO:GG 根据subscribers表的成员来校准？
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

  // TODO:GG call
  Future<SubscriberSchema?> add(SubscriberSchema? schema, {bool checkDuplicated = true}) async {
    if (schema == null || schema.topic.isEmpty) return null;
    if (checkDuplicated) {
      SubscriberSchema? exist = await queryByTopicChatId(schema.topic, schema.clientAddress);
      if (exist != null) {
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    SubscriberSchema? added = await _subscriberStorage.insert(schema);
    if (added != null) _addSink.add(added);
    return added;
  }

  // TODO:GG call
  Future<bool> delete(int? subscriberId, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool deleted = await _subscriberStorage.delete(subscriberId);
    if (deleted) _deleteSink.add(subscriberId);
    return deleted;
  }

  Future<SubscriberSchema?> query(int? subscriberId) {
    return _subscriberStorage.query(subscriberId);
  }

  Future<SubscriberSchema?> queryByTopicChatId(String? topic, String? chatId) async {
    if (topic == null || topic.isEmpty || chatId == null || chatId.isEmpty) return null;
    return await _subscriberStorage.queryByTopicChatId(topic, chatId);
  }

  Future<List<SubscriberSchema>> queryList(String? topic, {int? statue, String? orderBy, int? offset, int? limit}) {
    return _subscriberStorage.queryListByTopic(topic, status: statue, orderBy: orderBy, offset: offset, limit: limit);
  }

  // TODO:GG call
  Future<bool> setStatus(int? subscriberId, int? status, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.setStatus(subscriberId, status);
    if (success && notify) queryAndNotify(subscriberId);
    return success;
  }

  // TODO:GG call
  Future<bool> setPermPage(int? subscriberId, int? permPage, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.setPermPage(subscriberId, permPage);
    if (success && notify) queryAndNotify(subscriberId);
    return success;
  }

  Future queryAndNotify(int? subscriberId) async {
    if (subscriberId == null || subscriberId == 0) return;
    SubscriberSchema? updated = await _subscriberStorage.query(subscriberId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
