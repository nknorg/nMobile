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
}
