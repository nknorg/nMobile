import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Crypto
class Crypto {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/crypto');

  /// [gcmEncrypt]
  static Future<Uint8List> gcmEncrypt(Uint8List data, Uint8List key, int nonceSize) async {
    try {
      return await _methodChannel.invokeMethod('gcmEncrypt', {
        'data': data,
        'key': key,
        'nonceSize': nonceSize,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [gcmDecrypt]
  static Future<Uint8List> gcmDecrypt(Uint8List data, Uint8List key, int nonceSize) async {
    try {
      return await _methodChannel.invokeMethod('gcmDecrypt', {
        'data': data,
        'key': key,
        'nonceSize': nonceSize,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getPublicKeyFromPrivateKey]
  static Future<Uint8List> getPublicKeyFromPrivateKey(Uint8List privateKey) async {
    try {
      return await _methodChannel.invokeMethod('getPublicKeyFromPrivateKey', {
        'privateKey': privateKey,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getPublicKeyFromPrivateKey]
  static Future<Uint8List> getPrivateKeyFromSeed(Uint8List seed) async {
    try {
      return await _methodChannel.invokeMethod('getPrivateKeyFromSeed', {
        'seed': seed,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getSeedFromPrivateKey]
  static Future<Uint8List> getSeedFromPrivateKey(Uint8List privateKey) async {
    try {
      return await _methodChannel.invokeMethod('getSeedFromPrivateKey', {
        'privateKey': privateKey,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [sign] signs the given message with priv
  static Future<Uint8List> sign(Uint8List privateKey, Uint8List data) async {
    try {
      return await _methodChannel.invokeMethod('sign', {
        'privateKey': privateKey,
        'data': data,
      });
    } catch (e) {
      throw e;
    }
  }

  /// [verify] reports whether sig is a valid signature of message by publicKey.
  static Future<bool> verify(Uint8List publicKey, Uint8List data, Uint8List signature) async {
    try {
      return await _methodChannel.invokeMethod('verify', {
        'publicKey': publicKey,
        'data': data,
        'signature': signature,
      });
    } catch (e) {
      throw e;
    }
  }
}
