import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';

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

  Future<bool> protectionStatus() async{
    final localStorage = LocalStorage();
    bool status = await localStorage.get('${LocalStorage.SETTINGS_KEY}:${LocalStorage.AUTH_KEY}');
    if (status == null){
      return true;
    }
    if (status == true){
      return true;
    }
    return false;
  }

  Future<BiometricType> getAuthType() async {
    try {
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      print('availableBiometrics __'+availableBiometrics.toString());
      if (availableBiometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }
    } on PlatformException
    catch (e) {
      Global.debugLog('getAuthType | PlatformException');
    } on MissingPluginException catch (e) {
      Global.debugLog('getAuthType | MissingPluginException');
    } catch (e) {
      Global.debugLog('getAuthType | ?');
    }
    return null;
  }

  Future<bool> authenticate() async {
    bool isProtectionEnabled = await protectionStatus();
    if (isProtectionEnabled) {
      try {
        final success = await _localAuth.authenticateWithBiometrics(
          localizedReason: NL10ns.of(Global.appContext).authenticate_to_access,
          useErrorDialogs: false,
          stickyAuth: true,
        );
        return success;
      } on PlatformException catch (e) {
        Global.debugLog('authenticate | PlatformException'+ e.toString());
      } on MissingPluginException catch (e) {
        Global.debugLog('authenticate | MissingPluginException'+e.toString());
      } catch (e) {
        Global.debugLog('authenticate | ?'+e.toString());
      }
    }
    return false;
  }


  Future<bool> hasBiometrics() async {
    bool canCheck = await _localAuth.canCheckBiometrics;
    if (canCheck) {
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.contains(BiometricType.face)) {
        return true;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return true;
      }
    }
    return false;
  }
}
