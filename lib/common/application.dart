import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/theme/light.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/logger.dart';

typedef Func = Future Function();

class Application {
  List<Func> _initializeFutures = <Func>[];
  List<Func> _mountedFutures = <Func>[];

  SkinTheme theme = LightTheme();

  // ignore: close_sinks
  StreamController<List<AppLifecycleState>> _appLifeController = StreamController<List<AppLifecycleState>>.broadcast();
  StreamSink<List<AppLifecycleState>> get appLifeSink => _appLifeController.sink;
  Stream<List<AppLifecycleState>> get appLifeStream => _appLifeController.stream.distinct((prev, next) => (prev[0] == next[0]) && (prev[1] == next[1]));
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;

  bool inBackGround = false;

  Application();

  void init() {
    appLifeStream.listen((List<AppLifecycleState> states) {
      logger.d("Application - init - appLifeStream - states:$states");
      if (isFromBackground(states)) {
        logger.i("Application - init - in foreground");
        inBackGround = false;
      } else if (isGoBackground(states)) {
        logger.i("Application - init - in background");
        inBackGround = true;
      }
    });
  }

  registerInitialize(Func fn) {
    _initializeFutures.add(fn);
  }

  Future<void> initialize() async {
    List<Future> futures = [];
    _initializeFutures.forEach((func) {
      futures.add(func());
    });
    await Future.wait(futures);
  }

  registerMounted(Func fn) {
    _mountedFutures.add(fn);
  }

  Future<void> mounted() async {
    List<Future> futures = [];
    _mountedFutures.forEach((func) {
      futures.add(func());
    });
    await Future.wait(futures);
  }

  // paused -> inactive(just ios) -> resumed
  bool isFromBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return (states[0] == AppLifecycleState.paused) && (states[1] == AppLifecycleState.inactive);
      } else {
        return (states[0] == AppLifecycleState.paused) && (states[1] == AppLifecycleState.resumed);
      }
    }
    return false;
  }

  // resumed -> inactive -> paused
  bool isGoBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return (states[0] == AppLifecycleState.inactive) && (states[1] == AppLifecycleState.paused);
      } else {
        return (states[0] == AppLifecycleState.inactive) && (states[1] == AppLifecycleState.paused);
      }
    }
    return false;
  }
}
