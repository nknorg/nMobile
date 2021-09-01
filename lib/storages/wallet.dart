import 'dart:async';
import 'dart:io';

import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class WalletStorage with Tag {
  static const String KEY_WALLET = 'WALLETS';
  static const String KEY_PUBKEY = 'PUBKEYS';
  static const String KEY_KEYSTORE = 'KEYSTORES';
  static const String KEY_PASSWORD = 'PASSWORDS';
  static const String KEY_SEEDS = 'SEEDS';
  static const String KEY_DEFAULT_ADDRESS = 'default_d_chat_wallet_address';

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  Future add(WalletSchema wallet, String keystore, String password, String seed) async {
    List<Future> futures = <Future>[];
    // index
    List<WalletSchema> wallets = await getAll();
    int index = wallets.indexWhere((w) => w.address == wallet.address);
    if (index < 0) {
      futures.add(_localStorage.addItem(KEY_WALLET, wallet.toMap()));
    } else {
      futures.add(_localStorage.setItem(KEY_WALLET, index, wallet.toMap()));
    }
    // keystore
    if (Platform.isAndroid) {
      futures.add(_localStorage.set('$KEY_KEYSTORE:${wallet.address}', keystore));
    } else {
      futures.add(_secureStorage.set('$KEY_KEYSTORE:${wallet.address}', keystore));
    }
    // password
    futures.add(_secureStorage.set('$KEY_PASSWORD:${wallet.address}', password));
    // seed
    futures.add(_secureStorage.set('$KEY_SEEDS:${wallet.address}', seed));
    await Future.wait(futures);

    logger.v("$TAG - add - index:$index - wallet:$wallet - keystore:$keystore - password:$password");
    return;
  }

  Future delete(int index, String? address) async {
    List<Future> futures = <Future>[];
    if (index >= 0) {
      futures.add(_localStorage.removeItem(KEY_WALLET, index));
      // keystore
      if (Platform.isAndroid) {
        futures.add(_localStorage.remove('$KEY_KEYSTORE:$address'));
      } else {
        futures.add(_secureStorage.delete('$KEY_KEYSTORE:$address'));
      }
      // pwd + seed
      futures.add(_secureStorage.delete('$KEY_PASSWORD:$address'));
      futures.add(_secureStorage.delete('$KEY_SEEDS:$address'));
      // default
      if (await getDefaultAddress() == address) {
        futures.add(_localStorage.remove('$KEY_DEFAULT_ADDRESS'));
      }
    }
    await Future.wait(futures);

    logger.v("$TAG - delete - index:$index - address:$address");
    return;
  }

  Future update(int index, WalletSchema wallet, {String? keystore, String? password, String? seed}) async {
    List<Future> futures = <Future>[];
    if (index >= 0) {
      futures.add(_localStorage.setItem(KEY_WALLET, index, wallet.toMap()));
      // keystore
      if (keystore != null && keystore.isNotEmpty) {
        if (Platform.isAndroid) {
          futures.add(_localStorage.set('$KEY_KEYSTORE:${wallet.address}', keystore));
        } else {
          futures.add(_secureStorage.set('$KEY_KEYSTORE:${wallet.address}', keystore));
        }
      }
      // password
      if (password != null && password.isNotEmpty) {
        futures.add(_secureStorage.set('$KEY_PASSWORD:${wallet.address}', password));
      }
      // seed
      if (seed != null && seed.isNotEmpty) {
        futures.add(_secureStorage.set('$KEY_SEEDS:${wallet.address}', seed));
      }
    }
    await Future.wait(futures);

    logger.v("$TAG - update - index:$index - wallet:$wallet - keystore:$keystore - password:$password");
    return;
  }

  Future<List<WalletSchema>> getAll() async {
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
    logger.i("$TAG - getWallets - wallets == []");
    return [];
  }

  Future getKeystore(String? address) async {
    if (address == null || address.isEmpty) return null;
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

  Future getSeed(String? address) async {
    if (address == null || address.isEmpty) return null;
    return _secureStorage.get('$KEY_SEEDS:$address');
  }

  // default
  Future setDefaultAddress(String? address) async {
    if (address == null || address.isEmpty) return null;
    logger.v("$TAG - setDefaultAddress - address:$address");
    return _localStorage.set('$KEY_DEFAULT_ADDRESS', address);
  }

  Future<String?> getDefaultAddress() async {
    String? address = await _localStorage.get('$KEY_DEFAULT_ADDRESS');
    // if (address == null || !verifyNknAddress(address)) {
    //   List<WalletSchema> wallets = await getAll();
    //   if (wallets.isEmpty) {
    //     logger.w("$TAG - getDefaultAddress - wallets.isEmpty");
    //     return null;
    //   }
    //   String firstAddress = wallets[0].address;
    //   if (firstAddress.isNotEmpty && !verifyNknAddress(firstAddress)) {
    //     logger.w("$TAG - getDefaultAddress - address error");
    //     return null;
    //   }
    //   await setDefaultAddress(firstAddress);
    //   logger.i("$TAG - getDefaultAddress - default - address:$address");
    //   return firstAddress;
    // }
    logger.v("$TAG - getDefaultAddress - address:$address");
    return address;
  }
}
