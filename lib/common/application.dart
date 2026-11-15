import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/theme/light.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/logger.dart';

typedef Func = Future Function();

class Application {
  static const env = String.fromEnvironment("APP_ENV", defaultValue: "production");
  List<Func> _initializeFutures = <Func>[];
  List<Func> _mountedFutures = <Func>[];

  SkinTheme theme = LightTheme();

  // ignore: close_sinks
  StreamController<List<AppLifecycleState>> _appLifeController = StreamController<List<AppLifecycleState>>.broadcast();
  StreamSink<List<AppLifecycleState>> get appLifeSink => _appLifeController.sink;
  Stream<List<AppLifecycleState>> get _appLifeStream => _appLifeController.stream.distinct((prev, next) => (prev[0] == next[0]) && (prev[1] == next[1]));

  // ignore: close_sinks
  StreamController<bool> _appLife2Controller = StreamController<bool>.broadcast();
  StreamSink<bool> get _appLifeSink => _appLife2Controller.sink;
  Stream<bool> get appLifeStream => _appLife2Controller.stream.distinct((prev, next) => (prev == next));

  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;

  bool inBackGround = false;
  bool inAuthProgress = false;
  bool inSystemSelecting = false;

  int goBackgroundAt = 0;
  int goForegroundAt = 0;


  bool get isDev => env == "development";
  bool get isProd => env == "production";
  
  Application();

  void init() {
    _appLifeStream.listen((List<AppLifecycleState> states) {
      if (_isGoBackground(states)) {
        logger.i("Application - appLifeStream - in background - states:$states");
        inBackGround = true;
        goBackgroundAt = DateTime.now().millisecondsSinceEpoch;
        _appLifeSink.add(true);
      } else if (_isFromBackground(states)) {
        logger.i("Application - appLifeStream - in foreground - states:$states");
        inBackGround = false;
        goForegroundAt = DateTime.now().millisecondsSinceEpoch;
        _appLifeSink.add(false);
      } else {
        if (states.length >= 2 && states[1] == AppLifecycleState.paused && !inBackGround && !inSystemSelecting) {
          logger.i("Application - appLifeStream - in background (missed detection) - states:$states");
          inBackGround = true;
          goBackgroundAt = DateTime.now().millisecondsSinceEpoch;
          _appLifeSink.add(true);
        }
        else if (states.length >= 2 && states[1] == AppLifecycleState.resumed && inBackGround) {
          logger.i("Application - appLifeStream - in foreground (missed detection) - states:$states");
          inBackGround = false;
          goForegroundAt = DateTime.now().millisecondsSinceEpoch;
          _appLifeSink.add(false);
        } else {
          logger.d("Application - appLifeStream - nothing - states:$states");
        }
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

  // resumed -> inactive -> hidden -> paused (iOS with hidden state)
  // resumed -> inactive -> paused (iOS without hidden state / Android)
  bool _isGoBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return !inSystemSelecting && 
               ((states[0] == AppLifecycleState.inactive && states[1] == AppLifecycleState.paused) ||
                (states[0] == AppLifecycleState.hidden && states[1] == AppLifecycleState.paused));
      } else if (Platform.isAndroid) {
        return !inSystemSelecting && (states[0] == AppLifecycleState.inactive) && (states[1] == AppLifecycleState.paused);
      }
    }
    return false;
  }

  // paused -> hidden -> inactive -> resumed (iOS with hidden state)
  // paused -> inactive -> resumed (iOS without hidden state)
  // paused -> resumed (Android)
  bool _isFromBackground(List<AppLifecycleState> states) {
    if (states.length >= 2) {
      if (Platform.isIOS) {
        return inBackGround && 
               ((states[0] == AppLifecycleState.paused && states[1] == AppLifecycleState.resumed) ||
                (states[0] == AppLifecycleState.hidden && states[1] == AppLifecycleState.resumed) ||
                (states[0] == AppLifecycleState.inactive && states[1] == AppLifecycleState.resumed));
      } else if (Platform.isAndroid) {
        // Android: paused -> resumed
        return inBackGround && (states[0] == AppLifecycleState.paused) && (states[1] == AppLifecycleState.resumed);
      }
    }
    return false;
  }
}
