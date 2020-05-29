import 'package:common_utils/common_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/common/page/change_update_content.dart';
import 'package:nmobile/screens/common_web_page.dart';
import 'package:nmobile/screens/contact/add_contact.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/home.dart';
import 'package:nmobile/screens/ncdn/home.dart';
import 'package:nmobile/screens/ncdn/node_detail.dart';
import 'package:nmobile/screens/ncdn/with_draw_page.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/screens/select.dart';
import 'package:nmobile/screens/settings/channel.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_detail.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_export.dart';
import 'package:nmobile/screens/wallet/recieve_nkn.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';
import 'package:nmobile/splash.dart';

Map<String, WidgetBuilder> routes = {
  SplashPage.routeName: (BuildContext context) => SplashPage(),
  AppScreen.routeName: (BuildContext context) => AppScreen(),
  HomeScreen.routeName: (BuildContext context) => HomeScreen(),
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
  PhotoPage.routeName: (BuildContext context, {arguments}) => PhotoPage(arguments: arguments),
  CreateNknWalletScreen.routeName: (BuildContext context) => CreateNknWalletScreen(),
  ImportNknWalletScreen.routeName: (BuildContext context) => ImportNknWalletScreen(),
  NknWalletDetailScreen.routeName: (BuildContext context, {arguments}) => NknWalletDetailScreen(arguments: arguments),
  NknWalletExportScreen.routeName: (BuildContext context, {arguments}) => NknWalletExportScreen(arguments: arguments),
  ReceiveNknScreen.routeName: (BuildContext context, {arguments}) => ReceiveNknScreen(arguments: arguments),
  SendNknScreen.routeName: (BuildContext context, {arguments}) => SendNknScreen(arguments: arguments),
  NoConnectScreen.routeName: (BuildContext context) => NoConnectScreen(),
  ChatSinglePage.routeName: (BuildContext context, {arguments}) => ChatSinglePage(arguments: arguments),
  ChatGroupPage.routeName: (BuildContext context, {arguments}) => ChatGroupPage(arguments: arguments),
  ContactScreen.routeName: (BuildContext context, {arguments}) => ContactScreen(arguments: arguments),
  ContactHome.routeName: (BuildContext context, {arguments}) => ContactHome(arguments: arguments),
  ChannelSettingsScreen.routeName: (BuildContext context, {arguments}) => ChannelSettingsScreen(arguments: arguments),
  ChannelMembersScreen.routeName: (BuildContext context, {arguments}) => ChannelMembersScreen(arguments: arguments),
  CommonWebViewPage.routeName: (BuildContext context, {arguments}) => CommonWebViewPage(arguments: arguments),
  ChangeUpdateContentPage.routeName: (BuildContext context, {arguments}) => ChangeUpdateContentPage(arguments: arguments),
  AddContact.routeName: (BuildContext context) => AddContact(),
  NcdnHomeScreen.routeName: (BuildContext context, {arguments}) => NcdnHomeScreen(arguments: arguments),
  NodeDetailScreen.routeName: (BuildContext context, {arguments}) => NodeDetailScreen(arguments: arguments),
  WithDrawPage.routeName: (BuildContext context, {arguments}) => WithDrawPage(arguments: arguments),
};


var onGenerateRoute = (RouteSettings settings) {
  final String name = settings.name;
  LogUtil.v(name);
  LogUtil.v(settings.arguments);
  final Function pageContentBuilder = routes[name];
  if (pageContentBuilder != null) {
    if (settings.arguments != null) {
      final Route route = MaterialPageRoute(builder: (context) => pageContentBuilder(context, arguments: settings.arguments));
      return route;
    } else {
      final Route route = MaterialPageRoute(builder: (context) => pageContentBuilder(context));
      return route;
    }
  }
};
