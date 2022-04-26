import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class Global {
  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");

  static late BuildContext appContext;
  static late Directory applicationRootDirectory; // eg:/data/user/0/org.nkn.mobile.app/app_flutter

  static String packageName = '';
  static String version = '';
  static String build = '';

  static String get versionFormat {
    String suffix = (Global.packageName.endsWith("test") || Global.packageName.endsWith("Test")) ? " + test" : "";
    return '${Global.version} + (Build ${Global.build})$suffix';
  }

  static String deviceId = "";
  static String deviceVersionName = "";
  static String deviceVersion = "";

  static double screenWidth({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.width;
  static double screenHeight({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.height;

  static S? _s;

  static S? s({BuildContext? ctx}) {
    if (_s != null) return _s;
    if (ctx != null) return S.maybeOf(ctx);
    if (appContext != null) {
      S? s = S.maybeOf(appContext);
      if ((s != null) && (_s == null)) _s = s;
    }
    return _s;
  }

  static String locale(Function(S s) func, {BuildContext? ctx, String defShow = " "}) {
    S? __s = s(ctx: ctx);
    if (__s == null) return defShow;
    return func(__s);
  }

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

  static Lock _heightLock = Lock();
  static int? blockHeight;

  static Lock _nonceLock = Lock();

  static int topicDefaultSubscribeHeight = 400000; // 93day
  static int topicWarnBlockExpireHeight = 100000; // 23day

  static int clientReAuthGapMs = 1 * 60 * 1000; // 1m
  static int topicSubscribeCheckGapMs = 12 * 60 * 60 * 1000; // 12h
  static int contactsPingGapMs = 3 * 60 * 60 * 1000; // 3h
  static int profileExpireMs = 30 * 60 * 1000; // 30m
  static int deviceInfoExpireMs = 12 * 60 * 60 * 1000; // 12h
  static int txPoolDelayMs = 1 * 60 * 1000; // 1m

  static double topicSubscribeFeeDefault = 0.00010009; // fee

  static init() async {
    Global.applicationRootDirectory = await getApplicationDocumentsDirectory();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Global.packageName = packageInfo.packageName;
    Global.version = packageInfo.version;
    Global.build = packageInfo.buildNumber.replaceAll('.', '');

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      Global.deviceId = (await deviceInfo.androidInfo).androidId ?? "";
      Global.deviceVersionName = (await deviceInfo.androidInfo).version.release ?? "";
      Global.deviceVersion = Global.deviceVersionName.split(".")[0];
    } else if (Platform.isIOS) {
      Global.deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "";
      Global.deviceVersionName = (await deviceInfo.iosInfo).systemVersion ?? "";
      Global.deviceVersion = Global.deviceVersionName.split(".")[0];
    }
  }

  /// ***********************************************************************************************************
  /// ********************************************* SeedRpcServers **********************************************
  /// ***********************************************************************************************************

  static Future<List<String>> getRpcServers(String? walletAddress, {bool measure = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    // if (application.inBackGround) return;

    // get
    List<String> list = await _getRpcServers(walletAddress: walletAddress);
    logger.d("Global - getRpcServers - init - walletAddress:$walletAddress - length:${list.length} - list:$list");

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
        list = await Wallet.measureSeedRPCServer(list, 3 * 1000) ?? [];
        await _setRpcServers(walletAddress, list);

        if (walletAddress?.isNotEmpty == true) {
          List<String> saved = await _getRpcServers(walletAddress: walletAddress);
          if (saved.isEmpty) {
            logger.w("Global - getRpcServers - saved empty - walletAddress:$walletAddress");
          } else {
            logger.i("Global - getRpcServers - saved ok - walletAddress:$walletAddress - length:${saved.length} - list:$saved");
          }
        }
      } catch (e) {
        // list = defaultSeedRpcList;
        handleError(e);
      }
    }

    // again
    if (list.length <= 2) {
      if (!appendDefault) return getRpcServers(walletAddress, measure: measure, delayMs: 0);
    }

    logger.d("Global - getRpcServers - return - walletAddress:$walletAddress - length:${list.length} - list:$list");
    return list;
  }

  static Future addRpcServers(String? walletAddress, List<String> rpcServers) async {
    if (rpcServers.isEmpty) return;
    List<String> list = await _getRpcServers(walletAddress: walletAddress);
    list.insertAll(0, rpcServers);
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

  static Future _setRpcServers(String? walletAddress, List<String> list) async {
    list = _filterRepeatAndSeedsFromRpcServers(list);
    return SettingsStorage.setSettings('${SettingsStorage.SEED_RPC_SERVERS_KEY}${walletAddress?.isNotEmpty == true ? ":$walletAddress" : ""}', list);
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
    return await _heightLock.synchronized(() {
      return _getBlockHeightWithNoLock();
    });
  }

  static Future<int?> _getBlockHeightWithNoLock() async {
    int? newBlockHeight;
    try {
      if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        newBlockHeight = await clientCommon.client?.getHeight();
      }
      if ((newBlockHeight == null) || (newBlockHeight <= 0)) {
        List<String> seedRpcList = await Global.getRpcServers(null);
        newBlockHeight = await Wallet.getHeight(config: RpcConfig(seedRPCServerAddr: seedRpcList));
      }
    } catch (e) {
      handleError(e);
    }
    if ((newBlockHeight != null) && (newBlockHeight > 0)) blockHeight = newBlockHeight;
    return blockHeight;
  }

  /// ***********************************************************************************************************
  /// ************************************************** nonce **************************************************
  /// ***********************************************************************************************************

  static Future<int?> getNonce(String? walletAddress, {bool txPool = true}) async {
    return await _nonceLock.synchronized(() {
      return _getNonceWithNoLock(walletAddress, txPool: txPool);
    });
  }

  static Future<int?> _getNonceWithNoLock(String? walletAddress, {bool txPool = true}) async {
    int? nonce;
    // rpc
    try {
      if (walletAddress?.isNotEmpty == true) {
        // walletAddress no check
        List<String> seedRpcList = await Global.getRpcServers(walletAddress);
        nonce = await Wallet.getNonceByAddress(walletAddress!, txPool: txPool, config: RpcConfig(seedRPCServerAddr: seedRpcList));
      } else if (clientCommon.isClientCreated && !clientCommon.clientClosing) {
        // client no check rpcSeed
        nonce = await clientCommon.client?.getNonce(txPool: txPool);
      }
    } catch (e) {
      handleError(e);
    }
    logger.d("Global - getNonce - nonce:$nonce - txPool:$txPool - walletAddress:$walletAddress - clientPublicKey:${clientCommon.client?.publicKey != null ? hexEncode(clientCommon.client!.publicKey) : ""}");
    return nonce;
  }
}
