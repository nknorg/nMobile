import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/private_group/profile.dart';
import 'package:nmobile/screens/private_group/subscribers.dart';

// TODO:GG PG check
Map<String, WidgetBuilder> _routes = {
  PrivateGroupProfileScreen.routeName: (BuildContext context, {arguments}) => PrivateGroupProfileScreen(arguments: arguments),
  PrivateGroupSubscribersScreen.routeName: (BuildContext context, {arguments}) => PrivateGroupSubscribersScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
