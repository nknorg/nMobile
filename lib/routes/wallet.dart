import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/wallet/home.dart';

Map<String, WidgetBuilder> routes = {
  WalletHomeScreen.routeName: (BuildContext context) => WalletHomeScreen(),
};

init() {
  application.registerRoutes(routes);
}
