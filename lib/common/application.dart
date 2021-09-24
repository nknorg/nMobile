import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/theme/light.dart';
import 'package:nmobile/theme/theme.dart';

typedef Func = Future Function();

class Application {
  List<Func> _initializeFutures = <Func>[];
  List<Func> _mountedFutures = <Func>[];

  SkinTheme theme = LightTheme();

  // ignore: close_sinks
  StreamController<List<AppLifecycleState>> _appLifeController = StreamController<List<AppLifecycleState>>.broadcast();
  StreamSink<List<AppLifecycleState>> get appLifeSink => _appLifeController.sink;
  Stream<List<AppLifecycleState>> get appLifeStream => _appLifeController.stream;
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;

  Application();

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

  bool isFromBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return (states[0] == AppLifecycleState.inactive) && (states[1] == AppLifecycleState.resumed);
      } else {
        // android same with inactive
        return (states[0] == AppLifecycleState.paused) && (states[1] == AppLifecycleState.resumed);
      }
    }
    return false;
  }

  bool isGoBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return (states[0] == AppLifecycleState.resumed) && (states[1] == AppLifecycleState.inactive);
      } else {
        return (states[0] == AppLifecycleState.inactive) && (states[1] == AppLifecycleState.paused);
      }
    }
    return false;
  }
}
