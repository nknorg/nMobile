import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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
  static String deviceVersion = "";

  static double screenWidth({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.width;
  static double screenHeight({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.height;

  static int topicDefaultSubscribeHeight = 400000; // 93day
  static int topicWarnBlockExpireHeight = 100000; // 23day

  static late int clientReAuthGapMs = 1 * 60 * 1000; // 1m
  static late int profileExpireMs = 1 * 60 * 60 * 1000; // 1h
  static late int deviceInfoExpireMs = 30 * 60 * 1000; // 30m
  static late int txPoolDelayMs = 3 * 60 * 1000; // 3m

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
    'http://mainnet-seed-0009.nkn.org:30003',
  ];

  static Map<String, int> nonceMap = {};

  static init() async {
    Global.applicationRootDirectory = await getApplicationDocumentsDirectory();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Global.packageName = packageInfo.packageName;
    Global.version = packageInfo.version;
    Global.build = packageInfo.buildNumber.replaceAll('.', '');

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      Global.deviceId = (await deviceInfo.androidInfo).androidId ?? "";
      Global.deviceVersion = (await deviceInfo.androidInfo).version.release ?? "";
      Global.deviceVersion = Global.deviceVersion.split(".")[0];
    } else if (Platform.isIOS) {
      Global.deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "";
      Global.deviceVersion = (await deviceInfo.iosInfo).systemVersion ?? "";
      Global.deviceVersion = Global.deviceVersion.split(".")[0];
    }
  }

  static Future<List<String>> getSeedRpcList(String? prefix, {bool measure = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    // get
    List<String> list = await SettingsStorage.getSeedRpcServers(prefix: prefix);
    list.addAll(defaultSeedRpcList);
    list = LinkedHashSet<String>.from(list).toList();
    logger.d("Global - getSeedRpcList - seedRPCServer - prefix:$prefix - length:${list.length} - list:$list");

    // measure
    if (measure) {
      list = await Wallet.measureSeedRPCServer(list) ?? defaultSeedRpcList;
      logger.i("Global - getSeedRpcList - measureSeedRPCServer - prefix:$prefix - length:${list.length} - list:$list");
      SettingsStorage.setSeedRpcServers(list, prefix: prefix); // await
    }
    return list;
  }

  static Future<int?> getNonce({String? walletAddress, bool forceFetch = false}) async {
    // walletAddress
    if ((walletAddress == null || walletAddress.isEmpty) && (clientCommon.client?.publicKey.isNotEmpty == true)) {
      try {
        walletAddress = await Wallet.pubKeyToWalletAddr(hexEncode(clientCommon.client!.publicKey));
      } catch (e) {
        handleError(e);
      }
    }

    int? nonce;

    // cached
    if (walletAddress?.isNotEmpty == true) {
      if (nonceMap[walletAddress] != null && nonceMap[walletAddress] != 0) {
        nonce = nonceMap[walletAddress]! + 1;
        logger.d("Global - getNonce - cached - nonce:$nonce");
      }
    }

    // rpc
    if (forceFetch || nonce == null || nonce <= 0) {
      nonce = await refreshNonce(walletAddress: walletAddress, useNow: true);
    }

    // set
    if ((walletAddress?.isNotEmpty == true) && (nonce != null && nonce != 0)) {
      nonceMap[walletAddress!] = nonce;
    }

    logger.d("Global - getNonce - nonce:$nonce - address:$walletAddress - clientPublicKey:${clientCommon.client?.publicKey != null ? hexEncode(clientCommon.client!.publicKey) : ""}");
    return nonce;
  }

  static Future<int?> refreshNonce({String? walletAddress, bool useNow = false, int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));

    // walletAddress
    if (walletAddress == null || walletAddress.isEmpty) {
      if (clientCommon.client?.publicKey.isNotEmpty == true) {
        try {
          walletAddress = await Wallet.pubKeyToWalletAddr(hexEncode(clientCommon.client!.publicKey));
        } catch (e) {
          handleError(e);
        }
      } else {
        return null;
      }
    }

    int? nonce;

    // rpc
    if (walletAddress?.isNotEmpty == true) {
      List<String> seedRpcList = await Global.getSeedRpcList(null);
      nonce = await Wallet.getNonceByAddress(walletAddress!, txPool: true, config: RpcConfig(seedRPCServerAddr: seedRpcList));
    } else {
      nonce = await clientCommon.client?.getNonce(txPool: true);
    }

    if (!useNow && nonce != null) --nonce;

    // set
    if ((walletAddress?.isNotEmpty == true) && (nonce != null && nonce != 0)) {
      nonceMap[walletAddress!] = nonce;
    }

    logger.d("Global - refreshNonce - nonce:$nonce - address:$walletAddress - clientPublicKey:${clientCommon.client?.publicKey != null ? hexEncode(clientCommon.client!.publicKey) : ""}");
    return nonce;
  }
}
