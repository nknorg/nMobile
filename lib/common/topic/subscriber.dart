import 'dart:async';

import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';

class SubscriberCommon with Tag {
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

  /// ***********************************************************************************************************
  /// ********************************************** subscribers ************************************************
  /// ***********************************************************************************************************

  // caller = everyone
  Future<int> getSubscribersCount(String? topicId, bool isPrivate, {bool fetch = false}) async {
    if (topicId == null || topicId.isEmpty) return 0;
    int? count;
    if (fetch) count = await RPC.getSubscribersCount(topicId); // just subscribe and no permission
    if ((count == null) || (count <= 0)) {
      if (isPrivate) {
        // count = (await _mergePermissionsAndSubscribers(topic, meta: true, txPool: true)).length;
        count = await queryCountByTopicId(topicId, status: SubscriberStatus.Subscribed); // maybe wrong but subscribers screen will check it
      } else {
        count = await queryCountByTopicId(topicId, status: SubscriberStatus.Subscribed); // maybe wrong but subscribers screen will check it
      }
    }
    logger.d("$TAG - getSubscribersCount - count:$count - topicId:$topicId - isPrivate:$isPrivate");
    return count;
  }

  // caller = everyone, meta = isPrivate
  Future refreshSubscribers(String? topicId, String? ownerPubKey, {bool meta = false, bool txPool = true}) async {
    if (topicId == null || topicId.isEmpty) return [];
    // db
    int limit = 20;
    List<SubscriberSchema> dbSubscribers = [];
    for (int offset = 0; true; offset += limit) {
      List<SubscriberSchema> result = await queryListByTopicId(topicId, offset: offset, limit: limit);
      dbSubscribers.addAll(result);
      if (result.length < limit) break;
    }
    // node
    List<SubscriberSchema>? nodeSubscribers = await _mergeSubscribersAndPermissionsFromNode(topicId, ownerPubKey, meta: meta, txPool: txPool);
    if (nodeSubscribers == null) {
      logger.w("$TAG - refreshSubscribers - nodeSubscribers = null - topicId:$topicId");
      return;
    }
    logger.d("$TAG - refreshSubscribers - topicId:$topicId - mete:${!meta} - txPool:$txPool - db_count:${dbSubscribers.length} - node_count:${nodeSubscribers.length}");
    // delete/update DB data
    for (var i = 0; i < dbSubscribers.length; i++) {
      SubscriberSchema dbItem = dbSubscribers[i];
      if (dbItem.isPermissionProgress() != null) {
        logger.i("$TAG - refreshSubscribers - DB is progress, skip - status:${dbItem.isPermissionProgress()} - data:${dbItem.data} - dbSub:$dbItem");
        continue;
      }
      SubscriberSchema? nodeItem;
      for (SubscriberSchema item in nodeSubscribers) {
        if (dbItem.contactAddress == item.contactAddress) {
          logger.d("$TAG - refreshSubscribers - start check db_item - status:${item.status} - perm:${item.permPage} - subscriber:$dbItem");
          nodeItem = item;
          break;
        }
      }
      // filter in txPool
      var createGap = DateTime.now().millisecondsSinceEpoch - (dbItem.createAt ?? 0);
      var updateGap = DateTime.now().millisecondsSinceEpoch - (dbItem.updateAt ?? 0);
      if (createGap < Settings.gapTxPoolUpdateDelayMs) {
        if (dbItem.status == SubscriberStatus.None) {
          logger.d("$TAG - refreshSubscribers - DB created just now, next by status none - status:${dbItem.status} - perm:${dbItem.permPage} - dbSub:$dbItem");
        } else if ((dbItem.status == SubscriberStatus.InvitedSend) || (dbItem.status == SubscriberStatus.InvitedReceipt)) {
          if (nodeItem?.status == SubscriberStatus.Subscribed) {
            logger.d("$TAG - refreshSubscribers - DB created just now, next bu subscribed - status:${dbItem.status} - perm:${dbItem.permPage} - dbSub:$dbItem");
          } else {
            logger.i("$TAG - refreshSubscribers - DB created just now, skip by invited - gap:$createGap<${Settings.gapTxPoolUpdateDelayMs} - status:${dbItem.status} - perm:${dbItem.permPage} - dbSub:$dbItem");
            continue;
          }
        } else {
          logger.i("$TAG - refreshSubscribers - DB created just now, maybe in tx pool - gap:$createGap<${Settings.gapTxPoolUpdateDelayMs} - status:${dbItem.status} - perm:${dbItem.permPage} - dbSub:$dbItem");
          continue;
        }
      } else if (updateGap < Settings.gapTxPoolUpdateDelayMs) {
        logger.i("$TAG - refreshSubscribers - DB updated just now, maybe in tx pool - gap:$updateGap<${Settings.gapTxPoolUpdateDelayMs} - status:${dbItem.status} - perm:${dbItem.permPage} - dbSub:$dbItem");
        continue;
      } else {
        logger.v("$TAG - refreshSubscribers - DB updated to long, so can next");
      }
      // different with node in DB
      if (nodeItem == null) {
        if (dbItem.status != SubscriberStatus.None) {
          logger.w("$TAG - refreshSubscribers - DB delete because node no find - DB:$dbItem");
          await setStatus(dbItem.topicId, dbItem.contactAddress, SubscriberStatus.None, notify: true);
        }
      } else {
        if (dbItem.status == nodeItem.status) {
          logger.v("$TAG - refreshSubscribers - DB same node - DB:$dbItem - node:$nodeItem");
        } else {
          if ((nodeItem.status == SubscriberStatus.InvitedSend) && (dbItem.status == SubscriberStatus.InvitedReceipt)) {
            logger.i("$TAG - refreshSubscribers - DB is receive invited so no update - DB:$dbItem - node:$nodeItem");
          } else {
            logger.w("$TAG - refreshSubscribers - DB update to sync node - status:${dbItem.status}!=${nodeItem.status} - DB:$dbItem - node:$nodeItem");
            await setStatus(dbItem.topicId, dbItem.contactAddress, nodeItem.status, notify: true);
          }
        }
        // prmPage
        if ((dbItem.permPage != nodeItem.permPage) && (nodeItem.permPage != null)) {
          logger.w("$TAG - refreshSubscribers - DB set permPage to sync node - perm:${dbItem.permPage}!=${nodeItem.permPage} - DB:$dbItem - node:$nodeItem");
          await setPermPage(dbItem.topicId, dbItem.contactAddress, nodeItem.permPage, notify: true);
        }
      }
    }
    // insert node data
    for (var i = 0; i < nodeSubscribers.length; i++) {
      SubscriberSchema nodeItem = nodeSubscribers[i];
      bool findInDB = false;
      for (SubscriberSchema dbItem in dbSubscribers) {
        if (dbItem.contactAddress == nodeItem.contactAddress) {
          findInDB = true;
          break;
        }
      }
      // different with DB in node
      if (!findInDB) {
        logger.w("$TAG - refreshSubscribers - node add because DB no find - status:${nodeItem.status} - perm:${nodeItem.permPage} - nodeSub:$nodeItem");
        await add(nodeItem, notify: true); // no need batch
      }
    }
  }

  // caller = everyone, meta = isPrivate
  Future<List<SubscriberSchema>?> _mergeSubscribersAndPermissionsFromNode(String? topicId, String? ownerPubKey, {bool meta = false, bool txPool = true}) async {
    if (topicId == null || topicId.isEmpty) return null;
    // subscribers(subscribe + permission)
    Map<String, dynamic>? metas = await RPC.getSubscribers(topicId, meta: meta, txPool: txPool);
    if (metas == null) {
      logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - metas = null - topicId:$topicId");
      return null;
    }
    // subscribers(subscribe)
    List<SubscriberSchema> subscribers = [];
    metas.forEach((key, value) {
      if (key.isNotEmpty && !key.contains('.__permission__.')) {
        SubscriberSchema? item = SubscriberSchema.create(topicId, key, SubscriberStatus.None, null);
        if (item != null) subscribers.add(item);
      }
    });
    // permissions
    bool? _acceptAll = true;
    List<SubscriberSchema>? permissions = [];
    if (meta) {
      List<dynamic> permissionsResult = await _getPermissionsFromNode(topicId, txPool: txPool, metas: metas);
      _acceptAll = permissionsResult[0];
      permissions = permissionsResult[1];
      if ((_acceptAll == null) || (permissions == null)) {
        logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - _acceptAll = null - topicId:$topicId");
        return null;
      }
    }
    logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - topicId:$topicId - mete:${!meta} - acceptAll:$_acceptAll - subscribers_count:${subscribers.length} - permissions_count:${permissions.length}");
    // merge
    List<SubscriberSchema> results = [];
    if (!meta || (_acceptAll == true)) {
      results = subscribers.map((e) {
        e.status = SubscriberStatus.Subscribed;
        return e;
      }).toList();
    } else {
      for (int i = 0; i < subscribers.length; i++) {
        var subscriber = subscribers[i];
        if (ownerPubKey == subscriber.pubKey) {
          logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - owner be find - subscriber:$subscriber");
          subscriber.status = SubscriberStatus.Subscribed;
          results.add(subscriber);
          continue;
        }
        bool find = false;
        for (int j = 0; j < permissions.length; j++) {
          SubscriberSchema permission = permissions[j];
          if (subscriber.contactAddress.isNotEmpty && (subscriber.contactAddress == permission.contactAddress)) {
            if (permission.status == InitialAcceptStatus) {
              permission.status = SubscriberStatus.Subscribed;
            } else if (permission.status == InitialRejectStatus) {
              permission.status = SubscriberStatus.Unsubscribed;
            }
            logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - subscribers && permission - status:${permission.status} - permission:$permission");
            results.add(permission);
            find = true;
            break;
          }
        }
        if (!find) {
          logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - no permission but in subscribe - status:${subscriber.status} - subscriber:$subscriber");
          results.add(subscriber); // status == None
        }
      }
      for (int i = 0; i < permissions.length; i++) {
        SubscriberSchema permission = permissions[i];
        if (subscribers.where((element) => element.contactAddress.isNotEmpty && (element.contactAddress == permission.contactAddress)).toList().isEmpty) {
          if (ownerPubKey != permission.pubKey) {
            logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - no subscribe but in permission - status:${permission.status} - permission:$permission");
            results.add(permission); // status == InitialAcceptStatus/InitialRejectStatus
          } else {
            logger.w("$TAG - _mergeSubscribersAndPermissionsFromNode - owner no subscribe but in permission - status:${permission.status} - permission:$permission");
          }
        }
      }
    }
    List<int?> statusList = results.map((e) => e.status).toList();
    List<int?> permList = results.map((e) => e.permPage).toList();
    List<String?> addressList = results.map((e) => e.contactAddress).toList();
    logger.d("$TAG - _mergeSubscribersAndPermissionsFromNode - topicId:$topicId - mete:${!meta} - acceptAll:$_acceptAll - subscribers_count:${subscribers.length} - permissions_count:${permissions.length} - result_status:$statusList - result_perm:$permList - result_address:$addressList");
    return results;
  }

  /// ***********************************************************************************************************
  /// ********************************************** permission *************************************************
  /// ***********************************************************************************************************

  // caller = everyone, result = [acceptAll, permPage, accept, reject]
  @Deprecated('Replace by PrivateGroup')
  Future<List<dynamic>> findPermissionFromNode(String? topicId, String? contactAddress, {bool txPool = true}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) {
      return [null, null, null, null];
    }
    // permissions
    List<dynamic> permissionsResult = await _getPermissionsFromNode(topicId, txPool: txPool);
    bool? _acceptAll = permissionsResult[0];
    List<SubscriberSchema>? permissions = permissionsResult[1];
    if ((_acceptAll == null) || (permissions == null)) {
      logger.w("$TAG - findPermissionFromNode - acceptAll is null - topicId:$topicId");
      return [null, null, true, false];
    } else if (_acceptAll == true) {
      logger.d("$TAG - findPermissionFromNode - acceptAll = true - topicId:$topicId");
      return [_acceptAll, null, true, false];
    }
    // find
    List<SubscriberSchema> finds = permissions.where((element) => element.contactAddress == contactAddress).toList();
    if (finds.isNotEmpty) {
      int? permPage = finds[0].permPage;
      bool isAccept = finds[0].status == InitialAcceptStatus;
      bool isReject = finds[0].status == InitialRejectStatus;
      logger.d("$TAG - findPermissionFromNode - topicId:$topicId - permPage:$permPage - isAccept:$isAccept - isReject:$isReject");
      return [_acceptAll, permPage, isAccept, isReject];
    }
    logger.d("$TAG - findPermissionFromNode - no find - topicId:$topicId");
    return [_acceptAll, null, null, null];
  }

  @Deprecated('Replace by PrivateGroup')
  Future<List<dynamic>> _getPermissionsFromNode(String? topicId, {bool txPool = true, Map<String, dynamic>? metas}) async {
    if (topicId == null || topicId.isEmpty) return [null, null];
    // permissions + subscribers
    metas = metas ?? await RPC.getSubscribers(topicId, meta: true, txPool: txPool);
    if (metas == null) {
      logger.w("$TAG - _getPermissionsFromNode - metas = null - topicId:$topicId - txPool:$txPool - metas:$metas");
      return [null, null];
    }
    List<String> metaKeys = metas.keys.toList();
    // permissions
    bool _acceptAll = false;
    List<SubscriberSchema> _permissions = [];
    for (var i = 0; i < metaKeys.length; i++) {
      String key = metaKeys[i];
      var value = metas[key];
      if (key.contains('.__permission__.')) {
        // permPage
        String prefix = key.split("__.__permission__.")[0];
        String permIndex = prefix.split("__")[prefix.split("__").length - 1];
        int permPage = int.tryParse(permIndex) ?? 0;
        // meta (same with client_subscription[meta])
        Map<String, dynamic>? meta = Util.jsonFormatMap(value);
        // accept
        List<dynamic> acceptList = meta?['accept'] ?? [];
        for (int i = 0; i < acceptList.length; i++) {
          var element = acceptList[i];
          if (element is Map) {
            String? address = element["addr"]?.toString();
            SubscriberSchema? item = SubscriberSchema.create(topicId, address, InitialAcceptStatus, permPage);
            if (item != null) _permissions.add(item);
          } else if (element is String) {
            if (element.trim() == "*") {
              _acceptAll = true;
            } else {
              logger.w("$TAG - _getPermissionsFromNode - accept content error - accept:$element");
            }
          } else {
            logger.w("$TAG - _getPermissionsFromNode - accept type error - accept:$element");
          }
          if (_acceptAll) break;
        }
        if (_acceptAll) break;
        // reject
        List<dynamic> rejectList = meta?['reject'] ?? [];
        rejectList.forEach((element) {
          if (element is Map) {
            String? address = element["addr"]?.toString();
            SubscriberSchema? item = SubscriberSchema.create(topicId, address, InitialRejectStatus, permPage);
            if (item != null) _permissions.add(item);
          } else {
            logger.w("$TAG - _getPermissionsFromNode - reject type error - accept:$element");
          }
        });
      } else {
        logger.v("$TAG - _getPermissionsFromNode - skip key no contains permission - key:$key - value:$value");
      }
    }
    if (_acceptAll) {
      logger.d("$TAG - _getPermissionsFromNode - acceptAll - topicId:$topicId");
      _permissions = [];
    } else {
      List<int?> statusList = _permissions.map((e) => e.status).toList();
      List<int?> permList = _permissions.map((e) => e.permPage).toList();
      List<String?> addressList = _permissions.map((e) => e.contactAddress).toList();
      logger.d("$TAG - _getPermissionsFromNode - topicId:$topicId - count:${_permissions.length} - statusList:$statusList - permList:$permList - addressList:$addressList");
    }
    return [_acceptAll, _permissions];
  }

  /// ***********************************************************************************************************
  /// ************************************************** status *************************************************
  /// ***********************************************************************************************************

  // status: InvitedSend (caller = owner)
  Future<SubscriberSchema?> onInvitedSend(String? topicId, String? contactAddress, int? permPage) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await query(topicId, contactAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicId, contactAddress, SubscriberStatus.InvitedSend, permPage), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedSend) {
      bool success = await setStatus(topicId, contactAddress, SubscriberStatus.InvitedSend, notify: true);
      if (success) subscriber.status = SubscriberStatus.InvitedSend;
    }
    // permPage
    if ((subscriber.permPage != permPage) && (permPage != null)) {
      bool success = await setPermPage(topicId, contactAddress, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    return subscriber;
  }

  // status: InvitedReceipt (caller = owner)
  Future<SubscriberSchema?> onInvitedReceipt(String? topicId, String? contactAddress) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await query(topicId, contactAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicId, contactAddress, SubscriberStatus.InvitedReceipt, null), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.InvitedReceipt) {
      bool success = await setStatus(topicId, contactAddress, SubscriberStatus.InvitedReceipt, notify: true);
      if (success) subscriber.status = SubscriberStatus.InvitedReceipt;
    }
    return subscriber;
  }

  // status: Subscribed (caller = self + other)
  Future<SubscriberSchema?> onSubscribe(String? topicId, String? contactAddress, int? permPage) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await query(topicId, contactAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicId, contactAddress, SubscriberStatus.Subscribed, permPage), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.Subscribed) {
      bool success = await setStatus(topicId, contactAddress, SubscriberStatus.Subscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Subscribed;
    }
    // permPage
    if ((subscriber.permPage != permPage) && (permPage != null)) {
      bool success = await setPermPage(topicId, contactAddress, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    return subscriber;
  }

  // status: Unsubscribed (caller = self + other)
  Future<SubscriberSchema?> onUnsubscribe(String? topicId, String? contactAddress, {int? permPage}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await query(topicId, contactAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicId, contactAddress, SubscriberStatus.Unsubscribed, permPage), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.Unsubscribed) {
      bool success = await setStatus(topicId, contactAddress, SubscriberStatus.Unsubscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Unsubscribed;
    }
    // permPage
    if ((subscriber.permPage != permPage) && (permPage != null)) {
      bool success = await setPermPage(topicId, contactAddress, permPage, notify: true);
      if (success) subscriber.permPage = permPage;
    }
    // delete (just node sync can delete)
    // bool success = await delete(subscriber.id, notify: true);
    // return success ? subscriber : null;
    return subscriber;
  }

  // status: Kick (caller = owner)
  Future<SubscriberSchema?> onKickOut(String? topicId, String? contactAddress, {int? permPage}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return null;
    // subscriber
    SubscriberSchema? subscriber = await query(topicId, contactAddress);
    if (subscriber == null) {
      subscriber = await add(SubscriberSchema.create(topicId, contactAddress, SubscriberStatus.Unsubscribed, permPage), notify: true);
    }
    if (subscriber == null) return null;
    // status
    if (subscriber.status != SubscriberStatus.Unsubscribed) {
      bool success = await setStatus(topicId, contactAddress, SubscriberStatus.Unsubscribed, notify: true);
      if (success) subscriber.status = SubscriberStatus.Unsubscribed;
    }
    // permPage
    if ((subscriber.permPage != permPage) && (permPage != null)) {
      bool success = await setPermPage(topicId, contactAddress, permPage, notify: true);
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

  Future<SubscriberSchema?> add(SubscriberSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.topicId.isEmpty) return null;
    SubscriberSchema? added = await SubscriberStorage.instance.insert(schema);
    if ((added != null) && notify) _addSink.add(added);
    return added;
  }

  /*Future<bool> delete(int? subscriberId, {bool notify = false}) async {
    if (subscriberId == null || subscriberId == 0) return false;
    bool success = await SubscriberStorage.instance.delete(subscriberId);
    if (success && notify) _deleteSink.add(subscriberId);
    return success;
  }*/

  /*Future<int> deleteByTopic(String? topic) async {
    if (topic == null || topic.isEmpty) return 0;
    int count = await SubscriberStorage.instance.deleteByTopic(topic);
    return count;
  }*/

  Future<SubscriberSchema?> query(String? topicId, String? chatId) async {
    if (topicId == null || topicId.isEmpty || chatId == null || chatId.isEmpty) return null;
    return await SubscriberStorage.instance.query(topicId, chatId);
  }

  Future<List<SubscriberSchema>> queryListByTopicId(String? topicId, {int? status, int offset = 0, int limit = 20}) {
    return SubscriberStorage.instance.queryListByTopicId(topicId, status: status, offset: offset, limit: limit);
  }

  Future<List<SubscriberSchema>> queryListByTopicIdPerm(String? topicId, int? permPage, int limit) {
    return SubscriberStorage.instance.queryListByTopicIdPerm(topicId, permPage, limit);
  }

  Future<int> queryCountByTopicId(String? topicId, {int? status}) {
    return SubscriberStorage.instance.queryCountByTopicId(topicId, status: status);
  }

  Future<int> queryCountByTopicIdPerm(String? topicId, int permPage, {int? status}) {
    return SubscriberStorage.instance.queryCountByTopicIdPerm(topicId, permPage, status: status);
  }

  Future<int> queryMaxPermPageByTopicId(String? topicId) async {
    int maxPermPage = await SubscriberStorage.instance.queryMaxPermPageByTopicId(topicId);
    return maxPermPage < 0 ? 0 : maxPermPage;
  }

  Future<int> queryNextPermPageByTopicId(String? topicId) async {
    int maxPermPage = await queryMaxPermPageByTopicId(topicId);
    int maxPageCount = await queryCountByTopicIdPerm(topicId, maxPermPage);
    if (maxPageCount >= SubscriberSchema.PermPageSize) {
      maxPermPage++;
    }
    return maxPermPage;
  }

  Future<bool> setStatus(String? topicId, String? contactAddress, int? status, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    bool success = await SubscriberStorage.instance.setStatus(topicId, contactAddress, status ?? SubscriberStatus.None);
    if (success && notify) queryAndNotify(topicId, contactAddress);
    return success;
  }

  Future<bool> setPermPage(String? topicId, String? contactAddress, int? permPage, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    if (permPage != null && permPage < 0) return false;
    bool success = await SubscriberStorage.instance.setPermPage(topicId, contactAddress, permPage);
    if (success && notify) queryAndNotify(topicId, contactAddress);
    return success;
  }

  Future<bool> setStatusProgressStart(String? topicId, String? contactAddress, int status, int? nonce, double fee, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    var data = await SubscriberStorage.instance.setData(topicId, contactAddress, {
      "permission_progress": status,
      "progress_permission_nonce": nonce,
      "progress_permission_fee": fee,
    });
    logger.d("$TAG - setStatusProgressStart - status:$status - nonce:$nonce - fee:$fee - data:$data - topicId:$topicId - contactAddress:$contactAddress");
    if ((data != null) && notify) queryAndNotify(topicId, contactAddress);
    return data != null;
  }

  Future<bool> setStatusProgressEnd(String? topicId, String? contactAddress, {bool notify = false}) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return false;
    var data = await SubscriberStorage.instance.setData(topicId, contactAddress, null, removeKeys: [
      "permission_progress",
      "progress_permission_nonce",
      "progress_permission_fee",
    ]);
    logger.d("$TAG - setStatusProgressEnd - data:$data - topicId:$topicId - contactAddress:$contactAddress");
    if ((data != null) && notify) queryAndNotify(topicId, contactAddress);
    return data != null;
  }

  Future queryAndNotify(String? topicId, String? contactAddress) async {
    if (topicId == null || topicId.isEmpty || contactAddress == null || contactAddress.isEmpty) return;
    SubscriberSchema? updated = await query(topicId, contactAddress);
    if (updated != null) {
      _updateSink.add(updated);
    }
  }
}
