import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/layout/nav.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/settings/home.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/utils/logger.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/';
  static final String argIndex = "index";

  static go(BuildContext? context) {
    if (context == null) return;
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

  StreamSubscription? _clientStatusChangeSubscription;
  StreamSubscription? _appLifeChangeSubscription;

  bool firstConnect = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // init
    Settings.appContext = context; // before at mounted

    // mounted
    application.registerMounted(() async {
      application.init();
      BlocProvider.of<WalletBloc>(Settings.appContext).add(LoadWallet());
      // await backgroundFetchService.install();
      await localNotification.init();
    });
    application.mounted(); // await

    // page_controller
    this._currentIndex = widget.arguments != null ? (widget.arguments?[AppScreen.argIndex] ?? 0) : 0;
    _pageController = PageController(initialPage: this._currentIndex);

    // clientStatus
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (clientCommon.isClientOK) {
        if (firstConnect) {
          firstConnect = false;
          taskService.addTask(TaskService.KEY_CLIENT_CONNECT, 10, (key) => clientCommon.connectCheck(), delayMs: 5 * 1000);
          taskService.addTask(TaskService.KEY_SUBSCRIBE_CHECK, 50, (key) => topicCommon.checkAndTryAllSubscribe(), delayMs: 2 * 1000);
          taskService.addTask(TaskService.KEY_PERMISSION_CHECK, 50, (key) => topicCommon.checkAndTryAllPermission(), delayMs: 3 * 1000);
        }
      } else if (clientCommon.isClientStop) {
        taskService.removeTask(TaskService.KEY_CLIENT_CONNECT, 10);
        taskService.removeTask(TaskService.KEY_SUBSCRIBE_CHECK, 50);
        taskService.removeTask(TaskService.KEY_PERMISSION_CHECK, 50);
        firstConnect = true;
      }
    });

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.listen((List<AppLifecycleState> states) async {
      if (application.isFromBackground(states)) {
        // nothing
      } else if (application.isGoBackground(states)) {
        // nothing
      }
    });

    // wallet
    taskService.addTask(TaskService.KEY_WALLET_BALANCE, 60, (key) => walletCommon.queryAllBalance(), delayMs: 1 * 1000);
  }

  @override
  void dispose() {
    _clientStatusChangeSubscription?.cancel();
    _appLifeChangeSubscription?.cancel();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
            ),
          ],
        ),
      ),
    );
  }
}
