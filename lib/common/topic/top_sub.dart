import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/utils.dart';

class TopSub {
  /// ***********************************************************************************************************
  /// *********************************************** subscribe *************************************************
  /// ***********************************************************************************************************

  static Future<int> getSubscribersCount(String? topic) async {
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
    return count ?? 0;
  }

  static Future<Map<String, dynamic>> getSubscribers(
    String? topic, {
    int offset = 0,
    int limit = 10000,
    bool meta = false,
    bool txPool = true,
    // Uint8List? subscriberHashPrefix,
  }) async {
    if (topic == null || topic.isEmpty) return Map();
    Map<String, dynamic> results = Map();
    try {
      bool loop = true;
      while (loop) {
        Map<String, dynamic>? result = await clientCommon.client?.getSubscribers(
          topic: genTopicHash(topic),
          offset: offset,
          limit: limit,
          meta: meta,
          txPool: txPool,
          // subscriberHashPrefix: subscriberHashPrefix,
        );
        results.addAll(result ?? Map());
        offset += limit;
        loop = result?.isNotEmpty == true;
      }
    } catch (e) {
      handleError(e);
      return results;
    }
    return results;
  }

// TODO:GG _clientGetSubscription
}
