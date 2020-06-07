import 'package:flutter/services.dart';

class ApkInstallerPlugin {
  final MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/installApk');
  final EventChannel _eventChannel = EventChannel('org.nkn.sdk/installApk/event');

  ApkInstallerPlugin.ins();

  void installApk(String path) async {
    _eventChannel.receiveBroadcastStream().listen((event) {});
    try {
      await _methodChannel.invokeMethod('installApk', {'apk_file_path': path});
    } catch (e) {
      throw e;
    }
  }
}
