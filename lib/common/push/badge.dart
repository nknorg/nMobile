import 'dart:io';

import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class Badge {
  static bool? isEnable;
  static int _currentCount = 0;

  static ParallelQueue _queue = ParallelQueue("badge", onLog: (log, error) => error ? logger.w(log) : null);

  static Future<bool> checkEnable() async {
    if (isEnable != null) return isEnable!;
    isEnable = Platform.isIOS;
    logger.d("Badge - checkEnable - isEnable:$isEnable");
    return isEnable!;
  }

  static Future refreshCount({int count = 0}) async {
    if (!(await checkEnable())) return;
    _queue.add(() async {
      _currentCount = count;
      logger.i("Badge - refreshCount - currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future onCountUp(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    _queue.add(() async {
      _currentCount += count;
      logger.i("Badge - onCountUp - up:$count - currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future onCountDown(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    _queue.add(() async {
      _currentCount -= count;
      logger.i("Badge - onCountDown - down:$count currentCount:$_currentCount");
      await _updateCount(_currentCount);
    });
  }

  static Future _updateCount(int count) async {
    if (!(await checkEnable())) return;
    logger.d("Badge - updateCount - count:$count");
    if (count < 0) {
      _currentCount = 0;
      count = 0;
    }
    await Common.updateBadgeCount(count);
  }
}
