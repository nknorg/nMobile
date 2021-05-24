import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/screens/contact/chat_profile.dart';
import 'package:nmobile/screens/contact/detail.dart';
import 'package:nmobile/screens/contact/home.dart';

Map<String, WidgetBuilder> _routes = {
  ContactHomeScreen.routeName: (BuildContext context, {arguments}) => ContactHomeScreen(arguments: arguments),
  ContactAddScreen.routeName: (BuildContext context) => ContactAddScreen(),
  ContactDetailScreen.routeName: (BuildContext context, {arguments}) => ContactDetailScreen(arguments: arguments),
  ContactChatProfileScreen.routeName: (BuildContext context, {arguments}) => ContactChatProfileScreen(arguments: arguments),
};

init() {
  application.registerRoutes(_routes);
}
