import 'dart:async';
import 'dart:io';

import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/utils.dart';

import '../helpers/local_storage.dart';
import '../helpers/secure_storage.dart';

class WalletStorage {
  static const String KEY_WALLET = 'WALLETS';
  static const String KEY_KEYSTORE = 'KEYSTORES';
  static const String KEY_PASSWORD = 'PASSWORDS';
  static const String KEY_BACKUP = 'BACKUP';
  static const String KEY_DEFAULT_ADDRESS = 'WALLET_DEFAULT_ADDRESS';

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  Future<List<WalletSchema>> getWallets() async {
    var wallets = await _localStorage.getArray(KEY_WALLET);
    if (wallets.isNotEmpty) {
      final list = wallets.map((e) {
        WalletSchema walletSchema = WalletSchema.fromMap(e);
        return walletSchema;
      }).toList();
      return list;
    }
    return [];
  }

  Future add(WalletSchema? walletSchema, String? keystore, {String? password}) async {
    List<Future> futures = <Future>[];
    var wallets = await _localStorage.getArray(KEY_WALLET);
    int index = wallets.indexWhere((x) => x['address'] == walletSchema?.address);
    if (index < 0) {
      futures.add(_localStorage.addItem(KEY_WALLET, walletSchema?.toMap()));
    } else {
      futures.add(_localStorage.setItem(KEY_WALLET, index, walletSchema?.toMap()));
    }
    if (keystore != null && keystore.isNotEmpty) {
      if (Platform.isAndroid) {
        futures.add(_localStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
      } else {
        futures.add(_secureStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
      }
    }
    if (password != null && password.isNotEmpty) {
      futures.add(_secureStorage.set('$KEY_PASSWORD:${walletSchema?.address}', password));
    }
    return Future.wait(futures);
  }

  Future delete(int n, WalletSchema? walletSchema) async {
    List<Future> futures = <Future>[];
    if (n >= 0) {
      futures.add(_localStorage.removeItem(KEY_WALLET, n));
      if (Platform.isAndroid) {
        futures.add(_localStorage.remove('$KEY_KEYSTORE:${walletSchema?.address}'));
      } else {
        futures.add(_secureStorage.delete('$KEY_KEYSTORE:${walletSchema?.address}'));
      }
      futures.add(_secureStorage.delete('$KEY_PASSWORD:${walletSchema?.address}'));
      futures.add(_localStorage.remove('$KEY_BACKUP:${walletSchema?.address}'));
      if (await getDefaultAddress() == walletSchema?.address) {
        futures.add(_localStorage.remove('$KEY_DEFAULT_ADDRESS'));
      }
    }
    return Future.wait(futures);
  }

  Future update(int n, WalletSchema? walletSchema, {String? keystore, String? password, String? seed}) {
    List<Future> futures = <Future>[];
    if (n >= 0) {
      futures.add(_localStorage.setItem(KEY_WALLET, n, walletSchema?.toMap()));
      if (keystore != null && keystore.isNotEmpty) {
        if (Platform.isAndroid) {
          futures.add(_localStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
        } else {
          futures.add(_secureStorage.set('$KEY_KEYSTORE:${walletSchema?.address}', keystore));
        }
      }
      if (password != null && password.isNotEmpty) {
        futures.add(_secureStorage.set('$KEY_PASSWORD:${walletSchema?.address}', password));
      }
    }
    return Future.wait(futures);
  }

  Future getKeystore(String? address) async {
    if (address == null || address.isEmpty) {
      return null;
    }
    var keystore;
    if (Platform.isAndroid) {
      keystore = await _localStorage.get('$KEY_KEYSTORE:$address');
    } else {
      keystore = await _secureStorage.get('$KEY_KEYSTORE:$address');
    }
    // SUPPORT:START
    if (keystore == null || keystore.isEmpty) {
      keystore = await _secureStorage.get('NKN_KEYSTORES:$address');
      if (keystore == null || keystore.isEmpty) {
        if (Platform.isAndroid) {
          keystore = await _localStorage.get('WALLET_KEYSTORE_ENCRYPT_VALUE_$address');
        }
      }
      // sync wallet_add
      if (keystore != null && keystore.isNotEmpty) {
        if (Platform.isAndroid) {
          await _localStorage.set('$KEY_KEYSTORE:$address', keystore);
        } else {
          await _secureStorage.set('$KEY_KEYSTORE:$address', keystore);
        }
      }
    }
    // SUPPORT:END
    return keystore;
  }

  Future getPassword(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _secureStorage.get('$KEY_PASSWORD:$address');
  }

  Future setBackup(String? address, bool backup) async {
    if (address == null || address.isEmpty) return null;
    return Future(() => _localStorage.set('$KEY_BACKUP:$address', backup));
  }

  Future isBackupByAddress(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _localStorage.get('$KEY_BACKUP:$address');
  }

  Future setDefaultAddress(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _localStorage.set('$KEY_DEFAULT_ADDRESS', address);
  }

  Future<String?> getDefaultAddress() async {
    String? address = await _localStorage.get('$KEY_DEFAULT_ADDRESS');
    if (address == null || !verifyAddress(address)) {
      List<WalletSchema> wallets = await getWallets();
      if (wallets.isEmpty) {
        return null;
      }
      String? firstAddress = wallets[0].address;
      if (!verifyAddress(firstAddress)) {
        return null;
      }
      await setDefaultAddress(firstAddress);
      return firstAddress;
    }
    return address;
  }
}
