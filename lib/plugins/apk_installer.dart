import 'package:flutter/services.dart';

class ApkInstallerPlugin {
  final MethodChannel _methodChannel = MethodChannel('org.nkn.native.call/apk_installer');

  ApkInstallerPlugin.ins();

  void installApk(String path) async {
    try {
      await _methodChannel.invokeMethod('installApk', {'apk_file_path': path});
    } catch (e) {
      throw e;
    }
  }
}
