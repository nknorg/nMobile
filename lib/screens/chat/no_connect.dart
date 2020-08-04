import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/utils/log_tag.dart';

class NoConnectScreen extends StatefulWidget {
//  static const String routeName = '/chat/no_connect';

  final ActivePage activePage;

  NoConnectScreen(this.activePage);

  @override
  _NoConnectScreenState createState() => _NoConnectScreenState();
}

class _NoConnectScreenState extends State<NoConnectScreen> with RouteAware, WidgetsBindingObserver, Tag {
  ClientBloc _clientBloc;
  WalletSchema _currentWallet;
  String _walletAddr;

  DChatAuthenticationHelper _authHelper = DChatAuthenticationHelper();

  // ignore: non_constant_identifier_names
  LOG _LOG;

  @override
  void didPopNext() {
    super.didPopNext();
    _authHelper.canShow = true;
    _LOG.i('canShow:true, call _authHelper.ensureAutoShowAuthentication()');
    Timer(Duration(milliseconds: 600), () {
      _authHelper.ensureAutoShowAuthentication(onGetPassword);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _LOG.i('didChangeAppLifecycleState($state)');
    if (state == AppLifecycleState.resumed) {
      _authHelper.ensureAutoShowAuthentication(onGetPassword);
    } else if (state == AppLifecycleState.paused) {
      // When app brought to foreground again,
      // lifecycle state order is: inactive -> resumed.
      // so...only judge if is `inactive` not enough.
      _authHelper.canShow = true;
    }
  }

  void onCurrPageActive(active) {
    _LOG.i('onCurrPageActive($active)');
    _authHelper.isPageActive = active;
    if (active) {
      _authHelper.ensureAutoShowAuthentication(onGetPassword);
    }
  }

  @override
  void didPushNext() {
    _LOG.i('didPushNext()');
    super.didPushNext();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _LOG = LOG(tag);
    _clientBloc = BlocProvider.of<ClientBloc>(context);
    _authHelper.isPageActive = widget.activePage.isCurrPageActive;
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((addr) {
      _LOG.i('DEFAULT_D_CHAT_WALLET_ADDRESS:$addr');
      setState(() {
        _walletAddr = addr ?? '';
      });
    });
    widget.activePage.addOnCurrPageActive(onCurrPageActive);
  }

  @override
  void didChangeDependencies() {
    RouteUtils.routeObserver.subscribe(this, ModalRoute.of(context));
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    RouteUtils.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    DChatAuthenticationHelper.cancelAuthentication();
    widget.activePage.removeOnCurrPageActive(onCurrPageActive);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Padding(
          padding: EdgeInsets.only(left: 20.h),
          child: Label(
            NMobileLocalizations.of(context).menu_chat.toUpperCase(),
            type: LabelType.h2,
          ),
        ),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        leading: null,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(left: 20.w, right: 20.w),
          color: DefaultTheme.backgroundColor1,
          child: Container(
            child: Flex(
              direction: Axis.vertical,
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Padding(
                    padding: EdgeInsets.only(top: 80.h),
                    child: Image(
                        image: AssetImage(
                          "assets/chat/messages.png",
                        ),
                        width: 198.w,
                        height: 144.h),
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(
                          top: 32.h,
                        ),
                        child: Label(
                          NMobileLocalizations.of(context).chat_no_wallet_title,
                          type: LabelType.h2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 8.h, left: 0, right: 0),
                        child: Label(
                          NMobileLocalizations.of(context).click_connect,
                          type: LabelType.bodyRegular,
                          textAlign: TextAlign.center,
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: BlocBuilder<WalletsBloc, WalletsState>(builder: (context, state) {
                          if (state is WalletsLoaded) {
                            _currentWallet = state.wallets.firstWhere((w) => w.address == _walletAddr, orElse: () => state.wallets.first);
                            if (_walletAddr != null) {
                              _authHelper.wallet = _currentWallet;
                              _authHelper.ensureAutoShowAuthentication(onGetPassword);
                            }
                            return Button(
                              width: double.infinity,
                              text: NMobileLocalizations.of(context).connect,
                              onPressed: () {
                                _authHelper.wallet = _currentWallet;
                                _authHelper.prepareConnect(onGetPassword);
                              },
                            );
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  initData() async {
    WidgetsBinding.instance.addPostFrameCallback((timestamp) async {
//      bool isActive = await CommonNative.isActive();
//      if (Global.isAutoShowPassword && canShow && isActive && _currentWallet != null) {
//        Global.isAutoShowPassword = false;
//        canShow = false;
//        _next();
//      }
    });
  }

  void onGetPassword(WalletSchema wallet, String password) {
    _clientBloc.add(CreateClient(wallet, password));
  }
}
