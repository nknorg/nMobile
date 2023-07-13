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
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/share.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/settings/home.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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

  StreamSubscription? _intentDataTextStreamSubscription;
  StreamSubscription? _intentDataMediaStreamSubscription;

  bool firstConnect = true;

  Completer loginCompleter = Completer();

  bool isAuthProgress = false;

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
      clientCommon.init();
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
      _tryCompleteLogin();
      if (clientCommon.isClientOK) {
        // task add
        if (firstConnect) {
          firstConnect = false;
          taskService.addTask(TaskService.KEY_CLIENT_CONNECT, 6, (key) => clientCommon.ping(), delayMs: 0);
          taskService.addTask(TaskService.KEY_SUBSCRIBE_CHECK, 50, (key) => topicCommon.checkAndTryAllSubscribe(), delayMs: 2 * 1000);
          taskService.addTask(TaskService.KEY_PERMISSION_CHECK, 50, (key) => topicCommon.checkAndTryAllPermission(), delayMs: 3 * 1000);
        }
      } else if (clientCommon.isClientStop) {
        // task remove
        taskService.removeTask(TaskService.KEY_CLIENT_CONNECT, 6);
        taskService.removeTask(TaskService.KEY_SUBSCRIBE_CHECK, 50);
        taskService.removeTask(TaskService.KEY_PERMISSION_CHECK, 50);
        firstConnect = true;
      }
    });

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.listen((bool inBackground) {
      if (inBackground) {
        loginCompleter = Completer();
      } else {
        if (dbCommon.isOpen()) {
          int gap = application.goForegroundAt - application.goBackgroundAt;
          _tryAuth(gap >= Settings.gapClientReAuthMs);
        }
      }
    });

    // For sharing images coming from outside the app while the app is in the memory
    _intentDataMediaStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile>? values) async {
      if (values == null || values.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithFiles(this.context, values);
    }, onError: (err, stack) {
      handleError(err, stack);
    });

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataTextStreamSubscription = ReceiveSharingIntent.getTextStream().listen((String? value) async {
      if (value == null || value.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithTexts(this.context, [value]);
    }, onError: (err, stack) {
      handleError(err, stack);
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile>? values) async {
      if (values == null || values.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithFiles(this.context, values);
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) async {
      if (value == null || value.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithTexts(this.context, [value]);
    });

    // wallet
    taskService.addTask(TaskService.KEY_WALLET_BALANCE, 60, (key) => walletCommon.queryAllBalance(), delayMs: 1 * 1000);
  }

  @override
  void dispose() {
    _clientStatusChangeSubscription?.cancel();
    _appLifeChangeSubscription?.cancel();
    _intentDataTextStreamSubscription?.cancel();
    _intentDataMediaStreamSubscription?.cancel();
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

  Future<bool> _tryAuth(bool gapOk) async {
    if (clientCommon.isClientStop) return false;
    Function() clientReconnect = () {
      clientCommon.reconnect(force: true);
      _tryCompleteLogin();
    };
    if (!gapOk) {
      clientReconnect();
      return true;
    }
    if (isAuthProgress) return false;
    // view
    _setAuthProgress(true);
    AppScreen.go(this.context);
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null) {
      logger.i("AppScreen - _tryAuth - wallet default is empty");
      // ui handle, ChatNoWalletLayout()
      await clientCommon.signOut(clearWallet: true, closeDB: true);
      _setAuthProgress(false);
      return false;
    }
    // password (android bug return null when fromBackground)
    String? password = await authorization.getWalletPassword(wallet.address);
    if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
      logger.i("AppScreen - _tryAuth - password error, close all");
      Toast.show(Settings.locale((s) => s.tip_password_error, ctx: context));
      await clientCommon.signOut(clearWallet: true, closeDB: true);
      _setAuthProgress(false);
      return false;
    }
    // view
    _setAuthProgress(false);
    // client
    clientReconnect(); // await
    chatCommon.startInitChecks(delay: 500); // await
    return true;
  }

  _setAuthProgress(bool progress) {
    application.inAuthProgress = progress;
    if (isAuthProgress != progress) {
      isAuthProgress = progress; // no check mounted
      setState(() {
        isAuthProgress = progress;
      });
    }
  }

  void _tryCompleteLogin() {
    if (clientCommon.isClientOK) {
      try {
        if (!(loginCompleter.isCompleted == true)) {
          loginCompleter.complete();
        }
      } catch (e, st) {
        handleError(e, st);
      }
    }
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
            isAuthProgress
                ? Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      child: Asset.image(
                        "splash/splash@3x.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
