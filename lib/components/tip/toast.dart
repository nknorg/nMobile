import 'package:bot_toast/bot_toast.dart';

class Toast {
  static show(String? text) {
    if (text == null || text.isEmpty) return;
    BotToast.showText(text: text);
  }
}
