import 'package:flutter/material.dart';

import '../app.dart';
import '../common/locator.dart';
import 'chat.dart' as chat;
import 'home.dart' as home;
import 'settings.dart' as settings;
import 'wallet.dart' as wallet;

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
