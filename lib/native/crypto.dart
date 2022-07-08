import 'dart:typed_data';

import 'package:flutter/services.dart';

class Crypto {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.mobile/native/crypto_method');
  static const EventChannel _eventChannel = EventChannel('org.nkn.mobile/native/crypto_event');

  static install() {}

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
}
