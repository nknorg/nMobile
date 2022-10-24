import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/common/media.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/common/select.dart';
import 'package:nmobile/screens/common/video.dart';

Map<String, WidgetBuilder> _routes = {
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
  MediaScreen.routeName: (BuildContext context, {arguments}) => MediaScreen(arguments: arguments),
  // PhotoScreen.routeName: (BuildContext context, {arguments}) => PhotoScreen(arguments: arguments),
  // VideoScreen.routeName: (BuildContext context, {arguments}) => VideoScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
