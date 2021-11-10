import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/client/client.dart';
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
import 'package:nmobile/components/tip/toast.dart';
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

  String? dbUpdateTip;
  StreamSubscription? _upgradeTipListen;

  bool dbOpen = false;
  StreamSubscription? _dbOpenedSubscription;

  ContactSchema? _contactMe;
  StreamSubscription? _contactMeUpdateSubscription;

  bool isLoginProgress = false;
  bool showSessionList = false;

  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusChangeSubscription;

  bool firstLogin = true;
  int appBackgroundAt = 0;
  int lastSendPangsAt = 0;
  int lastCheckTopicsAt = 0;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    firstLogin = true;

    // db
    _upgradeTipListen = dbCommon.upgradeTipStream.listen((String? tip) {
      setState(() {
        dbUpdateTip = tip;
      });
    });
    _dbOpenedSubscription = dbCommon.openedStream.listen((event) {
      setState(() {
        dbOpen = event;
        if (event) _refreshContactMe();
        // _tryLogin();
      });
    });

    // app life
    _appLifeChangeSubscription = application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
      if (application.isFromBackground(states)) {
        if (!firstLogin) {
          int between = DateTime.now().millisecondsSinceEpoch - appBackgroundAt;
          if (between >= Global.clientReAuthGapMs) {
            _tryAuth(); // await
          } else {
            clientCommon.connectCheck(); // await
          }
        }
      } else if (application.isGoBackground(states)) {
        appBackgroundAt = DateTime.now().millisecondsSinceEpoch;
      }
    });

    // client status
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (clientCommon.client != null && status == ClientConnectStatus.connected) {
        // send pangs (3h)
        if ((DateTime.now().millisecondsSinceEpoch - lastSendPangsAt) > (3 * 60 * 60 * 1000)) {
          chatCommon.sendPang2SessionsContact(delayMs: 1000); // await
          lastSendPangsAt = DateTime.now().millisecondsSinceEpoch;
        }
        // check topics (1h)
        if ((DateTime.now().millisecondsSinceEpoch - lastCheckTopicsAt) > (1 * 60 * 60 * 1000)) {
          topicCommon.checkAllTopics(refreshSubscribers: false, delayMs: 2000); // await
          lastCheckTopicsAt = DateTime.now().millisecondsSinceEpoch;
        }
      }
    });

    // contactMe
    _contactMeUpdateSubscription = contactCommon.meUpdateStream.listen((event) {
      _refreshContactMe();
    });

    // login
    _tryLogin();
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
    _upgradeTipListen?.cancel();
    _dbOpenedSubscription?.cancel();
    _contactMeUpdateSubscription?.cancel();
    _appLifeChangeSubscription?.cancel();
    _clientStatusChangeSubscription?.cancel();
    Routes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future _tryLogin({WalletSchema? wallet}) async {
    // wallet
    wallet = wallet ?? await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _tryLogin - wallet default is empty");
      return;
    }
    firstLogin = false;
    if (isLoginProgress) return;
    isLoginProgress = true;

    // client
    List result = await clientCommon.signIn(wallet, fetchRemote: true, loadingVisible: (show, tryCount) {
      if (tryCount > 1) return;
      _toggleSessionListShow(true);
    });
    final client = result[0];
    final isPwdError = result[1];
    if (client == null) {
      if (isPwdError) {
        logger.i("$TAG - _tryLogin - signIn - password error, close all");
        _toggleSessionListShow(false);
        await clientCommon.signOut(closeDB: true, clearWallet: false);
      } else {
        logger.w("$TAG - _tryLogin - signIn - other error, should be not go here");
        await clientCommon.signOut(closeDB: false, clearWallet: false);
      }
    } else {
      _toggleSessionListShow(true);
    }

    isLoginProgress = false;
  }

  Future _tryAuth() async {
    if (!clientCommon.isClientCreated && (clientCommon.status != ClientConnectStatus.connecting)) return;
    _toggleSessionListShow(false);
    AppScreen.go(this.context);

    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _authAgain - wallet default is empty");
      await clientCommon.signOut(closeDB: true, clearWallet: true);
      return;
    }

    // password
    String? password = await authorization.getWalletPassword(wallet.address);
    if (password == null) return; // android bug return null when fromBackground
    if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
      logger.i("$TAG - _authAgain - signIn - password error, close all");
      Toast.show(S.of(this.context).tip_password_error);
      await clientCommon.signOut(closeDB: true, clearWallet: false);
      return;
    }
    _toggleSessionListShow(true);

    // connect
    clientCommon.connectCheck(reconnect: true);
  }

  _toggleSessionListShow(bool show) {
    if (showSessionList != show) {
      showSessionList = show; // no check mounted
      setState(() {
        showSessionList = show;
      });
    }
  }

  _refreshContactMe() async {
    ContactSchema? contact = await contactCommon.getMe();
    if ((contact == null) && mounted) {
      return await Future.delayed(Duration(seconds: 1), () => _refreshContactMe());
    }
    setState(() {
      dbOpen = true;
      _contactMe = contact;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        // wallet no loaded
        if (!(state is WalletLoaded)) {
          return Container(
            child: SpinKitThreeBounce(
              color: application.theme.primaryColor,
              size: Global.screenWidth() / 15,
            ),
          );
        }

        if (state.isWalletsEmpty()) {
          return ChatNoWalletLayout();
        } else if ((dbUpdateTip?.isNotEmpty == true) && !dbOpen) {
          return _dbUpgradeTip();
        } else if (!showSessionList || (state.defaultWallet() == null)) {
          return ChatNoConnectLayout((wallet) => _tryLogin(wallet: wallet));
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
        Widget statusWidget;
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

  _dbUpgradeTip() {
    S _localizations = S.of(context);

    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: Global.screenHeight() / 4,
        ),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            CircularProgressIndicator(
              backgroundColor: Colors.white,
            ),
            SizedBox(height: 25),
            Label(
              dbUpdateTip ?? "...",
              type: LabelType.display,
              textAlign: TextAlign.center,
              softWrap: true,
              fontWeight: FontWeight.w500,
            ),
            SizedBox(height: 15),
            ((dbUpdateTip ?? "").length >= 3)
                ? Label(
                    _localizations.upgrade_db_tips,
                    type: LabelType.display,
                    softWrap: true,
                  )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  _showFloatActionMenu() {
    S _localizations = S.of(context);
    double btnSize = 48;

    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
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
                              _localizations.new_group,
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
                              _localizations.new_whisper,
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
                            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                            BottomDialog.of(context).showWithTitle(
                              height: Global.screenHeight() * 0.8,
                              title: _localizations.create_channel,
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
                              title: _localizations.new_whisper,
                              inputTip: _localizations.send_to,
                              inputHint: _localizations.enter_or_select_a_user_pubkey,
                              validator: Validator.of(context).identifierNKN(),
                              contactSelect: true,
                            );
                            if (address?.isNotEmpty == true) {
                              ContactSchema? contact = await contactCommon.queryByClientAddress(address);
                              if (contact != null) {
                                if (contact.type == ContactType.none) {
                                  bool success = await contactCommon.setType(contact.id, ContactType.stranger, notify: true);
                                  if (success) contact.type = ContactType.stranger;
                                }
                              } else {
                                ContactSchema? _contact = await ContactSchema.createByType(address, type: ContactType.stranger);
                                contact = await contactCommon.add(_contact, notify: true);
                              }
                              await ChatMessagesScreen.go(context, contact);
                            }
                            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context); // floatActionBtn
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
