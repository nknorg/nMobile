import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/chat/chat.dart';
import 'package:nmobile/screens/chat/home.dart';

Map<String, WidgetBuilder> _routes = {
  ChatHomeScreen.routeName: (BuildContext context) => ChatHomeScreen(),
  ChatScreen.routeName: (BuildContext context, {arguments}) => ChatScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
}
