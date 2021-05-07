import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/screens/wallet/import.dart';

Map<String, WidgetBuilder> routes = {
  WalletHomeScreen.routeName: (BuildContext context) => WalletHomeScreen(),
  WalletCreateNKNScreen.routeName: (BuildContext context) => WalletCreateNKNScreen(),
  WalletCreateETHScreen.routeName: (BuildContext context) => WalletCreateETHScreen(),
  WalletImportScreen.routeName: (BuildContext context, {arguments}) => WalletImportScreen(arguments: arguments),
};

init() {
  application.registerRoutes(routes);
}
