import 'dart:async';
import 'dart:typed_data';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class SubscriberCommon with Tag {
  SubscriberStorage _subscriberStorage = SubscriberStorage();

  // ignore: close_sinks
  StreamController<SubscriberSchema> _addController = StreamController<SubscriberSchema>.broadcast();
  StreamSink<SubscriberSchema> get _addSink => _addController.sink;
  Stream<SubscriberSchema> get addStream => _addController.stream;

  // ignore: close_sinks
  // StreamController<int> _deleteController = StreamController<int>.broadcast();
  // StreamSink<int> get _deleteSink => _deleteController.sink;
  // Stream<int> get deleteStream => _deleteController.stream;

  // ignore: close_sinks
  StreamController<SubscriberSchema> _updateController = StreamController<SubscriberSchema>.broadcast();
  StreamSink<SubscriberSchema> get _updateSink => _updateController.sink;
  Stream<SubscriberSchema> get updateStream => _updateController.stream;

  static const int InitialAcceptStatus = SubscriberStatus.InvitedSend;
  static const int InitialRejectStatus = SubscriberStatus.Unsubscribed;

  SubscriberCommon();

  Future fetchSubscribersInfo(String? topic, {bool contact = true, bool deviceInfo = true}) async {
    if (topic == null || topic.isEmpty) return;
    int limit = 20;
    List<SubscriberSchema> subscribers = [];
    // query
    for (int offset = 0; true; offset += limit) {
      List<SubscriberSchema> result = await queryListByTopic(topic, offset: offset, limit: limit);
      subscribers.addAll(result);
      if (result.length < limit) break;
    }
    if (subscribers.isEmpty) return;
    // fetch
    for (var i = 0; i < subscribers.length; i++) {
      SubscriberSchema sub = subscribers[i];
      if (sub.clientAddress.isEmpty) continue;
      // contact
      ContactSchema? _contact = await contactCommon.queryByClientAddress(sub.clientAddress);
      if (_contact == null) {
        logger.d("$TAG - fetchSubscribersInfo - contact fetch ($i/${subscribers.length})- clientAddress:${sub.clientAddress}");
        _contact = await contactCommon.addByType(sub.clientAddress, ContactType.none, notify: true, checkDuplicated: false);
        await chatOutCommon.sendContactRequest(_contact?.clientAddress, RequestType.header, null);
      }
      // deviceInfo
      DeviceInfoSchema? _deviceInfo = await deviceInfoCommon.queryLatest(sub.clientAddress);
      if (_deviceInfo == null) {
        logger.d("$TAG - refreshSubscribers - deviceInfo fetch ($i/${subscribers.length}) - clientAddress:${sub.clientAddress}");
        _deviceInfo = await deviceInfoCommon.set(DeviceInfoSchema(contactAddress: sub.clientAddress));
        await chatOutCommon.sendDeviceRequest(_deviceInfo?.contactAddress);
      }
    }
  }

  /// ***********************************************************************************************************
  /// ********************************************** subscribers ************************************************
  /// ***********************************************************************************************************

  // caller = everyone, meta = isPrivate
  Future refreshSubscribers(
    String? topic, {
    String? ownerPubKey,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topic == null || topic.isEmpty) return [];

    List<SubscriberSchema> dbSubscribers = await queryListByTopic(topic);
    List<SubscriberSchema> nodeSubscribers = await _mergeSubscribersAndPermissionsFromNode(
      topic,
      ownerPubKey: ownerPubKey,
      meta: meta,
      txPool: txPool,
      subscriberHashPrefix: subscriberHashPrefix,
    );

    // delete/update DB data
    for (var i = 0; i < dbSubscribers.length; i++) {
      SubscriberSchema dbItem = dbSubscribers[i];
      if (dbItem.isPermissionProgress() != null) {
        logger.i("$TAG - refreshSubscribers - DB need try, skip - dbSub:$dbItem");
        continue;
      }
      SubscriberSchema? findInNode;
      for (SubscriberSchema nodeItem in nodeSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findInNode = nodeItem;
          break;
        }
      }
      // filter in txPool
      int createAt = dbItem.createAt ?? DateTime.now().millisecondsSinceEpoch;
      int updateAt = dbItem.updateAt ?? DateTime.now().millisecondsSinceEpoch;
      bool isCreateJustNow = (DateTime.now().millisecondsSinceEpoch - createAt) < Global.txPoolDelayMs;
      bool isUpdateJustNow = (DateTime.now().millisecondsSinceEpoch - updateAt) < Global.txPoolDelayMs;
      if (isCreateJustNow) {
        if (dbItem.status == SubscriberStatus.None) {
          logger.i("$TAG - refreshSubscribers - DB created just now, next by status none - dbSub:$dbItem");
        } else if (dbItem.status == SubscriberStatus.InvitedSend || dbItem.status == SubscriberStatus.InvitedReceipt) {
          if (findInNode?.status == SubscriberStatus.Subscribed) {
            logger.i("$TAG - refreshSubscribers - DB created just now, next bu subscribed - dbSub:$dbItem");
          } else {
            var betweenS = (DateTime.now().millisecondsSinceEpoch - updateAt) / 1000;
            logger.d("$TAG - refreshSubscribers - DB created just now, skip by invited - between:${betweenS}s - dbSub:$dbItem");
            continue;
          }
        } else {
          logger.i("$TAG - refreshSubscribers - DB created just now, maybe in tx pool - dbSub:$dbItem");
          continue;
        }
      } else if (isUpdateJustNow) {
        logger.i("$TAG - refreshSubscribers - DB updated just now, maybe in tx pool - dbSub:$dbItem");
        continue;
      } else {
        var betweenS = (DateTime.now().millisecondsSinceEpoch - updateAt) / 1000;
        logger.d("$TAG - refreshSubscribers - DB updated to long, so can next - between:${betweenS}s");
      }
      // different with node in DB
      if (findInNode == null) {
        if (dbItem.status != SubscriberStatus.None) {
          logger.i("$TAG - refreshSubscribers - DB delete because node no find - DB:$dbItem");
          await setStatus(dbItem.id, SubscriberStatus.None, notify: true);
        }
      } else {
        if (findInNode.status == SubscriberStatus.Unsubscribed) {
          logger.i("$TAG - refreshSubscribers - DB find, but node is unsubscribe - DB:$dbItem - node:$findInNode");
          if (dbItem.status != findInNode.status) {
            await setStatus(dbItem.id, findInNode.status, notify: true);
          }
        } else {
          // status
          if (dbItem.status != findInNode.status) {
            if (findInNode.status == SubscriberStatus.InvitedSend && dbItem.status == SubscriberStatus.InvitedReceipt) {
              logger.i("$TAG - refreshSubscribers - DB is receive invited so no update - DB:$dbItem - node:$findInNode");
            } else {
              logger.i("$TAG - refreshSubscribers - DB update to sync node - DB:$dbItem - node:$findInNode");
              await setStatus(dbItem.id, findInNode.status, notify: true);
            }
          } else {
            logger.d("$TAG - refreshSubscribers - DB same node - DB:$dbItem - node:$findInNode");
          }
          // prmPage
          if (dbItem.permPage != findInNode.permPage && findInNode.permPage != null) {
            logger.i("$TAG - refreshSubscribers - DB set permPage to sync node - DB:$dbItem - node:$findInNode");
            await setPermPage(dbItem.id, findInNode.permPage, notify: true);
          }
        }
      }
    }

    // insert node data
    for (var i = 0; i < nodeSubscribers.length; i++) {
      SubscriberSchema nodeItem = nodeSubscribers[i];
      bool findInDB = false;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.clientAddress == nodeItem.clientAddress) {
          findInDB = true;
          break;
        }
      }
      // different with DB in node
      if (!findInDB) {
        logger.i("$TAG - refreshSubscribers - node add because DB no find - nodeSub:$nodeItem");
        await add(nodeItem, notify: true); // no need batch
      }
    }
  }

  // caller = everyone, meta = isPrivate
  Future<List<SubscriberSchema>> _mergeSubscribersAndPermissionsFromNode(
    String? topic, {
    String? ownerPubKey,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
  }) async {
    if (topic == null || topic.isEmpty) return [];
    // subscribers(permission)
    Map<String, dynamic> noMergeResults = await _clientGetSubscribers(
      topic,
      meta: meta,
      txPool: txPool,
      subscriberHashPrefix: subscriberHashPrefix,
    );

    // subscribers(subscribe)
    List<SubscriberSchema> subscribers = [];
    noMergeResults.forEach((key, value) {
      if (key.isNotEmpty && !key.contains('.__permission__.')) {
        SubscriberSchema? item = SubscriberSchema.create(topic, key, SubscriberStatus.None, null);
        if (item != null) subscribers.add(item);
      }
    });

    // permissions
    List<dynamic> permissionsResult = [<SubscriberSchema>[], true];
    if (meta) {
      permissionsResult = await _getPermissionsFromNode(
        topic,
        clientGetSubscribers: noMergeResults,
        txPool: txPool,
        subscriberHashPrefix: subscriberHashPrefix,
      );
    }
    List<SubscriberSchema> permissions = permissionsResult[0];
    bool? _acceptAll = permissionsResult[1];

    // merge
    List<SubscriberSchema> results = [];
    if (!meta || _acceptAll == true) {
      results = subscribers.map((e) {
        e.status = SubscriberStatus.Subscribed;
        return e;
      }).toList();
    } else {
      for (int i = 0; i < subscribers.length; i++) {
        var subscriber = subscribers[i];
        if (ownerPubKey == getPubKeyFromTopicOrChatId(subscriber.clientAddress)) {
          subscriber.status = SubscriberStatus.Subscribed;
          results.add(subscriber);
          continue;
        }
        bool find = false;
        for (int j = 0; j < permissions.length; j++) {
          SubscriberSchema permission = permissions[j];
          if (subscriber.clientAddress.isNotEmpty && subscriber.clientAddress == permission.clientAddress) {
            logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - subscribers && permission - permission:$permission");
            if (permission.status == InitialAcceptStatus) {
              permission.status = SubscriberStatus.Subscribed;
            } else if (permission.status == InitialRejectStatus) {
              permission.status = SubscriberStatus.Unsubscribed;
            }
            results.add(permission);
            find = true;
            break;
          }
        }
        if (!find) {
          logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - no invited but in subscribe - subscriber:$subscriber");
          results.add(subscriber);
        }
      }
      for (int i = 0; i < permissions.length; i++) {
        SubscriberSchema permission = permissions[i];
        if (subscribers.where((element) => element.clientAddress.isNotEmpty && element.clientAddress == permission.clientAddress).toList().isEmpty) {
          if (ownerPubKey != getPubKeyFromTopicOrChatId(permission.clientAddress)) {
            logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - no subscribe but in permission - permission:$permission");
            results.add(permission);
          } else {
            logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - no subscribe but in permission (owner) - permission:$permission");
          }
        }
      }
    }
    logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - results:$results");
    return results;
  }

  /// ***********************************************************************************************************
  /// ********************************************** permission *************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<List<dynamic>> findPermissionFromNode(String? topic, bool isPrivate, String? clientAddress, {bool txPool = true}) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) {
      return [null, null, null, null];
    }
    if (!isPrivate) {
      logger.i("$TAG - findPermissionFromNode - isPrivate = false");
      return [null, true, true, false];
    }
    // permissions
    List<dynamic> result = await _getPermissionsFromNode(topic, txPool: txPool);
    List<SubscriberSchema> subscribers = result[0];
    bool? _acceptAll = result[1];
    if (_acceptAll == true) {
      logger.i("$TAG - findPermissionFromNode - acceptAll = true");
      return [null, _acceptAll, true, false];
    }
    // find
    List<SubscriberSchema> finds = subscribers.where((element) => element.clientAddress == clientAddress).toList();
    if (finds.isNotEmpty) {
      int? permPage = finds[0].permPage;
      bool isAccept = finds[0].status == InitialAcceptStatus;
      bool isReject = finds[0].status == InitialRejectStatus;
      logger.d("$TAG - findPermissionFromNode - permPage:$permPage - isAccept:$isAccept");
      return [permPage, false, isAccept, isReject];
    }
    logger.i("$TAG - findPermissionFromNode - null");
    return [null, _acceptAll, null, null];
  }

  Future<List<dynamic>> _getPermissionsFromNode(String? topic, {bool txPool = true, Uint8List? subscriberHashPrefix, Map<String, dynamic>? clientGetSubscribers}) async {
    if (topic == null || topic.isEmpty) return [[], null];
    // permissions + subscribers
    Map<String, dynamic> noMergeResults = clientGetSubscribers ??
        await _clientGetSubscribers(
          topic,
          meta: true,
          txPool: txPool,
          subscriberHashPrefix: subscriberHashPrefix,
        );

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
            SubscriberSchema? item = SubscriberSchema.create(topic, element["addr"], InitialAcceptStatus, permPage);
            if (item != null) permissions.add(item);
          } else if (element is String) {
            if (element.trim() == "*") {
              logger.i("$TAG - _getPermissionsFromNode - accept all - accept:$element");
              _acceptAll = true;
              break;
            } else {
              logger.w("$TAG - _getPermissionsFromNode - accept content error - accept:$element");
            }
          } else {
            logger.w("$TAG - _getPermissionsFromNode - accept type error - accept:$element");
          }
        }
        // reject
        List<dynamic> rejectList = meta?['reject'] ?? [];
        if (!_acceptAll) {
          rejectList.forEach((element) {
            if (element is Map) {
              SubscriberSchema? item = SubscriberSchema.create(topic, element["addr"], InitialRejectStatus, permPage);
              if (item != null) permissions.add(item);
            } else {
              logger.w("$TAG - _getPermissionsFromNode - reject type error - accept:$element");
            }
          });
        }
      }
    });
    logger.d("$TAG - _getPermissionsFromNode - acceptAll:$_acceptAll - permissions:$permissions");
    return [permissions, _acceptAll];
  }

  Future<Map<String, dynamic>> _clientGetSubscribers(
    String? topic, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
    Map<String, dynamic>? prefixResult,
  }) async {
    if (topic == null || topic.isEmpty) return prefixResult ?? Map();
    try {
      Map<String, dynamic>? results = await clientCommon.client?.getSubscribers(
        topic: genTopicHash(topic),
        offset: offset,
        limit: limit,
        meta: meta,
        txPool: txPool,
        subscriberHashPrefix: subscriberHashPrefix,
      );
      if (results?.isNotEmpty == true) {
        results?.addAll(prefixResult ?? Map());
        return _clientGetSubscribers(
          topic,
          offset: offset + limit,
          limit: limit,
          meta: meta,
          txPool: txPool,
          subscriberHashPrefix: subscriberHashPrefix,
          prefixResult: results,
        );
      }
      logger.d("$TAG - _clientGetSubscribers - offset:$offset - limit:$limit - results:$prefixResult");
    } catch (e) {
      handleError(e);
      return prefixResult ?? Map();
    }
    return prefixResult ?? Map();
  }

  /// ***********************************************************************************************************
  /// ************************************************** count **************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<int> getSubscribersCount(String? topic, bool isPrivate, {bool fetch = false, Uint8List? subscriberHashPrefix}) async {
    if (topic == null || topic.isEmpty) return 0;
    int count = 0;
    if (fetch) {
      count = await this._clientGetSubscribersCount(topic, subscriberHashPrefix: subscriberHashPrefix);
    } else if (isPrivate) {
      // count = (await _mergePermissionsAndSubscribers(topic, meta: true, txPool: true, subscriberHashPrefix: subscriberHashPrefix)).length;
      count = await queryCountByTopic(topic, status: SubscriberStatus.Subscribed); // maybe wrong but subscribers screen will check it
    } else {
      count = await queryCountByTopic(topic, status: SubscriberStatus.Subscribed); // maybe wrong but subscribers screen will check it
    }
    logger.d("$TAG - getSubscribersCount - topic:$topic - isPrivate:$isPrivate - count:$count");
    return count;
  }

  Future<int> _clientGetSubscribersCount(String? topic, {Uint8List? subscriberHashPrefix}) async {
    if (topic == null || topic.isEmpty) return 0;
    int? count;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        count = await clientCommon.client?.getSubscribersCount(
          topic: genTopicHash(topic),
          subscriberHashPrefix: subscriberHashPrefix,
        );
      }
    } catch (e) {
      handleError(e);
    }
    return count ?? 0;
  }

  /// ***********************************************************************************************************
  /// ************************************************** status *************************************************
  /// ***********************************************************************************************************

  // status: InvitedSend (caller = owner)
  Future<SubscriberSchema?> onInvitedSend(String? topic, String? clientAddress, int? permPage) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topic, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topic, clientAddress, SubscriberStatus.InvitedSend, permPage), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedSend) {
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
  Future<SubscriberSchema?> onInvitedReceipt(String? topic, String? clientAddress) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topic, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topic, clientAddress, SubscriberStatus.InvitedReceipt, null), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedReceipt) {
      bool success = await setStatus(subscriber.id, SubscriberStatus.InvitedReceipt, notify: true);
      if (success) subscriber.status = SubscriberStatus.InvitedReceipt;
    }
    return subscriber;
  }

  // status: Subscribed (caller = self + other)
  Future<SubscriberSchema?> onSubscribe(String? topic, String? clientAddress, int? permPage) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topic, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topic, clientAddress, SubscriberStatus.Subscribed, permPage), notify: true);
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
  Future<SubscriberSchema?> onUnsubscribe(String? topic, String? clientAddress, {int? permPage}) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topic, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topic, clientAddress, SubscriberStatus.Unsubscribed, permPage), notify: true);
    }
    if (subscriber == null) return null;
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
    // delete (just node sync can delete)
    // bool success = await delete(subscriber.id, notify: true);
    // return success ? subscriber : null;
    return subscriber;
  }

  // status: Kick (caller = owner)
  Future<SubscriberSchema?> onKickOut(String? topic, String? clientAddress, {int? permPage}) async {
    if (topic == null || topic.isEmpty || clientAddress == null || clientAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await queryByTopicChatId(topic, clientAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topic, clientAddress, SubscriberStatus.Unsubscribed, permPage), notify: true);
    }
    if (subscriber == null) return null;
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
    // delete (just node sync can delete)
    // bool success = await delete(subscriber.id, notify: true);
    // return success ? subscriber : null;
    return subscriber;
  }

  /// ***********************************************************************************************************
  /// ************************************************* common **************************************************
  /// ***********************************************************************************************************

  Future<SubscriberSchema?> add(SubscriberSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.topic.isEmpty) return null;
    if (checkDuplicated) {
      SubscriberSchema? exist = await queryByTopicChatId(schema.topic, schema.clientAddress);
      if (exist != null) {
        logger.i("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    SubscriberSchema? added = await _subscriberStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  // Future<bool> delete(int? subscriberId, {bool notify = false}) async {
  //   if (subscriberId == null || subscriberId == 0) return false;
  //   bool success = await _subscriberStorage.delete(subscriberId);
  //   if (success && notify) _deleteSink.add(subscriberId);
  //   return success;
  // }

  // Future<int> deleteByTopic(String? topic) async {
  //   if (topic == null || topic.isEmpty) return 0;
  //   int count = await _subscriberStorage.deleteByTopic(topic);
  //   return count;
  // }

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
    if (maxPageCount >= SubscriberSchema.PermPageSize) {
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

  Future<bool> setData(int? subscriberId, Map<String, dynamic>? newData, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await _subscriberStorage.setData(subscriberId, newData);
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
