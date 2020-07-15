/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:flutter/material.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/const_utils.dart';

/// @author Chenai
/// @version 1.0, 14/07/2020
class DChatAuthenticationHelper {
  // For account switch.
  static bool _initLaunch = true;

  bool canShow = false;
  bool isPageActive = true; // e.g. isTabOnCurrentPageIndex
  WalletSchema wallet;

  ensureAutoShowAuthentication(void onGetPassword(WalletSchema wallet, String password)) {
    if ((_initLaunch || canShow) && isPageActive && wallet != null) {
      prepareConnect(onGetPassword);
    }
  }

  prepareConnect(void onGetPassword(WalletSchema wallet, String password)) async {
    final _wallet = wallet;
    final _password = await authToGetPassword(_wallet);
    if (_password != null) {
      _initLaunch = false;
      canShow = false;
      onGetPassword(_wallet, _password);
    }
  }

  static bool _authenticating = false;

  static Future<String> authToGetPassword(WalletSchema wallet, {bool forceShowInputDialog = false}) async {
    if (_authenticating) return null;
    _authenticating = true;
    final _password = await wallet.getPassword(showDialogIfCanceledBiometrics: true /*default*/, forceShowInputDialog: forceShowInputDialog);
    _authenticating = false;
    return _password;
  }

  static void cancelAuthentication() async {
    LocalAuthenticationService.instance.then((instance) {
      instance.cancelAuthentication();
    });
    // TODO: cancel input password dialog, `_authenticating` also played a role.
  }

  static void verifyPassword({
    @required WalletSchema wallet,
    @required String password,
    @required void onGot(Map nknWallet),
    void onError(bool pwdIncorrect, dynamic e),
  }) async {
    try {
      final nknWallet = await wallet.exportWallet(password);
      onGot(nknWallet);
    } catch (e) {
      if (onError != null) onError(e.message == ConstUtils.WALLET_PASSWORD_ERROR, e);
    }
  }

  static authToVerifyPassword({
    @required WalletSchema wallet,
    @required void onGot(Map nknWallet),
    void onError(bool pwdIncorrect, dynamic e),
    bool forceShowInputDialog = false,
  }) async {
    final _password = await authToGetPassword(wallet, forceShowInputDialog: forceShowInputDialog);
    if (_password != null) {
      verifyPassword(wallet: wallet, password: _password, onGot: onGot, onError: onError);
    } else {
      if (onError != null) onError(true, null);
    }
  }

  static void loadDChatUseWallet(WalletsBloc walletBloc, void callback(WalletSchema wallet)) {
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((walletAddress) {
      // `walletAddress` can be null.
      final addr = walletAddress;

      void parse(WalletsLoaded state) {
        final wallet = state.wallets.firstWhere((w) => w.address == addr, orElse: () => state.wallets.first);
        callback(wallet);
      }

      if (walletBloc.state is WalletsLoaded) {
        parse(walletBloc.state as WalletsLoaded);
      } else {
        var subscription;

        void onData(state) {
          if (walletBloc.state is WalletsLoaded) {
            parse(walletBloc.state as WalletsLoaded);
            subscription.cancel();
          }
        }

        subscription = walletBloc.listen(onData);
      }
    });
  }
}
