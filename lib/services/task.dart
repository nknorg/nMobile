import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';

class TaskService {
  static const KEY_WALLET_BALANCE = "wallet_balance";
  static const KEY_CLIENT_CONNECT = "client_connect";
  static const KEY_SUBSCRIBE_CHECK = "subscribe_check";
  static const KEY_PERMISSION_CHECK = "permission_check";
  static const KEY_MSG_BURNING_ = "message_burning_";

  ParallelQueue _queue = ParallelQueue("task_service", onLog: (log, error) => error ? logger.w(log) : null);

  Map<int, Timer> _timers = Map<int, Timer>();
  Map<int, Map<String, Function(String)>> _tasks = Map<int, Map<String, Function(String)>>();
  Map<int, Map<String, Function(String)>> _delays = Map<int, Map<String, Function(String)>>();

  TaskService();

  void addTask(String key, int sec, Function(String) func, {bool background = false, int? delayMs}) {
    _queue.add(() async {
      // timer
      if (_timers[sec] == null) {
        logger.i("TaskService - addTask - timer create - sec:$sec - key:$key - delayMs:$delayMs");
        _timers[sec] = Timer.periodic(Duration(seconds: sec), (timer) async {
          _tasks[sec]?.keys.forEach((String key) {
            if (!background && application.inBackGround) return;
            Function? _func = _tasks[sec]?[key];
            if (_func == null) {
              logger.w("TaskService - addTask - timer tick nil - sec:$sec - key:$key - delayMs:$delayMs");
              return;
            }
            // logger.v("TaskService - timer tick - sec:$sec - key:$key - delayMs:$delayMs");
            _func.call(key); // await
          });
        });
      }
      // task
      Function toTask = () {
        if (_tasks[sec] == null) {
          logger.i("TaskService - addTask - task create - sec:$sec - key:$key - delayMs:$delayMs");
          _tasks[sec] = Map<String, Function(String)>();
        }
        _tasks[sec]?[key] = func;
      };
      // delay
      if ((delayMs ?? 0) > 0) {
        if (_delays[sec] == null) {
          logger.i("TaskService - addTask - delay create - sec:$sec - key:$key - delayMs:$delayMs");
          _delays[sec] = Map<String, Function(String)>();
        }
        _delays[sec]?[key] = func;
        Future.delayed(Duration(milliseconds: delayMs ?? 0)).then((value) {
          if (!background && application.inBackGround) return;
          if (_delays[sec]?.keys.contains(key) != true) return;
          Function? _func = _delays[sec]?[key];
          if (_func == null) {
            logger.w("TaskService - addTask - delay tick nil - sec:$sec - key:$key - delayMs:$delayMs");
            return;
          }
          logger.i("TaskService - addTask - delay tick - sec:$sec - key:$key - delayMs:$delayMs");
          _func.call(key); // await
          _delays[sec]?.remove(key);
          toTask();
        });
      } else if (delayMs == 0) {
        func.call(key); // await
        toTask();
      } else {
        toTask();
      }
    }, id: key);
  }

  void removeTask(String key, int sec) {
    _queue.add(() async {
      if (_delays[sec]?.keys.contains(key) == true) {
        logger.d("TaskService - removeTask - delays start - sec:$sec - key:$key");
        // _delays[sec]?.removeWhere((k, v) => k == key);
        Map<String, Function(String)> temp = Map();
        _delays[sec]?.forEach((k, v) {
          if (k != key) {
            temp[k] = v;
          } else {
            logger.d("TaskService - removeTask - delays find - sec:$sec - key:$key");
          }
        });
        _delays[sec] = temp;
      }
      if (_tasks[sec]?.keys.contains(key) == true) {
        logger.d("TaskService - removeTask - tasks start - sec:$sec - key:$key");
        // _tasks[sec]?.removeWhere((k, v) => k == key);
        Map<String, Function(String)> temp = Map();
        _tasks[sec]?.forEach((k, v) {
          if (k != key) {
            temp[k] = v;
          } else {
            logger.d("TaskService - removeTask - tasks find - sec:$sec - key:$key");
          }
        });
        _tasks[sec] = temp;
      }
      if (((_tasks[sec]?.length ?? 0) <= 0) && (_delays[sec]?.length ?? 0) <= 0) {
        logger.d("TaskService - removeTask - timers start - sec:$sec - key:$key");
        // _timers.removeWhere((k, v) => k == sec);
        Map<int, Timer> temp = Map();
        _timers.forEach((k, v) {
          if (k != sec) {
            temp[k] = v;
          } else {
            logger.d("TaskService - removeTask - timers find - sec:$sec - key:$key");
          }
        });
        _timers = temp;
      }
      // log
      // String timerKeys = _timers.keys.join(",");
      // String? taskKeys;
      // _tasks.forEach((key, value) {
      //   String secKeys = value.keys.join("/");
      //   if (secKeys.isNotEmpty) taskKeys = (taskKeys ?? "") + secKeys + ",";
      // });
      // String? delayKeys;
      // _delays.forEach((key, value) {
      //   String secKeys = value.keys.join("/");
      //   if (secKeys.isNotEmpty) delayKeys = (delayKeys ?? "") + secKeys + ",";
      // });
      // logger.i("TaskService - exists\n - timerKeys:$timerKeys\n - taskKeys:$taskKeys\n - delayKeys:$delayKeys");
    }, id: key);
  }

  bool isTaskRun(String key, int sec) {
    bool inDelays = _delays[sec]?.keys.contains(key) == true;
    bool inTask = _tasks[sec]?.keys.contains(key) == true;
    return inDelays || inTask;
  }
}
