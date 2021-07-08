import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/topic/profile.dart';

Map<String, WidgetBuilder> _routes = {
  TopicProfileScreen.routeName: (BuildContext context, {arguments}) => TopicProfileScreen(arguments: arguments),
};

init() {
  Routes.registerRoutes(_routes);
}
