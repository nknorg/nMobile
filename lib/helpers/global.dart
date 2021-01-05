import 'dart:io';

import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/settings.dart';
import 'package:nmobile/plugins/common_native.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/services/android_messaging_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';

import 'local_notification.dart';

class Global {
  static LOG _LOG = LOG('Global'.tag());
  static BuildContext appContext;
  static String locale;
  static String currentOtherChatId;
  static Directory applicationRootDirectory;
  static String version;
  static String buildVersion;
  static Map<String, DateTime> loadTopicDataTime = {};
  static Map<String, num> loadLoadSubscribers = {};
  static AppLifecycleState state;
  static Map<String, DateTime> _loadProfileCache = {};

  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");

  static bool isLocaleZh() => locale != null && locale.startsWith('zh');

  static String get versionFull => '${Global.version} + (Build ${Global.buildVersion})';

  static String get showVersion => '${Global.buildVersion}';

  static bool upgradedGroupBlockHeight = false;
  static bool clientCreated = false;

  // 工厂模式
  factory Global() => _getInstance();

  static Global get instance => _getInstance();
  static Global _instance;

  /// 创建Map来记录发送的信息
  static Map<String, dynamic> postNameMap = Map<String, dynamic>();
  static Map<String, Map> sendDataMap = Map<String,Map>();
  /// 这个是常驻listening的
  static Map<String, dynamic> postEventListening = Map<String, dynamic>();

  Global._internal() {
    // 初始化
  }

  static Global _getInstance() {
    if (_instance == null) {
      _instance = new Global._internal();

    }
    return _instance;
  }


  static debugLog(String logInfo){
    if (Global.isRelease == false){
      print(logInfo);
    }
  }

  static Future init(VoidCallback callback) async {
    _LOG.d('--->>> init --->>>');
    WidgetsFlutterBinding.ensureInitialized();
    // Do not set value here. Will be set in `AppState.didChangeAppLifecycleState()`.
    // state = AppLifecycleState.resumed;
    await SpUtil.getInstance();
    setupSingleton();
    await initData();
    callback();
    if (Platform.isAndroid) {
      SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent);
      SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
//      BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
      AndroidMessagingService.registerNativeCallback();
    }
  }

  static Future initData() async {
    NknWalletPlugin.init();
    LocalNotification.init();
    Global.applicationRootDirectory = await getApplicationDocumentsDirectory();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Global.version = packageInfo.version;
    Global.buildVersion = packageInfo.buildNumber.replaceAll('.', '');
    LocalStorage localStorage = LocalStorage();
    // load language
    Global.locale = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.LOCALE_KEY}')) ?? 'auto';
    // load settings
    Settings.localNotificationType = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.LOCAL_NOTIFICATION_TYPE_KEY}')) ?? 0;
    Settings.debug = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.DEBUG_KEY}')) ?? false;
  }

  static bool isLoadTopic(String topic) {
    DateTime currentT = DateTime.now();
    if (loadTopicDataTime.containsKey(topic)) {
      if (currentT.isAfter(loadTopicDataTime[topic])) {
        loadTopicDataTime[topic] = currentT.add(Duration(minutes: 1));
        return true;
      } else {
        return false;
      }
    } else {
      loadTopicDataTime[topic] = currentT.add(Duration(minutes: 1));
      return true;
    }
  }

  static removeTopicCache(String topic) {
    loadTopicDataTime.remove(topic);
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
