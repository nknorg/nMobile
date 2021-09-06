import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
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
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/screens/chat/no_wallet.dart';
import 'package:nmobile/screens/chat/session_list.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class ChatHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends BaseStateFulWidgetState<ChatHomeScreen> with AutomaticKeepAliveClientMixin, RouteAware, Tag {
  GlobalKey _floatingActionKey = GlobalKey();

  bool dbOpen = false;
  StreamSubscription? _dbOpenedSubscription;

  ContactSchema? _contactMe;
  StreamSubscription? _contactMeUpdateSubscription;

  bool isLoginProgress = false;

  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusChangeSubscription;

  bool firstConnected = true;
  int? appBackgroundAt;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();

    _dbOpenedSubscription = dbCommon.openedStream.listen((event) {
      setState(() {
        dbOpen = event;
        _refreshContactMe();
        _tryLogin();
      });
    });

    // contactMe
    _contactMeUpdateSubscription = contactCommon.meUpdateStream.listen((event) {
      setState(() {
        _contactMe = event;
      });
    });

    // app life
    _appLifeChangeSubscription = application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
      if (states.length > 0) {
        if (states[states.length - 1] == AppLifecycleState.resumed) {
          if (!firstConnected) {
            int between = DateTime.now().millisecondsSinceEpoch - (appBackgroundAt ?? 0);
            if (between >= Settings.clientReAuthGapMs) {
              _tryAuth();
            } else {
              clientCommon.connectCheck();
            }
          }
        } else {
          appBackgroundAt = DateTime.now().millisecondsSinceEpoch;
        }
      }
    });

    // client status
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (clientCommon.client != null && status == ClientConnectStatus.connected) {
        topicCommon.checkAllTopics(refreshSubscribers: firstConnected);
        firstConnected = false;
      }
    });

    // init
    dbOpen = dbCommon.isOpen();
    _refreshContactMe();

    // login
    _tryLogin();

    // TODO:GG auth ?
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
    _dbOpenedSubscription?.cancel();
    _contactMeUpdateSubscription?.cancel();
    _appLifeChangeSubscription?.cancel();
    _clientStatusChangeSubscription?.cancel();
    Routes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future _tryLogin() async {
    if (isLoginProgress) return;
    isLoginProgress = true;

    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _tryLogin - wallet default is empty");
      return;
    }

    if (clientCommon.client != null) {
      clientCommon.connectCheck();
      return;
    }

    // client
    List result = await clientCommon.signIn(wallet, fetchRemote: false);
    final client = result[0];
    final isPwdError = result[1];
    if (client == null) {
      if (isPwdError) {
        logger.i("$TAG - _tryLogin - signIn - password error, close all");
        clientCommon.signOut(closeDB: true);
      } else {
        logger.w("$TAG - _tryLogin - signIn - other error, should be not go here");
        clientCommon.signOut(closeDB: false);
      }
    }

    isLoginProgress = false;
  }

  Future _tryAuth() async {
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _authAgain - wallet default is empty");
      return;
    }
    // password
    String? password = await authorization.getWalletPassword(wallet.address);
    if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
      logger.i("$TAG - _authAgain - signIn - password error, close all");
      await clientCommon.signOut(closeDB: true);
      return;
    }
    // connect
    if (clientCommon.isClientCreated) {
      await clientCommon.connectCheck();
    } else {
      await _tryLogin();
    }
  }

  _refreshContactMe() async {
    if (!dbOpen) return;
    ContactSchema? contact = await contactCommon.getMe();
    setState(() {
      _contactMe = contact;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletLoaded) {
          if (state.isWalletsEmpty()) {
            return ChatNoWalletLayout();
          } else if (state.defaultWallet() == null) {
            return ChatNoConnectLayout();
          }
        }

        return Layout(
          headerColor: application.theme.primaryColor,
          bodyColor: application.theme.backgroundLightColor,
          header: Header(
            titleChild: Container(
              margin: EdgeInsets.only(left: 20),
              child: _contactMe != null
                  ? ContactHeader(
                      contact: _contactMe!,
                      onTap: () {
                        ContactProfileScreen.go(context, contactId: _contactMe!.id);
                      },
                      body: _headerBody(),
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
          body: (_contactMe != null) && dbOpen
              ? ChatSessionListLayout(_contactMe!)
              : Container(
                  child: SpinKitThreeBounce(
                    color: application.theme.primaryColor,
                    size: Global.screenWidth() / 15,
                  ),
                ),
        );
      },
    );
  }

  Widget _headerBody() {
    S _localizations = S.of(context);

    return StreamBuilder<int>(
      stream: clientCommon.statusStream,
      initialData: clientCommon.status,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
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
    );
  }

  _showFloatActionMenu() {
    double btnSize = 48;
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(this.context);
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
                            Navigator.pop(this.context);
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
                              var contact = await ContactSchema.createByType(address, type: ContactType.stranger);
                              await contactCommon.add(contact, notify: true);
                              await ChatMessagesScreen.go(context, contact);
                            }
                            Navigator.pop(this.context); // floatActionBtn
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
