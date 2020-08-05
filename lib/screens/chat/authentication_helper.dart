/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:flutter/material.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/log_tag.dart';

/// @author Chenai
/// @version 1.0, 14/07/2020
enum PageAction { init, pushNext, popToCurr, force }

class DChatAuthenticationHelper with Tag {
  // ignore: non_constant_identifier_names
  LOG _LOG;

  DChatAuthenticationHelper() {
    _LOG = LOG(tag, usePrint: false);
  }

  bool canShow = false;
  WalletSchema wallet;

  bool _pageActiveInited = false;
  bool _isPageActive = true; // e.g. isTabOnCurrentPageIndex

  void setPageActive(PageAction action, [bool value]) {
    if (_pageActiveInited) {
      switch (action) {
        case PageAction.init:
//        _isPageActive = force;
          throw 'illegal state';
          break;
        case PageAction.pushNext:
          _isPageActive = false;
          break;
        case PageAction.popToCurr:
          _isPageActive = true;
          break;
        case PageAction.force:
          assert(value != null);
          _isPageActive = value;
          break;
        default:
          throw 'unknown';
      }
    } else {
      switch (action) {
        case PageAction.init:
          _pageActiveInited = true;
          _isPageActive = value;
          break;
        default:
          throw 'illegal state';
      }
    }
  }

  ensureAutoShowAuthentication(String debug, void onGetPassword(WalletSchema wallet, String password)) {
    _LOG.d('ensureAutoShowAuth...[$debug] | canShow: $canShow, _isPageActive: $_isPageActive,'
        ' route: ${ModalRoute.of(Global.appContext).settings.name}, wallet: $wallet.');
    LocalNotification.debugNotification('<[DEBUG]> ensureAutoShowAuth...',
        '[$debug] canShow: $canShow, pageActive: $_isPageActive, wallet: ${wallet != null}, ' + DateTime.now().toLocal().toString());
    if (canShow && _isPageActive && wallet != null) {
      prepareConnect(onGetPassword);
    }
  }

  prepareConnect(void onGetPassword(WalletSchema wallet, String password)) {
    authToPrepareConnect(wallet, (wallet, password) {
      canShow = false;
      onGetPassword(wallet, password);
    });
  }

  static void authToPrepareConnect(WalletSchema wallet, void onGetPassword(WalletSchema wallet, String password)) async {
    final _wallet = wallet;
    final _password = await authToGetPassword(_wallet);
    if (_password != null && _password.length > 0) {
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

  static getPassword4BackgroundFetch({
    @required WalletSchema wallet,
    bool verifyProtectionEnabled = true,
    @required void onGetPassword(WalletSchema wallet, String password),
  }) async {
    // 22508-22760 E/flutter: [ERROR:flutter/lib/ui/ui_dart_state.cc(157)] Unhandled Exception: MissingPluginException(
    // No implementation found for method getAvailableBiometrics on channel plugins.flutter.io/local_auth)
    // Since Android Native Service create a new `DartVM`, and not init other MethodChannel.
    bool isProtectionEnabled = false;
    if (verifyProtectionEnabled) {
      isProtectionEnabled = (await LocalAuthenticationService.instance).isProtectionEnabled;
    } else {
      isProtectionEnabled = true;
    }
    if (isProtectionEnabled) {
      final _password = await SecureStorage().get('${SecureStorage.PASSWORDS_KEY}:${wallet.address}');
      if (_password != null && _password.length > 0) {
        onGetPassword(wallet, _password);
      }
    }
  }

  static void cancelAuthentication() async {
    // Must be canceled accompanied by `inputPasswordDialog`, or it only shows `inputPasswordDialog`.
//    LocalAuthenticationService.instance.then((instance) {
//      instance.cancelAuthentication();
//    });
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
    if (_password != null && _password.length > 0) {
      verifyPassword(wallet: wallet, password: _password, onGot: onGot, onError: onError);
    } else {
      if (onError != null) onError(true, null);
    }
  }

  static void loadDChatUseWalletByState(WalletsLoaded state, void callback(WalletSchema wallet)) {
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((walletAddress) {
      // `walletAddress` can be null.
      final addr = walletAddress;

      void parse(WalletsLoaded state) {
        final wallet = state.wallets.firstWhere((w) => w.address == addr, orElse: () => state.wallets.first);
        callback(wallet);
      }

      parse(state);
    });
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
