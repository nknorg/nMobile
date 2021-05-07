import 'package:bot_toast/bot_toast.dart';

class Toast {
  static show(String text) {
    BotToast.showText(text: text);
  }
}
