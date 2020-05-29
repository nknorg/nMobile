import 'package:flutter/services.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:oktoast/oktoast.dart';

class CopyUtils {
  static void copyAction(context, String content) {
    Clipboard.setData(ClipboardData(text: content));
    showToast(NMobileLocalizations.of(context).copy_success);
  }
}
