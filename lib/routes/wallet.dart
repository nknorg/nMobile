import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/detail_nkn.dart';
import 'package:nmobile/screens/wallet/export_nkn.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/screens/wallet/import.dart';

Map<String, WidgetBuilder> routes = {
  WalletHomeScreen.routeName: (BuildContext context) => WalletHomeScreen(),
  WalletCreateNKNScreen.routeName: (BuildContext context) => WalletCreateNKNScreen(),
  WalletCreateETHScreen.routeName: (BuildContext context) => WalletCreateETHScreen(),
  WalletImportScreen.routeName: (BuildContext context, {arguments}) => WalletImportScreen(arguments: arguments),
  WalletDetailNKNScreen.routeName: (BuildContext context, {arguments}) => WalletDetailNKNScreen(arguments: arguments),
  WalletExportNKNScreen.routeName: (BuildContext context, {arguments}) => WalletExportNKNScreen(arguments: arguments),
};

init() {
  application.registerRoutes(routes);
}
