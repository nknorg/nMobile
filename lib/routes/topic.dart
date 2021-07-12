import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/topic/profile.dart';
import 'package:nmobile/screens/topic/subscribers.dart';

Map<String, WidgetBuilder> _routes = {
  TopicProfileScreen.routeName: (BuildContext context, {arguments}) => TopicProfileScreen(arguments: arguments),
  TopicSubscribersScreen.routeName: (BuildContext context, {arguments}) => TopicSubscribersScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
