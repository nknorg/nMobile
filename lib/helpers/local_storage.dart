import 'dart:async';
import 'dart:convert';

import 'package:flustars/flustars.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_aes_ecb_pkcs5/flutter_aes_ecb_pkcs5.dart';

class LocalStorage {
  static const String NKN_WALLET_KEY = 'WALLETS';
  static const String SETTINGS_KEY = 'SETTINGS';
  static const String LENGTH_SUFFIX = 'length';

  static const String preAuthTime = 'preAuthTime';

  static const String LOCALE_KEY = 'locale';
  static const String LOCAL_NOTIFICATION_TYPE_KEY = 'local_notification_type';
  static const String AUTH_KEY = 'auth';
  static const String DEBUG_KEY = 'debug';

  static const String NEWS_BANNER = 'NEWS_BANNER';
  static const String NEWS_LIST = 'NEWS_LIST';

  static const String WALLET_TIP_STATUS = 'WALLET_TIP_STATUS';
  static const String CHAT_UNSEND_CONTENT = 'CHAT_UNSEND_CONTENT';
  static const String RN_WALLET_UPGRADED = 'RN_WALLET_UPGRADED';

  static const String UN_SUBSCRIBE_LIST = 'UN_SUBSCRIBE_LIST';
  static const String DEFAULT_D_CHAT_WALLET_ADDRESS =
      'default_d_chat_wallet_address';

  static const String WALLET_KEYSTORE_ENCRYPT_VALUE =
      'WALLET_KEYSTORE_ENCRYPT_VALUE';
  static const String WALLET_KEYSTORE_ENCRYPT_SKEY =
      'WALLET_KEYSTORE_AESVALUE_KEY';
  static const String WALLET_KEYSTORE_ENCRYPT_IV = 'WALLET_KEYSTORE_ENCRYPT_IV';

  static const String WALLET_KEYSTORE_AES_FILENAME = '/keystore.aes';

  static const String NKN_RPC_NODE_LIST = 'NKN_RPC_NODE_LIST';

  static const String NKN_MESSAGE_NOTIFICATION_ALERT =
      'NKN_MESSAGE_NOTIFICATION_ALERT';

  static const String NKN_ONE_PIECE_READY_JUDGE = 'NKN_ONE_PIECE_READY_JUDGE';

  static const String NKN_USER_PROFILE_VERSION_RESPONSE_TIME =
      'NKN_USER_PROFILE_VERSION_KEY';

  set(String key, val) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (val == null) {
      await prefs.setString(key, val);
    } else if (val is String) {
      await prefs.setString(key, val);
    } else if (val is int) {
      await prefs.setInt(key, val);
    } else if (val is bool) {
      await prefs.setBool(key, val);
    } else if (val is Map) {
      await prefs.setString(key, jsonEncode(val));
    }
  }

  saveKeyStoreInFile(String address, String keyStore) async {
    String addressKey = '$WALLET_KEYSTORE_ENCRYPT_VALUE' + '_' + address;
    set(addressKey, keyStore);

    if (keyStore != null && addressKey != null) {
      NLog.w('save Keystore to Local__' + addressKey + '___' + keyStore);
    } else {
      showToast('keyStore is null');
    }
  }

  // saveValueEncryptByKey(String encodeValue,String key) async {
  //   if (encodeValue == null || encodeValue.length == 0){
  //     return;
  //   }
  //   var randomKey = await FlutterAesEcbPkcs5.generateDesKey(128);
  //   print('randomKey is'+randomKey);
  //   set(WALLET_KEYSTORE_ENCRYPT_SKEY, randomKey);
  //   if (key.length > 0 || key.length < 32){
  //     randomKey = randomKey.substring(key.length)+key;
  //   }
  //   print('save Encrypt Value'+randomKey);
  //   var encryptString = await FlutterAesEcbPkcs5.encryptString(encodeValue, randomKey);
  //   print('save Encrypt Value'+encryptString);
  //   set(WALLET_KEYSTORE_ENCRYPT_VALUE, encryptString);
  // }

  Future<String> getValueDecryptByKey(String key, String address) async {
    String decryptKey = await get(WALLET_KEYSTORE_ENCRYPT_SKEY);
    if (decryptKey == null || decryptKey.length == 0) {
      return '';
    }
    if (key.length > 0 || key.length < 32 && decryptKey.length == 32) {
      decryptKey = decryptKey.substring(key.length) + key;
    }
    String decodedValue = await get(WALLET_KEYSTORE_ENCRYPT_VALUE);
    if (decodedValue == null || decodedValue.length == 0) {
      String addressKey = '$WALLET_KEYSTORE_ENCRYPT_VALUE' + '_' + address;
      decodedValue = await get(addressKey);
      if (decodedValue == null || decodedValue.length == 0) {
        return '';
      }
    }
    print('解密中' + decodedValue);
    print('解密中' + decryptKey);
    String decryptValue =
        await FlutterAesEcbPkcs5.decryptString(decodedValue, decryptKey);
    if (decryptValue == null || decryptValue.length == 0) {
      return '';
    }
    print('解密成功' + decryptValue);
    return decryptValue;
  }

  Future<String> getKeyStoreValue(String address) async {
    String addressKey = '$WALLET_KEYSTORE_ENCRYPT_VALUE' + '_' + address;
    String keyStore = await get(addressKey);
    if (keyStore == null) {
      // keyStore = await get(WALLET_KEYSTORE_ENCRYPT_VALUE);
      if (keyStore == null) {
        NLog.w('getKeyStoreValue is null');
      }
    } else {
      NLog.w('getKeyStoreValue is not null');
    }
    return keyStore;
  }

  Future<dynamic> get(key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.get(key);
  }

  remove(key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  clear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  getKeys() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getKeys();
  }

  Future<int> getArrayLength(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var val = prefs.get('$key:$LENGTH_SUFFIX');
    if (val == null) {
      return 0;
    }
    return val;
  }

  Future<Map<String, dynamic>> getItem(String key, int n) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var result = prefs.get('$key:$n');
    if (result == null) return null;
    return jsonDecode(prefs.get('$key:$n'));
  }

  Future<List<Map<String, dynamic>>> getArray(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var length = prefs.get('$key:$LENGTH_SUFFIX');
    if (length == null) return null;

    List<Map<String, dynamic>> res = [];
    for (var i = 0; i < length; i++) {
      res.add(await getItem(key, i));
    }
    return res;
  }

  setArray(String key, List<String> val) async {
    List<Future> futures = <Future>[];
    futures.add(set('$key:$LENGTH_SUFFIX', val.length.toString()));
    val.map((v) {
      futures.add(set('$key:$v', v));
    });
    await Future.wait(futures);
  }

  setItem(String key, int n, val) async {
    int length = await getArrayLength(key);
    if (n >= length) {
      throw RangeError('n is out index: ${length - 1}');
    }
    await set('$key:$n', val);
  }

  addItem(String key, val) async {
    List<Future> futures = <Future>[];
    int length = await getArrayLength(key);
    futures.add(set('$key:$LENGTH_SUFFIX', length + 1));
    futures.add(set('$key:$length', val));
    await Future.wait(futures);
  }

  removeItem(String key, int n) async {
    List<Future> futures = <Future>[];
    int length = await getArrayLength(key);
    futures.add(set('$key:$LENGTH_SUFFIX', length - 1));

    for (var i = n; i < length - 1; i++) {
      var item = await getItem('$key', i + 1);
      futures.add(set('$key:$n', item));
    }
    futures.add(remove('$key:${length - 1}'));

    await Future.wait(futures);
  }

  static String getChatUnSendContentFromId(String accountPubkey, String to) {
    return SpUtil.getString(to + accountPubkey);
  }

  static saveChatUnSendContentWithId(String accountPubkey, String to,
      {String content}) async {
    if (to.length == 0) return;
    if (content == null || content.length == 0) {
      SpUtil.remove(to + accountPubkey);
    }
    SpUtil.putString(to + accountPubkey, content);
  }
}
