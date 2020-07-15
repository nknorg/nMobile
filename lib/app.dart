import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/screens/news.dart';
import 'package:nmobile/services/background_fetch_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/android_back_desktop.dart';
import 'package:orientation/orientation.dart';

import 'components/footer/nav.dart';
import 'screens/chat/chat.dart';
import 'screens/home.dart';
import 'screens/settings/settings.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/AppScreen';

  @override
  _AppScreenState createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  WalletsBloc _walletsBloc;
  PageController _pageController;
  int _currentIndex = 1;
  List<Widget> screens = <Widget>[
    ChatScreen(),
    HomeScreen(),
    NewsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    OrientationPlugin.forceOrientation(DeviceOrientation.portraitUp);
    _pageController = PageController(initialPage: 1);
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _walletsBloc.add(LoadWallets());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 375, height: 812);
    Global.appContext = context;

    locator<TaskService>().init();
    locator<BackgroundFetchService>().init();
    return WillPopScope(
      onWillPop: () async {
        await AndroidBackTop.backToDesktop();
        return false;
      },
      child: getView(),
    );
  }

  getView() {
    return Stack(
      children: <Widget>[
        Scaffold(
          body: ConstrainedBox(
            constraints: BoxConstraints.expand(),
            child: Container(
              constraints: BoxConstraints.expand(),
              child: Flex(
                direction: Axis.vertical,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: PageView(
                      onPageChanged: (n) {
                        setState(() {
                          _currentIndex = n;
                        });
                      },
                      controller: _pageController,
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        getBottomView()
      ],
    );
  }

  getBottomView() {
    return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Column(children: <Widget>[
          Container(
            child: Nav(
              currentIndex: _currentIndex,
              screens: screens,
              controller: _pageController,
            ),
          ),
          Container(
            height: MediaQuery.of(context).padding.bottom,
            width: double.infinity,
            color: DefaultTheme.backgroundLightColor,
          )
        ]));
  }
}
