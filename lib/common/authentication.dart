import 'package:local_auth/local_auth.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validation.dart';

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
      localizedReason = Settings.locale((s) => s.authenticate_to_access);
    }
    try {
      bool success = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );
      return success;
    } catch (e, st) {
      handleError(e, st, upload: false);
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

  Future<String?> getWalletPassword(String? walletAddress, {Function(bool)? onInput}) {
    if (walletAddress == null || walletAddress.isEmpty) {
      return Future.value(null);
    }
    return Future(() async {
      if (Settings.biometricsAuthentication) {
        return authenticationIfSupport();
      }
      return false;
    }).then((bool authOk) async {
      String? pwd;
      try {
        pwd = await walletCommon.getPassword(walletAddress);
        // Default Account / empty password wallet: skip dialog, use empty password to login
        if (pwd == '' && Settings.biometricsAuthentication) {
          return null;
        } else if (pwd == '') {
          return '';
        }
        if (!authOk || pwd == null) {
          onInput?.call(true);
          String? password = await BottomDialog.of(Settings.appContext).showInput(
            title: Settings.locale((s) => s.verify_wallet_password),
            inputTip: Settings.locale((s) => s.wallet_password),
            inputHint: Settings.locale((s) => s.input_password),
            actionText: Settings.locale((s) => s.continue_text),
            validator: Validator.of(Settings.appContext).password(),
            password: true,
          );
          onInput?.call(false);
          return password;
        }
      } catch (_) {}
      return pwd;
    });
  }
}
