import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletSchema extends Equatable {
  static const String NKN_WALLET = 'nkn';
  static const String ETH_WALLET = 'eth';
  final String address;
  final String type;
  String name;
  double balance = 0;
  String keystore;
  String publicKey;
  String seed;
  double balanceEth = 0;
  bool isBackedUp = false;

//  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();
  final LocalAuthenticationService _localAuth = locator<LocalAuthenticationService>();

  WalletSchema({this.address, this.type, this.name, this.balance = 0, this.balanceEth = 0, this.isBackedUp = false});

  @override
  List<Object> get props => [address, type, name];

  @override
  String toString() => 'WalletSchema { address: $address }';

  Future<String> getPassword() async {
    NLog.d('getPassword');
    if (_localAuth.isProtectionEnabled) {
      final password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');
      if (password == null) {
        return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NMobileLocalizations.of(Global.appContext).verify_wallet_password);
      } else {
        bool auth = await _localAuth.authenticate();
        if (auth) {
          return password;
        } else {
          return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NMobileLocalizations.of(Global.appContext).verify_wallet_password);
        }
      }
    } else {
      return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NMobileLocalizations.of(Global.appContext).verify_wallet_password);
    }
  }

  Future<String> getKeystore() async {
    var keystore = await _secureStorage.get('${SecureStorage.NKN_KEYSTORES_KEY}:$address');
    return keystore;
  }

  Future exportWallet(password) async {
    var keystore = await _secureStorage.get('${SecureStorage.NKN_KEYSTORES_KEY}:$address');
    try {
      var wallet = await NknWalletPlugin.openWallet(keystore, password);
      await _secureStorage.set('${SecureStorage.PASSWORDS_KEY}:$address', password);
      return wallet;
    } catch (e) {
      throw e;
    }
  }

  static getWallet({int index = 0}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String s = prefs.get('${LocalStorage.NKN_WALLET_KEY}:$index');
      if (s == null) return null;
      var walletData = jsonDecode(s);
      var wallet = WalletSchema(name: walletData['name'], address: walletData['address']);
      return wallet;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isDefaultWallet() async {
    WalletSchema wallet = await getWallet();
    if (wallet == null || address == null) return false;
    return wallet.address == address;
  }
}
