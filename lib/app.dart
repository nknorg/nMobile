import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/wallet/home.dart';

import 'common/application.dart';
import 'common/global.dart';
import 'common/locator.dart';
import 'components/layout/nav.dart';
import 'native/common.dart';
import 'screens/settings/settings.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/';
  static final String argIndex = "index";

  final Map<String, dynamic> arguments;

  const AppScreen({Key key, this.arguments}) : super(key: key);

  @override
  _AppScreenState createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  GetIt locator = GetIt.instance;
  Application app;
  int _currentIndex = 0; // TODO:GG fixed_me
  PageController _pageController;
  List<Widget> screens = <Widget>[
    ChatHomeScreen(),
    WalletHomeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    app = locator.get<Application>();
    this._currentIndex = widget.arguments != null ? (widget.arguments[AppScreen.argIndex] ?? 0) : 0;
    _pageController = PageController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // init
    Global.appContext = context;
    app.mounted();

    return WillPopScope(
      onWillPop: () async {
        if (Platform.isAndroid) {
          await Common.backDesktop();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: application.theme.backgroundColor,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (n) {
                setState(() {
                  _currentIndex = n;
                });
              },
              children: screens,
            ),
            // footer nav
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PhysicalModel(
                color: application.theme.backgroundColor,
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                child: Nav(
                  currentIndex: _currentIndex,
                  screens: screens,
                  controller: _pageController,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
