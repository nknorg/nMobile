import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/utils.dart';

class TopSub {
  // TODO:GG mean? subscriber = "identifier.publickey"
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
        List<String> seedRpcList = await Global.getSeedRpcList(null);
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
            List<String> seedRpcList = await Global.getSeedRpcList(null);
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
        List<String> seedRpcList = await Global.getSeedRpcList(null);
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
