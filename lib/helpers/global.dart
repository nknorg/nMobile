import 'dart:io';

import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/settings.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/client.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart';

import 'local_notification.dart';

class Global {
  static BuildContext appContext;
  static String locale;
  static ClientSchema currentClient;
  static ContactSchema currentUser;
  static Database currentChatDb;
  static Directory applicationRootDirectory;
  static String version;
  static String buildVersion;
  static Map<String, num> loadTopicTime = {};
  static Map<String, num> loadLoadSubscribers = {};
  static AppLifecycleState state = AppLifecycleState.resumed;
  static Map<String, DateTime> _loadProfileCache = {};
  static String currentChatId;

  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");

  static bool isLocaleZh() => locale != null && locale.startsWith('zh');

  static Future init(VoidCallback callback) async {
    WidgetsFlutterBinding.ensureInitialized();
    await SpUtil.getInstance();
    LogUtil.init(isDebug: true, tag: '@@nMobile@@');
    LogUtil.v('start App');
    setupLocator();
    await initData();
    callback();
    if (Platform.isAndroid) {
      SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent);
      SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    }
  }

  static Future initData() async {
    NknWalletPlugin.init();
    NknClientPlugin.init();
    LocalNotification.init();
    Global.applicationRootDirectory = await getApplicationDocumentsDirectory();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Global.version = packageInfo.version;
//    Global.buildVersion = '101';
    Global.buildVersion = packageInfo.buildNumber.replaceAll('.', '');
    LocalStorage localStorage = LocalStorage();
    // load language
    Global.locale = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.LOCALE_KEY}')) ?? 'auto';
    // load settings
    Settings.localNotificationType = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.LOCAL_NOTIFICATION_TYPE_KEY}')) ?? 0;
    Settings.debug = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.DEBUG_KEY}')) ?? false;

    final LocalAuthenticationService localAuth = locator<LocalAuthenticationService>();
    localAuth.isProtectionEnabled = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.AUTH_KEY}')) as bool ?? false;
    localAuth.authType = await localAuth.getAuthType();
  }

  static bool isLoadTopic(String topic) {
    num currentTime = num.parse(DateUtil.formatDate(DateTime.now(), format: "yyyyMMddHHmm"));
    if (loadTopicTime.containsKey(topic)) {
      if ((currentTime - loadTopicTime[topic]) >= 5) {
        loadTopicTime[topic] = currentTime;
        return true;
      } else {
        return false;
      }
    } else {
      loadTopicTime[topic] = currentTime;
      return true;
    }
  }

  static removeTopicCache(String topic) {
    loadTopicTime.remove(topic);
    loadLoadSubscribers.remove(topic);
  }

  static bool isLoadSubscribers(String topic) {
    num currentTime = num.parse(DateUtil.formatDate(DateTime.now(), format: "yyyyMMddHHmm"));
    if (loadLoadSubscribers.containsKey(topic)) {
      if ((currentTime - loadLoadSubscribers[topic]) >= 10) {
        loadLoadSubscribers[topic] = currentTime;
        return true;
      } else {
        return false;
      }
    } else {
      loadLoadSubscribers[topic] = currentTime;
      return true;
    }
  }

  static isLoadProfile(String publicKey) {
    if (_loadProfileCache.containsKey(publicKey)) {
      if (DateTime.now().isAfter(_loadProfileCache[publicKey])) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }

  static saveLoadProfile(String publicKey) {
    _loadProfileCache[publicKey] = DateTime.now().add(Duration(minutes: 1));
  }
}
