import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/messages.dart';

Map<String, WidgetBuilder> _routes = {
  ChatHomeScreen.routeName: (BuildContext context) => ChatHomeScreen(),
  ChatMessagesScreen.routeName: (BuildContext context, {arguments}) => ChatMessagesScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
