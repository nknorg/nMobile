import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

import '../locator.dart';

class WalletCommon {
  WalletStorage _walletStorage = WalletStorage();

  Future<WalletSchema> getWalletInStorageByAddress(String address) async {
    if (address == null || address.length == 0) return null;
    List<WalletSchema> wallets = await _walletStorage.getWallets();
    if (wallets == null || wallets.isEmpty) return null;
    return wallets.firstWhere((x) => x?.address == address, orElse: () => null);
  }

  WalletSchema getWalletInOriginalByAddress(List<WalletSchema> wallets, String address) {
    if (address == null || address.length == 0) return null;
    if (wallets == null || wallets.isEmpty) return null;
    return wallets.firstWhere((x) => x?.address == address, orElse: () => null);
  }

  Future<String> getWalletKeystoreByAddress(String address) async {
    String keystore = await _walletStorage.getKeystore(address);
    if (keystore == null || keystore.isEmpty) {
      throw new Exception("keystore not exits");
    }
    return keystore;
  }

  Future<bool> isWalletsBackup({List original}) async {
    List wallets = original ?? await _walletStorage.getWallets();
    // backups
    List<Future> futures = <Future>[];
    wallets?.forEach((value) {
      futures.add(_walletStorage.isBackupByAddress(value?.address));
    });
    List backups = await Future.wait(futures);
    // allBackup
    logger.d("wallet backup - $backups");
    bool find = backups?.firstWhere((backup) => backup == false || backup == null, orElse: () => true);
    bool allBackup = find == true ? true : false;
    logger.d("wallet backup - allBackup:$allBackup");
    return allBackup;
  }

  Future<WalletSchema> getWalletDefault() async {
    String address = await getWalletDefaultAddress();
    WalletSchema result = await getWalletInStorageByAddress(address);
    if (result == null) {
      List wallets = await _walletStorage.getWallets();
      if (wallets != null && wallets.isNotEmpty) {
        address = (wallets[0] as WalletSchema)?.address;
        await _walletStorage.setDefaultAddress(address);
        result = await getWalletInStorageByAddress(address);
      }
    }
    return result;
  }

  Future<String> getWalletDefaultAddress() {
    return _walletStorage.getDefaultAddress();
  }

  Future<String> getWalletPassword(BuildContext context, String walletAddress) {
    if (walletAddress == null || walletAddress.isEmpty) {
      return Future.value(null);
    }
    S _localizations = S.of(context ?? Global.appContext);
    return Future(() async {
      if (Settings.biometricsAuthentication) {
        return authorization.authenticationIfCan();
      }
      return false;
    }).then((bool authOk) async {
      String pwd = await getWalletPasswordNoCheck(walletAddress);
      if (!authOk || pwd == null || pwd.isEmpty) {
        return BottomDialog.of(context ?? Global.appContext).showInput(
          title: _localizations.verify_wallet_password,
          inputTip: _localizations.wallet_password,
          inputHint: _localizations.input_password,
          actionText: _localizations.continue_text,
          password: true,
        );
      }
      return pwd;
    });
  }

  Future getWalletPasswordNoCheck(String walletAddress) {
    return _walletStorage.getPassword(walletAddress);
  }

  bool isBalanceSame(WalletSchema w1, WalletSchema w2) {
    if (w1 == null || w2 == null) return true;
    return w1.balance == w2.balance && w1.balanceEth == w2.balanceEth;
  }
}
