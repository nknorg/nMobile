import 'package:flutter/material.dart';
import 'package:nmobile/theme/light.dart';
import 'package:nmobile/theme/theme.dart';

typedef Func = Future Function();

class Application {
  List<Func> _initializeFutures = <Func>[];
  List<Func> _mountedFutures = <Func>[];
  Map<String, WidgetBuilder> _routes = {};
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

  registerRoutes(Map<String, WidgetBuilder> routes) {
    _routes.addAll(routes);
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String name = settings.name;
    final Function pageContentBuilder = _routes[name];
    if (pageContentBuilder != null) {
      if (settings.arguments != null) {
        return MaterialPageRoute(builder: (context) => pageContentBuilder(context, arguments: settings.arguments));
      } else {
        return MaterialPageRoute(builder: (context) => pageContentBuilder(context));
      }
    }
    return null;
  }
}
