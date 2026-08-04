import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/settings/settings_bloc.dart';
import 'package:nmobile/blocs/settings/settings_state.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/native/crypto.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/settings.dart' as settings_storage;
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'upgrade.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  if (Platform.isAndroid) {
    SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // nkn
  await Wallet.install();
  await Client.install();
  await Crypto.install();
  await Common.install();

  // locator
  setupLocator();

  // init
  application.registerInitialize(() async {
    Routes.init();
    await Settings.init();
    await appCache.init();
    await Upgrade.run();
  });
  await application.initialize();
  // Auto create default wallet on first launch
  try {
    final createdFlag = await settings_storage.SettingsStorage.getSettings(settings_storage.SettingsStorage.DEFAULT_WALLET_CREATED);
    if (!(createdFlag == true || createdFlag?.toString() == 'true')) {
      final WalletStorage walletStorage = WalletStorage();
      final List<WalletSchema> existingWallets = await walletStorage.getAll();
      if (existingWallets.isNotEmpty) {
        await settings_storage.SettingsStorage.setSettings(settings_storage.SettingsStorage.DEFAULT_WALLET_CREATED, true);
      } else {
        // create NKN wallet with empty password
        final Wallet nkn = await Wallet.create(null, config: WalletConfig(password: ''));
        if (nkn.address.isNotEmpty && nkn.keystore.isNotEmpty) {
          final WalletSchema wallet = WalletSchema(
            type: WalletType.nkn,
            address: nkn.address,
            publicKey: hexEncode(nkn.publicKey),
            name: 'Default Account',
          );
          await walletStorage.add(wallet, nkn.keystore, '', hexEncode(nkn.seed));
          await walletStorage.setDefaultAddress(wallet.address);
          await settings_storage.SettingsStorage.setSettings(settings_storage.SettingsStorage.DEFAULT_WALLET_CREATED, true);
        }
      }
    }
  } catch (e, st) {
    handleError(e, st, upload: false);
  }

  if (Settings.sentryEnable) {
    await SentryFlutter.init(
      (options) {
        options.debug = !Settings.isRelease;
        options.environment = Settings.isRelease ? 'production' : 'debug';
        options.release = Settings.versionFormat;
        options.dsn = Settings.sentryDSN;
        options.autoInitializeNativeSdk = true;
        options.enableTracing = true;
        options.attachStacktrace = true;
        options.attachViewHierarchy = true;
        options.idleTimeout = Duration(seconds: 10);
        options.sendClientReports = true;
        options.captureFailedRequests = true;
        options.enableNativeCrashHandling = true;
        options.enableAutoSessionTracking = true;
        options.enableNdkScopeSync = true;
        options.attachThreads = true;
        options.enableAutoPerformanceTracing = true;
        options.enableWatchdogTerminationTracking = true;
        options.enableScopeSync = true;
        options.reportPackages = true;
        options.anrEnabled = true;
        options.reportSilentFlutterErrors = true;
        options.autoAppStart = true;
        options.enableAutoNativeBreadcrumbs = true;
        options.enableUserInteractionBreadcrumbs = true;
        // options.beforeSend = (SentryEvent event, {Hint? hint}) {};
      },
      appRunner: () => runApp(ProviderScope(child: Main())),
    );
  } else {
    catchGlobalError(() async {
      runApp(ProviderScope(child: Main()));
    }, onZoneError: (Object error, StackTrace stack) {
      if (Settings.debug) logger.e(error);
      if (Settings.sentryEnable) Sentry.captureException(error, stackTrace: stack);
    });
  }
}

class Main extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  List<BlocProvider> providers = [
    BlocProvider<WalletBloc>(create: (BuildContext context) => WalletBloc()),
    BlocProvider<SettingsBloc>(create: (BuildContext context) => SettingsBloc()),
  ];

  final botToastBuilder = BotToastInit();

  @override
  void initState() {
    super.initState();
    Settings.appContext = context; // be replace by app.context
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers,
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return MaterialApp(
            builder: (context, child) {
              child = botToastBuilder(context, child);
              return child;
            },
            onGenerateTitle: (context) {
              return Settings.appName;
            },
            title: Settings.appName,
            theme: application.theme.themeData,
            navigatorObservers: [
              BotToastNavigatorObserver(),
              SentryNavigatorObserver(),
              Routes.routeObserver,
            ],
            onGenerateRoute: Routes.onGenerateRoute,
            initialRoute: AppScreen.routeName,
            locale: Settings.language == 'auto' ? null : Locale.fromSubtags(languageCode: Settings.language),
            localizationsDelegates: [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              ...S.delegate.supportedLocales,
            ],
            localeResolutionCallback: (locale, supportLocales) {
              if (locale?.languageCode.toLowerCase() == 'en') {
                return const Locale('en');
              } else if (locale?.languageCode.toLowerCase() == 'zh') {
                if (locale?.scriptCode?.toLowerCase() == 'hant') {
                  return const Locale('zh', 'TW');
                } else {
                  return const Locale('zh', 'CN');
                }
              } else if (locale?.languageCode.toLowerCase() == 'zh_hant_cn') {
                return const Locale('zh', 'TW');
              }
              // else if (locale?.languageCode == 'auto') {
              //   return null;
              // }
              // return null;
              return const Locale('en');
            },
          );
        },
      ),
    );
  }
}
