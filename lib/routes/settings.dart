import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/settings/cache.dart';
import 'package:nmobile/screens/settings/settings.dart';

Map<String, WidgetBuilder> _routes = {
  SettingsScreen.routeName: (BuildContext context) => SettingsScreen(),
  CacheScreen.routeName: (BuildContext context) => CacheScreen(),
};

init() {
  application.registerRoutes(_routes);
}
