import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/common/select.dart';

Map<String, WidgetBuilder> _routes = {
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
}
