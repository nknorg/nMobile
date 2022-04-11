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
    bool exists = results[2];
    int? _nonce = results[3];

    if (!success) {
      if (exists && fee > 0) {
        int? blockNonce = await Global.getNonce(txPool: false);
        int? poolNonce = await Global.getNonce(txPool: true);
        if ((blockNonce != null) && (blockNonce >= 0) && (poolNonce != null) && (poolNonce >= blockNonce)) {
          for (var i = blockNonce; i <= poolNonce; i++) {
            List results = await _subscribe(topic, fee: fee, identifier: identifier, meta: metaString, nonce: i);
            if (results[0] != true) {
              await _subscribeReplace(i, fee);
            } else {
              nonce = i;
              break;
            }
          }
        }
      } else if (tryTimes < maxTryTimes) {
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
    } else if (success && (fee > 0)) {
      int? blockNonce = await Global.getNonce(txPool: false);
      if ((blockNonce != null) && (blockNonce >= 0) && (_nonce != null) && (_nonce > blockNonce)) {
        for (var i = blockNonce; i < _nonce; i++) {
          await _subscribeReplace(i, fee);
        }
      }
    }

    SubscriberSchema? _schema = await subscriberCommon.queryByTopicChatId(topic, clientAddress);
    if (_schema != null && newStatus != null) {
      if (!canTryTimer) {
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, false, null, 0);
        logger.w("TopSub - subscribeWithPermission - cancel permission try - nonce:$_nonce - fee:$fee - topic:$topic - clientAddress:$clientAddress - newData:$newData - identifier:$identifier - metaString:$metaString");
        await subscriberCommon.setData(_schema.id, newData); // await
        await subscriberCommon.setStatus(_schema.id, oldStatus, notify: true);
      } else {
        success = true; // will success by try timer
        Map<String, dynamic> newData = _schema.newDataByAppendStatus(newStatus, true, _nonce, fee);
        logger.i("TopSub - subscribeWithPermission - add permission try - nonce:$_nonce - fee:$fee - topic:$topic - clientAddress:$clientAddress - newData:$newData - identifier:$identifier - metaString:$metaString");
        await subscriberCommon.setData(_schema.id, newData); // await
      }
    }
    return success;
  }

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
    bool exists = results[2];
    int? _nonce = results[3];

    if (!success) {
      if (exists && fee > 0) {
        int? blockNonce = await Global.getNonce(txPool: false);
        int? poolNonce = await Global.getNonce(txPool: true);
        if ((blockNonce != null) && (blockNonce >= 0) && (poolNonce != null) && (poolNonce >= blockNonce)) {
          for (var i = blockNonce; i <= poolNonce; i++) {
            List results = isJoin ? await _subscribe(topic, fee: fee, identifier: identifier, meta: "", nonce: i) : await _unsubscribe(topic, fee: fee, identifier: identifier, nonce: i);
            if (results[0] != true) {
              await _subscribeReplace(i, fee);
            } else {
              nonce = i;
              break;
            }
          }
        }
      } else if (tryTimes < maxTryTimes) {
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
    } else if (success && (fee > 0)) {
      int? blockNonce = await Global.getNonce(txPool: false);
      if ((blockNonce != null) && (blockNonce >= 0) && (_nonce != null) && (_nonce > blockNonce)) {
        for (var i = blockNonce; i < _nonce; i++) {
          await _subscribeReplace(i, fee);
        }
      }
    }

    TopicSchema? _schema = await topicCommon.queryByTopic(topic);
    if (_schema != null) {
      if (isJoin) {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, false, null, 0);
          logger.w("TopSub - subscribeWithJoin - cancel subscribe try - nonce:$nonce - fee:$fee - topic:$topic - newData:$newData - identifier:$identifier");
          await topicCommon.setData(_schema.id, newData); // await
          await topicCommon.setJoined(_schema.id, false, notify: true);
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(true, true, _nonce, fee);
          logger.i("TopSub - subscribeWithJoin - add subscribe try - nonce:$nonce - fee:$fee - topic:$topic - newData:$newData - identifier:$identifier");
          await topicCommon.setData(_schema.id, newData); // await
        }
      } else {
        if (!canTryTimer) {
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, false, null, 0);
          logger.i("TopSub - _unsubscribe - cancel unsubscribe try - nonce:$nonce - fee:$fee - topic:$topic - newData:$newData");
          await topicCommon.setData(_schema.id, newData); // await
          await topicCommon.setJoined(_schema.id, true, notify: true);
        } else {
          success = true; // will success by try timer
          Map<String, dynamic> newData = _schema.newDataByAppendSubscribe(false, true, _nonce, fee);
          logger.i("TopSub - _unsubscribe - add unsubscribe try - nonce:$nonce - fee:$fee - topic:$topic - newData:$newData");
          await topicCommon.setData(_schema.id, newData); // await
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
    bool exists = false;
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
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$meta");
        success = false;
        canTryTimer = false;
        _nonce = null;
      } else if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _subscribe - try over by nonce is not continuous - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$meta");
        if ((nonce != null) || (tryTimes >= maxTryTimes)) {
          if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
          _nonce = null;
        } else {
          nonce = await Global.getNonce();
        }
      } else if (e.toString().contains("nonce is too low")) {
        // can not append tx to txpool: nonce is too low
        logger.w("TopSub - _subscribe - try over by nonce is too low - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$meta");
        nonce = await Global.getNonce();
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.w("TopSub - _subscribe - block duplicated - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$meta");
        if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.request_processed));
        success = false; // permission action can add to try timer
        exists = true;
        _nonce = null;
      } else if (e.toString().contains('not sufficient funds')) {
        // can not append tx to txpool: not sufficient funds
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$meta");
        if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.balance_not_enough));
        success = false;
        canTryTimer = false;
        _nonce = null;
      } else {
        if (tryTimes >= maxTryTimes) {
          success = false;
          _nonce = null;
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
    return [success, canTryTimer, exists, _nonce];
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
    bool exists = false;
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
        logger.w("TopSub - _unsubscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier");
        success = false;
        canTryTimer = false;
        _nonce = null;
      } else if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        logger.w("TopSub - _unsubscribe - try over by nonce is not continuous - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier");
        if ((nonce != null) || (tryTimes >= maxTryTimes)) {
          if (toast) Toast.show(Global.locale((s) => s.something_went_wrong));
          success = false;
          _nonce = null;
        } else {
          nonce = await Global.getNonce();
        }
      } else if (e.toString().contains("nonce is too low")) {
        // can not append tx to txpool: nonce is too low
        logger.w("TopSub - _subscribe - try over by nonce is too low - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier");
        nonce = await Global.getNonce();
      } else if (e.toString().contains('duplicate subscription exist in block')) {
        // can not append tx to txpool: duplicate subscription exist in block
        logger.w("TopSub - _unsubscribe - block duplicated - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier");
        if (toast) Toast.show(Global.locale((s) => s.request_processed));
        success = false;
        exists = true;
        _nonce = null;
      } else if (e.toString().contains('not sufficient funds')) {
        // can not append tx to txpool: not sufficient funds
        logger.w("TopSub - _subscribe - topic doesn't exist - tryTimes:$tryTimes - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier");
        if (toast && identifier.isEmpty) Toast.show(Global.locale((s) => s.balance_not_enough));
        success = false;
        canTryTimer = false;
        _nonce = null;
      } else {
        if (tryTimes >= maxTryTimes) {
          success = false;
          _nonce = null;
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
    return [success, canTryTimer, exists, _nonce];
  }

  static _subscribeReplace(int nonce, double fee) async {
    bool? success;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        String? address = await walletCommon.getDefaultAddress();
        if (address == null || address.isEmpty) return false;
        String keystore = await walletCommon.getKeystore(address);
        if (keystore.isEmpty) return false;
        String? password = await walletCommon.getPassword(address);
        if (password == null || password.isEmpty) return false;
        List<String> seedRpcList = await Global.getRpcServers(address);
        Wallet nkn = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
        String? txHash = await nkn.transfer(address, "0", fee: fee.toStringAsFixed(8), nonce: nonce);
        success = (txHash != null) && (txHash.isNotEmpty);
      }
    } catch (e) {
      logger.w("TopSub - subscribeEmpty - nonce:$nonce - fee:${fee.toStringAsFixed(8)} - error:${e.toString()}");
      success = false;
    }
    return success;
  }

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
