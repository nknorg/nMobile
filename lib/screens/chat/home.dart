import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/chat_topic_search.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/session_list.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';

import 'no_wallet.dart';

class ChatHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends BaseStateFulWidgetState<ChatHomeScreen> with AutomaticKeepAliveClientMixin, RouteAware {
  GlobalKey _floatingActionKey = GlobalKey();

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
  }

  @override
  void didPush() {
    // self push in, self show
    super.didPush();
  }

  @override
  void didPushNext() {
    // other push in, self hide
    super.didPushNext();
  }

  @override
  void didPopNext() {
    // other pop out, self show
    super.didPopNext();
  }

  @override
  void didPop() {
    // self pop out, self hide
    super.didPop();
  }

  @override
  void didChangeDependencies() {
    Routes.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    Routes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    S _localizations = S.of(context);

    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletLoaded) {
          if (state.isWalletsEmpty()) {
            return ChatNoWalletLayout();
          }
        }
        return StreamBuilder<int>(
          stream: clientCommon.statusStream,
          initialData: clientCommon.status,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            if (snapshot.data == ClientConnectStatus.disconnected || snapshot.data == ClientConnectStatus.stopping) {
              return ChatNoConnectLayout();
            }
            return StreamBuilder<ContactSchema?>(
              initialData: contactCommon.currentUser,
              stream: contactCommon.currentUpdateStream,
              builder: (BuildContext context, AsyncSnapshot<ContactSchema?> snapshot) {
                ContactSchema? contact = snapshot.data ?? contactCommon.currentUser;
                return Layout(
                  headerColor: application.theme.primaryColor,
                  bodyColor: application.theme.backgroundLightColor,
                  header: Header(
                    titleChild: Container(
                      margin: EdgeInsets.only(left: 20),
                      child: contact != null
                          ? ContactHeader(
                              contact: contact,
                              onTap: () {
                                ContactProfileScreen.go(context, contactId: contact.id);
                              },
                              body: StreamBuilder<int>(
                                stream: clientCommon.statusStream,
                                initialData: clientCommon.status,
                                builder: (context, snapshot) {
                                  late Widget statusWidget;
                                  switch (snapshot.data) {
                                    case ClientConnectStatus.disconnected:
                                      statusWidget = Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Label(
                                            _localizations.disconnect,
                                            type: LabelType.h4,
                                            color: application.theme.strongColor,
                                          ),
                                        ],
                                      );
                                      break;
                                    case ClientConnectStatus.connected:
                                      statusWidget = Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Label(
                                            _localizations.connected,
                                            type: LabelType.h4,
                                            color: application.theme.successColor,
                                          ),
                                        ],
                                      );
                                      break;
                                    default:
                                      statusWidget = Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Label(
                                            _localizations.connecting,
                                            type: LabelType.h4,
                                            color: application.theme.fontLightColor.withAlpha(200),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2, left: 4),
                                            child: SpinKitThreeBounce(
                                              color: application.theme.fontLightColor.withAlpha(200),
                                              size: 10,
                                            ),
                                          ),
                                        ],
                                      );
                                      break;
                                  }
                                  return statusWidget;
                                },
                              ),
                            )
                          : SizedBox.shrink(),
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
                    padding: EdgeInsets.only(bottom: 60, right: 4),
                    child: FloatingActionButton(
                      key: _floatingActionKey,
                      elevation: 12,
                      backgroundColor: application.theme.primaryColor,
                      child: Asset.iconSvg('pencil', width: 24),
                      onPressed: () {
                        _showFloatActionMenu();
                      },
                    ),
                  ),
                  body: contact != null ? ChatSessionListLayout(contact) : SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }

  _showFloatActionMenu() {
    double btnSize = 48;
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: EdgeInsets.only(bottom: 67, right: 16),
              child: Row(
                children: [
                  Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: btnSize,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              color: Colors.black26,
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
                      SizedBox(height: 10),
                      SizedBox(
                        height: btnSize,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              color: Colors.black26,
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
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(32)),
                      color: application.theme.primaryColor,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Button(
                          width: btnSize,
                          height: btnSize,
                          fontColor: application.theme.fontLightColor,
                          backgroundColor: application.theme.backgroundLightColor.withAlpha(77),
                          child: Asset.iconSvg('group', width: 22, color: application.theme.fontLightColor),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            BottomDialog.of(context).showWithTitle(
                              height: Global.screenHeight() * 0.8,
                              title: S.of(context).create_channel,
                              child: ChatTopicSearchLayout(),
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        Button(
                          width: btnSize,
                          height: btnSize,
                          fontColor: application.theme.fontLightColor,
                          backgroundColor: application.theme.backgroundLightColor.withAlpha(77),
                          child: Asset.iconSvg('user', width: 24, color: application.theme.fontLightColor),
                          onPressed: () async {
                            String? address = await BottomDialog.of(context).showInput(
                              title: S.of(context).new_whisper,
                              inputTip: S.of(context).send_to,
                              inputHint: S.of(context).enter_or_select_a_user_pubkey,
                              validator: Validator.of(context).identifierNKN(),
                              contactSelect: true,
                            );
                            if (address?.isNotEmpty == true) {
                              var contact = await ContactSchema.createByType(address, ContactType.stranger);
                              await contactCommon.add(contact);
                              await ChatMessagesScreen.go(context, contact);
                            }
                            Navigator.of(context).pop(); // floatActionBtn
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
