import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/common/select.dart';

import '../common/application.dart';

Map<String, WidgetBuilder> routes = {
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
};

GetIt locator = GetIt.instance;
Application app = locator.get<Application>();

init() {
  app.registerRoutes(routes);
}
