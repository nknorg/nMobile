import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';

import '../storages/settings.dart';

class Global {
  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");
  static BuildContext appContext;

  static Directory applicationRootDirectory; // eg:/data/user/0/org.nkn.mobile.app.debug/app_flutter
  static String version;
  static String build;

  static String get versionFormat => '${Global.version} + (Build ${Global.build})';

  static List<String> defaultSeedRpcList = ['http://seed.nkn.org:30003', 'http://mainnet-seed-0009.nkn.org:30003'];
  static List<String> seedRpcList;

  static Future<List<String>> getSeedRpcList() async {
    SettingsStorage settingsStorage = SettingsStorage();
    List<String> list = await settingsStorage.getSeedRpcServers();
    list.addAll(defaultSeedRpcList);
    list = LinkedHashSet<String>.from(list).toList();
    return list;
  }

  static init() async {
    Global.applicationRootDirectory = await getApplicationDocumentsDirectory();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Global.version = packageInfo.version;
    Global.build = packageInfo.buildNumber.replaceAll('.', '');
  }
}
