import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/settings/settings_bloc.dart';
import 'package:nmobile/blocs/settings/settings_state.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  // nkn
  await Wallet.install();
  await Client.install();
  await Common.install();

  // locator
  setupLocator();

  // init
  application.registerInitialize(() async {
    Routes.init();
    await Global.init();
    await Settings.init();
  });
  await application.initialize();

  // mounted
  application.registerMounted(() async {
    taskService.init();
    await localNotification.init();
    // await backgroundFetchService.install();

    BlocProvider.of<WalletBloc>(Global.appContext).add(LoadWallet());
  });

  // error
  catchGlobalError(() async {
    await SentryFlutter.init(
      (options) {
        options.debug = Settings.debug;
        options.dsn = Settings.sentryDSN;
        options.environment = Global.isRelease ? 'production' : 'debug';
        options.release = Global.versionFormat;
      },
      // return
      appRunner: () => runApp(Main()),
    );
  }, onZoneError: (Object error, StackTrace stack) async {
    if (Settings.debug) logger.e(error, stack);
    await Sentry.captureException(error, stackTrace: stack);
  });
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
              return S.of(context).app_name;
            },
            title: Settings.appName,
            theme: application.theme.themeData,
            locale: Settings.locale == 'auto' ? null : Locale.fromSubtags(languageCode: Settings.locale),
            localizationsDelegates: [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              ...S.delegate.supportedLocales,
            ],
            initialRoute: AppScreen.routeName,
            onGenerateRoute: Routes.onGenerateRoute,
            navigatorObservers: [
              BotToastNavigatorObserver(),
              SentryNavigatorObserver(),
              Routes.routeObserver,
            ],
            localeResolutionCallback: (locale, supportLocales) {
              if (locale?.languageCode == 'zh') {
                if (locale?.scriptCode == 'Hant') {
                  return const Locale('zh', 'TW');
                } else {
                  return const Locale('zh', 'CN');
                }
              } else if (locale?.languageCode == 'zh_Hant_CN') {
                return const Locale('zh', 'TW');
              } else if (locale?.languageCode == 'auto') {
                return null;
              }
              return locale;
            },
          );
        },
      ),
    );
  }
}
