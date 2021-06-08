import 'package:bot_toast/bot_toast.dart';

class Loading {
  static CancelFunc show() {
    return BotToast.showLoading();
  }

  static void dismiss() {
    BotToast.closeAllLoading();
  }
}
