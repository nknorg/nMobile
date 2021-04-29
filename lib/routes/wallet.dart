import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/home.dart';

Map<String, WidgetBuilder> routes = {
  WalletHomeScreen.routeName: (BuildContext context) => WalletHomeScreen(),
  WalletCreateNKNScreen.routeName: (BuildContext context) => WalletCreateNKNScreen(),
};

init() {
  application.registerRoutes(routes);
}
