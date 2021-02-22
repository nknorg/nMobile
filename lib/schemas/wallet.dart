import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/credentials.dart';

enum WalletType { nkn, eth }

class WalletSchema extends Equatable with Tag {
  static const String NKN_WALLET = 'nkn';
  static const String ETH_WALLET = 'eth';
  final String address;
  final String type;
  String name;
  double balance = 0;

  double balanceEth = 0;
  bool isBackedUp = false;

  final SecureStorage _secureStorage = SecureStorage();

  WalletSchema({this.address, this.type, this.name, this.balance = 0, this.balanceEth = 0, this.isBackedUp = false});

  @override
  List<Object> get props => [address, type, name];

  @override
  String toString() => 'WalletSchema { address: $address }';

  Future<String> _showDialog(String reason) {
    return BottomDialog.of(Global.appContext).showInputPasswordDialog(title: NL10ns.of(Global.appContext).verify_wallet_password);
  }

  Future<String> getPassword({bool showDialogIfCanceledBiometrics = true, bool forceShowInputDialog = false}) async {
    if (forceShowInputDialog) {
      return _showDialog('force');
    }

    bool underProtection = await LocalAuthenticationService.instance.protectionStatus();
    if (underProtection) {
      String password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:$address');

      if (password == null) {
        return _showDialog('no password');
      } else {
        bool auth = await LocalAuthenticationService.instance.authenticate();
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

  Future<String> getKeystoreByPassword(String password) async{
    String keystore = await LocalStorage().getValueDecryptByKey(password,address);
    if (keystore.isNotEmpty && keystore.length > 0){
      return keystore;
    }
    return '';
  }

  Future<String> getKeystore() async {
    if (Platform.isAndroid){
      LocalStorage storage = LocalStorage();
      String keyStore = await storage.getKeyStoreValue(address);
      if (keyStore == null || keyStore.length == 0){
        /// if not new Comer
        keyStore = await _secureStorage.get('${SecureStorage.NKN_KEYSTORES_KEY}:$address');
        if (keyStore == null){
          /// keystore is broken
          keyStore = '';
        }
        else {
          storage.saveKeyStoreInFile(address,keyStore);
        }
      }
      return keyStore;
    }
    else{
      return await _secureStorage.get('${SecureStorage.NKN_KEYSTORES_KEY}:$address');
    }
  }

  Future<Map> exportWallet(password) async {
    String exportKeystore = await getKeystore();
    if (exportKeystore == null || exportKeystore.length == 0){
      exportKeystore = await LocalStorage().getValueDecryptByKey(password,address);
      // showToast('exportKeystore 111for key__'+exportKeystore.toString());
      if (exportKeystore != null && exportKeystore.length > 0){
        /// 1.0.3 bug pass
        LocalStorage().saveKeyStoreInFile(address,exportKeystore);
      }
      else{
        // showToast('exportKeystore 13333311for key__'+exportKeystore.toString());
        return null;
      }
    }

    var wallet = await NknWalletPlugin.openWallet(exportKeystore, password);

    await _secureStorage.set('${SecureStorage.PASSWORDS_KEY}:$address', password);

    print('Save password for key__'+password+'___'+address);
    return wallet;
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
