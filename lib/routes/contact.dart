import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/contact/home.dart';

Map<String, WidgetBuilder> _routes = {
  ContactHomeScreen.routeName: (BuildContext context, {arguments}) => ContactHomeScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
}
