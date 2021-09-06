import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/nav.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/settings/home.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/utils/logger.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/';
  static final String argIndex = "index";

  static go(BuildContext context) {
    // return Navigator.pushNamed(context, routeName, arguments: {
    //   argIndex: index,
    // });
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  final Map<String, dynamic>? arguments;

  const AppScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _AppScreenState createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> with WidgetsBindingObserver {
  List<Widget> screens = <Widget>[
    ChatHomeScreen(),
    WalletHomeScreen(),
    SettingsHomeScreen(),
  ];

  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    Global.appContext = context; // before at mounted

    application.mounted(); // await

    this._currentIndex = widget.arguments != null ? (widget.arguments![AppScreen.argIndex] ?? 0) : 0;
    _pageController = PageController(initialPage: this._currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logger.i("AppScreen - didChangeAppLifecycleState - $state");
    AppLifecycleState old = application.appLifecycleState;
    application.appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
    application.appLifeSink.add([old, state]);
  }

  @override
  Widget build(BuildContext context) {
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
