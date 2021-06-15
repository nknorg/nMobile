import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/screens/contact/chat_profile.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/contact/profile.dart';

Map<String, WidgetBuilder> _routes = {
  ContactHomeScreen.routeName: (BuildContext context, {arguments}) => ContactHomeScreen(arguments: arguments),
  ContactAddScreen.routeName: (BuildContext context) => ContactAddScreen(),
  ContactProfileScreen.routeName: (BuildContext context, {arguments}) => ContactProfileScreen(arguments: arguments),
  ContactChatProfileScreen.routeName: (BuildContext context, {arguments}) => ContactChatProfileScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
