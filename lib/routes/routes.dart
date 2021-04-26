import 'package:flutter/material.dart';

import '../common/locator.dart';
import '../app.dart';
import 'chat.dart' as chat;
import 'home.dart' as home;
import 'wallet.dart' as wallet;
import 'settings.dart' as settings;

Map<String, WidgetBuilder> routes = {
  AppScreen.routeName: (BuildContext context) => AppScreen(),
};

init() {
  application.registerRoutes(routes);
  home.init();
  chat.init();
  wallet.init();
  settings.init();
}
