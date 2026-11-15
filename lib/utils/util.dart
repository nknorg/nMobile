import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

class Util {
  /// Dismiss soft keyboard with focus unfocus + platform IME hide as fallback.
  /// Some Android/iOS builds leave the IME up after [FocusNode.unfocus] alone.
  static void hideKeyboard([BuildContext? context]) {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.hasFocus) {
      primary.unfocus();
    } else if (context != null && context.mounted) {
      FocusScope.of(context).unfocus();
    }
    try {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (e) {
      logger.e("Util - hideKeyboard ---> $e");
    }
  }

  static void copyText(String? content, {bool toast = true}) {
    if (content == null || content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: content));
    if (toast) Toast.show(Settings.locale((s) => s.copy_success));
  }

  static void launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final Uri _uri = Uri.parse(url);
      await UrlLauncher.launchUrl(_uri);
    } catch (e) {
      logger.e("Util - launchUrl ---> $e");
    }
  }

  static Future launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final Uri _uri = Uri.file(filePath);
      if (await File(_uri.toFilePath()).exists()) {
        await UrlLauncher.launchUrl(_uri);
      } else {
        logger.e("Util - launchFile ---> file not exist");
      }
    } catch (e) {
      logger.e("Util - launchFile ---> $e");
    }
  }

  static Map<String, dynamic>? jsonFormatMap(raw) {
    Map<String, dynamic>? jsonData;
    try {
      jsonData = jsonDecode(raw);
    } on Exception catch (e) {
      logger.e("Util - jsonFormat ---> $e");
    }
    return jsonData;
  }

  static List? jsonFormatList(raw) {
    List? jsonData;
    try {
      jsonData = jsonDecode(raw);
    } on Exception catch (e) {
      logger.e("Util - jsonFormat ---> $e");
    }
    return jsonData;
  }

  static num? getNumByValueDouble(double? value, int fractionDigits) {
    if (value == null) return null;
    String valueStr = value.toStringAsFixed(fractionDigits);
    return fractionDigits == 0 ? int.tryParse(valueStr) : double.tryParse(valueStr);
  }
}
