import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthenticationService {
  LocalAuthenticationService._();

  static LocalAuthenticationService _instance;

  static LocalAuthenticationService get instance {
    _instance ??= LocalAuthenticationService._();
    return _instance;
  }

  final _localAuth = LocalAuthentication();
  bool isProtectionEnabled = false;
  bool isAuthenticated = false;
  BiometricType authType;

  Future<BiometricType> getAuthType() async {
    try {
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }
    } on PlatformException catch (e) {
      debugPrint(e.message);
      debugPrintStack();
    }
  }

  Future<bool> authenticate() async {
    if (isProtectionEnabled) {
      try {
        return isAuthenticated = await _localAuth.authenticateWithBiometrics(
          localizedReason: 'authenticate to access',
          useErrorDialogs: false,
          stickyAuth: true,
        );
      } on PlatformException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
      }
      return false;
    }
  }

  Future<bool> hasBiometrics() async {
    LocalAuthentication localAuth = new LocalAuthentication();
    bool canCheck = await localAuth.canCheckBiometrics;
    if (canCheck) {
      List<BiometricType> availableBiometrics = await localAuth.getAvailableBiometrics();

      if (availableBiometrics.contains(BiometricType.face)) {
        return true;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return true;
      }
    }
    return false;
  }
}
