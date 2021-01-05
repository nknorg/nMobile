import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/common_native.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/wallet/wallet.dart';
import 'package:nmobile/services/background_fetch_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

import 'screens/chat/chat.dart';
import 'screens/settings/settings.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/AppScreen';

  @override
  _AppScreenState createState() => _AppScreenState();

  final int selectIndex;

  AppScreen(this.selectIndex);
}

class _AppScreenState extends State<AppScreen> with SingleTickerProviderStateMixin,WidgetsBindingObserver{
  WalletsBloc _walletsBloc;
  int _currentIndex = 0;
  List<Widget> screens = <Widget>[
    ChatScreen(ActivePage(0)),
    WalletScreen(),
    SettingsScreen(),
  ];

  TabController _tabController;

  NKNClientBloc _clientBloc;
  AuthBloc _authBloc;

  bool fromBackground = false;

  @override
  didChangeAppLifecycleState(AppLifecycleState state){
    if (state == AppLifecycleState.paused){
      TimerAuth.instance.onHomePagePaused(context);
      _authBloc.add(AuthFailEvent());
    }
    if (state == AppLifecycleState.resumed) {
      // _authBloc.add(AuthFailEvent());
      ensureAutoShowAuth();
    }
    print('didChangeAppLifecycleState__'+state.toString());
    if (state == AppLifecycleState.resumed) {
      if (fromBackground) {
        fromBackground = false;
      }
    } else if (state == AppLifecycleState.paused) {
      fromBackground = true;
    }
  }

  ensureAutoShowAuth(){
    int ensureShow = TimerAuth.instance.onHomePageResumed(context);
    if (ensureShow == 1){
      print('ensureShowAuth 1');
      if (TimerAuth.onOtherPage == true){
        return;
      }

      if (TimerAuth.authed == false){
        if (TimerAuth.instance.pagePushed){
          while (Navigator.canPop(context)){
            Navigator.pop(context);
          }
        }
        if (fromBackground == true && _currentIndex == 0){
          _delayAuth();
          print('wallet Loaded from _ensureAutoShowAuth');
        }
      }
    }
    else if (ensureShow == -1){
      print('ensureShowAuth -1');
      _authBloc.add(AuthSuccessEvent());
      Timer(Duration(milliseconds: 350), () async {
        if (TimerAuth.authed == true) {
          WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
          DChatAuthenticationHelper.getPassword4BackgroundFetch(
            wallet: wallet,
            verifyProtectionEnabled: false,
            onGetPassword: (wallet, password) {
              onGetPassword(wallet, password);
            },
          );
        }
      });
    }
  }

  void onGetPassword(WalletSchema wallet, String password) async{
    Global.debugLog('app.dart onGetPassword');
    TimerAuth.instance.enableAuth();
    if (_authBloc != null && _clientBloc != null){
      _authBloc.add(AuthSuccessEvent());
      _clientBloc.add(NKNCreateClientEvent(wallet, password));
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    WidgetsBinding.instance.addObserver(this);

    _tabController = new TabController(length: 3, vsync: this);
    _setDefaultSelectIndex();

    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _walletsBloc.add(LoadWallets());
    _authBloc = BlocProvider.of<AuthBloc>(context);

    _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    _clientBloc.aBloc = _authBloc;

    _tabController.addListener(() {
      setState(() {
        if (_currentIndex != _tabController.index){
          print('index is'+_tabController.index.toString());
          _currentIndex = _tabController.index;
          if (_currentIndex == 0){
            if (TimerAuth.authed == false){
              _authBloc.add(AuthFailEvent());
              _delayAuth();
              print('wallet Loaded from _tabController');
            }
          }
        }
      });
    });
  }

  _delayAuth(){
    Timer(Duration(milliseconds: 350), () async {
      WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
      if (wallet == null){
        showToast(NL10ns.of(context).something_went_wrong);
        return;
      }
      if (TimerAuth.authed == false){
        var password = await wallet.getPassword();
        Global.debugLog('app.dart got password'+password);
        if (password != null) {
          try {
            var w = await wallet.exportWallet(password);
            if (w['address'] == wallet.address) {
              onGetPassword(wallet, password);
            } else {
              showToast(NL10ns.of(context).tip_password_error);
            }
          } catch (e) {
            if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
              showToast(NL10ns.of(context).tip_password_error);
            }
          }
        }
      }
    });
  }

  _setDefaultSelectIndex(){
    _tabController.index = widget.selectIndex;
    _currentIndex = widget.selectIndex;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 375, height: 812);
    Global.appContext = context;

    instanceOf<TaskService>().init();
    if (Platform.isAndroid){
      instanceOf<BackgroundFetchService>().init();
    }

    Color _color = Theme.of(context).unselectedWidgetColor;
    Color _selectedColor = DefaultTheme.primaryColor;

    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          await CommonNative.androidBackToDesktop();
          return false;
        },
        child: new TabBarView(
          controller: _tabController,
          children: screens,
        ),
      ),
      bottomNavigationBar: new Container(
        decoration: new BoxDecoration(
          // color: Colors.white,
          //设置四周圆角 角度
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30),topRight: Radius.circular(30)),
          color: DefaultTheme.backgroundLightColor,
          //设置四周边框
        ),
        child: new TabBar(
          controller: _tabController,
          labelColor: DefaultTheme.primaryColor,
          unselectedLabelColor: ColorValue.lightGreyColor,
          indicatorColor: Colors.white,
          tabs: <Widget>[
            Tab(
              icon: loadAssetIconsImage('chat', color: _currentIndex == 0 ? _selectedColor : _color),
              text: NL10ns.of(context).menu_chat,
              iconMargin: EdgeInsets.only(top:2, bottom: 2),
            ),
            Tab(
              icon: loadAssetIconsImage('wallet', color: _currentIndex == 1 ? _selectedColor : _color),
              text: NL10ns.of(context).menu_wallet,
              iconMargin: EdgeInsets.only(top:2, bottom: 2),
            ),
            Tab(
              icon: loadAssetIconsImage('settings', color: _currentIndex == 2 ? _selectedColor : _color),
              text: NL10ns.of(context).menu_settings,
              iconMargin: EdgeInsets.only(top:2, bottom: 2),
            )
          ],
        ),
      ),
    );
  }
}
