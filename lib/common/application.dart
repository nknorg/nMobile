import 'package:flutter/material.dart';
import 'package:nmobile/theme/light.dart';
import 'package:nmobile/theme/theme.dart';

typedef Func = Future Function();

class Application {
  List<Func> _initializeFutures = <Func>[];
  List<Func> _mountedFutures = <Func>[];

  SkinTheme theme = LightTheme();
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;

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
}
