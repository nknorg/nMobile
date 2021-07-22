import 'dart:async';
import 'dart:typed_data';

import 'package:nmobile/common/settings.dart';
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

  /// ***********************************************************************************************************
  /// ********************************************** subscribers ************************************************
  /// ***********************************************************************************************************

  // caller = everyone, meta = isPrivate
  Future refreshSubscribers(
    String? topicName, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topicName == null || topicName.isEmpty) return [];

    List<SubscriberSchema> dbSubscribers = await queryListByTopic(topicName);
    List<SubscriberSchema> nodeSubscribers = await _clientGetSubscribers(topicName, offset: offset, limit: limit, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix);

    // delete DB data
    List<Future> futures = [];
    for (SubscriberSchema dbItem in dbSubscribers) {
      // filter in txPool
      int updateAt = dbItem.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - updateAt).abs() < Settings.txPoolDelayMs) {
        logger.i("$TAG - refreshSubscribers - dbSub update just now, maybe in tx pool - dbSub:$dbItem");
        continue;
      }
      // different with node in DB
      SubscriberSchema? findSubscriber;
      for (SubscriberSchema nodeItem in nodeSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findSubscriber = nodeItem;
          break;
        }
      }
      if (findSubscriber == null) {
        logger.i("$TAG - refreshSubscribers - dbSub delete because node no find - dbSub:$dbItem");
        futures.add(delete(dbItem.id, notify: true));
      } else {
        if (dbItem.status != findSubscriber.status) {
          if (findSubscriber.status == SubscriberStatus.Subscribed || findSubscriber.status == SubscriberStatus.Unsubscribed) {
            logger.i("$TAG - refreshSubscribers - dbSub set status sync node - dbSub:$dbItem - nodeSub:$findSubscriber");
            futures.add(setStatus(dbItem.id, findSubscriber.status, notify: true));
          } else if (findSubscriber.status == SubscriberStatus.InvitedReceipt && (dbItem.status ?? SubscriberStatus.None) > (findSubscriber.status ?? SubscriberStatus.None)) {
            logger.i("$TAG - refreshSubscribers - dbSub set receipt sync node - dbSub:$dbItem - nodeSub:$findSubscriber");
            futures.add(setStatus(dbItem.id, findSubscriber.status, notify: true));
          }
        } else if (dbItem.permPage != findSubscriber.permPage && findSubscriber.permPage != null) {
          logger.i("$TAG - refreshSubscribers - dbSub set permPage sync node - dbSub:$dbItem - nodeSub:$findSubscriber");
          futures.add(setPermPage(dbItem.id, findSubscriber.permPage, notify: true));
        }
      }
    }
    await Future.wait(futures);

    // insert node data
    futures.clear();
    for (SubscriberSchema nodeItem in nodeSubscribers) {
      // different with DB in node
      SubscriberSchema? findSubscriber;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findSubscriber = dbItem;
          break;
        }
      }
      if (findSubscriber == null) {
        logger.i("$TAG - refreshSubscribers - nodeSub add because DB no find - nodeSub:$nodeItem");
        SubscriberSchema? subscriber = SubscriberSchema.create(topicName, nodeItem.clientAddress, nodeItem.status);
        subscriber?.permPage = nodeItem.permPage;
        futures.add(add(subscriber, notify: true));
      }
    }
    await Future.wait(futures);
  }

  // caller = everyone
  Future<int> getSubscribersCount(String? topicName, {bool? isPrivate, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    int count = 0;
    if (isPrivate ?? isPrivateTopicReg(topicName)) {
      int count1 = await queryCountByTopic(topicName, status: SubscriberStatus.InvitedSend);
      int count2 = await queryCountByTopic(topicName, status: SubscriberStatus.InvitedReceipt);
      int count3 = await queryCountByTopic(topicName, status: SubscriberStatus.Subscribed);
      count = count1 + count2 + count3;
    } else {
      count = await this._clientGetSubscribersCount(topicName, subscriberHashPrefix: subscriberHashPrefix);
    }
    return count;
  }

  Future<List<SubscriberSchema>> _clientGetSubscribers(
    String? topicName, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topicName == null || topicName.isEmpty) return [];
    List<SubscriberSchema> list = [];

    try {
      // meta + subscribers
      Map<String, dynamic>? results = await clientCommon.client?.getSubscribers(
        topic: genTopicHash(topicName),
        offset: offset,
        limit: limit,
        meta: meta,
        txPool: txPool,
        subscriberHashPrefix: subscriberHashPrefix,
      );
      logger.d("$TAG - _clientGetSubscribers - results:$results");

      // subscribers
      List<SubscriberSchema> subscribers = [];
      results?.forEach((key, value) {
        if (key.isNotEmpty && !key.contains('.__permission__.')) {
          SubscriberSchema? item = SubscriberSchema.create(topicName, key, SubscriberStatus.None);
          if (item != null) subscribers.add(item);
        }
      });
      logger.d("$TAG - _clientGetSubscribers - subscribers:$subscribers");

      // metas
      List<SubscriberSchema> metas = [];
      bool _acceptAll = false;
      results?.forEach((key, value) {
        if (!_acceptAll && key.contains('.__permission__.')) {
          // permPage
          String prefix = key.split("__.__permission__.")[0];
          String permIndex = prefix.split("__")[prefix.split("__").length - 1];
          int permPage = int.tryParse(permIndex) ?? 0;
          // meta (same with subscription meta)
          Map<String, dynamic>? meta = jsonFormat(value);
          // accept
          List<dynamic> acceptList = meta?['accept'] ?? [];
          acceptList.forEach((element) {
            if (element is Map) {
              SubscriberSchema? item = SubscriberSchema.create(topicName, element["addr"], SubscriberStatus.InvitedReceipt);
              item?.permPage = permPage < 0 ? 0 : permPage;
              if (item != null) metas.add(item);
            } else if (element is String) {
              if (element.trim() == "*") {
                logger.i("$TAG - _clientGetSubscribers - accept all - accept:$element");
                _acceptAll = true;
              } else {
                logger.w("$TAG - _clientGetSubscribers - accept content error - accept:$element");
              }
            } else {
              logger.w("$TAG - _clientGetSubscribers - accept type error - accept:$element");
            }
          });
          // reject
          List<dynamic> rejectList = meta?['reject'] ?? [];
          rejectList.forEach((element) {
            if (element is Map) {
              SubscriberSchema? item = SubscriberSchema.create(topicName, element["addr"], SubscriberStatus.Unsubscribed);
              item?.permPage = permPage < 0 ? 0 : permPage;
              if (item != null) metas.add(item);
            } else {
              logger.w("$TAG - _clientGetSubscribers - reject type error - accept:$element");
            }
          });
        }
      });
      logger.d("$TAG - _clientGetSubscribers - metas:$metas");

      // merge
      if (_acceptAll) {
        list = subscribers;
      } else {
        for (int i = 0; i < subscribers.length; i++) {
          var subscriber = subscribers[i];
          for (int j = 0; j < metas.length; j++) {
            SubscriberSchema meta = metas[j];
            if (subscriber.clientAddress.isNotEmpty && subscriber.clientAddress == meta.clientAddress) {
              logger.d("$TAG - _clientGetSubscribers - sub + meta - meta:$meta");
              if (meta.status == SubscriberStatus.InvitedReceipt) meta.status = SubscriberStatus.Subscribed;
              list.add(meta);
              break;
            }
          }
        }
        List<SubscriberSchema> noFindMetas = [];
        for (int i = 0; i < metas.length; i++) {
          SubscriberSchema meta = metas[i];
          if (subscribers.where((element) => element.clientAddress.isNotEmpty && element.clientAddress == meta.clientAddress).toList().isEmpty) {
            logger.d("$TAG - _clientGetSubscribers - no find meta - meta:$meta");
            noFindMetas.add(meta);
          }
        }
        list.addAll(noFindMetas);
      }
      logger.d("$TAG - _clientGetSubscribers - list:$list");
    } catch (e) {
      handleError(e);
    }
    return list;
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

  /// ***********************************************************************************************************
  /// ************************************************** status *************************************************
  /// ***********************************************************************************************************

  // status: InvitedSend (caller = owner)
  Future<SubscriberSchema?> onInvitedSend(String? topicName, String? clientAddress, int? permPage) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.InvitedSend), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedSend && subscriber.status != SubscriberStatus.InvitedReceipt && subscriber.status != SubscriberStatus.Subscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.InvitedSend, notify: true);
      if (success) subscriber.status = SubscriberStatus.InvitedSend;
    }
    // permPage
    if (subscriber.permPage != permPage && permPage != null) {
      bool success = await setPermPage(subscriber.id, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    return subscriber;
  }

  // status: InvitedReceipt (caller = owner)
  Future<SubscriberSchema?> onInvitedReceipt(String? topicName, String? clientAddress, {int? permPage}) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.InvitedReceipt), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedReceipt && subscriber.status != SubscriberStatus.Subscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.InvitedReceipt, notify: true);
      if (success) subscriber.status = SubscriberStatus.InvitedReceipt;
    }
    // permPage
    if (subscriber.permPage != permPage && permPage != null) {
      bool success = await setPermPage(subscriber.id, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    return subscriber;
  }

  // status: Subscribed (caller = self + other)
  Future<SubscriberSchema?> onSubscribe(String? topicName, String? clientAddress, {int? permPage}) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.Subscribed), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.Subscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.Subscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Subscribed;
    }
    // permPage
    if (subscriber.permPage != permPage && permPage != null) {
      bool success = await setPermPage(subscriber.id, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    return subscriber;
  }

  // status: Unsubscribed (caller = self + other)
  Future<SubscriberSchema?> onUnsubscribe(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      logger.d("$TAG - onUnsubscribe - subscriber is null - topicName:$topicName - clientAddress:$clientAddress");
      return null;
    }
    // status
    if (subscriber.status != SubscriberStatus.Unsubscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.Unsubscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Unsubscribed;
    }
    // delete
    bool success = await delete(subscriber.id, notify: true);
    return success ? subscriber : null;
  }

  // status: Kick (caller = owner)
  Future<SubscriberSchema?> onKick(String? topicName, String? clientAddress) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      logger.d("$TAG - onKick - subscriber is null - topicName:$topicName - clientAddress:$clientAddress");
      return null;
    }
    // status
    if (subscriber.status != SubscriberStatus.Unsubscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.Unsubscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Unsubscribed;
    }
    // delete
    bool success = await delete(subscriber.id, notify: true);
    return success ? subscriber : null;
  }

  /// ***********************************************************************************************************
  /// ************************************************* common **************************************************
  /// ***********************************************************************************************************

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
    return added;
  }

  Future<bool> delete(int? subscriberId, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.delete(subscriberId);
    if (success && notify) _deleteSink.add(subscriberId);
    return success;
  }

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

  Future<List<SubscriberSchema>> queryListByTopicPerm(String? topic, int? permPage) {
    return _subscriberStorage.queryListByTopicPerm(topic, permPage);
  }

  Future<int> queryCountByTopic(String? topic, {int? status}) {
    return _subscriberStorage.queryCountByTopic(topic, status: status);
  }

  Future<int> queryCountByTopicPermPage(String? topic, int permPage, {int? status}) {
    return _subscriberStorage.queryCountByTopicPermPage(topic, permPage, status: status);
  }

  Future<int> queryMaxPermPageByTopic(String? topic) async {
    int mexPermPage = await _subscriberStorage.queryMaxPermPageByTopic(topic);
    mexPermPage = mexPermPage < 0 ? 0 : mexPermPage;
    int maxPageCount = await queryCountByTopicPermPage(topic, mexPermPage);
    if (maxPageCount > SubscriberSchema.PermPageSize) {
      mexPermPage++;
    }
    return mexPermPage;
  }

  Future<bool> setStatusAndPermPageByTopic(String? topic, int? status, int? permPage) async {
    if (topic == null || topic.isEmpty || status == null) return false;
    bool success = await _subscriberStorage.setStatusAndPermPageByTopic(topic, status, permPage);
    // if (success && notify) queryAndNotify(subscriberId);
    return success;
  }

  Future<bool> setStatus(int? subscriberId, int? status, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.setStatus(subscriberId, status);
    if (success && notify) queryAndNotify(subscriberId);
    return success;
  }

  Future<bool> setPermPage(int? subscriberId, int? permPage, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    if (permPage != null && permPage < 0) return false;
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
