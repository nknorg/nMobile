import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../storages/settings.dart';

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

  static int topicDefaultSubscribeHeight = 400000;
  static int topicWarnBlockExpireHeight = 100000;

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

  static Future<List<String>> getSeedRpcList({bool measure = true}) async {
    SettingsStorage settingsStorage = SettingsStorage();
    List<String> list = await settingsStorage.getSeedRpcServers();
    list.addAll(defaultSeedRpcList);
    list = LinkedHashSet<String>.from(list).toList();
    logger.i("Global - getSeedRpcList - seedRPCServer - length:${list.length} - list:$list");
    if (measure) {
      list = await Wallet.measureSeedRPCServer(list) ?? defaultSeedRpcList;
      logger.i("Global - getSeedRpcList - measureSeedRPCServer - length:${list.length} - list:$list");
    }
    return list;
  }

  static Future<int?> getNonce({String? walletAddress}) async {
    int? nonce;

    // walletAddress
    if ((walletAddress == null || walletAddress.isEmpty) && (clientCommon.client?.publicKey.isNotEmpty == true)) {
      walletAddress = await Wallet.pubKeyToWalletAddr(hexEncode(clientCommon.client!.publicKey));
    }

    // cached
    if (walletAddress?.isNotEmpty == true) {
      if (nonceMap[walletAddress] != null && nonceMap[walletAddress] != 0) {
        nonce = nonceMap[walletAddress]! + 1;
        logger.d("Global - getNonce - cached - nonce:$nonce");
      }
    }

    // rpc
    if (nonce == null || nonce == 0) {
      if (walletAddress?.isNotEmpty == true) {
        nonce = await Wallet.getNonceByAddress(walletAddress!, txPool: true, config: RpcConfig(seedRPCServerAddr: await getSeedRpcList()));
      } else {
        nonce = await clientCommon.client?.getNonce(txPool: true);
      }
    }

    // set
    if ((walletAddress?.isNotEmpty == true) && (nonce != null && nonce != 0)) {
      nonceMap[walletAddress!] = nonce;
    }

    logger.i("Global - getNonce - nonce:$nonce - address:$walletAddress - clientPublicKey:${clientCommon.client?.publicKey != null ? hexEncode(clientCommon.client!.publicKey) : ""}");
    return nonce;
  }
}
