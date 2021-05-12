import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/detail.dart';
import 'package:nmobile/screens/wallet/export.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/screens/wallet/receive_nkn.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';

Map<String, WidgetBuilder> routes = {
  WalletHomeScreen.routeName: (BuildContext context) => WalletHomeScreen(),
  WalletCreateNKNScreen.routeName: (BuildContext context) => WalletCreateNKNScreen(),
  WalletCreateETHScreen.routeName: (BuildContext context) => WalletCreateETHScreen(),
  WalletImportScreen.routeName: (BuildContext context, {arguments}) => WalletImportScreen(arguments: arguments),
  WalletDetailScreen.routeName: (BuildContext context, {arguments}) => WalletDetailScreen(arguments: arguments),
  WalletExportScreen.routeName: (BuildContext context, {arguments}) => WalletExportScreen(arguments: arguments),
  WalletReceiveNKNScreen.routeName: (BuildContext context, {arguments}) => WalletReceiveNKNScreen(arguments: arguments),
  WalletSendNKNScreen.routeName: (BuildContext context, {arguments}) => WalletSendNKNScreen(arguments: arguments),
};

init() {
  application.registerRoutes(routes);
}
