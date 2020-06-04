import 'dart:convert';

import 'package:common_utils/common_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/services/service_locator.dart';
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

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();
  final LocalAuthenticationService _localAuth = locator<LocalAuthenticationService>();

  WalletSchema({this.address, this.type, this.name, this.balance, this.balanceEth, this.isBackedUp});

  @override
  List<Object> get props => [address, type, name];

  @override
  String toString() => 'WalletSchema { address: $address }';

  Future<String> getPassword({int count = 0}) async {
    if (_localAuth.isProtectionEnabled && count < 1) {
      final password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');
      if (password == null) {
        return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NMobileLocalizations.of(Global.appContext).verify_wallet_password);
      } else {
        await _localAuth.authenticate();
        if (_localAuth.isAuthenticated) {
          return password;
        } else {
          count++;
          LogUtil.v(count.toString());
          return getPassword(count: count);
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
      _secureStorage.set('${SecureStorage.PASSWORDS_KEY}:$address', password);
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
}
