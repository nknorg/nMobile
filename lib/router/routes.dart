import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/screens/advice_page.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/chat/populai_group_page.dart';
import 'package:nmobile/screens/common/page/change_update_content.dart';
import 'package:nmobile/screens/common_web_page.dart';
import 'package:nmobile/screens/contact/add_contact.dart';
import 'package:nmobile/screens/contact/chat_profile.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/contact/show_chat_id.dart';
import 'package:nmobile/screens/contact/show_my_chat_address.dart';
import 'package:nmobile/screens/home.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/screens/select.dart';
import 'package:nmobile/screens/settings/channel.dart';
import 'package:nmobile/screens/wallet/create_eth_wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_detail.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_export.dart';
import 'package:nmobile/screens/wallet/recieve_nkn.dart';
import 'package:nmobile/screens/wallet/send_erc_20.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';
import 'package:nmobile/screens/wallet/wallet.dart';
import 'package:nmobile/splash.dart';
import 'package:nmobile/utils/nlog_util.dart';

Map<String, WidgetBuilder> routes = {
  SplashPage.routeName: (BuildContext context) => SplashPage(),
  AppScreen.routeName: (BuildContext context) => AppScreen(),
  HomeScreen.routeName: (BuildContext context) => HomeScreen(),
  ScannerScreen.routeName: (BuildContext context) => ScannerScreen(),
  SelectScreen.routeName: (BuildContext context, {arguments}) => SelectScreen(arguments: arguments),
  PhotoPage.routeName: (BuildContext context, {arguments}) => PhotoPage(arguments: arguments),
  CreateNknWalletScreen.routeName: (BuildContext context) => CreateNknWalletScreen(),
  CreateEthWalletScreen.routeName: (BuildContext context) => CreateEthWalletScreen(),
  ImportNknWalletScreen.routeName: (BuildContext context) => ImportNknWalletScreen(),
  NknWalletDetailScreen.routeName: (BuildContext context, {arguments}) => NknWalletDetailScreen(arguments: arguments),
  NknWalletExportScreen.routeName: (BuildContext context, {arguments}) => NknWalletExportScreen(arguments: arguments),
  ReceiveNknScreen.routeName: (BuildContext context, {arguments}) => ReceiveNknScreen(arguments: arguments),
  SendNknScreen.routeName: (BuildContext context, {arguments}) => SendNknScreen(arguments: arguments),
  SendErc20Screen.routeName: (BuildContext context, {arguments}) => SendErc20Screen(arguments: arguments),
//  NoConnectScreen.routeName: (BuildContext context) => NoConnectScreen(),
  ChatSinglePage.routeName: (BuildContext context, {arguments}) => ChatSinglePage(arguments: arguments),
  ChatGroupPage.routeName: (BuildContext context, {arguments}) => ChatGroupPage(arguments: arguments),
  ContactScreen.routeName: (BuildContext context, {arguments}) => ContactScreen(arguments: arguments),
  ContactHome.routeName: (BuildContext context, {arguments}) => ContactHome(arguments: arguments),
  ChannelSettingsScreen.routeName: (BuildContext context, {arguments}) => ChannelSettingsScreen(arguments: arguments),
  ChannelMembersScreen.routeName: (BuildContext context, {arguments}) => ChannelMembersScreen(arguments: arguments),
  CommonWebViewPage.routeName: (BuildContext context, {arguments}) => CommonWebViewPage(arguments: arguments),
  ChangeUpdateContentPage.routeName: (BuildContext context, {arguments}) => ChangeUpdateContentPage(arguments: arguments),
  AddContact.routeName: (BuildContext context) => AddContact(),
  PopularGroupPage.routeName: (BuildContext context) => PopularGroupPage(),
  ShowMyChatID.routeName: (BuildContext context) => ShowMyChatID(),
  WalletScreen.routeName: (BuildContext context) => WalletScreen(),
  AdvancePage.routeName: (BuildContext context) => AdvancePage(),
  ChatProfile.routeName: (BuildContext context, {arguments}) => ChatProfile(arguments: arguments),
  ShowMyChatAddress.routeName: (BuildContext context, {arguments}) => ShowMyChatAddress(arguments: arguments),
};

var onGenerateRoute = (RouteSettings settings) {
  final String name = settings.name;
  NLog.d(name);
  NLog.d(settings.arguments);
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
