import 'dart:async';
import 'dart:io';

import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class WalletStorage with Tag {
  static const String KEY_WALLET = 'WALLETS';
  static const String KEY_KEYSTORE = 'KEYSTORES';
  static const String KEY_PASSWORD = 'PASSWORDS';
  static const String KEY_BACKUP = 'BACKUP';
  static const String KEY_DEFAULT_ADDRESS = 'WALLET_DEFAULT_ADDRESS'; // not support 'default_d_chat_wallet_address'

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  Future<List<WalletSchema>> getWallets() async {
    var wallets = await _localStorage.getArray(KEY_WALLET);
    if (wallets.isNotEmpty) {
      String logText = '';
      var list = wallets.map((e) {
        WalletSchema walletSchema = WalletSchema.fromMap(e);
        logText += "\n      $e";
        return walletSchema;
      }).toList();
      logger.v("$TAG - getWallets - wallets:$logText");
      return list;
    }
    logger.i("$TAG - getWallets - wallets.isNotEmpty");
    return [];
  }

  Future add(WalletSchema? schema, String? keystore, {String? password}) async {
    List<Future> futures = <Future>[];
    var wallets = await _localStorage.getArray(KEY_WALLET);
    int index = wallets.indexWhere((x) => x['address'] == schema?.address);
    if (index < 0) {
      futures.add(_localStorage.addItem(KEY_WALLET, schema?.toMap()));
    } else {
      futures.add(_localStorage.setItem(KEY_WALLET, index, schema?.toMap()));
    }
    if (keystore != null && keystore.isNotEmpty) {
      if (Platform.isAndroid) {
        futures.add(_localStorage.set('$KEY_KEYSTORE:${schema?.address}', keystore));
      } else {
        futures.add(_secureStorage.set('$KEY_KEYSTORE:${schema?.address}', keystore));
      }
    }
    if (password != null && password.isNotEmpty) {
      futures.add(_secureStorage.set('$KEY_PASSWORD:${schema?.address}', password));
    }
    // backup
    futures.add(_localStorage.set('$KEY_BACKUP:${schema?.address}', false));
    await Future.wait(futures);

    logger.v("$TAG - add - schema:$schema - keystore:$keystore - password:$password");
    return;
  }

  Future delete(int index, WalletSchema? schema) async {
    List<Future> futures = <Future>[];
    if (index >= 0) {
      futures.add(_localStorage.removeItem(KEY_WALLET, index));
      if (Platform.isAndroid) {
        futures.add(_localStorage.remove('$KEY_KEYSTORE:${schema?.address}'));
      } else {
        futures.add(_secureStorage.delete('$KEY_KEYSTORE:${schema?.address}'));
      }
      futures.add(_secureStorage.delete('$KEY_PASSWORD:${schema?.address}'));
      // backup + default
      futures.add(_localStorage.remove('$KEY_BACKUP:${schema?.address}'));
      if (await getDefaultAddress() == schema?.address) {
        futures.add(_localStorage.remove('$KEY_DEFAULT_ADDRESS'));
      }
    }
    await Future.wait(futures);

    logger.v("$TAG - delete - index:$index - schema:$schema");
    return;
  }

  Future update(int index, WalletSchema? schema, {String? keystore, String? password}) async {
    List<Future> futures = <Future>[];
    if (index >= 0) {
      futures.add(_localStorage.setItem(KEY_WALLET, index, schema?.toMap()));
      if (keystore != null && keystore.isNotEmpty) {
        if (Platform.isAndroid) {
          futures.add(_localStorage.set('$KEY_KEYSTORE:${schema?.address}', keystore));
        } else {
          futures.add(_secureStorage.set('$KEY_KEYSTORE:${schema?.address}', keystore));
        }
      }
      if (password != null && password.isNotEmpty) {
        futures.add(_secureStorage.set('$KEY_PASSWORD:${schema?.address}', password));
      }
    }
    await Future.wait(futures);

    logger.v("$TAG - update - index:$index - schema:$schema - keystore:$keystore - password:$password");
    return;
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
        // String? decryptKey = await _localStorage.get("WALLET_KEYSTORE_AESVALUE_KEY");
        // if (decryptKey?.isNotEmpty == true) {
        //   String? decodedValue = await _localStorage.get('WALLET_KEYSTORE_ENCRYPT_VALUE');
        //   if (decodedValue == null || decodedValue.isEmpty) {
        //     decodedValue = await _localStorage.get('WALLET_KEYSTORE_ENCRYPT_VALUE_$address');
        //   }
        //   if (decodedValue?.isNotEmpty == true) {
        //     keystore = await FlutterAesEcbPkcs5.decryptString(decodedValue, decryptKey);
        //   }
        // } else {
        keystore = await _localStorage.get('WALLET_KEYSTORE_ENCRYPT_VALUE_$address');
        // }
        logger.i("$TAG - getKeystore - from(NKN_KEYSTORES) - address:$address - keystore:$keystore");
      } else {
        logger.i("$TAG - getKeystore - from(WALLET_KEYSTORE_ENCRYPT_VALUE_) - address:$address - keystore:$keystore");
      }
      // sync wallet_add
      if (keystore != null && keystore.isNotEmpty) {
        if (Platform.isAndroid) {
          await _localStorage.set('$KEY_KEYSTORE:$address', keystore);
        } else {
          await _secureStorage.set('$KEY_KEYSTORE:$address', keystore);
        }
      } else {
        logger.w("$TAG - getKeystore - address:$address - keystore is empty");
      }
    }
    // SUPPORT:END
    logger.v("$TAG - getKeystore - address:$address - keystore:$keystore");
    return keystore;
  }

  Future getPassword(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _secureStorage.get('$KEY_PASSWORD:$address');
  }

  Future setBackup(String? address, bool backup) async {
    if (address == null || address.isEmpty) return null;
    logger.v("$TAG - setBackup - address:$address - backup:$backup");
    return Future(() => _localStorage.set('$KEY_BACKUP:$address', backup));
  }

  Future isBackupByAddress(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _localStorage.get('$KEY_BACKUP:$address');
  }

  Future setDefaultAddress(String? address) async {
    if (address == null || address.isEmpty) return null;
    logger.v("$TAG - setDefaultAddress - address:$address");
    return _localStorage.set('$KEY_DEFAULT_ADDRESS', address);
  }

  Future<String?> getDefaultAddress() async {
    String? address = await _localStorage.get('$KEY_DEFAULT_ADDRESS');
    if (address == null || !verifyNknAddress(address)) {
      List<WalletSchema> wallets = await getWallets();
      if (wallets.isEmpty) {
        logger.w("$TAG - getDefaultAddress - wallets.isEmpty");
        return null;
      }
      String? firstAddress = wallets[0].address;
      if (!verifyNknAddress(firstAddress)) {
        logger.w("$TAG - getDefaultAddress - !verifyAddress(firstAddress)");
        return null;
      }
      await setDefaultAddress(firstAddress);
      logger.i("$TAG - getDefaultAddress - default - address:$address");
      return firstAddress;
    }
    logger.v("$TAG - getDefaultAddress - address:$address");
    return address;
  }
}
