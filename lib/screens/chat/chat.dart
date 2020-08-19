import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/plugins/common_native.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/no_wallet_account.dart';
import 'package:nmobile/utils/log_tag.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final ActivePage activePage;

  const ChatScreen(this.activePage);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, RouteAware, WidgetsBindingObserver, Tag {
  final DChatAuthenticationHelper authHelper = DChatAuthenticationHelper();
  bool noConnPageShowing = true;
  bool homePageShowing = false;
  bool fromBackground = false;
  bool uiShowed = false;
  ClientBloc clientBloc;
  LocalStorage localStorage;
  TimerAuth timerAuth;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _LOG.i('didChangeAppLifecycleState($state), ${DateTime.now().toLocal().toString()}');
    if (state == AppLifecycleState.resumed) {
      if (fromBackground) {
        fromBackground = false;
        authHelper.canShow = noConnPageShowing;
        authHelper.ensureAutoShowAuthentication('lifecycle', onGetPassword);
      }
    } else if (state == AppLifecycleState.paused) {
      // When app brought to foreground again,
      // lifecycle state order is: inactive -> resumed.
      // so...only judge if is `inactive` not enough.
      fromBackground = true;
    }
    timerAuth.homePageShowing = homePageShowing;
    if (state == AppLifecycleState.resumed) {
      timerAuth.onHomePageResumed(context);
    }
    if (state == AppLifecycleState.paused) {
      timerAuth.onHomePagePaused(context);
    }
  }

  void onCurrPageActive(active) {
    _LOG.i('onCurrPageActive($active)');
    Timer(Duration(milliseconds: 350), () {
      authHelper.setPageActive(PageAction.force, active);
      authHelper.ensureAutoShowAuthentication('tab change', onGetPassword);
      timerAuth.homePageShowing = homePageShowing;
      timerAuth.ensureVerifyPassword(context);
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _LOG.i('canShow: $noConnPageShowing, call _authHelper.ensureAutoShowXxx()');
    Timer(Duration(milliseconds: 350), () {
      authHelper.canShow = noConnPageShowing;
      authHelper.setPageActive(PageAction.popToCurr);
      authHelper.ensureAutoShowAuthentication('popToCurr', onGetPassword);
    });
  }

  @override
  void didPushNext() {
    _LOG.i('didPushNext()');
    authHelper.setPageActive(PageAction.pushNext);
    super.didPushNext();
  }

  void whenUiFirstShowing() async {
    WidgetsBinding.instance.addPostFrameCallback((timestamp) async {
      uiShowed = true;
      if (await Global.isInBackground) {
        fromBackground = true;
        timerAuth.onHomePagePaused(context);
      }
      _LOG.d('whenUiFirstShowing | isInBackground: ${await Global.isInBackground}, isStateActive: ${await Global.isStateActive}, ' +
          DateTime.now().toLocal().toString());
      LocalNotification.debugNotification(
          '<[DEBUG]> whenUiFirstShowing',
          'isInBackground: ${await Global.isInBackground}, isStateActive: ${await Global.isStateActive}'
              ', nativeActive: ${await CommonNative.isActive()}, ${DateTime.now().toLocal().toString()}');
      authHelper.canShow = uiShowed && noConnPageShowing && !(await Global.isInBackground);
      authHelper.ensureAutoShowAuthentication('first show', onGetPassword);
    });
  }

  void onGetWallet(WalletSchema accountWallet) async {
    if (authHelper.wallet != null && authHelper.wallet.address == accountWallet.address) return;
    // When account changed, `authHelper.wallet` should be changed.
    authHelper.wallet = accountWallet;
    // fix bug of `showing-input-pwd-dialog` in background.
    authHelper.canShow = uiShowed && noConnPageShowing && !(await Global.isInBackground);
    authHelper.ensureAutoShowAuthentication('wallet', onGetPassword);
  }

  void onGetPassword(WalletSchema wallet, String password) {
    clientBloc.add(CreateClient(wallet, password));
  }

  @override
  void initState() {
    super.initState();
    _LOG = LOG(tag);
    LocalNotification.debugNotification('<[DEBUG]> chatPageInitState', '${DateTime.now().toLocal().toString()}');
    whenUiFirstShowing();
    WidgetsBinding.instance.addObserver(this);
    clientBloc = BlocProvider.of<ClientBloc>(context);
    authHelper.setPageActive(PageAction.init, widget.activePage.isCurrPageActive);
    widget.activePage.addOnCurrPageActive(onCurrPageActive);
    timerAuth = TimerAuth(widget.activePage);
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
    super.build(context);
    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, state) {
        if (state is WalletsLoaded) {
          if (state.wallets.length > 0) {
            return BlocBuilder<ClientBloc, ClientState>(
              builder: (context, clientState) {
                if (clientState is NoConnect) {
                  noConnPageShowing = true;
                  homePageShowing = false;
                  timerAuth.onNoConnection();
                  DChatAuthenticationHelper.loadDChatUseWalletByState(state, onGetWallet);
                  return NoConnectScreen(() {
                    authHelper.prepareConnect(onGetPassword);
                  });
                } else {
                  noConnPageShowing = false;
                  authHelper.wallet = null;
                  if (!homePageShowing) {
                    timerAuth.onHomePageFirstShow(context);
                  }
                  homePageShowing = true;
                  return ChatHome(timerAuth);
                }
              },
            );
          } else {
            noConnPageShowing = false;
            homePageShowing = false;
            authHelper.wallet = null;
            timerAuth.onNoConnection();
            return NoWalletAccount(timerAuth);
          }
        }
        noConnPageShowing = false;
        homePageShowing = false;
        authHelper.wallet = null;
        timerAuth.onNoConnection();
        return Container();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
