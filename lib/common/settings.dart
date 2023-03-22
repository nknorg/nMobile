import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class NotificationType {
  static const only_name = 0;
  static const name_and_message = 1;
  static const none = 2;
}

class Settings {
  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");

  static late BuildContext appContext;

  // settings
  static const bool debug = true;
  static const String sentryDSN = '';
  static const String infuraProjectId = '';
  static const String infuraApiKeySecret = '';

  // app_info
  static const String appName = "nMobile";
  static String packageName = '';
  static String version = '';
  static String build = '';
  static String get versionFormat {
    String suffix = (packageName.endsWith("test") || packageName.endsWith("Test")) ? " + test" : "";
    return '$version + (Build $build)$suffix';
  }

  // device_info
  static String deviceId = "";
  static String deviceVersionName = "";
  static String deviceVersion = "";
  static late Directory applicationRootDirectory; // eg:/data/user/0/org.nkn.mobile.app/app_flutter

  // language
  static late String language;

  // notification
  static const String apnsTopic = "";
  static late int notificationType;

  // authentication
  static late bool biometricsAuthentication;

  // locale
  static S? _s;

  static S? _ss({BuildContext? ctx}) {
    if (_s != null) return _s;
    if (ctx != null) return S.maybeOf(ctx);
    if (appContext != null) {
      S? s = S.maybeOf(appContext);
      if ((s != null) && (_s == null)) _s = s;
    }
    return _s;
  }

  static String locale(Function(S s) func, {BuildContext? ctx, String defShow = " "}) {
    S? __s = _ss(ctx: ctx);
    if (__s == null) return defShow;
    return func(__s);
  }

  // screen
  static double screenWidth({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.width;
  static double screenHeight({BuildContext? context}) => MediaQuery.of(context ?? appContext).size.height;

  // gap
  static const int gapClientReAuthMs = 60 * 1000; // 1m
  static const int gapTxPoolUpdateDelayMs = 1 * 60 * 1000; // 1m
  static const int gapPingSessionsMs = 6 * 60 * 60 * 1000; // 6h
  static const int gapPingContactMs = 3 * 60 * 1000; // 3m
  static const int gapPongPingMs = 30 * 1000; // 30s
  static const int gapGroupRequestOptionsMs = 5 * 60 * 1000; // 5m
  static const int gapTopicSubscribeCheckMs = 24 * 60 * 60 * 1000; // 24h
  static const int gapTopicSubscribersRefreshMs = 1 * 60 * 60 * 1000; // 1h
  static const int gapMessagesGroupSec = 2 * 60; // 2m
  // timeout
  static const int timeoutSeedMeasureMs = 5 * 1000; // 5s
  static const int timeoutPingSessionOnlineMs = 5 * 24 * 60 * 60 * 1000; // 5d
  static const int timeoutGroupInviteMs = 7 * 24 * 60 * 60 * 1000; // 7d
  static const int timeoutDeviceTokensDay = 5; // 5d
  // tryTimes
  static const int tryTimesClientConnectWait = 10;
  static const int tryTimesMsgSend = 10;
  static const int tryTimesIpfsThumbnailUpload = 3;
  static const int tryTimesIpfsThumbnailDownload = 5;
  static const int tryTimesNotificationPush = 3;
  // maxCount
  static const int maxCountPingSessions = 10;
  static const int maxCountPushDevices = 3;
  // fee
  static double feeTopicSubscribeDefault = 0.00010009; // fee
  // block_height
  static const int blockHeightTopicSubscribeDefault = 400000; // 93day
  static const int blockHeightTopicWarnBlockExpire = 100000; // 23day
  // size
  static const int sizeMsgMax = 32 * 1000; // < 32K
  static const int sizeNknSendMax = 4 * 1000 * 1000; // < 4,000,000
  static const int sizeIpfsMax = 100 * 1000 * 1000; // 100M
  static const int sizeAvatarMax = 25 * 1000; // 25K < 32K(sizeMsgMax)
  static const int sizeAvatarBest = 10 * 1000; // 12K
  static const int sizeThumbnailMax = 100 * 1000; // 100K
  static const int sizeThumbnailBest = 20 * 1000; // 20K
  // duration
  static const double durationAudioRecordMaxS = 60;
  static const double durationAudioRecordMinS = 0.5;
  // piece
  static const int piecesPreMinLen = 10 * 1000; // >= 10K
  static const int piecesPreMaxLen = 16 * 1000; // <= 16K < 32K(sizeMsgMax)
  static const int piecesMinParity = 1; // >= 1
  static const int piecesMinTotal = 3 - piecesMinParity; // >= 2 ((2*10)K < 32K)
  static const int piecesMaxParity = 2; // <= 2
  static const int piecesMaxTotal = 12 - piecesMaxParity; // <= 10
  static const int piecesMaxSize = piecesMaxTotal * piecesPreMaxLen; // <= 160K

  static init() async {
    // settings TODO:GG pro+dev
    IpfsHelper.init("infuraProjectId", "infuraApiKeySecret");
    // app_info
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Settings.packageName = packageInfo.packageName;
    Settings.version = packageInfo.version;
    Settings.build = packageInfo.buildNumber.replaceAll('.', '');
    // deviceInfo
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      Settings.deviceId = (await AndroidId().getId()) ?? "";
      AndroidDeviceInfo _info = await deviceInfo.androidInfo;
      Settings.deviceVersionName = _info.version.release;
      Settings.deviceVersion = Settings.deviceVersionName.split(".")[0];
    } else if (Platform.isIOS) {
      IosDeviceInfo _info = await deviceInfo.iosInfo;
      Settings.deviceId = _info.identifierForVendor ?? "";
      Settings.deviceVersionName = _info.systemVersion ?? "";
      Settings.deviceVersion = Settings.deviceVersionName.split(".")[0];
    }
    Settings.applicationRootDirectory = await getApplicationDocumentsDirectory();
    // language
    Settings.language = (await SettingsStorage.getSettings(SettingsStorage.LOCALE_KEY)) ?? 'auto';
    // notification
    Settings.notificationType = (await SettingsStorage.getSettings(SettingsStorage.NOTIFICATION_TYPE_KEY)) ?? NotificationType.only_name;
    // authentication
    final isAuth = await SettingsStorage.getSettings(SettingsStorage.BIOMETRICS_AUTHENTICATION);
    Settings.biometricsAuthentication = (isAuth == null) ? true : ((isAuth is bool) ? isAuth : true);
  }

  // return Your push(F_?_i_?_r_?_e_?_b_?_a_?_s_?_e) server token
  static String getGooglePushToken() {
    return "";
  }
}
