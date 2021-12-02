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
    int tryCount = 1,
    int maxTryTimes = 1,
  }) async {
    if (permissionPage == null) return false;
    String identifier = '__${permissionPage}__.__permission__';
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";
    List<bool> results = await _subscribe(
      topic,
      fee: fee,
      identifier: identifier,
      meta: metaString,
      nonce: nonce,
      toast: toast,
      tryCount: 0,
    );
    bool success = results[0];
    bool canTryTimer = results[1];

    if (!success) {
      if (tryCount < maxTryTimes) {
        logger.w("TopSub - subscribeWithPermission - clientSubscribe fail - tryCount:$tryCount - topic:$topic - permPage:$permissionPage - meta:$meta");
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
          tryCount: ++tryCount,
        );
      } else {
        logger.w("TopSub - subscribeWithPermission - clientSubscribe fail - topic:$topic - permPage:$permissionPage - meta:$meta");
      }
    }

    SubscriberSchema? _schema = await subscriberCommon.queryByTopicChatId(topic, clientAddress);
    if (_schema != null && newStatus != null) {
      if (!canTryTimer) {
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, false);
        logger.w("TopSub - subscribeWithPermission - cancel permission try - topic:$topic - clientAddress:$clientAddress - newData:$newData - nonce:$nonce - identifier:$identifier - metaString:$metaString");
        subscriberCommon.setData(_schema.id, newData).then((_) => subscriberCommon.setStatus(_schema.id, oldStatus, notify: true)); // await
      } else {
        success = true; // will success by try timer
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, true);
        logger.i("TopSub - subscribeWithPermission - add permission try - topic:$topic - clientAddress:$clientAddress - newData:$newData - nonce:$nonce - identifier:$identifier - metaString:$metaString");
        subscriberCommon.setData(_schema.id, newData); // await
      }
    }
    return success;
  }

  // TODO:GG identifier可以传马甲吗？
  static Future<bool> subscribeWithJoin(
    String? topic,
    bool isJoin, {
    double fee = 0,
    String identifier = "",
    int? nonce,
    bool toast = false,
    int tryCount = 1,
    int maxTryTimes = 1,
  }) async {
    List<bool> results = isJoin
        ? await _subscribe(
            topic,
            fee: fee,
            identifier: identifier,
            meta: "",
            nonce: nonce,
            toast: toast,
            tryCount: 0,
          )
        : await _unsubscribe(
            topic,
            fee: fee,
            identifier: identifier,
            nonce: nonce,
            toast: toast,
            tryCount: 0,
          );
    bool success = results[0];
    bool canTryTimer = results[1];

    if (!success) {
      if (tryCount < maxTryTimes) {
        logger.w("TopSub - subscribeWithJoin - clientSubscribe fail - tryCount:$tryCount - topic:$topic - identifier:$identifier");
        await Future.delayed(Duration(seconds: 2));
        return subscribeWithJoin(
          topic,
          isJoin,
          fee: fee,
          identifier: identifier,
          nonce: nonce,
          toast: toast,
          tryCount: ++tryCount,
        );
      } else {
        logger.w("TopSub - subscribeWithJoin - clientSubscribe fail - topic:$topic - identifier:$identifier");
      }
    }

    TopicSchema? _schema = await topicCommon.queryByTopic(topic);
    if (_schema != null) {
      if (isJoin) {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, false);
          logger.w("TopSub - subscribeWithJoin - cancel subscribe try - topic:$topic - newData:$newData - nonce:$nonce - identifier:$identifier");
          topicCommon.setData(_schema.id, newData).then((_) => topicCommon.setJoined(_schema.id, false, notify: true)); // await
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, true);
          logger.i("TopSub - subscribeWithJoin - add subscribe try - topic:$topic - newData:$newData - nonce:$nonce - identifier:$identifier");
          topicCommon.setData(_schema.id, newData); // await
        }
      } else {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, false);
          logger.i("TopSub - _unsubscribe - cancel unsubscribe try - topic:$topic - newData:$newData - nonce:$nonce");
          topicCommon.setData(_schema.id, newData).then((_) => topicCommon.setJoined(_schema.id, true, notify: true)); // await
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, true);
          logger.i("TopSub - _unsubscribe - add unsubscribe try - topic:$topic - newData:$newData - nonce:$nonce");
          topicCommon.setData(_schema.id, newData); // await
        }
      }
    }
    return success;
  }

  static Future<List<bool>> _unsubscribe(
    String? topic, {
    double fee = 0,
    String identifier = "",
    int? nonce,
    bool toast = false,
    int tryCount = 0,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false];
    int maxTryTimes = 2; // 3
    nonce = nonce ?? await Global.getNonce();

    bool? success;
    bool canTryTimer = true;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        String? topicHash = await clientCommon.client?.unsubscribe(
          topic: genTopicHash(topic),
          identifier: identifier,
          fee: fee.toString(),
          nonce: nonce,
        );
        success = (topicHash != null) && (topicHash.isNotEmpty);
      } else {
        canTryTimer = false;
      }
    } catch (e) {
      if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _unsubscribe - try over by nonce is not continuous - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier");
        if (tryCount >= maxTryTimes) {
          if (toast) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
        } else {
          nonce = await Global.getNonce(forceFetch: true);
        }
      } else if (e.toString().contains("doesn't exist")) {
        logger.w("TopSub - _unsubscribe - topic doesn't exist - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier");
        success = false;
        canTryTimer = false;
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.i("TopSub - _unsubscribe - block duplicated - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier");
        if (toast) Toast.show(Global.locale((s) => s.request_processed));
        success = false;
        nonce = await Global.refreshNonce();
      } else {
        nonce = await Global.getNonce(forceFetch: true);
        if (tryCount >= maxTryTimes) {
          success = false;
          handleError(e);
        }
      }
    }

    if (success == null) {
      if (tryCount < maxTryTimes) {
        await Future.delayed(Duration(seconds: 1));
        return _unsubscribe(
          topic,
          fee: fee,
          identifier: identifier,
          nonce: nonce,
          toast: toast,
          tryCount: ++tryCount,
        );
      } else {
        success = false; // permission action can add to try timer
      }
    }
    return [success, canTryTimer];
  }

  // publish(meta = null) / private(meta != null)(owner_create / invitee / kick)
  static Future<List<bool>> _subscribe(
    String? topic, {
    double fee = 0,
    String identifier = "",
    String meta = "",
    int? nonce,
    bool toast = false,
    int tryCount = 0,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false];
    int maxTryTimes = 2; // 3
    nonce = nonce ?? await Global.getNonce();

    bool? success;
    bool canTryTimer = true;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        String? topicHash = await clientCommon.client?.subscribe(
          topic: genTopicHash(topic),
          duration: Global.topicDefaultSubscribeHeight,
          fee: fee.toString(),
          identifier: identifier,
          meta: meta,
          nonce: nonce,
        );
        success = (topicHash != null) && (topicHash.isNotEmpty);
      } else {
        canTryTimer = false;
      }
    } catch (e) {
      if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _subscribe - try over by nonce is not continuous - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        if (tryCount >= maxTryTimes) {
          if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
        } else {
          nonce = await Global.getNonce(forceFetch: true);
        }
      } else if (e.toString().contains("doesn't exist")) {
        logger.w("TopSub - _subscribe - topic doesn't exist - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        success = false;
        canTryTimer = false;
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.i("TopSub - _subscribe - block duplicated - tryCount:$tryCount - topic:$topic - nonce:$nonce - identifier:$identifier - meta:$meta");
        if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.request_processed));
        success = false; // permission action can add to try timer
        nonce = await Global.refreshNonce();
      } else {
        nonce = await Global.getNonce(forceFetch: true);
        if (tryCount >= maxTryTimes) {
          success = false;
          handleError(e);
        }
      }
    }

    if (success == null) {
      if (tryCount < maxTryTimes) {
        await Future.delayed(Duration(seconds: 1));
        return _subscribe(
          topic,
          fee: fee,
          identifier: identifier,
          meta: meta,
          nonce: nonce,
          toast: toast,
          tryCount: ++tryCount,
        );
      } else {
        success = false; // permission action can add to try timer
      }
    }
    return [success, canTryTimer];
  }

  // TODO:GG mean? subscriber = "identifier.publickey"
  // TODO:GG 返回的都是啥
  static Future<Map<String, dynamic>> getSubscription(String? topic, String? subscriber, {int tryCount = 0}) async {
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
      if (tryCount < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscription(topic, subscriber, tryCount: ++tryCount);
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
    int tryCount = 0,
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
      if (tryCount < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscribers(topic, offset: 0, limit: limit, meta: meta, txPool: txPool, tryCount: ++tryCount);
      } else {
        results = Map();
      }
    }
    return results;
  }

  static Future<int> getSubscribersCount(String? topic, {int tryCount = 0}) async {
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
      if (tryCount < 2) {
        await Future.delayed(Duration(seconds: 1));
        return getSubscribersCount(topic, tryCount: ++tryCount);
      } else {
        count = 0;
      }
    }
    return count;
  }
}
