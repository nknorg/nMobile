import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

class RPC {
  static List<String> defaultSeedRpcList = [
    'http://seed.nkn.org:30003',
    'http://mainnet-seed-0001.nkn.org:30003',
    'http://mainnet-seed-0002.nkn.org:30003',
    'http://mainnet-seed-0003.nkn.org:30003',
    'http://mainnet-seed-0004.nkn.org:30003',
    'http://mainnet-seed-0005.nkn.org:30003',
    'http://mainnet-seed-0006.nkn.org:30003',
    'http://mainnet-seed-0007.nkn.org:30003',
    'http://mainnet-seed-0008.nkn.org:30003',
    'http://112.15.9.168:30003',
    // 'http://mainnet-seed-0009.nkn.org:30003', // ali disable
  ];

  static int? blockHeight;

  /// ***********************************************************************************************************
  /// ********************************************* SeedRpcServers **********************************************
  /// ***********************************************************************************************************

  static Future<List<String>> getRpcServers(String? walletAddress, {bool measure = false}) async {
    // get
    List<String> list = await _getRpcServers(walletAddress: walletAddress);
    logger.d("PRC - getRpcServers - init - walletAddress:$walletAddress - length:${list.length} - list:$list");

    // append
    bool appendDefault = false;
    if (list.length <= 2) {
      list.addAll(defaultSeedRpcList);
      list = LinkedHashSet<String>.from(list).toList();
      appendDefault = true;
    }

    // measure
    if (measure || appendDefault) {
      try {
        list = await Wallet.measureSeedRPCServer(list, Settings.timeoutSeedMeasureMs) ?? [];
        await setRpcServers(walletAddress, list);

        if (walletAddress?.isNotEmpty == true) {
          List<String> saved = await _getRpcServers(walletAddress: walletAddress);
          if (saved.isEmpty) {
            logger.w("PRC - getRpcServers - saved empty - walletAddress:$walletAddress");
          } else {
            logger.i("PRC - getRpcServers - saved ok - walletAddress:$walletAddress - length:${saved.length} - list:$saved");
          }
        }
      } catch (e, st) {
        // list = defaultSeedRpcList;
        handleError(e, st);
      }
    }

    // again
    if (list.length <= 2) {
      if (!measure && !appendDefault) return await getRpcServers(walletAddress, measure: measure);
    }

    logger.d("PRC - getRpcServers - return - walletAddress:$walletAddress - length:${list.length} - list:$list");
    return list;
  }

  static Future addRpcServers(String? walletAddress, List<String> rpcServers) async {
    if (rpcServers.isEmpty) return;
    List<String> list = await _getRpcServers(walletAddress: walletAddress);
    list.insertAll(0, rpcServers);
    list = _filterRepeatAndSeedsFromRpcServers(list);
    return SettingsStorage.setSettings('${SettingsStorage.SEED_RPC_SERVERS_KEY}${walletAddress?.isNotEmpty == true ? ":$walletAddress" : ""}', list);
  }

  static Future setRpcServers(String? walletAddress, List<String> list) async {
    list = _filterRepeatAndSeedsFromRpcServers(list);
    return SettingsStorage.setSettings('${SettingsStorage.SEED_RPC_SERVERS_KEY}${walletAddress?.isNotEmpty == true ? ":$walletAddress" : ""}', list);
  }

  static Future<List<String>> _getRpcServers({String? walletAddress}) async {
    List<String> results = [];
    List? list = await SettingsStorage.getSettings('${SettingsStorage.SEED_RPC_SERVERS_KEY}${walletAddress?.isNotEmpty == true ? ":$walletAddress" : ""}');
    if ((list != null) && list.isNotEmpty) {
      for (var i in list) {
        results.add(i.toString());
      }
    }
    results = _filterRepeatAndSeedsFromRpcServers(results);
    return results;
  }

  static List<String> _filterRepeatAndSeedsFromRpcServers(List<String> list) {
    if (list.isEmpty) return list;
    list = LinkedHashSet<String>.from(list).toList();
    for (var i = 0; i < defaultSeedRpcList.length; i++) {
      int index = list.indexOf(defaultSeedRpcList[i]);
      if ((index >= 0) && index < (list.length)) {
        list.removeAt(index);
      }
    }
    if (list.isEmpty) return list;
    if (list.length > 10) {
      list = list.skip(list.length - 10).take(10).toList();
    }
    return list;
  }

  /// ***********************************************************************************************************
  /// ************************************************* height **************************************************
  /// ***********************************************************************************************************

  static Future<int?> getBlockHeight() async {
    int? newBlockHeight;
    try {
      if (clientCommon.isClientOK) {
        newBlockHeight = await clientCommon.client?.getHeight();
      }
      if ((newBlockHeight == null) || (newBlockHeight <= 0)) {
        List<String> seedRpcList = await getRpcServers(null);
        newBlockHeight = await Wallet.getHeight(config: RpcConfig(seedRPCServerAddr: seedRpcList));
      }
    } catch (e, st) {
      handleError(e, st);
    }
    if ((newBlockHeight != null) && (newBlockHeight > 0)) blockHeight = newBlockHeight;
    return blockHeight;
  }

  /// ***********************************************************************************************************
  /// ************************************************** nonce **************************************************
  /// ***********************************************************************************************************

  static Future<int?> getNonce(String? walletAddress, {bool txPool = true}) async {
    int? nonce;
    // rpc
    try {
      if ((walletAddress != null) && walletAddress.isNotEmpty) {
        // walletAddress no check
        List<String> seedRpcList = await getRpcServers(walletAddress);
        nonce = await Wallet.getNonceByAddress(walletAddress, txPool: txPool, config: RpcConfig(seedRPCServerAddr: seedRpcList));
      } else if (clientCommon.isClientOK) {
        // client no check rpcSeed
        nonce = await clientCommon.client?.getNonce(txPool: txPool);
      }
    } catch (e, st) {
      handleError(e, st);
    }
    Uint8List? pk = clientCommon.client?.publicKey;
    logger.d("PRC - getNonce - nonce:$nonce - txPool:$txPool - walletAddress:$walletAddress - clientPublicKey:${(pk != null) ? hexEncode(pk) : ""}");
    return nonce;
  }

  /// ***********************************************************************************************************
  /// ************************************************** Topic **************************************************
  /// ***********************************************************************************************************
  static Future<bool> subscribeWithPermission(
    String? topic, {
    int? nonce,
    double fee = 0,
    int? permPage,
    Map<String, dynamic>? meta,
    bool toast = false,
    String? clientAddress,
    int? oldStatus,
    int? newStatus,
  }) async {
    if (permPage == null) return false;
    String identifier = '__${permPage}__.__permission__';
    String metaString = (meta?.isNotEmpty == true) ? jsonEncode(meta) : "";
    List results = await _subscribe(topic, fee: fee, identifier: identifier, meta: metaString, nonce: nonce, toast: toast);
    bool success = results[0];
    bool canTryTimer = results[1];
    bool isBlock = results[2];
    int? _nonce = results[3];
    // block
    if (fee > 0) {
      if (success) {
        int? blockNonce = await RPC.getNonce(null, txPool: false);
        if ((blockNonce != null) && (blockNonce >= 0) && (_nonce != null) && (_nonce > blockNonce)) {
          for (var i = blockNonce; i < _nonce; i++) {
            logger.w("PRC - subscribeWithPermission - success with reset before trans - nonce:$i/${_nonce - 1} - fee:${fee.toStringAsFixed(8)} - identifier:$identifier - meta:$metaString - topic:$topic");
            _resetSubscribe(i, fee); // await
          }
        } else {
          logger.d("PRC - subscribeWithPermission - success with nonce ok - blockNonce:$blockNonce - successNonce:$_nonce - fee:${fee.toStringAsFixed(8)} - identifier:$identifier - meta:$metaString - topic:$topic");
        }
      } else if (!success && isBlock) {
        int? blockNonce = await RPC.getNonce(null, txPool: false);
        int? poolNonce = await RPC.getNonce(null, txPool: true);
        if ((blockNonce != null) && (blockNonce >= 0) && (poolNonce != null) && (poolNonce >= blockNonce)) {
          for (var i = blockNonce; i <= poolNonce; i++) {
            List results = await _subscribe(topic, fee: fee, identifier: identifier, meta: metaString, nonce: i);
            if (results[0] != true) {
              logger.w("PRC - subscribeWithPermission - fail with reset before trans - nonce:$i/$poolNonce - fee:${fee.toStringAsFixed(8)} - identifier:$identifier - meta:$metaString - topic:$topic");
              _resetSubscribe(i, fee); // await
            } else {
              logger.i("PRC - subscribeWithPermission - fail with reAction before trans - nonce:$i/$poolNonce - fee:${fee.toStringAsFixed(8)} - identifier:$identifier - meta:$metaString - topic:$topic");
              _nonce = i;
              break;
            }
          }
        } else {
          logger.w("PRC - subscribeWithPermission - fail with nonce ok - blockNonce:$blockNonce - successNonce:$poolNonce - fee:${fee.toStringAsFixed(8)} - identifier:$identifier - meta:$metaString - topic:$topic");
        }
      }
    } else if (!success) {
      logger.w("PRC - subscribeWithPermission - action fail - results:$results - topic:$topic - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$metaString - topic:$topic");
    }
    // try
    SubscriberSchema? _schema = await subscriberCommon.queryByTopicChatId(topic, clientAddress);
    if ((_schema != null) && (newStatus != null)) {
      if (!canTryTimer) {
        logger.w("PRC - subscribeWithPermission - cancel permission try - newStatus:$newStatus - oldStatus:$oldStatus - clientAddress:$clientAddress - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$metaString - topic:$topic");
        await subscriberCommon.setStatusProgressEnd(_schema.id);
        await subscriberCommon.setStatus(_schema.id, oldStatus, notify: true);
      } else {
        success = true; // will success by try timer
        logger.i("PRC - subscribeWithPermission - add permission try - newStatus:$newStatus - oldStatus:$oldStatus - clientAddress:$clientAddress - nonce:$_nonce - fee:$fee - identifier:$identifier - meta:$metaString - topic:$topic");
        await subscriberCommon.setStatusProgressStart(_schema.id, newStatus, _nonce, fee, notify: true);
      }
    }
    return success;
  }

  static Future<bool> subscribeWithJoin(
    String? topic,
    bool isJoin, {
    int? nonce,
    double fee = 0,
    bool toast = false,
  }) async {
    Function(int?) func = (int? nonce) async {
      return isJoin
          ? await _subscribe(
              topic,
              nonce: nonce,
              fee: fee,
              identifier: "",
              meta: "",
              toast: toast,
            )
          : await _unsubscribe(
              topic,
              nonce: nonce,
              fee: fee,
              identifier: "",
              toast: toast,
            );
    };
    List results = await func(nonce);
    bool success = results[0];
    bool canTry = results[1];
    bool isBlock = results[2];
    int? _nonce = results[3];
    // block
    if (fee > 0) {
      if (success) {
        int? blockNonce = await RPC.getNonce(null, txPool: false);
        if ((blockNonce != null) && (blockNonce >= 0) && (_nonce != null) && (_nonce > blockNonce)) {
          for (var i = blockNonce; i < _nonce; i++) {
            logger.w("PRC - subscribeWithJoin - success with reset before trans - isJoin:$isJoin - nonce:$i/${_nonce - 1} - fee:${fee.toStringAsFixed(8)} - topic:$topic");
            _resetSubscribe(i, fee); // await
          }
        } else {
          logger.d("PRC - subscribeWithJoin - success with nonce ok - isJoin:$isJoin - blockNonce:$blockNonce - successNonce:$_nonce - fee:${fee.toStringAsFixed(8)} - topic:$topic");
        }
      } else if (!success && isBlock) {
        int? blockNonce = await RPC.getNonce(null, txPool: false);
        int? poolNonce = await RPC.getNonce(null, txPool: true);
        if ((blockNonce != null) && (blockNonce >= 0) && (poolNonce != null) && (poolNonce >= blockNonce)) {
          for (var i = blockNonce; i <= poolNonce; i++) {
            List results = await func(i);
            if (results[0] != true) {
              logger.w("PRC - subscribeWithJoin - fail with reset before trans - isJoin:$isJoin - nonce:$i/$poolNonce - fee:${fee.toStringAsFixed(8)} - topic:$topic");
              _resetSubscribe(i, fee); // await
            } else {
              logger.i("PRC - subscribeWithJoin - fail with reAction before trans - isJoin:$isJoin - nonce:$i/$poolNonce - fee:${fee.toStringAsFixed(8)} - topic:$topic");
              _nonce = i;
              break;
            }
          }
        } else {
          logger.w("PRC - subscribeWithJoin - fail with nonce ok - isJoin:$isJoin - blockNonce:$blockNonce - successNonce:$poolNonce - fee:${fee.toStringAsFixed(8)} - topic:$topic");
        }
      }
    } else if (!success) {
      logger.w("PRC - subscribeWithJoin - action fail - results:$results - isJoin:$isJoin - nonce:$nonce - fee:$fee - topic:$topic");
    }
    // try
    TopicSchema? _schema = await topicCommon.queryByTopic(topic);
    if (_schema != null) {
      if (isJoin) {
        if (!canTry) {
          logger.w("PRC - subscribeWithJoin - cancel subscribe try - isJoin:$isJoin - nonce:$_nonce - fee:$fee - topic:$topic");
          await topicCommon.setStatusProgressEnd(_schema.id);
          await topicCommon.setJoined(_schema.id, false, notify: true);
        } else {
          success = true; // will success by try timer
          logger.i("PRC - subscribeWithJoin - add subscribe try - isJoin:$isJoin - nonce:$_nonce - fee:$fee - topic:$topic");
          await topicCommon.setStatusProgressStart(_schema.id, true, _nonce, fee, notify: true); // await
        }
      } else {
        if (!canTry) {
          logger.i("PRC - _unsubscribe - cancel unsubscribe try - isJoin:$isJoin - nonce:$_nonce - fee:$fee - topic:$topic");
          await topicCommon.setStatusProgressEnd(_schema.id);
          await topicCommon.setJoined(_schema.id, true, notify: true);
        } else {
          success = true; // will success by try timer
          logger.i("PRC - _unsubscribe - add unsubscribe try - isJoin:$isJoin - nonce:$_nonce - fee:$fee - topic:$topic");
          await topicCommon.setStatusProgressStart(_schema.id, false, _nonce, fee, notify: true); // await
        }
      }
    }
    return success;
  }

  // publish(meta = null) / private(meta != null)(owner_create / invitee / kick)
  static Future<List> _subscribe(
    String? topic, {
    int? nonce,
    double fee = 0,
    String identifier = "",
    String meta = "",
    bool toast = false,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false, false, null];
    int maxTryTimes = Settings.tryTimesTopicRpc;
    // func
    Function(int?) func = (int? nonce) async {
      bool success = false;
      bool canTry = true;
      bool isBlock = false;
      nonce = nonce ?? await RPC.getNonce(null);
      try {
        if (clientCommon.isClientOK) {
          String? topicHash = await clientCommon.client?.subscribe(
            topic: RPC.genTopicHash(topic),
            duration: Settings.blockHeightTopicSubscribeDefault,
            fee: fee.toStringAsFixed(8),
            identifier: identifier,
            meta: meta,
            nonce: nonce,
          );
          success = (topicHash != null) && (topicHash.isNotEmpty);
        } else {
          canTry = false;
        }
      } catch (e, st) {
        if (e.toString().contains("nonce is not continuous")) {
          // can not append tx to txpool: nonce is not continuous
          logger.w("PRC - _subscribe - try over by nonce is not continuous - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
        } else if (e.toString().contains("nonce is too low")) {
          // can not append tx to txpool: nonce is too low
          logger.w("PRC - _subscribe - try over by nonce is too low - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
        } else if (e.toString().contains('duplicate subscription exist in block')) {
          // can not append tx to txpool: duplicate subscription exist in block
          logger.w("PRC - _subscribe - block duplicated - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
          if (toast && identifier.isEmpty) Toast.show(Settings.locale((s) => s.request_processed));
          canTry = false;
          isBlock = true;
        } else if (e.toString().contains("doesn't exist")) {
          logger.w("PRC - _subscribe - topic doesn't exist - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
          canTry = false;
        } else if (e.toString().contains("txpool full")) {
          // txpool full, rejecting transaction with low priority
          logger.w("PRC - _subscribe - txpool full - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
          if (toast && identifier.isEmpty) Toast.show(Settings.locale((s) => s.something_went_wrong));
          canTry = false;
        } else if (e.toString().contains('not sufficient funds')) {
          // can not append tx to txpool: not sufficient funds
          logger.w("PRC - _subscribe - not sufficient funds - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier - meta:$meta");
          if (toast && identifier.isEmpty) Toast.show(Settings.locale((s) => s.balance_not_enough));
          canTry = false;
        } else {
          handleError(e, st);
        }
        if (!success) nonce = null;
      }
      return [success, canTry, isBlock, nonce];
    };
    // call
    List result = [false, true, false, null];
    int tryTimes = 0;
    while (tryTimes < maxTryTimes) {
      result = await func(result[3]);
      if (result[1] != true) break;
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 100));
    }
    logger.d("PRC - _subscribe - success:${result[0]} - canTry:${result[1]} - isBlock:${result[2]} - nonce:${result[3]} - tryTimes:$tryTimes");
    return result;
  }

  static Future<List> _unsubscribe(
    String? topic, {
    int? nonce,
    double fee = 0,
    String identifier = "",
    bool toast = false,
  }) async {
    if (topic == null || topic.isEmpty) return [false, false, false, null];
    int maxTryTimes = Settings.tryTimesTopicRpc;
    // func
    Function(int?) func = (int? nonce) async {
      bool success = false;
      bool canTry = true;
      bool isBlock = false;
      nonce = nonce ?? await RPC.getNonce(null);
      try {
        if (clientCommon.isClientOK) {
          String? topicHash = await clientCommon.client?.unsubscribe(
            topic: RPC.genTopicHash(topic),
            identifier: identifier,
            fee: fee.toStringAsFixed(8),
            nonce: nonce,
          );
          success = (topicHash != null) && (topicHash.isNotEmpty);
        } else {
          canTry = false;
        }
      } catch (e, st) {
        if (e.toString().contains("nonce is not continuous")) {
          // can not append tx to txpool: nonce is not continuous
          logger.e("PRC - _unsubscribe - try over by nonce is not continuous - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
        } else if (e.toString().contains("nonce is too low")) {
          // can not append tx to txpool: nonce is too low
          logger.e("PRC - _subscribe - try over by nonce is too low - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
        } else if (e.toString().contains('duplicate subscription exist in block')) {
          // can not append tx to txpool: duplicate subscription exist in block
          logger.w("PRC - _unsubscribe - block duplicated - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
          if (toast) Toast.show(Settings.locale((s) => s.request_processed));
          canTry = false;
          isBlock = true;
        } else if (e.toString().contains("doesn't exist")) {
          logger.e("PRC - _unsubscribe - topic doesn't exist - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
          canTry = false;
        } else if (e.toString().contains("txpool full")) {
          // txpool full, rejecting transaction with low priority
          logger.w("PRC - _unsubscribe - txpool full - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
          if (toast) Toast.show(Settings.locale((s) => s.something_went_wrong));
          canTry = false;
        } else if (e.toString().contains('not sufficient funds')) {
          // can not append tx to txpool: not sufficient funds
          logger.w("PRC - _unsubscribe - not sufficient funds - topic:$topic - nonce:$nonce - fee:$fee - identifier:$identifier");
          if (toast) Toast.show(Settings.locale((s) => s.balance_not_enough));
          canTry = false;
        } else {
          handleError(e, st);
        }
        if (!success) nonce = null;
      }
      return [success, canTry, isBlock, nonce];
    };
    // call
    List result = [false, true, false, null];
    int tryTimes = 0;
    while (tryTimes < maxTryTimes) {
      result = await func(result[3]);
      if (result[1] != true) break;
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 100));
    }
    logger.d("PRC - _unsubscribe - success:${result[0]} - canTry:${result[1]} - isBlock:${result[2]} - nonce:${result[3]} - tryTimes:$tryTimes");
    return result;
  }

  static Future<bool> _resetSubscribe(int nonce, double fee) async {
    bool success = false;
    try {
      String? address = await walletCommon.getDefaultAddress();
      if (address == null || address.isEmpty) return false;
      String keystore = await walletCommon.getKeystore(address);
      if (keystore.isEmpty) return false;
      String? password = await walletCommon.getPassword(address);
      if (password == null || password.isEmpty) return false;
      List<String> seedRpcList = await RPC.getRpcServers(address);
      Wallet nkn = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
      String? txHash = await nkn.transfer(address, "0.00000001", fee: fee.toStringAsFixed(8), nonce: nonce);
      success = (txHash != null) && (txHash.isNotEmpty);
    } catch (e, st) {
      handleError(e, st, toast: false);
    }
    logger.i("PRC - _resetSubscribe - success:$success - nonce:$nonce - fee:${fee.toStringAsFixed(8)}");
    return success;
  }

  static Future<Map<String, dynamic>> getSubscription(
    String? topic,
    String? subscriber, {
    int maxTryTimes = Settings.tryTimesTopicRpc,
  }) async {
    if (topic == null || topic.isEmpty || subscriber == null || subscriber.isEmpty) return Map();
    // func
    Function() func = () async {
      Map<String, dynamic>? result;
      try {
        if (clientCommon.isClientOK) {
          result = await clientCommon.client?.getSubscription(
            topic: genTopicHash(topic),
            subscriber: subscriber,
          );
        }
      } catch (e, st) {
        handleError(e, st);
      }
      try {
        if ((result == null) || result.isEmpty) {
          List<String> seedRpcList = await RPC.getRpcServers(await walletCommon.getDefaultAddress());
          result = await Wallet.getSubscription(
            genTopicHash(topic),
            subscriber,
            config: RpcConfig(seedRPCServerAddr: seedRpcList),
          );
        }
      } catch (e, st) {
        handleError(e, st);
      }
      return result;
    };
    // call
    Map<String, dynamic>? subscription;
    int tryTimes = 0;
    while (tryTimes < maxTryTimes) {
      subscription = await func();
      if ((subscription != null) && subscription.isNotEmpty) break;
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 100));
    }
    logger.d("PRC - getSubscription - count:${subscription?.keys.length} - tryTimes:$tryTimes - subscription:$subscription");
    return subscription ?? Map();
  }

  static Future<Map<String, dynamic>> getSubscribers(
    String? topic, {
    bool meta = false,
    bool txPool = true,
    // Uint8List? subscriberHashPrefix,
    int maxTryTimes = Settings.tryTimesTopicRpc,
  }) async {
    if (topic == null || topic.isEmpty) return Map();
    // func
    Function(int, int) func = (int offset, int limit) async {
      Map<String, dynamic>? result;
      try {
        if (clientCommon.isClientOK) {
          result = await clientCommon.client?.getSubscribers(
            topic: genTopicHash(topic),
            offset: offset,
            limit: limit,
            meta: meta,
            txPool: txPool,
            // subscriberHashPrefix: subscriberHashPrefix,
          );
        }
      } catch (e, st) {
        handleError(e, st);
      }
      try {
        if ((result == null) || result.isEmpty) {
          List<String> seedRpcList = await RPC.getRpcServers(await walletCommon.getDefaultAddress());
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
      } catch (e, st) {
        handleError(e, st);
      }
      return result;
    };
    // call
    Map<String, dynamic> subscribers = Map();
    int offset = 0;
    int limit = 1000;
    int tryTimes = 0;
    while (tryTimes < maxTryTimes) {
      Map<String, dynamic>? subs = await func(offset, limit);
      if ((subs != null) && subs.isNotEmpty) {
        subscribers.addAll(subs);
        if (subs.length < limit) break;
        offset += limit;
        continue;
      }
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 100));
    }
    logger.d("PRC - getSubscribers - count:${subscribers.length} - tryTimes:$tryTimes - subscribers:$subscribers");
    return subscribers;
  }

  static Future<int> getSubscribersCount(
    String? topic, {
    int maxTryTimes = Settings.tryTimesTopicRpc,
  }) async {
    if (topic == null || topic.isEmpty) return 0;
    // func
    Function() func = () async {
      int? result;
      try {
        if (clientCommon.isClientOK) {
          result = await clientCommon.client?.getSubscribersCount(
            topic: genTopicHash(topic),
            // subscriberHashPrefix: subscriberHashPrefix,
          );
        }
      } catch (e, st) {
        handleError(e, st);
      }
      try {
        if ((result == null) || (result <= 0)) {
          List<String> seedRpcList = await RPC.getRpcServers(await walletCommon.getDefaultAddress());
          result = await Wallet.getSubscribersCount(
            genTopicHash(topic),
            // subscriberHashPrefix: subscriberHashPrefix
            config: RpcConfig(seedRPCServerAddr: seedRpcList),
          );
        }
      } catch (e, st) {
        handleError(e, st);
      }
      return result;
    };
    // call
    int? count;
    int tryTimes = 0;
    while (tryTimes < maxTryTimes) {
      count = await func();
      if (count != null) break;
      tryTimes++;
      await Future.delayed(Duration(milliseconds: 100));
    }
    logger.d("PRC - getSubscribersCount - count:$count - tryTimes:$tryTimes");
    return count ?? 0;
  }

  static String genTopicHash(String topic) {
    var t = topic.replaceFirst(RegExp(r'^#*'), '');
    return 'dchat' + hexEncode(Uint8List.fromList(Hash.sha1(t)));
  }
}
