import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validation.dart';

import 'global.dart';

/// Biometric authentication (Face ID, Touch ID or lock code), pin code, wallet password
class Authorization {
  /// This class provides means to perform local, on-device authentication of the user.
  /// This means referring to biometric authentication on iOS (Touch ID or lock code) and the fingerprint
  /// APIs on Android (introduced in Android 6.0).
  /// doc: https://github.com/flutter/plugins/tree/master/packages/local_auth
  LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get canCheckBiometrics async => await _localAuth.canCheckBiometrics;

  Future<List<BiometricType>> get availableBiometrics async => await _localAuth.getAvailableBiometrics();

  Authorization();

  Future<bool> authentication([String? localizedReason]) async {
    if (localizedReason == null || localizedReason.isEmpty) {
      localizedReason = S.of(Global.appContext).authenticate_to_access;
    }
    try {
      bool success = await _localAuth.authenticate(
        localizedReason: localizedReason,
        useErrorDialogs: true,
        stickyAuth: true,
      );
      return success;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> authenticationIfSupport([String? localizedReason]) async {
    if (await canCheckBiometrics) {
      return authentication(localizedReason);
    }
    return false;
  }

  Future<bool> cancelAuthentication() {
    return _localAuth.stopAuthentication();
  }

  Future<String?> getWalletPassword(String? walletAddress, {BuildContext? context}) {
    if (walletAddress == null || walletAddress.isEmpty) {
      return Future.value(null);
    }
    S _localizations = S.of(context ?? Global.appContext);
    return Future(() async {
      if (Settings.biometricsAuthentication) {
        return authenticationIfSupport();
      }
      return false;
    }).then((bool authOk) async {
      String? pwd = await walletCommon.getPassword(walletAddress);
      if (!authOk || pwd == null || pwd.isEmpty) {
        return BottomDialog.of(context ?? Global.appContext).showInput(
          title: _localizations.verify_wallet_password,
          inputTip: _localizations.wallet_password,
          inputHint: _localizations.input_password,
          actionText: _localizations.continue_text,
          validator: Validator.of(context ?? Global.appContext).password(),
          password: true,
        );
      }
      return pwd;
    });
  }
}
