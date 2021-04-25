import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/screens/settings/settings.dart';

import '../common/application.dart';

Map<String, WidgetBuilder> routes = {
  SettingsScreen.routeName: (BuildContext context) => SettingsScreen(),
  // ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  // SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
};

GetIt locator = GetIt.instance;
Application app = locator.get<Application>();

init() {
  app.registerRoutes(routes);
}
