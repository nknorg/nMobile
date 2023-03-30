import 'dart:io';

import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class Badge {
  static bool? isEnable;
  static int _count = 0;

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
      _count = count;
      logger.d("Badge - refreshCount - count:$_count");
      await _updateCount();
    });
  }

  static Future onCountUp(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    _queue.add(() async {
      _count += count;
      logger.d("Badge - onCountUp - up:$count - count:$_count");
      await _updateCount();
    });
  }

  static Future onCountDown(int count) async {
    if (count == 0) return;
    if (!(await checkEnable())) return;
    _queue.add(() async {
      _count -= count;
      logger.d("Badge - onCountDown - down:$count - count:$_count");
      await _updateCount();
    });
  }

  static Future _updateCount() async {
    if (!(await checkEnable())) return;
    if (_count < 0) _count = 0;
    await Common.updateBadgeCount(_count);
  }
}
