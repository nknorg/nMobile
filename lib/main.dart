import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/global/global_bloc.dart';
import 'package:nmobile/blocs/global/global_state.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/router/routes.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sentry/sentry.dart';

import 'blocs/wallet/wallets_bloc.dart';


void main() async {
  SentryClient sentry;
    // Global.init(() {
    //   runApp(App());
    // });
  runZonedGuarded(() {
    Global.init(() {
      sentry = SentryClient(
        // log
          dsn: 'https://c4d9d78cefc7457db9ade3f8026e9a34@o466976.ingest.sentry.io/5483254',
          environmentAttributes: const Event(
            release: 'nMobile',
            environment: 'production',
          ));
      runApp(App());
    });
  }, (error, stackTrace) async {
    await sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  });
  FlutterError.onError = (details, {bool forceReport = false}) {
    sentry.captureException(
      exception: details.exception,
      stackTrace: details.stack,
    );
  };
}

class App extends StatefulWidget {
  static final String sName = "App";

  @override
  AppState createState() => new AppState();
}

class AppState extends State<App> with WidgetsBindingObserver, Tag {
  List<BlocProvider> providers = [
    BlocProvider<GlobalBloc>(
      create: (BuildContext context) => GlobalBloc(),
    ),
    BlocProvider<WalletsBloc>(
      create: (BuildContext context) => WalletsBloc(),
    ),
    BlocProvider<ContactBloc>(
      create: (BuildContext context) => ContactBloc(),
    ),
    BlocProvider<FilteredWalletsBloc>(
      create: (BuildContext context) => FilteredWalletsBloc(
        walletsBloc: BlocProvider.of<WalletsBloc>(context),
      ),
    ),
    BlocProvider<ChatBloc>(
      create: (BuildContext context) => ChatBloc(
        contactBloc: BlocProvider.of<ContactBloc>(context),
      ),
    ),
    BlocProvider<ClientBloc>(
      create: (BuildContext context) => ClientBloc(
        chatBloc: BlocProvider.of<ChatBloc>(context),
      ),
    ),
    BlocProvider<ChannelMembersBloc>(
      create: (BuildContext context) => ChannelMembersBloc(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    LocalNotification.debugNotification('<[DEBUG]> --- app init ---', DateTime.now().toLocal().toString());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LOG(tag).d('didChangeAppLifecycleState($state)');
    Global.state = state;
    LocalNotification.debugNotification('<[DEBUG]> $state', DateTime.now().toLocal().toString());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers,
      child: BotToastInit(
        child: BlocBuilder<GlobalBloc, GlobalState>(builder: (context, state) {
          return OKToast(
            position: ToastPosition.bottom,
            backgroundColor: Colors.black54,
            radius: 100,
            textPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            child: MaterialApp(
              builder: (context, child) {
                return FlutterEasyLoading(child: child);
              },
              navigatorObservers: [BotToastNavigatorObserver(), RouteUtils.routeObserver],
              onGenerateTitle: (context) {
                return NL10ns.of(context).title;
              },
              onGenerateRoute: onGenerateRoute,
              title: 'nMobile',
              theme: ThemeData(
                primarySwatch: Colors.blue,
                primaryColor: DefaultTheme.primaryColor,
                sliderTheme: SliderThemeData(
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
                  trackHeight: 8,
                  tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 0),
                  // thumbShape: SliderThemeShape(),
                ),
              ),
              home: AppScreen(),
              locale: Global.locale != null && Global.locale != 'auto' ? Locale.fromSubtags(languageCode: Global.locale) : null,
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                NMobileLocalizationsDelegate(),
              ],
              supportedLocales: [
                const Locale('en'),
                const Locale.fromSubtags(languageCode: 'zh'),
              ],
            ),
          );
        }),
      ),
    );
  }
}
