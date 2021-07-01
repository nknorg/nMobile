import 'dart:io';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';

class Badge {
  static int _count = 0;

  static Future refreshCount({int? count}) async {
    if (!Platform.isIOS) return;
    int num = count ?? (await chatCommon.unreadCount());
    logger.d("Badge - refreshCount - $num");
    await updateCount(num);
  }

  static Future onCountUp(int count) async {
    if (!Platform.isIOS) return;
    _count += count;
    logger.d("Badge - onCountUp - $_count");
    updateCount(_count);
  }

  static Future onCountDown(int count) async {
    if (!Platform.isIOS) return;
    _count -= count;
    logger.d("Badge - onCountDown - $_count");
    updateCount(_count);
  }

  static Future updateCount(int count) async {
    if (!Platform.isIOS) return _count = count;
    logger.d("Badge - updateCount - $count");
    await Common.updateBadgeCount(_count);
  }
}
