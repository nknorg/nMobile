import 'dart:async';
import 'dart:typed_data';

import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../global.dart';
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
  Future<List<SubscriberSchema>> refreshSubscribers(
    String? topicName, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topicName == null || topicName.isEmpty) return [];
    List<Future> futures = [];

    List<SubscriberSchema> dbSubscribers = await queryListByTopic(topicName);
    List<SubscriberSchema> nodeSubscribers = await _clientGetSubscribers(topicName, offset: offset, limit: limit, meta: meta, txPool: txPool, subscriberHashPrefix: subscriberHashPrefix);

    // delete DB data
    for (SubscriberSchema dbItem in dbSubscribers) {
      // delete wrong subscriber
      if (dbItem.clientAddress.contains('.__permission__.')) {
        futures.add(queryByTopicChatId(topicName, dbItem.clientAddress).then((value) {
          if (value == null) return Future.value(null);
          logger.i("$TAG - refreshSubscribers - dbSub address contains permission - dbSub:$dbItem");
          return delete(value.id, notify: true);
        }));
        continue;
      }
      // filter not in txPool
      if (dbItem.updateAt != null && dbItem.updateAt! >= DateTime.now().subtract(Duration(seconds: 30)).millisecondsSinceEpoch) {
        logger.i("$TAG - refreshSubscribers - dbSub update just now - dbSub:$dbItem");
        continue;
      }
      // different with node in DB
      SubscriberSchema? findSubscriber;
      for (SubscriberSchema nodeItem in nodeSubscribers) {
        if (nodeItem.clientAddress.contains('.__permission__.')) {
          logger.d("$TAG - refreshSubscribers - dbSub handle later - dbSub:$nodeItem");
          continue;
        }
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findSubscriber = nodeItem;
          break;
        }
      }
      if (findSubscriber == null) {
        logger.i("$TAG - refreshSubscribers - dbSub deleted because node empty - dbSub:$dbItem");
        futures.add(delete(dbItem.id, notify: true));
      } else {
        if (dbItem.status != findSubscriber.status) {
          logger.i("$TAG - refreshSubscribers - dbSub set status sync node - dbSub:$dbItem - nodeSub:$findSubscriber");
          futures.add(setStatus(dbItem.id, findSubscriber.status, notify: true));
        }
      }
    }

    // insert node data
    for (SubscriberSchema nodeItem in nodeSubscribers) {
      // permission
      if (nodeItem.clientAddress.contains('.__permission__.')) {
        if (nodeItem.data == null || nodeItem.data!.isEmpty) {
          logger.w("$TAG - refreshSubscribers - nodeSub temp_meta is null - nodeSub:$nodeItem");
          continue;
        }
        futures.add(refreshSubscribersByMeta(topicName, nodeItem.data, permPage: nodeItem.permPage ?? 0));
        continue;
      }

      // different with DB in node
      SubscriberSchema? findSubscriber;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findSubscriber = dbItem;
          break;
        }
      }
      if (findSubscriber == null) {
        logger.i("$TAG - refreshSubscribers - nodeSub added because DB empty - nodeSub:$nodeItem");
        futures.add(add(SubscriberSchema.create(topicName, nodeItem.clientAddress, nodeItem.status), notify: true));
      }
    }

    Future.wait(futures);
    return await queryListByTopic(topicName, offset: offset, limit: limit);
  }

  // caller = everyone
  Future<int> getSubscribersCount(String? topicName, {bool? isPrivate, Uint8List? subscriberHashPrefix}) async {
    if (topicName == null || topicName.isEmpty) return 0;
    bool isPublic = !(isPrivate ?? isPrivateTopicReg(topicName));

    int count = 0;
    if (isPublic) {
      count = await this._clientGetSubscribersCount(topicName, subscriberHashPrefix: subscriberHashPrefix);
    } else {
      count = await this._clientGetSubscribersCount(topicName, subscriberHashPrefix: subscriberHashPrefix);
      // TODO:GG 到底准不准
      // count = await this.queryCountByTopic(topicName);
      // logger.i("$TAG - getSubscribersCount - node:$test - DB:$count");
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

      results?.forEach((key, value) {
        if (key.contains('.__permission__.')) {
          String prefix = key.split("__.__permission__.")[0];
          String permIndex = prefix.split("__")[prefix.split("__").length - 1];
          int permPage = int.tryParse(permIndex) ?? 0;
          SubscriberSchema? item = SubscriberSchema.create(topicName, key, SubscriberStatus.None);
          item?.permPage = permPage < 0 ? 0 : permPage;
          item?.data = jsonFormat(value);
          if (item != null) subscribers.add(item);
        } else {
          SubscriberSchema? item;
          if (meta) {
            item = SubscriberSchema.create(topicName, key, SubscriberStatus.Subscribed);
          } else {
            item = SubscriberSchema.create(topicName, key, SubscriberStatus.None);
          }
          if (item != null) subscribers.add(item);
        }
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

  /// ***********************************************************************************************************
  /// ************************************************** status *************************************************
  /// ***********************************************************************************************************

  // status: InvitedSend (caller = owner)
  Future<SubscriberSchema?> onInvitedSend(String? topicName, String? clientAddress) async {
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
    int appendPermPage = await queryMaxPermPageByTopic(topicName);
    if (subscriber.permPage != appendPermPage) {
      bool success = await setPermPage(subscriber.id, appendPermPage, notify: true);
      if (success) subscriber.permPage = appendPermPage;
    }
    // meta_permission(owner)
    Map<String, dynamic>? meta = await getPermissionsMetaByPage(topicName, subscriber, appendPermPage: appendPermPage);
    bool joinSuccess = await topicCommon.clientSubscribe(
      topicName,
      height: Global.topicDefaultSubscribeHeight,
      fee: 0,
      permissionPage: appendPermPage,
      meta: meta,
    );
    // check
    if (!joinSuccess) {
      await delete(subscriber.id, notify: true);
      return null;
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

  // status: Subscribed (caller = everyone)
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

  // status: Unsubscribed (caller = everyone)
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

  /// ***********************************************************************************************************
  /// ************************************************ permission ***********************************************
  /// ***********************************************************************************************************

  // caller = everyone, meta = subscription.meta(owner) / subscribers[x](everyone)
  Future refreshSubscribersByMeta(String? topicName, Map<String, dynamic>? meta, {int permPage = 0}) {
    if (topicName == null || topicName.isEmpty || meta == null || meta.isEmpty) return Future.value(null);
    List<Future> futures = [];

    List<dynamic> accepts = meta["accept"] ?? [];
    List<dynamic> rejects = meta["reject"] ?? [];
    if (accepts.isEmpty && rejects.isEmpty) {
      logger.w("$TAG - refreshSubscribersByMeta - meta is null - meta:$meta");
      return Future.value(null);
    }

    // accept
    for (dynamic accept in accepts) {
      if (accept is Map<String, String>) {
        if (accept.isNotEmpty == true) {
          String? address = accept["addr"];
          if (address == null || address.isEmpty || address.length < 64 || address.contains(".__permission__.")) {
            logger.w("$TAG - refreshSubscribersByMeta - accept address is wrong - accept:$accept");
            continue;
          }
          futures.add(queryByTopicChatId(topicName, address).then((value) {
            if (value?.isSubscribed != true) {
              return onSubscribe(topicName, address, permPage: permPage);
            } else if (value?.permPage != permPage) {
              return setPermPage(value?.id, permPage, notify: true);
            }
          }));
        } else {
          logger.w("$TAG - refreshSubscribersByMeta - accept is empty - accept:$accept");
        }
      } else if (accept is String) {
        if (accept.trim() == "*") {
          logger.i("$TAG - refreshSubscribersByMeta - accept all - accept:$accept");
          futures.add(setStatusAndPermPageByTopic(topicName, SubscriberStatus.Subscribed, null));
          break;
        } else {
          logger.w("$TAG - refreshSubscribersByMeta - accept content error - accept:$accept");
        }
      } else {
        logger.w("$TAG - refreshSubscribersByMeta - accept type error - accept:$accept");
      }
    }

    // reject
    for (dynamic reject in rejects) {
      if (reject is Map<String, String>) {
        if (reject.isNotEmpty == true) {
          String? address = reject["addr"];
          if (address == null || address.isEmpty || address.length < 64 || address.contains(".__permission__.")) {
            logger.w("$TAG - refreshSubscribersByMeta - reject address is wrong - reject:$reject");
            continue;
          }
          queryByTopicChatId(topicName, address).then((value) {
            if (value?.isSubscribed == true) {
              return onUnsubscribe(topicName, address, permPage: permPage);
            } else if (value?.permPage != permPage) {
              return setPermPage(value?.id, permPage, notify: true);
            }
          });
        } else {
          logger.w("$TAG - refreshSubscribersByMeta - reject is empty - reject:$reject");
        }
      } else {
        logger.w("$TAG - refreshSubscribersByMeta - reject type error - reject:$reject");
      }
    }

    return Future.wait(futures);
  }

  // caller = everyone
  Future<Map<String, dynamic>?> getPermissionsMetaByPage(String? topicName, SubscriberSchema? append, {int? appendPermPage}) async {
    if (topicName == null || topicName.isEmpty || append == null) return null;
    // appendPermPage
    if (appendPermPage == null) {
      appendPermPage = await queryMaxPermPageByTopic(topicName);
      logger.d("$TAG - getPermissionsMetaByPage - get max perm page - appendPermPage:$appendPermPage");
    }

    // me
    if (append.permPage != appendPermPage) {
      bool success = await setPermPage(append.id, appendPermPage, notify: true);
      if (success) append.permPage = appendPermPage;
    }

    // subscribers
    List<SubscriberSchema> subscribers = await queryListByTopicPerm(topicName, appendPermPage);
    List<SubscriberSchema> finds = subscribers.where((element) => element.clientAddress == append.clientAddress).toList();
    if (finds.isEmpty) subscribers.add(append);

    // meta
    List<Map<String, String>> acceptList = [];
    List<Map<String, String>> rejectList = [];
    subscribers.forEach((element) {
      int? _status = element.status;
      if (_status == SubscriberStatus.InvitedSend || _status == SubscriberStatus.InvitedReceipt || _status == SubscriberStatus.Subscribed) {
        acceptList.add({'addr': element.clientAddress});
      } else {
        rejectList.add({'addr': element.clientAddress});
      }
    });
    Map<String, dynamic> meta = Map();
    meta['accept'] = acceptList;
    meta['reject'] = rejectList;

    logger.i("$TAG - _getPermissionMeta - meta:${meta.toString()}");
    return meta;
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
