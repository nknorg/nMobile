import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/common/select.dart';

Map<String, WidgetBuilder> _routes = {
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
  PhotoScreen.routeName: (BuildContext context, {arguments}) => PhotoScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
