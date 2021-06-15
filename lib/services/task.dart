import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';

class TaskService with Tag {
  bool _isInit = false;

  Timer? _timer1;
  Map<String, Function> tasks1 = Map<String, Function>();

  Timer? _timer60;
  Map<String, Function> tasks60 = Map<String, Function>();

  // TODO:GG backgroundModalChange

  install() {
    if (!_isInit) {
      // timer 1
      _timer1 = Timer.periodic(Duration(seconds: 1), (timer) async {
        tasks1.keys.forEach((String key) {
          // logger.d("TickHelper - tick");
          tasks1[key]?.call();
        });
      });

      // timer 60
      _timer60 = Timer.periodic(Duration(seconds: 60), (timer) {
        tasks60.keys.forEach((String key) {
          // logger.d("TickHelper - tick");
          tasks60[key]?.call();
        });
      });

      // task
      addTask60("wallet_balance", walletCommon.queryBalance, callNow: true);

      _isInit = true;
    }
  }

  uninstall() {
    _timer1?.cancel();
    _timer60?.cancel();
  }

  void addTask1(String key, Function func, {bool callNow = true}) {
    if (callNow) func.call();
    tasks1[key] = func;
  }

  void removeTask1(String key) {
    tasks1.remove(key);
  }

  void addTask60(String key, Function func, {bool callNow = true}) {
    if (callNow) func.call();
    tasks60[key] = func;
  }

  void removeTask60(String key) {
    tasks60.remove(key);
  }
}
