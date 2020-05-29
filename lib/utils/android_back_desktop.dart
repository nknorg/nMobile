import 'package:flutter/services.dart';

class AndroidBackTop {
  static const String CHANNEL = "android/nmbile/native/common";
  static Future<bool> backToDesktop() async {
    final platform = MethodChannel(CHANNEL);
    try {
      await platform.invokeMethod('backDesktop');
    } on PlatformException catch (e) {
      print(e.toString());
    }
    return Future.value(false);
  }
}
