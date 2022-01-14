import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

class TaskService {
  static const KEY_WALLET_BALANCE = "wallet_balance";
  static const KEY_RPC_REFRESH = "rpc_refresh";
  static const KEY_NONCE_REFRESH = "nonce_refresh";
  static const KEY_SUBSCRIBE_CHECK = "subscribe_check";
  static const KEY_PERMISSION_CHECK = "permission_check";
  static const KEY_CLIENT_CONNECT = "client_connect";
  static const KEY_TOPIC_CHECK = "topic_check";
  static const KEY_MSG_BURNING = "message_burning"; // FUTURE:burning

  Timer? _timer1;
  Map<String, Function(String)> _tasks1 = Map<String, Function(String)>();

  Timer? _timer30;
  Map<String, Function(String)> _tasks30 = Map<String, Function(String)>();

  Timer? _timer60;
  Map<String, Function(String)> _tasks60 = Map<String, Function(String)>();

  Timer? _timer300;
  Map<String, Function(String)> _tasks300 = Map<String, Function(String)>();

  Map<String, Timer> _delayMap = Map<String, Timer>();

  Lock _lock = Lock();

  TaskService();

  init() {
    application.appLifeStream.listen((List<AppLifecycleState> states) {
      if (application.isFromBackground(states)) {
        uninstall();
        install();
      } else if (application.isGoBackground(states)) {
        uninstall();
      }
    });

    install();
  }

  install() {
    // timer 1s
    _timer1 = _timer1 ??
        Timer.periodic(Duration(seconds: 1), (timer) async {
          _tasks1.keys.forEach((String key) {
            // logger.d("TaskService - tick_1 - key:$key");
            if (application.inBackGround) return;
            _tasks1[key]?.call(key);
          });
        });

    // timer 30s
    _timer30 = _timer30 ??
        Timer.periodic(Duration(seconds: 30), (timer) {
          _tasks30.keys.forEach((String key) {
            logger.d("TaskService - tick_30 - key:$key");
            if (application.inBackGround) return;
            _tasks30[key]?.call(key);
          });
        });

    // timer 60s
    _timer60 = _timer60 ??
        Timer.periodic(Duration(seconds: 60), (timer) {
          _tasks60.keys.forEach((String key) {
            logger.d("TaskService - tick_60 - key:$key");
            if (application.inBackGround) return;
            _tasks60[key]?.call(key);
          });
        });

    // timer 300s
    _timer300 = _timer300 ??
        Timer.periodic(Duration(seconds: 300), (timer) {
          _tasks300.keys.forEach((String key) {
            logger.d("TaskService - tick_300 - key:$key");
            if (application.inBackGround) return;
            _tasks300[key]?.call(key);
          });
        });

    // immediate
    // addTask300(KEY_RPC_REFRESH, (key) => Global.getSeedRpcList(null, measure: true, delayMs: 500), callNow: true);
    addTask300(KEY_NONCE_REFRESH, (key) => Global.refreshNonce(), delayMs: 1000);
    addTask60(KEY_WALLET_BALANCE, (key) => walletCommon.queryBalance(), delayMs: 1000);
    // addTask30(KEY_SUBSCRIBE_CHECK, (key) => topicCommon.checkAndTryAllSubscribe(), delayMs: 2000);
    // addTask30(KEY_PERMISSION_CHECK, (key) => topicCommon.checkAndTryAllPermission(), delayMs: 3000);

    // delay
    // addTask60(KEY_MSG_FAIL_CHECK, (key) => chatCommon.checkSendingWithFail());
    addTask60(KEY_CLIENT_CONNECT, (key) => clientCommon.connectCheck(force: true));
    // addTask300(KEY_TOPIC_CHECK, (key) => topicCommon.checkAllTopics(refreshSubscribers: false));

    logger.d("TaskService - install");
  }

  uninstall() {
    // _tasks1.clear();
    // _tasks30.clear();
    // _tasks60.clear();
    // _tasks300.clear();

    _timer1?.cancel();
    _timer1 = null;
    _timer30?.cancel();
    _timer30 = null;
    _timer60?.cancel();
    _timer60 = null;
    _timer300?.cancel();
    _timer300 = null;

    _delayMap.keys.forEach((String key) {
      _delayMap[key]?.cancel();
    });
    // _delayMap.clear();

    logger.d("TaskService - uninstall");
  }

  bool isTask1Run(String key) {
    return _tasks1[key] != null;
  }

  void addTask1(String key, Function(String) func, {int? delayMs}) {
    logger.d("TaskService - addTask1 - key:$key - func:${func.toString()}");
    _lock.synchronized(() {
      if (delayMs == null) {
        // nothing
      } else if (delayMs == 0) {
        func.call(key);
      } else if (delayMs > 0) {
        _delayMap["1___$key"]?.cancel();
        _delayMap["1___$key"] = new Timer(Duration(milliseconds: delayMs), () {
          logger.i("TaskService - addTask1 - call by delay - key:$key - delayMs:$delayMs");
          if (application.inBackGround) return;
          func.call(key);
        });
      }
      _tasks1[key] = func;
    });
  }

  void removeTask1(String key) {
    _lock.synchronized(() {
      if (!_tasks1.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      _tasks1.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      _tasks1 = temp;
    });
  }

  bool isTask30Run(String key) {
    return _tasks30[key] != null;
  }

  void addTask30(String key, Function(String) func, {int? delayMs}) {
    logger.d("TaskService - addTask30 - key:$key - func:${func.toString()}");
    _lock.synchronized(() {
      if (delayMs == null) {
        // nothing
      } else if (delayMs == 0) {
        func.call(key);
      } else if (delayMs > 0) {
        _delayMap["30___$key"]?.cancel();
        _delayMap["30___$key"] = new Timer(Duration(milliseconds: delayMs), () {
          logger.i("TaskService - addTask30 - call by delay - key:$key - delayMs:$delayMs");
          if (application.inBackGround) return;
          func.call(key);
        });
      }
      _tasks30[key] = func;
    });
  }

  void removeTask30(String key) {
    _lock.synchronized(() {
      if (!_tasks30.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      _tasks30.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      _tasks30 = temp;
    });
  }

  bool isTask60Run(String key) {
    return _tasks60[key] != null;
  }

  void addTask60(String key, Function(String) func, {int? delayMs}) {
    logger.d("TaskService - addTask60 - key:$key - func:${func.toString()}");
    _lock.synchronized(() {
      if (delayMs == null) {
        // nothing
      } else if (delayMs == 0) {
        func.call(key);
      } else if (delayMs > 0) {
        _delayMap["60___$key"]?.cancel();
        _delayMap["60___$key"] = new Timer(Duration(milliseconds: delayMs), () {
          logger.i("TaskService - addTask60 - call by delay - key:$key - delayMs:$delayMs");
          if (application.inBackGround) return;
          func.call(key);
        });
      }
      _tasks60[key] = func;
    });
  }

  void removeTask60(String key) {
    _lock.synchronized(() {
      if (!_tasks60.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      _tasks60.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      _tasks60 = temp;
    });
  }

  bool isTask300Run(String key) {
    return _tasks300[key] != null;
  }

  void addTask300(String key, Function(String) func, {int? delayMs}) {
    logger.d("TaskService - addTask300 - key:$key - func:${func.toString()}");
    _lock.synchronized(() {
      if (delayMs == null) {
        // nothing
      } else if (delayMs == 0) {
        func.call(key);
      } else if (delayMs > 0) {
        _delayMap["300___$key"]?.cancel();
        _delayMap["300___$key"] = new Timer(Duration(milliseconds: delayMs), () {
          logger.i("TaskService - addTask300 - call by delay - key:$key - delayMs:$delayMs");
          if (application.inBackGround) return;
          func.call(key);
        });
      }
      _tasks300[key] = func;
    });
  }

  void removeTask300(String key) {
    _lock.synchronized(() {
      if (!_tasks300.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      _tasks300.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      _tasks300 = temp;
    });
  }
}
