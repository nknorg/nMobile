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
  /// ************************************************** count **************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<int> getSubscribersCount(String? topicName, {bool? isPrivate, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    int count = 0;
    if (isPrivate ?? isPrivateTopicReg(topicName)) {
      // count = (await _mergePermissionsAndSubscribers(topicName, meta: true, txPool: true, subscriberHashPrefix: subscriberHashPrefix)).length;
      count = await queryCountByTopic(topicName); // maybe wrong but subscribers screen will check it
    } else {
      count = await this._clientGetSubscribersCount(topicName, subscriberHashPrefix: subscriberHashPrefix);
    }
    logger.d("$TAG - getSubscribersCount - topicName:$topicName - isPrivate:${isPrivate ?? isPrivateTopicReg(topicName)} - count:$count");
    return count;
  }

  Future<int> _clientGetSubscribersCount(String? topicName, {Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    int? count;
    try {
      count = await clientCommon.client?.getSubscribersCount(
        topic: genTopicHash(topicName),
        subscriberHashPrefix: subscriberHashPrefix,
      );
    } catch (e) {
      handleError(e);
    }
    return count ?? 0;
  }

  /// ***********************************************************************************************************
  /// ********************************************** subscribers ************************************************
  /// ***********************************************************************************************************

  // caller = everyone, meta = isPrivate
  Future refreshSubscribers(String? topicName, {bool meta = false, bool txPool = true, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return [];

    List<SubscriberSchema> dbSubscribers = await queryListByTopic(topicName);
    List<SubscriberSchema> nodeSubscribers = await _mergePermissionsAndSubscribers(topicName, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix);

    // delete/update DB data
    List<Future> futures = [];
    for (SubscriberSchema dbItem in dbSubscribers) {
      // filter in txPool
      int updateAt = dbItem.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      if ((DateTime.now().millisecondsSinceEpoch - updateAt).abs() < Settings.txPoolDelayMs) {
        logger.i("$TAG - refreshSubscribers - DB update just now, maybe in tx pool - dbSub:$dbItem");
        continue;
      }
      SubscriberSchema? findNode;
      for (SubscriberSchema nodeItem in nodeSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findNode = nodeItem;
          break;
        }
      }
      // different with node in DB
      if (findNode == null) {
        logger.i("$TAG - refreshSubscribers - DB delete because node no find - DB:$dbItem");
        futures.add(delete(dbItem.id, notify: true));
      } else {
        if (dbItem.status != findNode.status) {
          if (findNode.status == SubscriberStatus.InvitedSend && dbItem.status == SubscriberStatus.InvitedReceipt) {
            logger.i("$TAG - refreshSubscribers - DB is receive invited so no update - DB:$dbItem - node:$findNode");
          } else {
            logger.i("$TAG - refreshSubscribers - DB set receipt to sync node - DB:$dbItem - node:$findNode");
            futures.add(setStatus(dbItem.id, findNode.status, notify: true));
          }
        } else if (dbItem.permPage != findNode.permPage && findNode.permPage != null) {
          logger.i("$TAG - refreshSubscribers - DB set permPage to sync node - DB:$dbItem - node:$findNode");
          futures.add(setPermPage(dbItem.id, findNode.permPage, notify: true));
        }
      }
    }
    await Future.wait(futures);

    // insert node data
    futures.clear();
    for (SubscriberSchema nodeItem in nodeSubscribers) {
      bool find = false;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          find = true;
          break;
        }
      }
      // different with DB in node
      if (!find) {
        logger.i("$TAG - refreshSubscribers - node add because DB no find - nodeSub:$nodeItem");
        futures.add(add(nodeItem, notify: true));
      }
    }
    await Future.wait(futures);
  }

  Future<List<SubscriberSchema>> _mergePermissionsAndSubscribers(String? topicName, {bool meta = false, bool txPool = true, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return [];
    // permissions + subscribers
    Map<String, dynamic> noMergeResults = await _clientGetSubscribers(topicName, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix);

    // subscribers
    List<SubscriberSchema> subscribers = [];
    noMergeResults.forEach((key, value) {
      if (key.isNotEmpty && !key.contains('.__permission__.')) {
        SubscriberSchema? item = SubscriberSchema.create(topicName, key, SubscriberStatus.None, null);
        if (item != null) subscribers.add(item);
      }
    });
    logger.d("$TAG - _mergePermissionsAndSubscribers - subscribers:$subscribers");

    // permissions
    List<SubscriberSchema> permissions = [];
    bool _acceptAll = false;
    noMergeResults.forEach((key, value) {
      if (!_acceptAll && key.contains('.__permission__.')) {
        // permPage
        String prefix = key.split("__.__permission__.")[0];
        String permIndex = prefix.split("__")[prefix.split("__").length - 1];
        int permPage = int.tryParse(permIndex) ?? 0;
        // meta (same with client_subscription[meta])
        Map<String, dynamic>? meta = jsonFormat(value);
        // accept
        List<dynamic> acceptList = meta?['accept'] ?? [];
        for (int i = 0; i < acceptList.length; i++) {
          var element = acceptList[i];
          if (element is Map) {
            SubscriberSchema? item = SubscriberSchema.create(topicName, element["addr"], SubscriberStatus.InvitedSend, permPage);
            if (item != null) permissions.add(item);
          } else if (element is String) {
            if (element.trim() == "*") {
              logger.i("$TAG - _mergePermissionsAndSubscribers - accept all - accept:$element");
              _acceptAll = true;
              break;
            } else {
              logger.w("$TAG - _mergePermissionsAndSubscribers - accept content error - accept:$element");
            }
          } else {
            logger.w("$TAG - _mergePermissionsAndSubscribers - accept type error - accept:$element");
          }
        }
        // reject
        List<dynamic> rejectList = meta?['reject'] ?? [];
        if (!_acceptAll) {
          rejectList.forEach((element) {
            if (element is Map) {
              SubscriberSchema? item = SubscriberSchema.create(topicName, element["addr"], SubscriberStatus.Unsubscribed, permPage);
              if (item != null) permissions.add(item);
            } else {
              logger.w("$TAG - _mergePermissionsAndSubscribers - reject type error - accept:$element");
            }
          });
        }
      }
    });
    logger.d("$TAG - _mergePermissionsAndSubscribers - permissions:$permissions");

    // merge
    List<SubscriberSchema> results = [];
    if (_acceptAll) {
      results = subscribers;
      results = results.map((e) {
        e.status = SubscriberStatus.Subscribed;
        return e;
      }).toList();
    } else {
      for (int i = 0; i < subscribers.length; i++) {
        var subscriber = subscribers[i];
        bool find = false;
        for (int j = 0; j < permissions.length; j++) {
          SubscriberSchema permission = permissions[j];
          if (subscriber.clientAddress.isNotEmpty && subscriber.clientAddress == permission.clientAddress) {
            logger.d("$TAG - _mergePermissionsAndSubscribers - subscribers && permission - permission:$permission");
            if (permission.status == SubscriberStatus.InvitedSend) {
              // same with up line accept status
              permission.status = SubscriberStatus.Subscribed;
            }
            results.add(permission);
            find = true;
            break;
          }
        }
        if (!find) {
          results.add(subscriber);
        }
      }
      List<SubscriberSchema> noFindMetas = [];
      for (int i = 0; i < permissions.length; i++) {
        SubscriberSchema permission = permissions[i];
        if (subscribers.where((element) => element.clientAddress.isNotEmpty && element.clientAddress == permission.clientAddress).toList().isEmpty) {
          logger.d("$TAG - _mergePermissionsAndSubscribers - subscribers !! permission - permission:$permission");
          if (permission.status != SubscriberStatus.Unsubscribed) {
            // same with up line reject status
            noFindMetas.add(permission);
          }
        }
      }
      results.addAll(noFindMetas);
    }
    logger.d("$TAG - _mergePermissionsAndSubscribers - results:$results");
    return results;
  }

  Future<Map<String, dynamic>> _clientGetSubscribers(
    String? topicName, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
    Map<String, dynamic>? prefixResult,
  }) async {
    if (topicName == null || topicName.isEmpty) return prefixResult ?? Map();
    Map<String, dynamic>? results = await clientCommon.client?.getSubscribers(
      topic: genTopicHash(topicName),
      offset: offset,
      limit: limit,
      meta: meta,
      txPool: txPool,
      subscriberHashPrefix: subscriberHashPrefix,
    );
    if (results?.isNotEmpty == true) {
      results?.addAll(prefixResult ?? Map());
      try {
        return _clientGetSubscribers(
          topicName,
          offset: offset + limit,
          limit: limit,
          meta: meta,
          txPool: txPool,
          subscriberHashPrefix: subscriberHashPrefix,
          prefixResult: results,
        );
      } catch (e) {
        handleError(e);
        return prefixResult ?? Map();
      }
    }
    logger.d("$TAG - _clientGetSubscribers - offset:$offset - limit:$limit - results:$prefixResult");
    return prefixResult ?? Map();
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
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.InvitedSend, permPage), notify: true);
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
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.InvitedReceipt, permPage), notify: true);
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
      subscriber = await add(SubscriberSchema.create(topicName, clientAddress, SubscriberStatus.Subscribed, permPage), notify: true);
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
  Future<SubscriberSchema?> onUnsubscribe(String? topicName, String? clientAddress, {int? permPage}) async {
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
    // permPage
    if (subscriber.permPage != permPage && permPage != null) {
      bool success = await setPermPage(subscriber.id, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    // delete
    bool success = await delete(subscriber.id, notify: true);
    return success ? subscriber : null;
  }

  // status: Kick (caller = owner)
  Future<SubscriberSchema?> onKickOut(String? topicName, String? clientAddress, {int? permPage}) async {
    if (topicName == null || topicName.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topicName, clientAddress);
    if (subscriber == null) {
      logger.d("$TAG - onKickOut - subscriber is null - topicName:$topicName - clientAddress:$clientAddress");
      return null;
    }
    // status
    if (subscriber.status != SubscriberStatus.Unsubscribed) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.Unsubscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Unsubscribed;
    }
    // permPage
    if (subscriber.permPage != permPage && permPage != null) {
      bool success = await setPermPage(subscriber.id, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
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
