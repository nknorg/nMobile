import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/session_list.dart';
import 'package:nmobile/screens/contact/detail.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/asset.dart';

class ChatHomeScreen extends StatefulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  GlobalKey _floatingActionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  _showMenu() {
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 60, right: 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 136,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 12, top: 12, right: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      color: Color(0x4D051C3F),
                                    ),
                                    child: Label(
                                      S.of(context).new_group,
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
                                    padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      color: Color(0x4D051C3F),
                                    ),
                                    child: Label(
                                      S.of(context).new_whisper,
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
                          padding: EdgeInsets.only(bottom: 12, top: 12),
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(32)),
                            color: application.theme.primaryColor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Button(
                                child: Asset.iconSvg('group', width: 22, color: application.theme.fontLightColor),
                                fontColor: application.theme.fontLightColor,
                                backgroundColor: application.theme.backgroundLightColor.withAlpha(77),
                                width: 48,
                                height: 48,
                                onPressed: () async {
                                  // TODO
                                  // Navigator.of(context).pop();
                                  // showModalBottomSheet(
                                  //     context: context,
                                  //     isScrollControlled: true,
                                  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
                                  //     builder: (context) {
                                  //       return Container();
                                  //       // return CreateGroupDialog();
                                  //     });
                                },
                              ),
                              Button(
                                child: Asset.iconSvg('user', width: 24, color: application.theme.fontLightColor),
                                fontColor: application.theme.fontLightColor,
                                backgroundColor: application.theme.backgroundLightColor.withAlpha(77),
                                width: 48,
                                height: 48,
                                onPressed: () async {
                                  // TODO
                                  // var address = await BottomDialog.of(context)
                                  //     .showInputAddressDialog(title: NL10ns.of(context).new_whisper, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
                                  // if (address != null) {
                                  //   ContactSchema contact = ContactSchema(type: ContactType.stranger, clientAddress: address);
                                  //   await contact.insertContact();
                                  //   var c = await ContactSchema.fetchContactByAddress(address);
                                  //   if (c != null) {
                                  //     _pushToSingleChat(c);
                                  //   } else {
                                  //     _pushToSingleChat(contact);
                                  //   }
                                  // } else {
                                  //   Navigator.of(context).pop();
                                  // }
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

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return StreamBuilder<int>(
      stream: chat.statusStream,
      initialData: chat.status,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        if (snapshot.data == ChatConnectStatus.disconnected) {
          return NoConnectScreen();
        } else {
          return Layout(
            header: Header(
              titleChild: Container(
                margin: EdgeInsets.only(left: 20),
                child: GestureDetector(
                  onTap: () {
                    ContactDetailScreen.go(context, contactId: contact?.currentUser?.id);
                  },
                  child: ContactHeader(
                    contact: contact.currentUser,
                    body: StreamBuilder<int>(
                      initialData: chat.status,
                      stream: chat.statusStream,
                      builder: (context, snapshot) {
                        Widget statusWidget = Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Label(_localizations.connecting, type: LabelType.h4, color: application.theme.fontLightColor.withAlpha(200)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2, left: 4),
                              child: SpinKitThreeBounce(
                                color: application.theme.fontLightColor.withAlpha(200),
                                size: 10,
                              ),
                            ),
                          ],
                        );
                        switch (snapshot.data) {
                          case ChatConnectStatus.disconnected:
                            statusWidget = Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Label(_localizations.disconnect, type: LabelType.h4, color: application.theme.strongColor),
                              ],
                            );
                            break;
                          case ChatConnectStatus.connected:
                            statusWidget = Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Label(_localizations.connected, type: LabelType.h4, color: application.theme.successColor),
                              ],
                            );
                            break;
                        }

                        return statusWidget;
                      },
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Asset.iconSvg('addbook', color: Colors.white, width: 24),
                    onPressed: () {
                      ContactHomeScreen.go(context);
                    },
                  ),
                )
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20, right: 4),
              child: FloatingActionButton(
                key: _floatingActionKey,
                elevation: 12,
                backgroundColor: application.theme.primaryColor,
                child: Asset.iconSvg('pencil', width: 24),
                onPressed: () {
                  _showMenu();
                },
              ),
            ),
            body: SessionListLayout(),
          );
        }
      },
    );
  }
}
