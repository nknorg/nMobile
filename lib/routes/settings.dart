import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/settings/cache.dart';
import 'package:nmobile/screens/settings/home.dart';

Map<String, WidgetBuilder> _routes = {
  SettingsHomeScreen.routeName: (BuildContext context) => SettingsHomeScreen(),
  SettingsCacheScreen.routeName: (BuildContext context) => SettingsCacheScreen(),
};

init() {
  application.registerRoutes(_routes);
}
