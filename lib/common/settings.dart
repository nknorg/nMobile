import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class NotificationType {
  static const only_name = 0;
  static const name_and_message = 1;
  static const none = 2;
}

class Settings {
  static bool get isRelease => const bool.fromEnvironment("dart.vm.product");

  static const bool debug = true;

  // global-context
  static late BuildContext appContext;

  // sentry
  static bool sentryEnable = true;
  static late String sentryDSN;

  // infura
  static late String infuraProjectId;
  static late String infuraApiKeySecret;

  // notification
  static bool notificationPushEnable = true;
  static int notificationType = NotificationType.only_name;
  static const String apnsTopic = "org.nkn.nmobile";

  // authentication
  static bool biometricsAuthentication = true;

  // language
  static String language = "auto";

  // app_info
  static const String appName = "nMobile";
  static String packageName = '';
  static String version = '';
  static String build = '';
  static String get versionFormat {
    String prefix = isRelease ? "" : "debug ";
    String suffix = (packageName.endsWith("test") || packageName.endsWith("Test")) ? " + test" : "";
    return '$prefix$version + (Build $build)$suffix';
  }

  // device_info
  static String deviceId = "";
  static String deviceVersionName = "";
  static String deviceVersion = "";
  static late Directory applicationRootDirectory; // eg:/data/user/0/org.nkn.mobile.app/app_flutter

  // debug
  static bool messageDebugInfo = false;

  // locale
  static S? _s;

  static S? _ss({BuildContext? ctx}) {
    try {
      if (_s != null) return _s;
      if (ctx != null) return S.maybeOf(ctx);
      if (appContext != null) {
        S? s = S.maybeOf(appContext);
        if ((s != null) && (_s == null)) _s = s;
      }
    } catch (e) {
      //handleError(e, st, toast: false, upload: false);
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
  static const int gapTxPoolUpdateDelayMs = 1 * 60 * 1000; // 1m
  static const int gapClientReAuthMs = 1 * 60 * 1000; // 1m
  static const int gapPingSessionsMs = 30 * 60 * 1000; // 30m
  static const int gapPingContactMs = 3 * 60 * 1000; // 3m
  static const int gapPongPingMs = 30 * 1000; // 30s
  static const int gapMessageQueueResendMs = 5 * 1000; // 5s
  static const int gapContactProfileSyncMs = 30 * 1000; // 30s
  static const int gapDeviceInfoRequestMs = 30 * 1000; // 30s
  static const int gapDeviceInfoSyncMs = 30 * 1000; // 30s
  static const int gapGroupRequestOptionsMs = 1 * 60 * 1000; // 1m
  static const int gapGroupRequestMembersMs = 1 * 60 * 1000; // 1m
  static const int gapTopicSubscribeCheckMs = 10 * 24 * 60 * 60 * 1000; // 10d < 23d
  static const int gapTopicPermissionCheckMs = 10 * 24 * 60 * 60 * 1000; // 10d < 23d
  static const int gapTopicSubscribersRefreshMs = 1 * 60 * 60 * 1000; // 1h
  static const int gapMessagesGroupSec = 2 * 60; // 2m
  // timeout
  static const int timeoutSeedMeasureMs = 3 * 1000; // 3s
  static const int timeoutPingSessionOnlineMs = 5 * 24 * 60 * 60 * 1000; // 5d
  static const int timeoutGroupInviteMs = 7 * 24 * 60 * 60 * 1000; // 7d
  static const int timeoutDeviceTokensDay = 5; // 5d
  static const int timeoutIpfsResetTimeoutMs = 30 * 24 * 60 * 60 * 1000; // 30d
  static const int timeoutIpfsThumbnailAutoDownloadMs = 7 * 24 * 60 * 60 * 1000; // 7d
  // tryTimes
  static const int tryTimesClientConnectWait = 10;
  static const int tryTimesMsgSend = 30;
  static const int tryTimesTopicRpc = 3;
  static const int tryTimesIpfsThumbnailUpload = 3;
  static const int tryTimesIpfsThumbnailDownload = 5;
  static const int tryTimesNotificationPush = 5;
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
    // init dotenv
    sentryDSN = dotenv.get('SENTRY_DSN');
    infuraProjectId = dotenv.get('INFURA_PROJECT_ID');
    infuraApiKeySecret = dotenv.get('INFURA_API_KEY_SECRET');

    // settings
    var bug = await SettingsStorage.getSettings(SettingsStorage.CLOSE_BUG_UPLOAD_API);
    sentryEnable = !((bug?.toString() == "true") || (bug == true));
    var push = await SettingsStorage.getSettings(SettingsStorage.CLOSE_NOTIFICATION_PUSH_API);
    notificationPushEnable = !((push?.toString() == "true") || (push == true));
    var msgDebug = await SettingsStorage.getSettings(SettingsStorage.OPEN_DEVELOP_OPTIONS_MESSAGE_DEBUG);
    messageDebugInfo = ((msgDebug?.toString() == "true") || (msgDebug == true));
    IpfsHelper.init(infuraProjectId, infuraApiKeySecret);
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
    logger.i("Settings - init - "
        "\n debug: $debug"
        "\n sentryEnable: $sentryEnable"
        "\n sentryDSN: $sentryDSN"
        "\n notificationPushEnable: $notificationPushEnable"
        "\n notificationType: $notificationType"
        "\n apnsTopic: $apnsTopic"
        "\n infuraProjectId: $infuraProjectId"
        "\n infuraApiKeySecret: $infuraApiKeySecret"
        "\n biometricsAuthentication: $biometricsAuthentication"
        "\n language: $language"
        "\n appName: $appName"
        "\n packageName: $packageName"
        "\n version: $version"
        "\n build: $build"
        "\n versionFormat: $versionFormat"
        "\n deviceId: $deviceId"
        "\n deviceVersionName: $deviceVersionName"
        "\n deviceVersion: $deviceVersion"
        "\n applicationRootDirectory: ${applicationRootDirectory.path}");
  }

  // return Your push(F_?_i_?_r_?_e_?_b_?_a_?_s_?_e) server token
  static String getGooglePushToken() {
    return "";
  }
}
