import 'dart:io';

import 'package:nmobile/schema/wallet.dart';

import '../helpers/local_storage.dart';
import '../helpers/secure_storage.dart';

class WalletStorage {
  static const String SEED_KEY = 'SEED';
  static const String WALLET_KEY = 'WALLETS';
  static const String KEYSTORES_KEY = 'KEYSTORES';
  static const String PASSWORDS_KEY = 'PASSWORDS';

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  Future<List> getWallets() async {
    var wallets = await _localStorage.getArray(WALLET_KEY);
    if (wallets != null && wallets.isNotEmpty) {
      final list = wallets.map((e) {
        WalletSchema walletSchema = WalletSchema.fromCacheMap(e);
        return walletSchema;
      }).toList();
      return list;
    }
    return null;
  }

  Future addWallet(WalletSchema walletSchema, String keystore) async {
    List<Future> futures = <Future>[];
    var wallets = await _localStorage.getArray(WALLET_KEY);
    int index = wallets?.indexWhere((x) => x['address'] == walletSchema.address) ?? -1;
    if (index < 0) {
      futures.add(_localStorage.addItem(WALLET_KEY, walletSchema.toCacheMap()));
    } else {
      futures.add(_localStorage.setItem(WALLET_KEY, index, walletSchema.toCacheMap()));
    }
    if (Platform.isAndroid) {
      futures.add(_localStorage.set('$KEYSTORES_KEY:${walletSchema.address}', keystore));
    } else {
      futures.add(_secureStorage.set('$KEYSTORES_KEY:${walletSchema.address}', keystore));
    }
    await Future.wait(futures);
  }

  Future deleteWallet(int n, WalletSchema walletSchema) async {
    List<Future> futures = <Future>[];
    futures.add(_localStorage.removeItem(WALLET_KEY, n));
    await Future.wait(futures);
  }

  Future updateWallet(int n, WalletSchema walletSchema) async {
    List<Future> futures = <Future>[];

    futures.add(_localStorage.setItem(WALLET_KEY, n, walletSchema.toCacheMap()));
    await Future.wait(futures);
  }
}
