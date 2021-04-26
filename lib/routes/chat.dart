import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/chat/home.dart';

Map<String, WidgetBuilder> routes = {
  ChatHomeScreen.routeName: (BuildContext context) => ChatHomeScreen(),
};

init() {
  application.registerRoutes(routes);
}
