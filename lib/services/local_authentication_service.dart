import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/nlog_util.dart';

class LocalAuthenticationService {
  factory LocalAuthenticationService() => _getInstance();

  static LocalAuthenticationService get instance => _getInstance();
  static LocalAuthenticationService _instance;

  LocalAuthenticationService._internal() {
    _localAuth = LocalAuthentication();
  }

  LocalAuthentication _localAuth;
  // BiometricType authType;

  static LocalAuthenticationService _getInstance() {
    if (_instance == null) {
      _instance = new LocalAuthenticationService._internal();
    }
    return _instance;
  }

  Future<bool> protectionStatus() async {
    final localStorage = LocalStorage();
    bool status = await localStorage
        .get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.AUTH_KEY}');
    if (status == null) {
      return true;
    }
    if (status == true) {
      return true;
    }
    return false;
  }

  Future<BiometricType> getAuthType() async {
    try {
      List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }
    } on PlatformException catch (e) {
      NLog.w('getAuthType | PlatformException');
    } on MissingPluginException catch (e) {
      NLog.w('getAuthType | MissingPluginException');
    } catch (e) {
      NLog.w('getAuthType | ?');
    }
    return null;
  }

  Future<bool> authenticate() async {
    bool isProtectionEnabled = await protectionStatus();
    if (isProtectionEnabled) {
      try {
        bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
        if (canCheckBiometrics == false) {
          NLog.w('bug here when failed auth by times');
          return false;
        }

        // List<BiometricType> availableBiometrics;
        // try {
        //   availableBiometrics = await getAuthType();
        // } on PlatformException catch (e) {
        //   availableBiometrics = <BiometricType>[];
        //   print(e);
        // }
        // if (!mounted) return;

        // setState(() {
        //   _availableBiometrics = availableBiometrics;
        // });

        final success = await _localAuth.authenticateWithBiometrics(
          localizedReason: NL10ns.of(Global.appContext).authenticate_to_access,
          useErrorDialogs: true,
          stickyAuth: false,
        );
        return success;
      } on PlatformException catch (e) {
        NLog.w('authenticate | PlatformException' + e.toString());
      } on MissingPluginException catch (e) {
        NLog.w('authenticate | MissingPluginException' + e.toString());
      } catch (e) {
        NLog.w('authenticate | ?' + e.toString());
      }
    }
    return false;
  }

  Future<bool> authenticateIfMay() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (canCheckBiometrics == false) {
        NLog.w('bug here when failed auth by times');
        return false;
      }
      final success = await _localAuth.authenticateWithBiometrics(
        localizedReason: NL10ns.of(Global.appContext).authenticate_to_access,
        useErrorDialogs: false,
        stickyAuth: true,
      );
      return success;
    } on PlatformException catch (e) {
      NLog.w('authenticate | PlatformException' + e.toString());
    } on MissingPluginException catch (e) {
      NLog.w('authenticate | MissingPluginException' + e.toString());
    } catch (e) {
      NLog.w('authenticate | ?' + e.toString());
    }
    return false;
  }

  Future<bool> hasBiometrics() async {
    bool canCheck = await _localAuth.canCheckBiometrics;
    if (canCheck) {
      List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.contains(BiometricType.face)) {
        return true;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return true;
      }
    }
    return false;
  }
}
