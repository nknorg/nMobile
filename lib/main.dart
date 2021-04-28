import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_state.dart';
import 'common/global.dart';
import 'common/locator.dart';
import 'common/settings.dart';
import 'generated/l10n.dart';
import 'services/task_service.dart';
import 'routes/routes.dart' as routes;

void initialize() {
  application.registerInitialize(() async {
    Global.init();
    Settings.init();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
  await Wallet.install();
  await Client.install();

  setupLocator();
  routes.init();
  initialize();
  await application.initialize();
  application.registerMounted(() async {
    locator.get<TaskService>().install();
  });

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://c4d9d78cefc7457db9ade3f8026e9a34@o466976.ingest.sentry.io/5483254';
      options.environment = Global.isRelease ? 'production' : 'debug';
      options.release = Global.versionFormat;
    },
    appRunner: () => runApp(Main()),
  );
}

class Main extends StatefulWidget {
  static final String name = 'nMobile';

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  List<BlocProvider> providers = [
    BlocProvider<SettingsBloc>(
      create: (BuildContext context) => SettingsBloc(),
    ),
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
            title: Main.name,
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
            onGenerateRoute: application.onGenerateRoute,
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
