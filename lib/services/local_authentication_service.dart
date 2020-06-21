import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthenticationService {
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

  ///
  /// authenticateWithBiometrics()
  ///
  /// @param [message] Message shown to user in FaceID/TouchID popup
  /// @returns [true] if successfully authenticated, [false] otherwise
  Future<bool> authenticate({message: 'authenticate to access'}) async {
    bool hasBiometricsEnrolled = await hasBiometrics();
    if (hasBiometricsEnrolled) {
      LocalAuthentication localAuth = new LocalAuthentication();
      return await localAuth.authenticateWithBiometrics(localizedReason: message, useErrorDialogs: false);
    }
    return false;
//    if (isProtectionEnabled) {
//      try {
//        isAuthenticated = await _localAuth.authenticateWithBiometrics(
//          localizedReason: 'authenticate to access',
//          useErrorDialogs: false,
//          stickyAuth: true,
//        );
//      } on PlatformException catch (e) {
//        debugPrint(e.message);
//        debugPrintStack();
//      }
//      return isAuthenticated;
//    }
  }

  ///
  /// hasBiometrics()
  ///
  /// @returns [true] if device has fingerprint/faceID available and registered, [false] otherwise
  Future<bool> hasBiometrics() async {
    LocalAuthentication localAuth = new LocalAuthentication();
    bool canCheck = await localAuth.canCheckBiometrics;
    if (canCheck) {
      List<BiometricType> availableBiometrics = await localAuth.getAvailableBiometrics();
//      availableBiometrics.forEach((type) {
//        sl.get<Logger>().i(type.toString());
//        sl.get<Logger>().i("${type == BiometricType.face ? 'face' : type == BiometricType.iris ? 'iris' : type == BiometricType.fingerprint ? 'fingerprint' : 'unknown'}");
//      });
      if (availableBiometrics.contains(BiometricType.face)) {
        return true;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return true;
      }
    }
    return false;
  }
}
