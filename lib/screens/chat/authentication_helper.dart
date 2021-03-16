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
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class TimerAuth {
  factory TimerAuth() => _getInstance();

  static TimerAuth get instance => _getInstance();
  static TimerAuth _instance;
  TimerAuth._internal() {
    // init
  }

  static TimerAuth _getInstance() {
    if (_instance == null) {
      _instance = new TimerAuth._internal();
    }
    return _instance;
  }

  final int gapTime = 1000 * 60;
  static bool authed = false;

  static bool _pagePushed = false;
  static bool onOtherPage = false;

  DateTime _startTime;

  bool get pagePushed => _pagePushed;

  AuthBloc _authBloc;

  int onHomePageResumed(BuildContext context) {
    if (_startTime == null) {
      return 1;
    }
    bool shouldAuth = DateTime.now().millisecondsSinceEpoch -
            _startTime.millisecondsSinceEpoch >=
        gapTime;
    NLog.w('wait to Auth gapTime is__' +
        (DateTime.now().millisecondsSinceEpoch -
                _startTime.millisecondsSinceEpoch)
            .toString());
    if (authed == false) {
      NLog.w('auth Returned');
      return 1;
    }
    if (shouldAuth) {
      authed = false;
      NLog.w('authDisabled');
      return 1;
    }
    authed = true;
    return -1;
  }

  enableAuth() {
    NLog.w('enableAuth');
    authed = true;
    _startTime = DateTime.now();
  }

  pageDidPushed() {
    _pagePushed = true;
  }

  pageDidPop() {
    _pagePushed = false;
  }

  onHomePagePaused(BuildContext context) {
    if (authed == true) {
      NLog.w('startTime renew__:' + _startTime.toString());
      _startTime = DateTime.now();
    }
  }

  Future<String> _checkUserInput(BuildContext context) async {
    /// AuthFailed
    TimerAuth.authed = false;
    _authBloc = BlocProvider.of<AuthBloc>(context);
    _authBloc.add(AuthFailEvent());

    String password = await BottomDialog.of(context).showInputPasswordDialog(
        title: NL10ns.of(context).verify_wallet_password);
    if (password != null && password.length > 0) {
      WalletSchema wallet = await loadCurrentWallet();
      try {
        Map walletInfo = await wallet.exportWallet(password);
        if (walletInfo == null) {
          showToast(
              'keyStore file broken,Reimport your wallet,(due to 1.0.3 Error)');
        } else {
          bool protection =
              await LocalAuthenticationService.instance.protectionStatus();
          if (protection == false) {
            BottomDialog.of(context).showOpenBiometric();
          }
          return password;
        }
      } catch (e) {
        _authBloc = BlocProvider.of<AuthBloc>(context);
        _authBloc.add(AuthFailEvent());

        NLog.w('_checkUserInput E:' + e.toString());

        // showToast(NL10ns.of(context).tip_password_error);
      }
      return password;
    } else {
      return '';
    }
  }

  Future<String> onCheckAuthGetPassword(BuildContext context) async {
    bool protection =
        await LocalAuthenticationService.instance.protectionStatus();

    /// Need authPassword can autoEnable Biometrics(eg:TouchId)
    String password = '';
    if (protection == false || protection == null) {
      password = await _checkUserInput(context);
    } else {
      bool auth = await LocalAuthenticationService.instance.authenticate();
      if (auth) {
        TimerAuth.instance.enableAuth();
        WalletSchema wallet = await loadCurrentWallet();
        if (wallet == null) {
          NLog.w('Wrong!!! wallet is null');
        }
        String address = wallet.address;
        password = await SecureStorage()
            .get('${SecureStorage.PASSWORDS_KEY}:$address');
        if (password == null) {
          password = await _checkUserInput(context);
        }
        try {
          await wallet.exportWallet(password);
        } catch (e) {
          showToast(NL10ns.of(context).tip_password_error);
        }
        return password;
      } else {
        password = await _checkUserInput(context);
      }
    }
    return password;
  }

  static Future<WalletSchema> loadCurrentWallet() async {
    WalletSchema walletModel;
    var walletAddress =
        await LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS);
    List wallets = await LocalStorage().getArray(LocalStorage.NKN_WALLET_KEY);

    if (walletAddress == null) {
      if (wallets.isNotEmpty) {
        Map resultWallet = wallets[0];
        walletModel = WalletSchema(
            address: resultWallet['address'],
            type: resultWallet['type'],
            name: resultWallet['name']);
        return walletModel;
      }
    } else {
      for (Map wallet in wallets) {
        var walletModel = WalletSchema(
            address: wallet['address'],
            type: wallet['type'],
            name: wallet['name']);

        if (walletModel.address == walletAddress) {
          return walletModel;
        }
      }
      if (wallets.isNotEmpty) {
        Map resultWallet = wallets[0];
        walletModel = WalletSchema(
            address: resultWallet['address'],
            type: resultWallet['type'],
            name: resultWallet['name']);
        return walletModel;
      }
    }
    return null;
  }
}
