import 'dart:async';
import 'dart:io';

import 'package:nmobile/schema/wallet.dart';

import '../helpers/local_storage.dart';
import '../helpers/secure_storage.dart';

class WalletStorage {
  static const String KEY_SEED = 'SEED';
  static const String KEY_WALLET = 'WALLETS';
  static const String KEY_KEYSTORE = 'KEYSTORE';
  static const String KEY_PASSWORD = 'PASSWORD';
  static const String KEY_BACKUP = 'BACKUP';

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  Future<List> getWallets() async {
    var wallets = await _localStorage.getArray(KEY_WALLET);
    if (wallets != null && wallets.isNotEmpty) {
      final list = wallets.map((e) {
        WalletSchema walletSchema = WalletSchema.fromCacheMap(e);
        return walletSchema;
      }).toList();
      return list;
    }
    return null;
  }

  Future addWallet(WalletSchema walletSchema, String keystore, {String password, String seed}) async {
    List<Future> futures = <Future>[];
    var wallets = await _localStorage.getArray(KEY_WALLET);
    int index = wallets?.indexWhere((x) => x['address'] == walletSchema?.address) ?? -1;
    if (index < 0) {
      futures.add(_localStorage.addItem(KEY_WALLET, walletSchema?.toCacheMap()));
    } else {
      futures.add(_localStorage.setItem(KEY_WALLET, index, walletSchema?.toCacheMap()));
    }
    if (keystore != null && keystore.isNotEmpty) {
      if (Platform.isAndroid) {
        futures.add(_localStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
      } else {
        futures.add(_secureStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
      }
    }
    if (password != null && password.isNotEmpty) {
      if (Platform.isAndroid) {
        futures.add(_localStorage.set('$KEY_PASSWORD:${walletSchema?.address}', password));
      } else {
        futures.add(_secureStorage.set('$KEY_PASSWORD:${walletSchema?.address}', password));
      }
    }
    if (seed != null && seed.isNotEmpty) {
      if (Platform.isAndroid) {
        futures.add(_localStorage.set('$KEY_SEED:${walletSchema?.address}', seed));
      } else {
        futures.add(_secureStorage.set('$KEY_SEED:${walletSchema?.address}', seed));
      }
    }
    await Future.wait(futures);
  }

  Future deleteWallet(int n, WalletSchema walletSchema) async {
    List<Future> futures = <Future>[];
    if (n >= 0) {
      futures.add(_localStorage.removeItem(KEY_WALLET, n));
      if (Platform.isAndroid) {
        futures.add(_localStorage.remove('$KEY_KEYSTORE:${walletSchema?.address}'));
        futures.add(_localStorage.remove('$KEY_PASSWORD:${walletSchema?.address}'));
        futures.add(_localStorage.remove('$KEY_SEED:${walletSchema?.address}'));
      } else {
        futures.add(_secureStorage.delete('$KEY_KEYSTORE:${walletSchema?.address}'));
        futures.add(_secureStorage.delete('$KEY_PASSWORD:${walletSchema?.address}'));
        futures.add(_secureStorage.delete('$KEY_SEED:${walletSchema?.address}'));
      }
      futures.add(_localStorage.remove('$KEY_BACKUP:${walletSchema?.address}'));
    }
    await Future.wait(futures);
  }

  Future updateWallet(int n, WalletSchema walletSchema) async {
    List<Future> futures = <Future>[];
    if (n >= 0) {
      futures.add(_localStorage.setItem(KEY_WALLET, n, walletSchema?.toCacheMap()));
    }
    await Future.wait(futures);
  }

  Future backupWallet(String address, bool backup) {
    return Future(() => _localStorage.set('$KEY_BACKUP:$address', backup));
  }

  Future isBackupByList(List<WalletSchema> wallets) async {
    List<Future> futures = <Future>[];
    wallets?.forEach((value) async {
      futures.add(isBackupByAddress(value?.address));
    });
    return Future.wait(futures);
  }

  Future isBackupByAddress(String address) {
    return Future(() => _localStorage.get('$KEY_BACKUP:$address'));
  }

  // TODO:GG need support old
  Future getKeystore(String address) {
    if (address != null && address.isNotEmpty) {
      if (Platform.isAndroid) {
        return Future(() => _localStorage.get('$KEY_KEYSTORE:$address'));
      } else {
        return Future(() => _secureStorage.get('$KEY_KEYSTORE:$address'));
      }
    }
    return Future.value(null);
  }

  Future getPassword(String address) {
    if (address != null && address.isNotEmpty) {
      if (Platform.isAndroid) {
        return Future(() => _localStorage.get('$KEY_PASSWORD:$address'));
      } else {
        return Future(() => _secureStorage.get('$KEY_PASSWORD:$address'));
      }
    }
    return Future.value(null);
  }

  Future getSeed(String address) {
    if (address != null && address.isNotEmpty) {
      if (Platform.isAndroid) {
        return Future(() => _localStorage.get('$KEY_SEED:$address'));
      } else {
        return Future(() => _secureStorage.get('$KEY_SEED:$address'));
      }
    }
    return Future.value(null);
  }
}
