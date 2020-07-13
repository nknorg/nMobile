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
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/log_tag.dart';

class NoConnectScreen extends StatefulWidget {
//  static const String routeName = '/chat/no_connect';

  @override
  _NoConnectScreenState createState() => _NoConnectScreenState();
}

class _NoConnectScreenState extends State<NoConnectScreen> with RouteAware, WidgetsBindingObserver, Tag {
  ClientBloc _clientBloc;
  WalletSchema _currentWallet;
  bool canShow = false;
  String _walletAddr;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  @override
  void didPopNext() {
    super.didPopNext();
    canShow = true;
    if (canShow) {
      _LOG.i('canShow:$canShow, call _ensureAutoShowAuthentication()');
      _ensureAutoShowAuthentication();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _LOG.i('didChangeAppLifecycleState($state)');
    if (state == AppLifecycleState.resumed) {
      _ensureAutoShowAuthentication();
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
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((addr) {
      setState(() {
        _walletAddr = addr;
      });
    });
//    initData();
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
                              _ensureAutoShowAuthentication();
                            }
                            return Button(
                              width: double.infinity,
                              text: NMobileLocalizations.of(context).connect,
                              onPressed: () {
                                _prepareConnect();
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

  bool _authenticating = false;

  _prepareConnect() async {
    if (_authenticating) return;
    _authenticating = true;
    var password = await _currentWallet.getPassword(showDialogIfCanceledAuth: false);
    _authenticating = false;
    if (password != null) {
      Global.shouldAutoShowGetPassword = false;
      canShow = false;
      _clientBloc.add(CreateClient(_currentWallet, password));
    }
  }

  initData() async {
    WidgetsBinding.instance.addPostFrameCallback((mag) async {
//      bool isActive = await CommonNative.isActive();
//      if (Global.isAutoShowPassword && canShow && isActive && _currentWallet != null) {
//        Global.isAutoShowPassword = false;
//        canShow = false;
//        _next();
//      }
    });
  }

  _ensureAutoShowAuthentication() async {
    if ((Global.shouldAutoShowGetPassword || canShow) && _currentWallet != null) {
      _prepareConnect();
    }
  }
}
