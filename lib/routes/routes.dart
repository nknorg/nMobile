import 'package:flutter/material.dart';

import '../app.dart';
import 'chat.dart' as chat;
import 'contact.dart' as contact;
import 'home.dart' as home;
import 'settings.dart' as settings;
import 'wallet.dart' as wallet;

class Routes {
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  static Map<String, WidgetBuilder> _routes = {};

  static init() {
    registerRoutes({
      AppScreen.routeName: (BuildContext context, {arguments}) => AppScreen(arguments: arguments),
    });
    home.init();
    chat.init();
    wallet.init();
    settings.init();
    contact.init();
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final Function? pageContentBuilder = _routes[name];
    if (pageContentBuilder != null) {
      if (settings.arguments != null) {
        return MaterialPageRoute(
          settings: RouteSettings(name: name),
          builder: (context) => pageContentBuilder(context, arguments: settings.arguments),
        );
      } else {
        return MaterialPageRoute(
          settings: RouteSettings(name: name),
          builder: (context) => pageContentBuilder(context),
        );
      }
    }
    return null;
  }

  static registerRoutes(Map<String, WidgetBuilder> routes) {
    _routes.addAll(routes);
  }
}
