import 'dart:io';

import 'package:flutter/services.dart';

class CommonNative {
  static Future<bool> isActive() async {
    String CHANNEL = Platform.isAndroid ? "android/nmobile/native/common" : "ios/nmobile/native/common";

    final platform = MethodChannel(CHANNEL);
    try {
      return await platform.invokeMethod('isActive');
    } on PlatformException catch (e) {
      return Future.value(false);
    }
  }
}
