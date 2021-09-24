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

  Timer? _timer300;
  Map<String, Function(String)> _tasks300 = Map<String, Function(String)>();

  TaskService();

  init({bool isFirst = true}) {
    // listen
    if (isFirst) {
      application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
        if (application.isFromBackground(states)) {
          init(isFirst: false);
        } else if (application.isGoBackground(states)) {
          uninstall();
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

    // timer 300s
    _timer300 = _timer300 ??
        Timer.periodic(Duration(seconds: 300), (timer) {
          _tasks300.keys.forEach((String key) {
            // logger.d("TickHelper - tick");
            _tasks300[key]?.call(key);
          });
        });

    // immediate
    addTask300(KEY_RPC_REFRESH, (key) => Global.getSeedRpcList(null, measure: true, delayMs: 500), callNow: true);
    addTask300(KEY_NONCE_REFRESH, (key) => Global.refreshNonce(delayMs: 1000), callNow: true);
    addTask60(KEY_WALLET_BALANCE, (key) => walletCommon.queryBalance(delayMs: 1000), callNow: true);

    // delay
    addTask60(KEY_CLIENT_CONNECT, (key) => clientCommon.connectCheck(), callNow: false);
    addTask60(KEY_MSG_FAIL_CHECK, (key) => chatCommon.checkSending(delayMs: 2000), callNow: true);
    addTask300(KEY_TOPIC_CHECK, (key) => topicCommon.checkAllTopics(refreshSubscribers: false), callNow: false);
  }

  uninstall() {
    _timer1?.cancel();
    _timer1 = null;
    _timer60?.cancel();
    _timer60 = null;
    _timer300?.cancel();
    _timer300 = null;
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

  void addTask300(String key, Function(String) func, {bool callNow = true}) {
    logger.d("$Tag - addTask300 - key:$key - func:${func.toString()}");
    if (callNow) func.call(key);
    _tasks300[key] = func;
  }

  void removeTask300(String key) {
    if (!_tasks300.keys.contains(key)) return;
    Map<String, Function(String)> temp = Map();
    _tasks300.forEach((k, v) {
      if (k != key) {
        temp[k] = v;
      }
    });
    _tasks300 = temp;
  }
}
