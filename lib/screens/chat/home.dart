import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/create_private_group.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/chat_topic_search.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
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

  StreamSubscription? _upgradeTipListen;
  StreamSubscription? _dbOpenedSubscription;

  StreamSubscription? _contactMeUpdateSubscription;

  StreamSubscription? _clientStatusChangeSubscription;

  String? dbUpdateTip;
  bool dbOpen = false;

  ContactSchema? _contactMe;

  int clientConnectStatus = ClientConnectStatus.connecting;

  bool isLoginProgress = false;
  bool connected = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();

    // db
    _upgradeTipListen = dbCommon.upgradeTipStream.listen((String? tip) {
      setState(() {
        dbUpdateTip = tip;
      });
    });
    _dbOpenedSubscription = dbCommon.openedStream.listen((open) {
      setState(() {
        dbOpen = open;
      });
      if (open) _refreshContactMe(deviceInfo: true);
    });

    // contactMe
    _contactMeUpdateSubscription = contactCommon.meUpdateStream.listen((event) {
      _refreshContactMe();
    });

    // clientStatus
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (clientConnectStatus != status) {
        setState(() {
          clientConnectStatus = status;
        });
      }
    });

    // login
    _tryLogin(init: true);
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
    _clientStatusChangeSubscription?.cancel();
    Routes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<bool> _tryLogin({WalletSchema? wallet, bool init = false}) async {
    if (clientCommon.isClientConnecting || clientCommon.isClientReconnecting || clientCommon.isClientOK) return true;
    if (isLoginProgress) return false;
    isLoginProgress = true;
    // view
    _setConnected(false);
    // wallet
    wallet = wallet ?? await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _tryLogin - wallet default is empty");
      isLoginProgress = false;
      return false;
    }
    // client
    bool success = await clientCommon.signIn(wallet, toast: true, loading: (visible, input, dbOpen) {
      if (dbOpen) _setConnected(true);
    });
    // check
    if (success) chatCommon.startInitChecks(delay: 500); // await
    // view
    _setConnected(success);
    isLoginProgress = false;
    return success;
  }

  _setConnected(bool show) {
    if (connected != show) {
      connected = show; // no check mounted
      setState(() {
        connected = show;
      });
    }
  }

  _refreshContactMe({bool deviceInfo = false}) async {
    ContactSchema? contact = await contactCommon.getMe(canAdd: true, fetchWalletAddress: true);
    if ((contact == null) && mounted) {
      return await Future.delayed(Duration(milliseconds: 500), () {
        _refreshContactMe(deviceInfo: deviceInfo);
      });
    }
    setState(() {
      dbOpen = true;
      _contactMe = contact;
    });
    if (deviceInfo) {
      await deviceInfoCommon.getMe(selfAddress: contact?.address, canAdd: true, fetchDeviceToken: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        // wallet loaded no
        if (!(state is WalletLoaded)) {
          return Container(
            child: SpinKitThreeBounce(
              color: application.theme.primaryColor,
              size: Settings.screenWidth() / 15,
            ),
          );
        }
        // wallet loaded yes
        if (state.isWalletsEmpty()) {
          return ChatNoWalletLayout();
        } else if (!dbOpen && (dbUpdateTip?.isNotEmpty == true)) {
          return _dbUpgradeTip();
        } else if (!connected || (state.defaultWallet() == null)) {
          return ChatNoConnectLayout((w) => _tryLogin(wallet: w));
        }
        // client connected
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
                        ContactProfileScreen.go(context, address: _contactMe?.address);
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
                    size: Settings.screenWidth() / 15,
                  ),
                ),
        );
      },
    );
  }

  Widget _headerBody() {
    Widget statusWidget;
    switch (clientConnectStatus) {
      case ClientConnectStatus.connecting:
      case ClientConnectStatus.connectPing:
        statusWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Label(
              Settings.locale((s) => s.connecting, ctx: context),
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
      case ClientConnectStatus.connected:
        statusWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Label(
              Settings.locale((s) => s.connected, ctx: context),
              type: LabelType.h4,
              color: application.theme.successColor,
            ),
          ],
        );
        break;
      case ClientConnectStatus.disconnecting:
        statusWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Label(
              Settings.locale((s) => s.disconnect, ctx: context),
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
      case ClientConnectStatus.disconnected:
        statusWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Label(
              Settings.locale((s) => s.disconnect, ctx: context),
              type: LabelType.h4,
              color: application.theme.strongColor,
            ),
          ],
        );
        break;
      default:
        statusWidget = SizedBox.shrink();
        break;
    }
    return statusWidget;
  }

  _dbUpgradeTip() {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: Settings.screenHeight() / 4,
          minWidth: Settings.screenHeight() / 4,
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
                    Settings.locale((s) => s.upgrade_db_tips, ctx: context),
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
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                              Settings.locale((s) => s.new_private_group, ctx: context),
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
                              Settings.locale((s) => s.new_public_group, ctx: context),
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
                              Settings.locale((s) => s.new_whisper, ctx: context),
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
                          child: Asset.iconSvg('lock', width: 22, color: application.theme.fontLightColor),
                          onPressed: () async {
                            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                            BottomDialog.of(Settings.appContext).showWithTitle(
                              height: 300,
                              title: Settings.locale((s) => s.create_private_group, ctx: context),
                              child: CreatePrivateGroup(),
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        Button(
                          width: btnSize,
                          height: btnSize,
                          fontColor: application.theme.fontLightColor,
                          backgroundColor: application.theme.backgroundLightColor.withAlpha(77),
                          child: Asset.iconSvg('group', width: 22, color: application.theme.fontLightColor),
                          onPressed: () async {
                            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                            BottomDialog.of(Settings.appContext).showWithTitle(
                              height: Settings.screenHeight() * 0.8,
                              title: Settings.locale((s) => s.create_channel, ctx: context),
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
                            String? address = await BottomDialog.of(Settings.appContext).showInput(
                              title: Settings.locale((s) => s.new_whisper, ctx: context),
                              inputTip: Settings.locale((s) => s.send_to, ctx: context),
                              inputHint: Settings.locale((s) => s.enter_or_select_a_user_pubkey, ctx: context),
                              // validator: Validator.of(context).identifierNKN(),
                              contactSelect: true,
                            );
                            Loading.show();
                            ContactSchema? contact = await contactCommon.resolveByAddress(address, canAdd: true);
                            Loading.dismiss();
                            if (contact != null) await ChatMessagesScreen.go(context, contact);
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
