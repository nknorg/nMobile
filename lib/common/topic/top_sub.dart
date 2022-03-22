import 'dart:convert';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class TopSub {
  // TODO:GG handle all
  static Future<bool> subscribeWithPermission(
    String? topic, {
    double fee = 0,
    int? permissionPage,
    Map<String, dynamic>? meta,
    String? clientAddress,
    int? oldStatus,
    int? newStatus,
    int? nonce,
    bool toast = false,
    int tryTimes = 1,
    int maxTryTimes = 1,
  }) async {
    if (permissionPage == null) return false;
    String identifier = '__${permissionPage}__.__permission__';
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";
    List results = await _subscribe(
      topic,
      fee: fee,
      identifier: identifier,
      meta: metaString,
      nonce: nonce,
      toast: toast,
      tryTimes: 0,
    );
    bool success = results[0];
    bool canTryTimer = results[1];
    int? _nonce = results[2];

    if (!success) {
      if (tryTimes < maxTryTimes) {
        logger.w("TopSub - subscribeWithPermission - clientSubscribe fail - tryTimes:$tryTimes - topic:$topic - permPage:$permissionPage - meta:$meta");
        await Future.delayed(Duration(seconds: 5));
        return subscribeWithPermission(
          topic,
          fee: fee,
          permissionPage: permissionPage,
          meta: meta,
          clientAddress: clientAddress,
          newStatus: newStatus,
          oldStatus: oldStatus,
          nonce: nonce,
          toast: toast,
          tryTimes: ++tryTimes,
        );
      } else {
        logger.w("TopSub - subscribeWithPermission - clientSubscribe fail - topic:$topic - permPage:$permissionPage - meta:$meta");
      }
    }

    SubscriberSchema? _schema = await subscriberCommon.queryByTopicChatId(topic, clientAddress);
    if (_schema != null && newStatus != null) {
      if (!canTryTimer) {
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, false, nonce: _nonce);
        logger.w("TopSub - subscribeWithPermission - cancel permission try - topic:$topic - clientAddress:$clientAddress - newData1:$newData - nonce:$nonce - identifier:$identifier - metaString:$metaString");
        subscriberCommon.setData(_schema.id, newData).then((_) => subscriberCommon.setStatus(_schema.id, oldStatus, notify: true)); // await
      } else {
        success = true; // will success by try timer
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, true, nonce: _nonce);
        logger.i("TopSub - subscribeWithPermission - add permission try - topic:$topic - clientAddress:$clientAddress - newData1:$newData - nonce:$nonce - identifier:$identifier - metaString:$metaString");
        subscriberCommon.setData(_schema.id, newData); // await
      }
    }
    return success;
  }

  // TODO:GG handle all
  static Future<bool> subscribeWithJoin(
    String? topic,
    bool isJoin, {
    double fee = 0,
    String identifier = "",
    int? nonce,
    bool toast = false,
    int tryTimes = 1,
    int maxTryTimes = 1,
  }) async {
    List results = isJoin
        ? await _subscribe(
            topic,
            fee: fee,
            identifier: identifier,
            meta: "",
            nonce: nonce,
            toast: toast,
            tryTimes: 0,
          )
        : await _unsubscribe(
            topic,
            fee: fee,
            identifier: identifier,
            nonce: nonce,
            toast: toast,
            tryTimes: 0,
          );
    bool success = results[0];
    bool canTryTimer = results[1];
    int? _nonce = results[2];

    if (!success) {
      if (tryTimes < maxTryTimes) {
        logger.w("TopSub - subscribeWithJoin - clientSubscribe fail - tryTimes:$tryTimes - topic:$topic - identifier:$identifier");
        await Future.delayed(Duration(seconds: 2));
        return subscribeWithJoin(
          topic,
          isJoin,
          fee: fee,
          identifier: identifier,
          nonce: nonce,
          toast: toast,
          tryTimes: ++tryTimes,
        );
      } else {
        logger.w("TopSub - subscribeWithJoin - clientSubscribe fail - topic:$topic - identifier:$identifier");
      }
    }

    TopicSchema? _schema = await topicCommon.queryByTopic(topic);
    if (_schema != null) {
      if (isJoin) {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, false, nonce: _nonce);
          logger.w("TopSub - subscribeWithJoin - cancel subscribe try - topic:$topic - newData:$newData - nonce:$nonce - identifier:$identifier");
          topicCommon.setData(_schema.id, newData).then((_) => topicCommon.setJoined(_schema.id, false, notify: true)); // await
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, true, nonce: _nonce);
          logger.i("TopSub - subscribeWithJoin - add subscribe try - topic:$topic - newData:$newData - nonce:$nonce - identifier:$identifier");
          topicCommon.setData(_schema.id, newData); // await
        }
      } else {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, false, nonce: _nonce);
          logger.i("TopSub - _unsubscribe - cancel unsubscribe try - topic:$topic - newData:$newData - nonce:$nonce");
          topicCommon.setData(_schema.id, newData).then((_) => topicCommon.setJoined(_schema.id, true, notify: true)); // await
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, true, nonce: _nonce);
          logger.i("TopSub - _unsubscribe - add unsubscribe try - topic:$topic - newData:$newData - nonce:$nonce");
          topicCommon.setData(_schema.id, newData); // await
        }
      }
    }
    return success;
  }

  // publish(meta = null) / private(meta != null)(owner_create / invitee / kick)
  static Future<List> _subscribe(
    String? topic, {
    double fee = 0,
    String identifier = "",
    String meta = "",
    int? nonce,
    bool toast = false,
    int tryTimes = 0,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false];
    int maxTryTimes = 2; // 3
    int? _nonce = nonce ?? await Global.getNonce();

    bool? success;
    bool canTryTimer = true;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        String? topicHash = await clientCommon.client?.subscribe(
          topic: genTopicHash(topic),
          duration: Global.topicDefaultSubscribeHeight,
          fee: fee.toStringAsFixed(8),
          identifier: identifier,
          meta: meta,
          nonce: _nonce,
        );
        success = (topicHash != null) && (topicHash.isNotEmpty);
      } else {
        canTryTimer = false;
      }
    } catch (e) {
      if (e.toString().contains("doesn't exist")) {
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        success = false;
        canTryTimer = false;
      } else if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _subscribe - try over by nonce is not continuous - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        if (tryTimes >= maxTryTimes) {
          if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
        } else {
          nonce = await Global.getNonce(forceFetch: true);
        }
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.w("TopSub - _subscribe - block duplicated - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.request_processed));
        success = false; // permission action can add to try timer
        nonce = await Global.refreshNonce();
      } else if (e.toString().contains('not sufficient funds')) {
        // INTERNAL ERROR, can not append tx to txpool: not sufficient funds
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        if (toast && identifier.isEmpty) Toast.show("订阅所需NKN不足"); // TODO:GG locale
        success = false;
        canTryTimer = false;
      } else {
        nonce = await Global.getNonce(forceFetch: true);
        if (tryTimes >= maxTryTimes) {
          success = false;
          handleError(e);
        }
      }
    }

    if (success == null) {
      if (tryTimes < maxTryTimes) {
        await Future.delayed(Duration(seconds: 1));
        return _subscribe(
          topic,
          fee: fee,
          identifier: identifier,
          meta: meta,
          nonce: nonce,
          toast: toast,
          tryTimes: ++tryTimes,
        );
      } else {
        success = false; // permission action can add to try timer
      }
    }
    return [success, canTryTimer, _nonce];
  }

  static Future<List> _unsubscribe(
    String? topic, {
    double fee = 0,
    String identifier = "",
    int? nonce,
    bool toast = false,
    int tryTimes = 0,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false];
    int maxTryTimes = 2; // 3
    int? _nonce = nonce ?? await Global.getNonce();

    bool? success;
    bool canTryTimer = true;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        String? topicHash = await clientCommon.client?.unsubscribe(
          topic: genTopicHash(topic),
          identifier: identifier,
          fee: fee.toStringAsFixed(8),
          nonce: _nonce,
        );
        success = (topicHash != null) && (topicHash.isNotEmpty);
      } else {
        canTryTimer = false;
      }
    } catch (e) {
      if (e.toString().contains("doesn't exist")) {
        logger.w("TopSub - _unsubscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier");
        success = false;
        canTryTimer = false;
      } else if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _unsubscribe - try over by nonce is not continuous - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier");
        if (tryTimes >= maxTryTimes) {
          if (toast) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
        } else {
          nonce = await Global.getNonce(forceFetch: true);
        }
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.w("TopSub - _unsubscribe - block duplicated - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier");
        if (toast) Toast.show(Global.locale((s) => s.request_processed));
        success = false;
        nonce = await Global.refreshNonce();
      } else if (e.toString().contains('not sufficient funds')) {
        // INTERNAL ERROR, can not append tx to txpool: not sufficient funds
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$nonce - identifier:$identifier");
        if (toast && identifier.isEmpty) Toast.show("退订所需NKN不足"); // TODO:GG locale
        success = false;
        canTryTimer = false;
      } else {
        nonce = await Global.getNonce(forceFetch: true);
        if (tryTimes >= maxTryTimes) {
          success = false;
          handleError(e);
        }
      }
    }

    if (success == null) {
      if (tryTimes < maxTryTimes) {
        await Future.delayed(Duration(seconds: 1));
        return _unsubscribe(
          topic,
          fee: fee,
          identifier: identifier,
          nonce: nonce,
          toast: toast,
          tryTimes: ++tryTimes,
        );
      } else {
        success = false; // permission action can add to try timer
      }
    }
    return [success, canTryTimer, _nonce];
  }

  // TODO:GG 还有subscriber可以 = "identifier.publickey" 吗?
  static Future<Map<String, dynamic>> getSubscription(String? topic, String? subscriber, {int tryTimes = 0}) async {
    if (topic == null || topic.isEmpty || subscriber == null || subscriber.isEmpty) return Map();
    Map<String, dynamic>? results;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        results = await clientCommon.client?.getSubscription(
          topic: genTopicHash(topic),
          subscriber: subscriber,
        );
      }
      if ((results == null) || results.isEmpty) {
        List<String> seedRpcList = await Global.getRpcServers(await walletCommon.getDefaultAddress());
        results = await Wallet.getSubscription(
          genTopicHash(topic),
          subscriber,
          config: RpcConfig(seedRPCServerAddr: seedRpcList),
        );
      }
    } catch (e) {
      handleError(e);
    }
    if ((results == null) || results.isEmpty) {
      if (tryTimes < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscription(topic, subscriber, tryTimes: ++tryTimes);
      } else {
        results = Map();
      }
    }
    return results;
  }

  static Future<Map<String, dynamic>> getSubscribers(
    String? topic, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    // Uint8List? subscriberHashPrefix,
    int tryTimes = 0,
  }) async {
    if (topic == null || topic.isEmpty) return Map();
    Map<String, dynamic>? results;
    try {
      bool loop = true;
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        while (loop) {
          Map<String, dynamic>? result = await clientCommon.client?.getSubscribers(
            topic: genTopicHash(topic),
            offset: offset,
            limit: limit,
            meta: meta,
            txPool: txPool,
            // subscriberHashPrefix: subscriberHashPrefix,
          );
          if ((result == null) || result.isEmpty) {
            List<String> seedRpcList = await Global.getRpcServers(await walletCommon.getDefaultAddress());
            result = await Wallet.getSubscribers(
              topic: genTopicHash(topic),
              offset: offset,
              limit: limit,
              meta: meta,
              txPool: txPool,
              // subscriberHashPrefix: subscriberHashPrefix,
              config: RpcConfig(seedRPCServerAddr: seedRpcList),
            );
          }
          if (result != null) {
            if (results == null) {
              results = result;
            } else {
              results.addAll(result);
            }
          }
          loop = (result?.length ?? 0) >= limit;
          offset += limit;
        }
      }
    } catch (e) {
      handleError(e);
    }
    if (results == null) {
      if (tryTimes < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscribers(topic, offset: 0, limit: limit, meta: meta, txPool: txPool, tryTimes: ++tryTimes);
      } else {
        results = Map();
      }
    }
    return results;
  }

  static Future<int> getSubscribersCount(String? topic, {int tryTimes = 0}) async {
    if (topic == null || topic.isEmpty) return 0;
    int? count;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        count = await clientCommon.client?.getSubscribersCount(
          topic: genTopicHash(topic),
          // subscriberHashPrefix: subscriberHashPrefix,
        );
      }
      if ((count == null) || (count <= 0)) {
        List<String> seedRpcList = await Global.getRpcServers(await walletCommon.getDefaultAddress());
        count = await Wallet.getSubscribersCount(
          genTopicHash(topic),
          // subscriberHashPrefix: subscriberHashPrefix
          config: RpcConfig(seedRPCServerAddr: seedRpcList),
        );
      }
    } catch (e) {
      handleError(e);
    }
    if (count == null) {
      if (tryTimes < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscribersCount(topic, tryTimes: ++tryTimes);
      } else {
        count = 0;
      }
    }
    return count;
  }
}
