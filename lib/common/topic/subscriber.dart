import 'dart:async';
import 'dart:typed_data';

import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
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

  Future onInvitee(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return;
    // db exist
    TopicSchema? exists = await topicCommon.queryByTopic(topicName);
    if (exists == null) {
      logger.w("$TAG - onInvitee - empty - schema:$exists");
      return;
    }
    if (exists.isPrivate == true && exists.isOwner(clientCommon.address) == true) {
      // TODO:GG topic + subers permissions
    }
  }

  Future<SubscriberSchema?> onSubscribe(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // db
    SubscriberSchema? subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      SubscriberSchema? subscriber = SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.Subscribed);
      subscriberCommon.add(subscriber, notify: true); // await
    }
    if (subscriber == null) return null;
    // status + perm
    if (subscriber.status != SubscriberStatus.Subscribed) {
      bool success = await subscriberCommon.setStatus(subscriber.id, SubscriberStatus.Subscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Subscribed;
      // TODO:GG subers  permission(owner)
    }
    return subscriber;
  }

  Future<SubscriberSchema?> onUnsubscribe(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    SubscriberSchema? subscriber = await subscriberCommon.queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) return null;
    // TODO:GG subers  permission(owner)
    bool success = await delete(subscriber.id, notify: true);
    return success ? subscriber : null;
  }

  Future<List<SubscriberSchema>> refreshSubscribers(
    String? topicName, {
    // bool checkJoined = false,
    int offset = 0,
    int limit = 1000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    List<SubscriberSchema> dbSubscribers = await queryListByTopic(topicName);
    List<SubscriberSchema> nodeSubscribers = await _clientGetSubscribers(
      topicName,
      offset: offset,
      limit: limit,
      meta: meta,
      txPool: txPool,
      subscriberHashPrefix: subscriberHashPrefix,
    );

    // delete DB data
    for (SubscriberSchema dbItem in dbSubscribers) {
      bool dbFindInNode = false;
      for (SubscriberSchema nodeItem in nodeSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          dbFindInNode = true;
          break;
        }
      }
      if (!dbFindInNode) {
        await delete(dbItem.id, notify: true);
      }
    }

    // insert node data
    for (SubscriberSchema nodeItem in nodeSubscribers) {
      bool nodeFindInDB = false;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          nodeFindInDB = true;
          break;
        }
      }
      if (!nodeFindInDB) {
        await add(SubscriberSchema.create(topicName, nodeItem.clientAddress, nodeItem.status), notify: true);
      }
    }

    return await queryListByTopic(topicName, offset: offset, limit: limit);
  }

  Future<int> getSubscribersCount(String? topicName, {bool? isPrivate, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    bool isPublic = !(isPrivate ?? isPrivateTopicReg(topicName));

    int count = 0;
    if (isPublic) {
      count = await this._clientGetSubscribersCount(topicName);
    } else {
      count = await this._clientGetSubscribersCount(topicName);
      // count = await this.queryCountByTopic(topicName);
      // logger.i("$TAG - getSubscribersCount - node:$test - DB:$count");
    }
    return count;
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
        meta: true,
        txPool: txPool,
        subscriberHashPrefix: subscriberHashPrefix,
      );
      logger.d("$TAG - _clientGetSubscribers - results:$results");
      results?.forEach((key, value) {
        var item = SubscriberSchema.create(topicName, key, SubscriberStatus.None); // TODO:GG subers ?? status + other
        if (item != null) subscribers.add(item);
      });
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

  Future<SubscriberSchema?> add(SubscriberSchema? schema, {bool topicCountCheck = true, bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.topic.isEmpty) return null;
    if (checkDuplicated) {
      SubscriberSchema? exist = await queryByTopicChatId(schema.topic, schema.clientAddress);
      if (exist != null) {
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    SubscriberSchema? added = await _subscriberStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);

    // topic count
    if (topicCountCheck) {
      topicCommon.queryByTopic(schema.topic).then((value) async {
        if (value != null) {
          // int count = await getSubscribersCount(schema.topic);
          // if (value.count != count) {
          //   topicCommon.setCount(value.id, count); // await
          // }
        }
      });
    }
    return added;
  }

  // TODO:GG call
  Future<bool> delete(int? subscriberId, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.delete(subscriberId);
    if (success && notify) _deleteSink.add(subscriberId);
    return success;
  }

  // TODO:GG call
  Future<int> deleteByTopic(String? topic) async {
    if (topic == null || topic.isEmpty) return 0;
    int count = await _subscriberStorage.deleteByTopic(topic);
    return count;
  }

  Future<SubscriberSchema?> query(int? subscriberId) {
    return _subscriberStorage.query(subscriberId);
  }

  Future<SubscriberSchema?> queryByTopicChatId(String? topic, String? chatId) async {
    if (topic == null || topic.isEmpty || chatId == null || chatId.isEmpty) return null;
    return await _subscriberStorage.queryByTopicChatId(topic, chatId);
  }

  Future<List<SubscriberSchema>> queryListByTopic(String? topic, {int? status, String? orderBy, int? offset, int? limit}) {
    return _subscriberStorage.queryListByTopic(topic, status: status, orderBy: orderBy, offset: offset, limit: limit);
  }

  // TODO:GG call
  Future<List<SubscriberSchema>> queryListByTopicPerm(String? topic, int? permPage) {
    return _subscriberStorage.queryListByTopicPerm(topic, permPage);
  }

  // TODO:GG call
  Future<int> queryCountByTopic(String? topic, {int? status}) {
    return _subscriberStorage.queryCountByTopic(topic, status: status);
  }

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
    SubscriberSchema? updated = await query(subscriberId);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
