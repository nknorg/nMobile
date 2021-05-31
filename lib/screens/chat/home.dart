import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/create_group.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/session_list.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/utils/asset.dart';

import 'no_wallet.dart';

class ChatHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends BaseStateFulWidgetState<ChatHomeScreen> {
  GlobalKey _floatingActionKey = GlobalKey();

  ContactSchema? _currentUser;

  // NKNClientBloc _clientBloc;
  // AuthBloc _authBloc;
  // bool firstShowAuth = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();

    // _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    // NKNClientCaller.clientBloc = _clientBloc;
    // _authBloc = BlocProvider.of<AuthBloc>(context);
    // _clientBloc.aBloc = _authBloc;
  }

  // _pushToSingleChat(ContactSchema contactInfo) async {
  //   Navigator.of(context).pushNamed(MessageChatPage.routeName, arguments: contactInfo);
  // }

  // void _onGetPassword(String password) async {
  //   WalletSchema wallet = await TimerAuth.loadCurrentWallet();
  //   TimerAuth.instance.enableAuth();
  //
  //   print('chat.dart _onGetPassword');
  //
  //   try {
  //     var eWallet = await wallet.exportWallet(password);
  //     var walletAddress = eWallet['address'];
  //     var publicKey = eWallet['publicKey'];
  //
  //     if (walletAddress != null && publicKey != null) {
  //       _authBloc.add(AuthToUserEvent(publicKey, walletAddress));
  //     }
  //
  //     if (_clientBloc.state is NKNNoConnectState) {
  //       _clientBloc.add(NKNCreateClientEvent(wallet, password));
  //     }
  //   } catch (e) {
  //     NLog.w('chat.dart Export wallet E' + e.toString());
  //     showToast(NL10ns.of(context).password_wrong);
  //     _authBloc.add(AuthFailEvent());
  //   }
  // }

  // void _clickConnect() async {
  //   String password = await TimerAuth().onCheckAuthGetPassword(context);
  //   if (password == null || password.length == 0) {
  //     showToast('Please input password');
  //   } else {
  //     NLog.w('Password is___' + password.toString());
  //     _onGetPassword(password);
  //   }
  // }

  // _firstAutoShowAuth() {
  //   if (TimerAuth.authed == false && firstShowAuth == false) {
  //     firstShowAuth = true;
  //     Timer(Duration(milliseconds: 200), () async {
  //       _clickConnect();
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    // _firstAutoShowAuth() TODO:GG auth

    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletLoaded) {
          if (state.isWalletsEmpty()) {
            return ChatNoWalletLayout();
          }
        }
        return StreamBuilder<int>(
          stream: chatCommon.statusStream,
          initialData: chatCommon.status,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            if (snapshot.data == ChatConnectStatus.disconnected) {
              return ChatNoConnectLayout();
            } else {
              return Layout(
                headerColor: application.theme.primaryColor,
                bodyColor: application.theme.backgroundLightColor,
                header: Header(
                  titleChild: Container(
                    margin: EdgeInsets.only(left: 20),
                    child: StreamBuilder<ContactSchema?>(
                      initialData: contactCommon.currentUser,
                      stream: contactCommon.updateStream.where((event) => event.id == contactCommon.currentUser?.id),
                      builder: (BuildContext context, AsyncSnapshot<ContactSchema?> snapshot) {
                        ContactSchema? _schema = snapshot.data ?? contactCommon.currentUser;
                        if (_schema == null) return SizedBox.shrink();
                        return ContactHeader(
                          contact: _schema,
                          onTap: () {
                            ContactProfileScreen.go(context, contactId: _schema.id);
                          },
                          body: StreamBuilder<int>(
                            stream: chatCommon.statusStream,
                            initialData: chatCommon.status,
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
                        );
                      },
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
                body: ChatSessionListLayout(),
              );
            }
          },
        );
      },
    );
  }

  _showFloatActionMenu() {
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
              padding: EdgeInsets.only(bottom: 67, right: 16),
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
                                  Navigator.of(context).pop();
                                  BottomDialog.of(context).showWithTitle(
                                    height: 650,
                                    title: S.of(context).create_channel,
                                    child: CreateGroupDialog(),
                                  );
                                  // TODO:GG chat 1t9
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
                                  String? address = await BottomDialog.of(context).showInput(
                                    title: S.of(context).new_whisper,
                                    inputTip: S.of(context).send_to,
                                    inputHint: S.of(context).enter_or_select_a_user_pubkey,
                                    validator: Validator.of(context).identifierNKN(),
                                    contactSelect: true,
                                  );
                                  if (address != null) {
                                    Navigator.of(context).pop();
                                    int count = await ContactStorage().queryCountByClientAddress(address);
                                    var contact = ContactSchema(
                                      type: ContactType.stranger,
                                      clientAddress: address,
                                    );
                                    if (count == 0) {
                                      await contactCommon.add(contact);
                                    }
                                    await ChatMessagesScreen.go(context, contact);
                                  } else {
                                    Navigator.of(context).pop();
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
