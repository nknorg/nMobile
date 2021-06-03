import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

class Common {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.mobile/native/common');

  static install() {}

  static Future<bool> backDesktop() async {
    try {
      await _methodChannel.invokeMethod('backDesktop');
    } catch (e) {
      logger.e(e);
    }
    return false;
  }

  static Future<List<Object?>> splitPieces(String dataBytesString, int dataShards, int parityShards) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('splitPieces', {
        'data': dataBytesString,
        'dataShards': dataShards,
        'parityShards': parityShards,
      });
      return resp['data'] ?? [];
    } catch (e) {
      throw e;
    }
  }

  static Future<String?> combinePieces(List<Uint8List> dataList, int dataShards, int parityShards, int bytesLength) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('combinePieces', {
        'data': dataList,
        'dataShards': dataShards,
        'parityShards': parityShards,
        'bytesLength': bytesLength,
      });
      return resp['data'];
    } catch (e) {
      throw e;
    }
  }
}
