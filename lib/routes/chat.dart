import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/chat/messages_detail.dart';

Map<String, WidgetBuilder> _routes = {
  ChatHomeScreen.routeName: (BuildContext context) => ChatHomeScreen(),
  ChatMessagesDetailScreen.routeName: (BuildContext context, {arguments}) => ChatMessagesDetailScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
}
