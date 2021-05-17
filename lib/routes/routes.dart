import 'package:flutter/material.dart';

import '../app.dart';
import '../common/locator.dart';
import 'chat.dart' as chat;
import 'contact.dart' as contact;
import 'home.dart' as home;
import 'settings.dart' as settings;
import 'wallet.dart' as wallet;

Map<String, WidgetBuilder> _routes = {
  AppScreen.routeName: (BuildContext context, {arguments}) => AppScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
  home.init();
  chat.init();
  wallet.init();
  settings.init();
  contact.init();
}
