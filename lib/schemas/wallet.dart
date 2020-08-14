import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WalletType { nkn, eth }

class WalletSchema extends Equatable with Tag {
  static const String NKN_WALLET = 'nkn';
  static const String ETH_WALLET = 'eth';
  final String address;
  final String type;
  String name;
  double balance = 0;
  String keystore;

  //String publicKey; // fixme: null!!!
  double balanceEth = 0;
  bool isBackedUp = false;

//  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  WalletSchema({this.address, this.type, this.name, this.balance = 0, this.balanceEth = 0, this.isBackedUp = false});

  @override
  List<Object> get props => [address, type, name];

  @override
  String toString() => 'WalletSchema { address: $address }';

  Future<String> getPassword({bool showDialogIfCanceledBiometrics = true, bool forceShowInputDialog = false}) async {
    LOG(tag, usePrint: false).d('getPassword');
    Future<String> _showDialog(String reason) {
      LocalNotification.debugNotification('<[DEBUG]> showInputPasswordDialog', 'reason: $reason, ' + DateTime.now().toLocal().toString());
      return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NL10ns.of(Global.appContext).verify_wallet_password);
    }

    if (forceShowInputDialog) {
      return _showDialog('force');
    }
    final _localAuth = await LocalAuthenticationService.instance;
    if (_localAuth.isProtectionEnabled) {
      final password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');
      if (password == null) {
        return _showDialog('no password');
      } else {
        bool auth = await _localAuth.authenticate();
        if (auth) {
          return password;
        } else if (showDialogIfCanceledBiometrics) {
          return _showDialog('auth failed');
        } else {
          return null;
        }
      }
    } else {
      return _showDialog('disabled');
    }
  }

  Future<String> getKeystore() async {
    return await _secureStorage.get('${SecureStorage.NKN_KEYSTORES_KEY}:$address');
  }

  Future exportWallet(password) async {
    try {
      var wallet = await NknWalletPlugin.openWallet(await getKeystore(), password);
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
