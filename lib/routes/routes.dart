import 'package:flutter/material.dart';

import '../app.dart';
import '../common/locator.dart';
import 'home.dart' as home;
import 'wallet.dart' as wallet;

Map<String, WidgetBuilder> routes = {
  AppScreen.routeName: (BuildContext context) => AppScreen(),
};

init() {
  application.registerRoutes(routes);
  home.init();
  wallet.init();
}
