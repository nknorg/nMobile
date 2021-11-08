import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

class TaskService with Tag {
  static const KEY_WALLET_BALANCE = "wallet_balance";
  static const KEY_RPC_REFRESH = "rpc_refresh";
  static const KEY_NONCE_REFRESH = "nonce_refresh";
  static const KEY_SUBSCRIBE_CHECK = "subscribe_check";
  static const KEY_PERMISSION_CHECK = "permission_check";
  static const KEY_CLIENT_CONNECT = "client_connect";
  static const KEY_TOPIC_CHECK = "topic_check";
  static const KEY_MSG_BURNING = "message_burning"; // FUTURE:burning

  Timer? _timer1;
  Map<String, Function(String)> tasks1 = Map<String, Function(String)>();

  Timer? _timer30;
  Map<String, Function(String)> tasks30 = Map<String, Function(String)>();

  Timer? _timer60;
  Map<String, Function(String)> tasks60 = Map<String, Function(String)>();

  Timer? _timer300;
  Map<String, Function(String)> _tasks300 = Map<String, Function(String)>();

  Lock _lock = Lock();

  TaskService();

  init({bool isFirst = true}) {
    // listen
    if (isFirst) {
      application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
        if (application.isFromBackground(states)) {
          uninstall();
          init(isFirst: false);
        } else if (application.isGoBackground(states)) {
          uninstall();
        }
      });
    }
    logger.d("$Tag - init");

    // timer 1s
    _timer1 = _timer1 ??
        Timer.periodic(Duration(seconds: 1), (timer) async {
          if (application.inBackGround && Platform.isIOS) return;
          tasks1.keys.forEach((String key) {
            // logger.d("$Tag - tick_1 - key:$key");
            if (application.inBackGround && Platform.isIOS) return;
            tasks1[key]?.call(key);
          });
        });

    // timer 30s
    _timer30 = _timer30 ??
        Timer.periodic(Duration(seconds: 30), (timer) {
          if (application.inBackGround && Platform.isIOS) return;
          tasks30.keys.forEach((String key) {
            // logger.d("$Tag - tick_30 - key:$key");
            if (application.inBackGround && Platform.isIOS) return;
            tasks30[key]?.call(key);
          });
        });

    // timer 60s
    _timer60 = _timer60 ??
        Timer.periodic(Duration(seconds: 60), (timer) {
          if (application.inBackGround && Platform.isIOS) return;
          tasks60.keys.forEach((String key) {
            // logger.d("$Tag - tick_60 - key:$key");
            if (application.inBackGround && Platform.isIOS) return;
            tasks60[key]?.call(key);
          });
        });

    // timer 300s
    _timer300 = _timer300 ??
        Timer.periodic(Duration(seconds: 300), (timer) {
          if (application.inBackGround && Platform.isIOS) return;
          _tasks300.keys.forEach((String key) {
            // logger.d("$Tag - tick_300 - key:$key");
            if (application.inBackGround && Platform.isIOS) return;
            _tasks300[key]?.call(key);
          });
        });

    // immediate
    addTask300(KEY_RPC_REFRESH, (key) => Global.getSeedRpcList(null, measure: true, delayMs: 500), callNow: true);
    addTask300(KEY_NONCE_REFRESH, (key) => Global.refreshNonce(delayMs: 1000), callNow: true);
    addTask60(KEY_WALLET_BALANCE, (key) => walletCommon.queryBalance(delayMs: 1500), callNow: true);
    addTask30(KEY_SUBSCRIBE_CHECK, (key) => topicCommon.checkAndTryAllSubscribe(delayMs: 5000), callNow: true);
    addTask30(KEY_PERMISSION_CHECK, (key) => topicCommon.checkAndTryAllPermission(delayMs: 7000), callNow: true);

    // delay
    addTask60(KEY_CLIENT_CONNECT, (key) => clientCommon.connectCheck(), callNow: false);
    // addTask60(KEY_MSG_FAIL_CHECK, (key) => chatCommon.checkSendingWithFail(), callNow: false);
    addTask300(KEY_TOPIC_CHECK, (key) => topicCommon.checkAllTopics(refreshSubscribers: false), callNow: false);
  }

  uninstall() {
    _timer1?.cancel();
    _timer1 = null;
    _timer30?.cancel();
    _timer30 = null;
    _timer60?.cancel();
    _timer60 = null;
    _timer300?.cancel();
    _timer300 = null;
    logger.d("$Tag - uninstall");
  }

  bool isTask1Run(String key) {
    return tasks1[key] != null;
  }

  void addTask1(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask1 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _lock.synchronized(() {
      tasks1[key] = func;
    });
  }

  void removeTask1(String key) {
    _lock.synchronized(() {
      if (!tasks1.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      tasks1.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      tasks1 = temp;
    });
  }

  bool isTask30Run(String key) {
    return tasks30[key] != null;
  }

  void addTask30(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask30 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _lock.synchronized(() {
      tasks30[key] = func;
    });
  }

  void removeTask30(String key) {
    _lock.synchronized(() {
      if (!tasks30.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      tasks30.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      tasks30 = temp;
    });
  }

  bool isTask60Run(String key) {
    return tasks60[key] != null;
  }

  void addTask60(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask60 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _lock.synchronized(() {
      tasks60[key] = func;
    });
  }

  void removeTask60(String key) {
    _lock.synchronized(() {
      if (!tasks60.keys.contains(key)) return;
      Map<String, Function(String)> temp = Map();
      tasks60.forEach((k, v) {
        if (k != key) {
          temp[k] = v;
        }
      });
      tasks60 = temp;
    });
  }

  bool isTask300Run(String key) {
    return _tasks300[key] != null;
  }

  void addTask300(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask300 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _lock.synchronized(() {
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
