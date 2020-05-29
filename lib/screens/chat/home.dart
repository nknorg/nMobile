import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/image_utils.dart';

class ChatHome extends StatefulWidget {
  static const String routeName = '/chat/home';
  @override
  _ChatHomeState createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> with SingleTickerProviderStateMixin {
  GlobalKey _floatingActionKey = GlobalKey();
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    List<String> tabs = [NMobileLocalizations.of(context).chat_tab_messages, NMobileLocalizations.of(context).chat_tab_group];
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: Global.currentUser);
          },
          child: Padding(
            padding: EdgeInsets.only(left: 16.h),
            child: Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Container(
                    padding: EdgeInsets.only(right: 16.h),
                    alignment: Alignment.center,
                    child: Global.currentUser.avatarWidget(backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200), size: 24),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Label(Global.currentUser.name, type: LabelType.h3, dark: true),
                      BlocBuilder<ClientBloc, ClientState>(
                        builder: (context, clientState) {
                          if (clientState is Connected) {
                            return Label(NMobileLocalizations.of(context).connected, type: LabelType.bodySmall, color: DefaultTheme.riseColor);
                          } else {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Label(NMobileLocalizations.of(context).connecting, type: LabelType.bodySmall, color: DefaultTheme.fontLightColor.withAlpha(200)),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                                  child: SpinKitThreeBounce(
                                    color: DefaultTheme.loadingColor,
                                    size: 10,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        action: IconButton(
          icon: loadAssetIconsImage('addbook', color: Colors.white, width: 20.w),
          onPressed: () {
            Navigator.of(context).pushNamed(ContactHome.routeName);
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 110.h),
        child: FloatingActionButton(
          key: _floatingActionKey,
          backgroundColor: DefaultTheme.primaryColor,
          child: loadAssetIconsImage(
            'pencil',
            width: 24,
          ),
          onPressed: () {
            showBottomMenu();
          },
        ),
      ),
      body: Container(
        child: ConstrainedBox(
          constraints: BoxConstraints.expand(),
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                  child: Container(
                    constraints: BoxConstraints.expand(),
                    color: DefaultTheme.primaryColor,
                    child: Flex(
                      direction: Axis.vertical,
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: DefaultTheme.backgroundColor1,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            child: Flex(
                              direction: Axis.vertical,
                              children: <Widget>[
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 0.2),
                                    child: MessagesTab(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  showBottomMenu() {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: EdgeInsets.only(bottom: 100.h, right: 12.w),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 150.h,
                  width: 300.w,
                  child: Flex(
                    direction: Axis.horizontal,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 16.h, top: 16.h, right: 8.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              SizedBox(
                                height: 48.h,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: EdgeInsets.only(top: 4.h, bottom: 4.h, left: 8.w, right: 8.w),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      color: Color.fromARGB(200, 5, 28, 63),
                                    ),
                                    child: Label(
                                      NMobileLocalizations.of(context).new_group,
                                      height: 1.2,
                                      type: LabelType.h4,
                                      dark: true,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: EdgeInsets.only(top: 4.h, bottom: 4.h, left: 8.w, right: 8.w),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      color: Color.fromARGB(200, 5, 28, 63),
                                    ),
                                    child: Label(
                                      NMobileLocalizations.of(context).new_whisper,
                                      height: 1.2,
                                      type: LabelType.h4,
                                      dark: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 0,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 16.h, top: 16.h),
                          width: 64.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(80)),
                            color: DefaultTheme.primaryColor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Button(
                                child: loadAssetIconsImage(
                                  'group',
                                  width: 24,
                                  color: DefaultTheme.fontLightColor,
                                ),
                                padding: const EdgeInsets.only(),
                                fontColor: DefaultTheme.fontLightColor,
                                backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
                                width: 48.w,
                                height: 48.w,
                                onPressed: () async {
                                  var address = await BottomDialog.of(context).showInputChannelDialog(title: NMobileLocalizations.of(context).create_channel);
                                },
                              ),
                              Button(
                                child: loadAssetIconsImage(
                                  'user',
                                  width: 24.w,
                                  color: DefaultTheme.fontLightColor,
                                ),
                                padding: const EdgeInsets.only(),
                                fontColor: DefaultTheme.fontLightColor,
                                backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
                                width: 48.w,
                                height: 48.h,
                                onPressed: () async {
                                  var address = await BottomDialog.of(context).showInputAddressDialog(title: NMobileLocalizations.of(context).new_whisper, hint: NMobileLocalizations.of(context).enter_or_select_a_user_pubkey);
                                  if (address != null) {
                                    ContactSchema contact = ContactSchema(type: ContactType.friend, clientAddress: address);
                                    await contact.createContact();
                                    var c = await ContactSchema.getContactByAddress(address);
                                    if (c != null) {
                                      Navigator.of(context).pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: c));
                                    } else {
                                      Navigator.of(context).pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
