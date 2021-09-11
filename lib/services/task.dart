import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';

class TaskService with Tag {
  static const KEY_WALLET_BALANCE = "wallet_balance";
  static const KEY_CLIENT_CONNECT = "client_connect";
  static const KEY_MSG_FAIL_CHECK = "msg_fail_check";
  static const KEY_RPC_REFRESH = "rpc_refresh";
  static const KEY_NONCE_REFRESH = "nonce_refresh";
  static const KEY_TOPIC_CHECK = "topic_check";
  static const KEY_MSG_BURNING = "message_burning";

  Timer? _timer1;
  Map<String, Function(String)> tasks1 = Map<String, Function(String)>();

  Timer? _timer60;
  Map<String, Function(String)> tasks60 = Map<String, Function(String)>();

  Timer? _timer600;
  Map<String, Function(String)> _tasks600 = Map<String, Function(String)>();

  TaskService();

  init({bool isFirst = true}) {
    // listen
    if (isFirst) {
      application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
        if (states.length > 0) {
          if (states[states.length - 1] == AppLifecycleState.resumed) {
            init(isFirst: false);
          } else if (states[1] == AppLifecycleState.paused) {
            uninstall();
          }
        }
      });
    }

    // timer 1s
    _timer1 = _timer1 ??
        Timer.periodic(Duration(seconds: 1), (timer) async {
          tasks1.keys.forEach((String key) {
            // logger.d("TickHelper - tick");
            tasks1[key]?.call(key);
          });
        });

    // timer 60s
    _timer60 = _timer60 ??
        Timer.periodic(Duration(seconds: 60), (timer) {
          tasks60.keys.forEach((String key) {
            // logger.d("TickHelper - tick");
            tasks60[key]?.call(key);
          });
        });

    // timer 600s
    _timer600 = _timer600 ??
        Timer.periodic(Duration(seconds: 600), (timer) {
          _tasks600.keys.forEach((String key) {
            // logger.d("TickHelper - tick");
            _tasks600[key]?.call(key);
          });
        });

    // task
    addTask60(KEY_WALLET_BALANCE, (key) => walletCommon.queryBalance(), callNow: true);
    addTask60(KEY_CLIENT_CONNECT, (key) => clientCommon.connectCheck(), callNow: false);
    addTask60(KEY_MSG_FAIL_CHECK, (key) => chatOutCommon.checkSending(), callNow: false);
    addTask600(KEY_RPC_REFRESH, (key) => Global.getSeedRpcList(null, measure: true), callNow: true);
    addTask600(KEY_NONCE_REFRESH, (key) => Global.refreshNonce(), callNow: true);
    addTask600(KEY_TOPIC_CHECK, (key) => topicCommon.checkAllTopics(), callNow: false);
  }

  uninstall() {
    _timer1?.cancel();
    _timer1 = null;
    _timer60?.cancel();
    _timer60 = null;
    _timer600?.cancel();
    _timer600 = null;
  }

  void addTask1(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask1 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    tasks1[key] = func;
  }

  void removeTask1(String key) {
    if (!tasks1.keys.contains(key)) return;
    Map<String, Function(String)> temp = Map();
    tasks1.forEach((k, v) {
      if (k != key) {
        temp[k] = v;
      }
    });
    tasks1 = temp;
  }

  void addTask60(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask60 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    tasks60[key] = func;
  }

  void removeTask60(String key) {
    if (!tasks60.keys.contains(key)) return;
    Map<String, Function(String)> temp = Map();
    tasks60.forEach((k, v) {
      if (k != key) {
        temp[k] = v;
      }
    });
    tasks60 = temp;
  }

  void addTask600(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask600 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _tasks600[key] = func;
  }

  void removeTask600(String key) {
    if (!_tasks600.keys.contains(key)) return;
    Map<String, Function(String)> temp = Map();
    _tasks600.forEach((k, v) {
      if (k != key) {
        temp[k] = v;
      }
    });
    _tasks600 = temp;
  }
}
