/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';


class TimerAuth {
  factory TimerAuth() => _getInstance();

  static TimerAuth get instance => _getInstance();
  static TimerAuth _instance;
  TimerAuth._internal() {
    // 初始化
  }

  static TimerAuth _getInstance() {
    if (_instance == null) {
      _instance = new TimerAuth._internal();
    }
    return _instance;
  }

  final int gapTime = 1000*60;
  static bool authed = false;

  static bool _pagePushed = false;
  static bool onOtherPage = false;

  DateTime _startTime;

  bool get pagePushed => _pagePushed;

  AuthBloc _authBloc;

  int onHomePageResumed(BuildContext context){
    if (_startTime == null){
      return 1;
    }
    bool shouldAuth = DateTime.now().millisecondsSinceEpoch - _startTime.millisecondsSinceEpoch >= gapTime;
    print('cal Gap Time is'+(DateTime.now().millisecondsSinceEpoch - _startTime.millisecondsSinceEpoch).toString());
    if (authed == false){
      print('auth Returned');
      return 1;
    }
    if (shouldAuth){
      authed = false;
      print('authDisabled');
      return 1;
    }
    authed = true;
    return -1;
  }

  enableAuth(){
    print('enableAuth');
    authed = true;
    _startTime = DateTime.now();
  }

  pageDidPushed(){
    _pagePushed = true;
  }

  pageDidPop(){
    _pagePushed = false;
  }

  onHomePagePaused(BuildContext context) {
    if (authed == true){
      print('startTime renew__:'+_startTime.toString());
      _startTime = DateTime.now();
    }
  }

  Future<String> _checkUserInput(BuildContext context) async{
    /// AuthFailed
    TimerAuth.authed = false;
    _authBloc = BlocProvider.of<AuthBloc>(context);
    _authBloc.add(AuthFailEvent());

    String password = await BottomDialog.of(context).showInputPasswordDialog(title: NL10ns.of(context).verify_wallet_password);
    WalletSchema wallet = await loadCurrentWallet();
    try  {
      Map walletInfo = await wallet.exportWallet(password);
    }
    catch (e){
      _authBloc = BlocProvider.of<AuthBloc>(context);
      _authBloc.add(AuthFailEvent());

      Global.debugLog('onCheckAuthGetPassword__'+e.toString());
      showToast(NL10ns.of(context).tip_password_error);
    }
    return password;
  }

  Future<String> onCheckAuthGetPassword(BuildContext context) async{
    bool protection = await LocalAuthenticationService.instance.protectionStatus();
    /// Need authPassword can autoEnable Biometrics(eg:TouchId)
    String password = '';
    if (protection == false){
      password = await _checkUserInput(context);
    }
    else{
      bool auth = await LocalAuthenticationService.instance.authenticate();
      if (auth) {
        TimerAuth.instance.enableAuth();
        WalletSchema wallet = await loadCurrentWallet();
        String address = wallet.address;
        try  {
          password = await SecureStorage().get('${SecureStorage.PASSWORDS_KEY}:$address');
          await wallet.exportWallet(password);
        }
        catch (e){
          Global.debugLog('onCheckAuthGetPassword__'+e.toString());
          showToast(NL10ns.of(context).tip_password_error);
        }
        return password;
      }
      else{
        password = await _checkUserInput(context);
      }
    }
    return password;
  }

  // Future<String> getStoredPassword() async{
  //   String password = '';
  //
  //
  //
  //   return password;
  // }
  // Future<String> getPassword({bool showDialogIfCanceledBiometrics = true, bool forceShowInputDialog = false}) async {
  //   if (forceShowInputDialog) {
  //     return _showDialog('force');
  //   }
  //   bool protect = await LocalAuthenticationService.instance.protectionStatus();
  //   if (protect) {
  //     String password = '';
  //     if (password == null) {
  //       return _showDialog('no password');
  //     } else {
  //       bool auth = await LocalAuthenticationService.instance.authenticate();
  //       if (auth) {
  //         TimerAuth.instance.enableAuth();
  //         password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');
  //         return password;
  //       } else if (showDialogIfCanceledBiometrics) {
  //         return _showDialog('auth failed');
  //       } else {
  //         return null;
  //       }
  //     }
  //   } else {
  //     return _showDialog('disabled');
  //   }
  // }

  // ensureVerifyPassword(BuildContext context) async {
  //   WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
  //   DChatAuthenticationHelper.authToVerifyPassword(
  //     wallet: wallet,
  //     onGot: (nw) {
  //       print('enableAuth ensureVerifyPassword');
  //       enableAuth();
  //     },
  //     onError: (pwdIncorrect, e) {
  //       authed = false;
  //       if (pwdIncorrect) {
  //         showToast(NL10ns.of(context).tip_password_error);
  //       }
  //     },
  //   );
  // }

  // Future<String> _showDialog(String reason) {
  //   return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NL10ns.of(Global.appContext).verify_wallet_password);
  // }
  //
  // Future<String> getPassword({bool showDialogIfCanceledBiometrics = true, bool forceShowInputDialog = false}) async {
  //   if (forceShowInputDialog) {
  //     return _showDialog('force');
  //   }
  //   bool protect = await LocalAuthenticationService.instance.protectionStatus();
  //   if (protect) {
  //     String password = '';
  //     if (password == null) {
  //       return _showDialog('no password');
  //     } else {
  //       bool auth = await LocalAuthenticationService.instance.authenticate();
  //       if (auth) {
  //         TimerAuth.instance.enableAuth();
  //         password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');
  //         return password;
  //       } else if (showDialogIfCanceledBiometrics) {
  //         return _showDialog('auth failed');
  //       } else {
  //         return null;
  //       }
  //     }
  //   } else {
  //     return _showDialog('disabled');
  //   }
  // }


// ensureVerifyPasswordWithCallBack(BuildContext context,WalletSchema wallet,void callBack(WalletSchema wallet, String password)){
  //   DChatAuthenticationHelper.authToPrepareConnect(wallet, (wallet, password) {
  //     DChatAuthenticationHelper.authToVerifyPassword(
  //       wallet: wallet,
  //       onGot: (nw) {
  //         enableAuth();
  //         print('enableAuth ensureVerifyPasswordWithCallBack');
  //         callBack(wallet,password);
  //       },
  //       onError: (pwdIncorrect, e) {
  //         authed = false;
  //         if (pwdIncorrect) {
  //           showToast(NL10ns.of(context).tip_password_error);
  //         }
  //       },
  //     );
  //   });
  // }

  static Future<WalletSchema> loadCurrentWallet() async{
    WalletSchema walletModel;
    var walletAddress = await LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS);
    List wallets = await LocalStorage().getArray(LocalStorage.NKN_WALLET_KEY);

    if (walletAddress == null && wallets.length > 0){
      Map resultWallet = wallets[0];
      walletModel = WalletSchema(address: resultWallet['address'], type: resultWallet['type'], name: resultWallet['name']);
      return walletModel;
    }

    for (Map wallet in wallets){
      var walletModel = WalletSchema(address: wallet['address'], type: wallet['type'], name: wallet['name']);
      if (walletModel.address == walletAddress){
        return walletModel;
      }
    }
    if (wallets.length > 0){
      return wallets[0];
    }
    return null;
  }
}

class DChatAuthenticationHelper with Tag {
  // WalletSchema wallet;

  // prepareConnect(void onGetPassword(WalletSchema wallet, String password)) {
  //   print('step4');
  //   authToPrepareConnect(wallet, (wallet, password) {
  //     // canShow = false;
  //     print('step5');
  //     onGetPassword(wallet, password);
  //   });
  // }
  //
  // static void authToPrepareConnect(WalletSchema wallet, void onGetPassword(WalletSchema wallet, String password)) async {
  //   final _wallet = wallet;
  //   final _password = await authToGetPassword(_wallet);
  //   if (_password != null && _password.length > 0) {
  //     onGetPassword(_wallet, _password);
  //   }
  // }
  //
  // static bool _authenticating = false;
  //
  // static Future<String> authToGetPassword(WalletSchema wallet, {bool forceShowInputDialog = false}) async {
  //   if (_authenticating) return null;
  //   _authenticating = true;
  //   final _password = await wallet.getPassword(showDialogIfCanceledBiometrics: true /*default*/, forceShowInputDialog: forceShowInputDialog);
  //   _authenticating = false;
  //   return _password;
  // }
  //
  // static Future<String> getPasswordToAuth(String address) async{
  //   bool protection = await LocalAuthenticationService.instance.protectionStatus();
  //   String password = '';
  //   password = await SecureStorage().get('${SecureStorage.PASSWORDS_KEY}:$address');
  //   return password;
  // }
  //
  // // static String getPassword4BackgroundFetch({
  // //   @required WalletSchema wallet,
  // //   bool verifyProtectionEnabled = true,
  // //   @required void onGetPassword(WalletSchema wallet, String password),
  // // }) async {
  // //   bool isProtectionEnabled = false;
  // //
  // //   if (verifyProtectionEnabled) {
  // //     bool protection = await LocalAuthenticationService.instance.protectionStatus();
  // //     isProtectionEnabled = protection;
  // //   } else {
  // //     isProtectionEnabled = true;
  // //   }
  // //   if (isProtectionEnabled) {
  // //     final _password = await SecureStorage().get('${SecureStorage.PASSWORDS_KEY}:${wallet.address}');
  // //     if (_password != null && _password.length > 0) {
  // //       onGetPassword(wallet, _password);
  // //     }
  // //   }
  // // }
  //
  // static void verifyPassword({
  //   @required WalletSchema wallet,
  //   @required String password,
  //   @required void onGot(Map nknWallet),
  //   void onError(bool pwdIncorrect, dynamic e),
  // }) async {
  //   try {
  //     print('exportWallet___33');
  //     final nknWallet = await wallet.exportWallet(password);
  //     onGot(nknWallet);
  //   } catch (e) {
  //     if (onError != null) onError(e.message == ConstUtils.WALLET_PASSWORD_ERROR, e);
  //   }
  // }
  //
  // static authToVerifyPassword({
  //   @required WalletSchema wallet,
  //   @required void onGot(Map nknWallet),
  //   void onError(bool pwdIncorrect, dynamic e),
  //   bool forceShowInputDialog = false,
  // }) async {
  //   final _password = await authToGetPassword(wallet, forceShowInputDialog: forceShowInputDialog);
  //   if (_password != null && _password.length > 0) {
  //     verifyPassword(wallet: wallet, password: _password, onGot: onGot, onError: onError);
  //   } else {
  //     if (onError != null) onError(false, null);
  //   }
  // }


}
