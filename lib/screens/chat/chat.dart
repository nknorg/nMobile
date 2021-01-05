
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/chat/auth_state.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/no_wallet_account.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final ActivePage activePage;

  const ChatScreen(this.activePage);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, RouteAware, Tag{
  final DChatAuthenticationHelper authHelper = DChatAuthenticationHelper();


  WalletsBloc _walletBloc;
  NKNClientBloc _clientBloc;
  AuthBloc _authBloc;
  bool firstShowAuth = false;

  @override
  void didPopNext() {
    super.didPopNext();
    TimerAuth.instance.pageDidPop();
    if (TimerAuth.authed == false){

    }
  }

  @override
  void didPushNext() {
    TimerAuth.instance.pageDidPushed();
    super.didPushNext();
  }

  @override
  void initState() {
    super.initState();

    _walletBloc = BlocProvider.of<WalletsBloc>(context);
    _walletBloc.add(LoadWallets());
    _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    NKNClientCaller.clientBloc = _clientBloc;
    _authBloc = BlocProvider.of<AuthBloc>(context);

    _clientBloc.aBloc = _authBloc;
  }

  @override
  void didChangeDependencies() {
    RouteUtils.routeObserver.subscribe(this, ModalRoute.of(context));
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    RouteUtils.routeObserver.unsubscribe(this);
    super.dispose();
  }


  void onGetPassword(WalletSchema wallet, String password) async{
    Global.debugLog('chat.dart onGetPassword');
    TimerAuth.instance.enableAuth();
    _authBloc.add(AuthSuccessEvent());
    _clientBloc.add(NKNCreateClientEvent(wallet, password));
  }

  void _clickConnect() async{
    WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
    if (wallet == null){
      showToast('Error Loading wallet');
      return;
    }
    var password = await wallet.getPassword();
    if (password != null) {
      try {
        var w = await wallet.exportWallet(password);
        if (w['address'] == wallet.address) {
          onGetPassword(wallet, password);
        } else {
          showToast(NL10ns.of(context).tip_password_error);
        }
      } catch (e) {
        if (Platform.isAndroid){
          Global.debugLog('exportWallet E:'+e.toString());
          /// Android DecryptFail present this
          if (e.toString().contains('Failed to get string encoded:')){
            showToast(NL10ns.of(context).tip_password_error);
          }
          else if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
            showToast(NL10ns.of(context).tip_password_error);
          }
        }
        if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
          showToast(NL10ns.of(context).tip_password_error);
        }
      }
    }
  }

  _delayAuth(){
    Timer(Duration(milliseconds: 200), () async {
      _clickConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, state) {
        if (state is WalletsLoaded) {
          if (state.wallets.length > 0) {
            return BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is AuthToUserState){
                  print('chat AuthState'+authState.currentUser.toString());
                  return BlocBuilder<NKNClientBloc, NKNClientState>(
                    builder: (context, clientState) {
                      if (state is NKNNoConnectState){
                        return NoConnectScreen(() {
                          authHelper.wallet = null;
                          _clickConnect();
                        });
                      }
                      return ChatHome(TimerAuth.instance);
                    },
                  );
                }
                if (authState is AuthedSuccessState){
                  if (authState.success == false){
                    print('on No Auth');
                    if (firstShowAuth == false){
                      _delayAuth();
                      firstShowAuth = true;
                    }
                    return NoConnectScreen(() {
                      _clickConnect();
                    });
                  }
                  if (authState.success == true){
                    return BlocBuilder<NKNClientBloc, NKNClientState>(
                      builder: (context, clientState) {
                        if (state is NKNNoConnectState){
                          return NoConnectScreen(() {
                            authHelper.wallet = null;
                            _clickConnect();
                          });
                        }
                        return ChatHome(TimerAuth.instance);
                      },
                    );
                  }
                }
                return NoConnectScreen(() {
                  authHelper.wallet = null;
                  _clickConnect();
                });
              },
            );
          }
          else{
            print('Wallet Length is '+state.wallets.length.toString());
          }
          authHelper.wallet = null;
          return NoWalletAccount(TimerAuth.instance);
        }
        authHelper.wallet = null;
        return NoWalletAccount(TimerAuth.instance);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

