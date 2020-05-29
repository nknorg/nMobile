import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/global/global_bloc.dart';
import 'package:nmobile/blocs/global/global_state.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/routes.dart';
import 'package:nmobile/services/navigate_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/theme/slider_theme.dart';
import 'package:oktoast/oktoast.dart';

import 'blocs/wallet/wallets_bloc.dart';
import 'consts/theme.dart';

void main() async {
  Global.init(() {
    runApp(App());
  });
}

class App extends StatelessWidget {
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
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers,
      child: BotToastInit(
        child: BlocBuilder<GlobalBloc, GlobalState>(builder: (context, state) {
          return OKToast(
            position: ToastPosition.bottom,
            textPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: MaterialApp(
              builder: (context, child) {
                return FlutterEasyLoading(child: child);
              },
              navigatorObservers: [BotToastNavigatorObserver()],
              onGenerateTitle: (context) {
                return NMobileLocalizations.of(context).title;
              },
              navigatorKey: locator<NavigateService>().key,
              onGenerateRoute: onGenerateRoute,
              title: 'nMobile',
              theme: ThemeData(
                primarySwatch: Colors.blue,
                primaryColor: DefaultTheme.primaryColor,
                sliderTheme: SliderThemeData(
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
                  trackHeight: 8,
                  tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 0),
                  thumbShape: SliderThemeShape(),
                ),
              ),
              home: AppScreen(),
              locale: Locale.fromSubtags(languageCode: Global.locale),
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
