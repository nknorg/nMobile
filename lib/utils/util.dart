import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:url_launcher/url_launcher.dart';

class Util {
  static void copyText(String? content, {bool toast = true}) {
    Clipboard.setData(ClipboardData(text: content));
    if (toast) Toast.show(Global.locale((s) => s.copy_success));
  }

  static void launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await launch(url, forceSafariVC: false);
    } catch (e) {
      throw e;
    }
  }

  static Map<String, dynamic>? jsonFormat(raw) {
    Map<String, dynamic>? jsonData;
    try {
      jsonData = jsonDecode(raw);
    } on Exception catch (e) {
      handleError(e);
    }
    return jsonData;
  }

  static num? getNumByValueDouble(double? value, int fractionDigits) {
    if (value == null) return null;
    String valueStr = value.toStringAsFixed(fractionDigits);
    return fractionDigits == 0 ? int.tryParse(valueStr) : double.tryParse(valueStr);
  }
}
