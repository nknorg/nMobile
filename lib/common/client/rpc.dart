import 'dart:collection';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/storages/settings.dart';
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

  static Future<List<String>> getRpcServers(String? walletAddress, {bool measure = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

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
        list = await Wallet.measureSeedRPCServer(list, Settings.timeoutMeasureSeedMs) ?? [];
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
}
