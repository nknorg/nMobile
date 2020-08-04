import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:synchronized/synchronized.dart';

class LocalAuthenticationService with Tag {
  // ignore: non_constant_identifier_names
  LOG _LOG;

  LocalAuthenticationService._() {
    _LOG = LOG(tag);
  }

  static LocalAuthenticationService _instance;
  static Lock _lock = Lock();

  static Future<LocalAuthenticationService> get instance async {
    if (_instance == null)
      await _lock.synchronized(() async {
        if (_instance == null) {
          final ins = LocalAuthenticationService._();
          final localStorage = LocalStorage();
          ins.isProtectionEnabled = (await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.AUTH_KEY}')) as bool ?? false;
          ins.authType = await ins.getAuthType();
          _instance = ins;
        }
      });
    return _instance;
  }

  final _localAuth = LocalAuthentication();
  bool isProtectionEnabled = false;
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
      _LOG.e('getAuthType', e);
    }
    return null;
  }

  Future<bool> authenticate() async {
    if (isProtectionEnabled) {
      try {
        return await _localAuth.authenticateWithBiometrics(
          localizedReason: 'authenticate to access',
          useErrorDialogs: false,
          stickyAuth: true,
        );
      } on PlatformException catch (e) {
        _LOG.e('authenticate', e);
      }
    }
    return false;
  }

  Future<bool> cancelAuthentication() {
    if (isProtectionEnabled) {
      return _localAuth.stopAuthentication();
    } else
      return Future.value(true);
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
