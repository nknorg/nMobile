import 'dart:io';

import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

class Badge {
  static Lock _lock = Lock();

  static bool? isEnable;
  static int _currentCount = 0;

  static Future<bool> checkEnable() async {
    if (isEnable != null) return isEnable!;
    isEnable = Platform.isIOS;
    logger.d("Badge - checkEnable - isEnable:$isEnable");
    return isEnable!;
  }

  static Future refreshCount({int count = 0}) async {
    if (!(await checkEnable())) return;
    await _lock.synchronized(() async {
      _currentCount = count;
      logger.d("Badge - refreshCount - currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future onCountUp(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    await _lock.synchronized(() async {
      _currentCount += count;
      logger.d("Badge - onCountUp - up:$count - currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future onCountDown(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    await _lock.synchronized(() async {
      _currentCount -= count;
      logger.d("Badge - onCountDown - down:$count currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future _updateCount(int count) async {
    if (!(await checkEnable())) return;
    logger.d("Badge - updateCount - count:$count");
    await Common.updateBadgeCount(count);
  }
}
