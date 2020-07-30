import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/ncdn/chat_cdn_main_page.dart';

class ChatMainPage extends StatefulWidget {
  static final String routeName = "ChatMainPage";

  @override
  ChatMainPageState createState() => new ChatMainPageState();
}

class ChatMainPageState extends State<ChatMainPage> with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(height: 2),
        TabBar(controller: _tabController, indicatorSize: TabBarIndicatorSize.label, labelColor: DefaultTheme.primaryColor, unselectedLabelColor: DefaultTheme.fontColor1, tabs: [
          Tab(text: NMobileLocalizations.of(context).message_text),
          Tab(text: NMobileLocalizations.of(context).niot_text),
        ]),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: NeverScrollableScrollPhysics(),
            children: [
              MessagesTab(),
              ChatCDNMainPage(),
            ],
          ),
        )
      ],
    );
  }
}
