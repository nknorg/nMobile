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
import 'package:nmobile/common/name_service/resolver.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/create_private_group.dart';
import 'package:nmobile/components/layout/chat_topic_search.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/share.dart';
import 'package:nmobile/helpers/validate.dart';
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
import 'package:nmobile/services/task.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ChatHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends BaseStateFulWidgetState<ChatHomeScreen> with AutomaticKeepAliveClientMixin, RouteAware, Tag {
  GlobalKey _floatingActionKey = GlobalKey();

  Completer loginCompleter = Completer();
  StreamSubscription? _intentDataTextStreamSubscription;
  StreamSubscription? _intentDataMediaStreamSubscription;

  String? dbUpdateTip;
  StreamSubscription? _upgradeTipListen;

  bool dbOpen = false;
  StreamSubscription? _dbOpenedSubscription;

  ContactSchema? _contactMe;
  StreamSubscription? _contactMeUpdateSubscription;

  bool isLoginProgress = false;
  bool showSessionList = false;
  bool showSessionListed = false;

  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusChangeSubscription;

  bool firstLogin = true;
  bool firstConnect = true;
  int appBackgroundAt = 0;
  int lastSendPangsAt = 0;
  int lastCheckTopicsAt = 0;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    SettingsStorage.getSettings(SettingsStorage.LAST_SEND_PANGS_AT).then((value) {
      lastSendPangsAt = int.tryParse(value?.toString() ?? "0") ?? 0;
    });
    SettingsStorage.getSettings(SettingsStorage.LAST_CHECK_TOPICS_AT).then((value) {
      lastCheckTopicsAt = int.tryParse(value?.toString() ?? "0") ?? 0;
    });

    // For sharing images coming from outside the app while the app is in the memory
    _intentDataMediaStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile>? values) async {
      if (values == null || values.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithFiles(this.context, values);
    }, onError: (err, stack) {
      handleError(err, stack);
    });

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataTextStreamSubscription = ReceiveSharingIntent.getTextStream().listen((String? value) async {
      if (value == null || value.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithTexts(this.context, [value]);
    }, onError: (err, stack) {
      handleError(err, stack);
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile>? values) async {
      if (values == null || values.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithFiles(this.context, values);
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) async {
      if (value == null || value.isEmpty) return;
      await loginCompleter.future;
      ShareHelper.showWithTexts(this.context, [value]);
    });

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
    _appLifeChangeSubscription = application.appLifeStream.listen((List<AppLifecycleState> states) {
      if (application.isFromBackground(states)) {
        if (!firstLogin) {
          int between = DateTime.now().millisecondsSinceEpoch - appBackgroundAt;
          if (between >= Global.clientReAuthGapMs) {
            _tryAuth(); // await
          } else {
            loginCompleter.complete();
            clientCommon.connectCheck(force: true); // await
          }
        }
      } else if (application.isGoBackground(states)) {
        loginCompleter = Completer();
        appBackgroundAt = DateTime.now().millisecondsSinceEpoch;
      }
    });

    // client status
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (clientCommon.client != null && status == ClientConnectStatus.connected) {
        if (!(loginCompleter.isCompleted == true)) {
          loginCompleter.complete();
        }
        // topic subscribe+permission
        if (firstConnect) {
          firstConnect = false;
          taskService.addTask60(TaskService.KEY_CLIENT_CONNECT, (key) => clientCommon.connectCheck(force: true), delayMs: 1000);
          taskService.addTask30(TaskService.KEY_SUBSCRIBE_CHECK, (key) => topicCommon.checkAndTryAllSubscribe(), delayMs: 1500);
          taskService.addTask30(TaskService.KEY_PERMISSION_CHECK, (key) => topicCommon.checkAndTryAllPermission(), delayMs: 2000);
        }
        // send pangs (3h)
        int lastSendPangsBetween = DateTime.now().millisecondsSinceEpoch - lastSendPangsAt;
        logger.i("$TAG - sendPang2SessionsContact - between:${lastSendPangsBetween - Global.contactsPingGapMs}");
        if (lastSendPangsBetween > Global.contactsPingGapMs) {
          Future.delayed(Duration(seconds: 1)).then((value) {
            if (application.inBackGround) return;
            chatCommon.sendPang2SessionsContact(); // await
            lastSendPangsAt = DateTime.now().millisecondsSinceEpoch;
            SettingsStorage.setSettings(SettingsStorage.LAST_SEND_PANGS_AT, lastSendPangsAt);
          });
        }
        // check topics (6h)
        int lastCheckTopicsBetween = DateTime.now().millisecondsSinceEpoch - lastCheckTopicsAt;
        logger.i("$TAG - checkAllTopics - between:${lastCheckTopicsBetween - Global.topicSubscribeCheckGapMs}");
        if (lastCheckTopicsBetween > Global.topicSubscribeCheckGapMs) {
          Future.delayed(Duration(seconds: 1)).then((value) {
            if (application.inBackGround) return;
            topicCommon.checkAllTopics(refreshSubscribers: false); // await
            lastCheckTopicsAt = DateTime.now().millisecondsSinceEpoch;
            SettingsStorage.setSettings(SettingsStorage.LAST_CHECK_TOPICS_AT, lastCheckTopicsAt);
          });
        }
      }
    });

    // contactMe
    _contactMeUpdateSubscription = contactCommon.meUpdateStream.listen((event) {
      _refreshContactMe();
    });

    // wallet
    taskService.addTask60(TaskService.KEY_WALLET_BALANCE, (key) => walletCommon.queryAllBalance(), delayMs: 1000);

    // login
    _tryLogin(first: true);
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
    _intentDataTextStreamSubscription?.cancel();
    _intentDataMediaStreamSubscription?.cancel();
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

  Future _tryLogin({WalletSchema? wallet, bool first = false}) async {
    // wallet
    wallet = wallet ?? await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _tryLogin - wallet default is empty");
      return;
    }
    if (isLoginProgress) return;
    isLoginProgress = true;

    // fixed:GG ios_152_db
    if (first) await dbCommon.fixIOS_152();

    // client
    Map<String, dynamic> result = await clientCommon.signIn(wallet, fetchRemote: true, loadingVisible: (show, tryTimes) {
      if (tryTimes > 1) return;
      _toggleSessionListShow(true);
    });
    final client = result["client"];
    final isPwdError = result["pwd_error"];
    if (client == null) {
      if (isPwdError) {
        logger.i("$TAG - _tryLogin - signIn - password error, close all");
        _toggleSessionListShow(false);
        await clientCommon.signOut(clearWallet: false, closeDB: true);
      } else {
        logger.e("$TAG - _tryLogin - signIn - other error, should be not go here");
        await clientCommon.signOut(clearWallet: false, closeDB: false);
      }
    } else {
      _toggleSessionListShow(true);
    }

    isLoginProgress = false;
    firstLogin = false;
  }

  Future _tryAuth({bool retry = false}) async {
    if (!clientCommon.isClientCreated && (clientCommon.status != ClientConnectStatus.connecting)) return;
    if (!retry) showSessionListed = false;
    _toggleSessionListShow(false);
    if (!showSessionListed) {
      await Future.delayed(Duration(milliseconds: 100));
      if (!showSessionListed) return _tryAuth(retry: true);
    }
    AppScreen.go(this.context);

    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null) {
      // ui handle, ChatNoWalletLayout()
      logger.i("$TAG - _authAgain - wallet default is empty");
      await clientCommon.signOut(clearWallet: true, closeDB: true);
      return;
    }

    // password
    String? password = await authorization.getWalletPassword(wallet.address);
    if (password == null) return; // android bug return null when fromBackground
    if (!(await walletCommon.isPasswordRight(wallet.address, password))) {
      logger.i("$TAG - _authAgain - signIn - password error, close all");
      Toast.show(Global.locale((s) => s.tip_password_error, ctx: context));
      await clientCommon.signOut(clearWallet: false, closeDB: true);
      return;
    }
    _toggleSessionListShow(true);

    // connect
    clientCommon.connectCheck(force: true, reconnect: true);
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
    ContactSchema? contact = await contactCommon.getMe(needWallet: true);
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
          showSessionListed = true;
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
                        ContactProfileScreen.go(context, contactId: _contactMe?.id);
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
                  Global.locale((s) => s.disconnect, ctx: context),
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
                  Global.locale((s) => s.connected, ctx: context),
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
                  Global.locale((s) => s.connecting, ctx: context),
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
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: Global.screenHeight() / 4,
          minWidth: Global.screenHeight() / 4,
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
                    Global.locale((s) => s.upgrade_db_tips, ctx: context),
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
                              Global.locale((s) => s.new_private_group, ctx: context),
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
                              Global.locale((s) => s.new_group, ctx: context),
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
                              Global.locale((s) => s.new_whisper, ctx: context),
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
                            BottomDialog.of(Global.appContext).showWithTitle(
                              height: 300,
                              title: Global.locale((s) => s.create_private_group, ctx: context),
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
                            BottomDialog.of(Global.appContext).showWithTitle(
                              height: Global.screenHeight() * 0.8,
                              title: Global.locale((s) => s.create_channel, ctx: context),
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
                            String? address = await BottomDialog.of(Global.appContext).showInput(
                              title: Global.locale((s) => s.new_whisper, ctx: context),
                              inputTip: Global.locale((s) => s.send_to, ctx: context),
                              inputHint: Global.locale((s) => s.enter_or_select_a_user_pubkey, ctx: context),
                              validator: Validator.of(context).identifierNKN(),
                              contactSelect: true,
                            );
                            if ((address != null) && address.isNotEmpty) {
                              Resolver resolver = Resolver();
                              String? clientAddress = await resolver.resolve(address);
                              bool resolveOk = false;
                              if ((clientAddress != null) && Validate.isNknChatIdentifierOk(clientAddress)) {
                                resolveOk = true;
                              } else {
                                if (Validate.isNknChatIdentifierOk(address)) {
                                  clientAddress = address;
                                } else {
                                  return;
                                }
                              }
                              ContactSchema? contact = await contactCommon.queryByClientAddress(clientAddress);
                              if (contact != null) {
                                if (contact.type == ContactType.none) {
                                  bool success = await contactCommon.setType(contact.id, ContactType.stranger, notify: true);
                                  if (success) contact.type = ContactType.stranger;
                                }
                              } else {
                                ContactSchema? _contact = await ContactSchema.create(clientAddress, ContactType.stranger);
                                contact = await contactCommon.add(_contact, notify: true);
                              }
                              if (contact == null) return;
                              if (resolveOk) {
                                if (!contact.mappedAddress.contains(address)) {
                                  List<String> added = contact.mappedAddress..add(address);
                                  await contactCommon.setMappedAddress(contact, added.toSet().toList(), notify: true);
                                }
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
