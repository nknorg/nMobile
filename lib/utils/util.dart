import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

import 'logger.dart';

class Util {
  static void copyText(String? content, {bool toast = true}) {
    Clipboard.setData(ClipboardData(text: content));
    if (toast) Toast.show(Global.locale((s) => s.copy_success));
  }

  static void launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final Uri _uri = Uri.parse(url);
      await UrlLauncher.launchUrl(_uri);
    } catch (e) {
      logger.w("Util - launchUrl ---> $e");
    }
  }

  static Future launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final Uri _uri = Uri.file(filePath);
      if (await File(_uri.toFilePath()).exists()) {
        await UrlLauncher.launchUrl(_uri);
      } else {
        logger.w("Util - launchFile ---> file not exist");
      }
    } catch (e) {
      logger.w("Util - launchFile ---> $e");
    }
  }

  static Map<String, dynamic>? jsonFormat(raw) {
    Map<String, dynamic>? jsonData;
    try {
      jsonData = jsonDecode(raw);
    } on Exception catch (e) {
      logger.w("Util - jsonFormat ---> $e");
    }
    return jsonData;
  }

  static num? getNumByValueDouble(double? value, int fractionDigits) {
    if (value == null) return null;
    String valueStr = value.toStringAsFixed(fractionDigits);
    return fractionDigits == 0 ? int.tryParse(valueStr) : double.tryParse(valueStr);
  }
}
