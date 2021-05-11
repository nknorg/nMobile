import 'package:local_auth/local_auth.dart';
import 'package:nmobile/utils/logger.dart';

/// Biometric authentication (Face ID, Touch ID or lock code), pin coode, wallet password
class Authorization {
  /// This class provides means to perform local, on-device authentication of the user.
  /// This means referring to biometric authentication on iOS (Touch ID or lock code) and the fingerprint
  /// APIs on Android (introduced in Android 6.0).
  /// doc: https://github.com/flutter/plugins/tree/master/packages/local_auth
  LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get canCheckBiometrics async => await _localAuth.canCheckBiometrics;

  Future<List<BiometricType>> get availableBiometrics async => await _localAuth.getAvailableBiometrics();

  Future<bool> authentication(String localizedReason) async {
    try {
      bool success = await _localAuth.authenticate(localizedReason: localizedReason);
      return success;
    } catch (e) {
      logger.e(e);
    }

    return false;
  }

  Future<bool> authenticationIfCan(String localizedReason) async {
    if (await canCheckBiometrics) {
      return authentication(localizedReason);
    }
    return false;
  }

  Future<bool> cancelAuthentication() {
    return _localAuth.stopAuthentication();
  }
}
