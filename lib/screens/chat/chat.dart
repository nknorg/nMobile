
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/chat/auth_state.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/create_input_group.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/selector_text.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/router/route_observer.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/screens/wallet/import_nkn_eth_wallet.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';


import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';


  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, RouteAware, Tag{
  // final DChatAuthenticationHelper authHelper = DChatAuthenticationHelper();

  WalletsBloc _walletBloc;
  NKNClientBloc _clientBloc;
  AuthBloc _authBloc;
  bool firstShowAuth = false;

  GlobalKey _floatingActionKey = GlobalKey();

  ContactSchema currentUser;

  @override
  void didPopNext() {
    super.didPopNext();
    TimerAuth.instance.pageDidPop();
  }

  @override
  void didPushNext() {
    TimerAuth.instance.pageDidPushed();
    super.didPushNext();
  }

  @override
  void initState() {
    super.initState();

    _walletBloc = BlocProvider.of<WalletsBloc>(context);
    _walletBloc.add(LoadWallets());
    _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    NKNClientCaller.clientBloc = _clientBloc;
    _authBloc = BlocProvider.of<AuthBloc>(context);

    _clientBloc.aBloc = _authBloc;
  }

  @override
  void didChangeDependencies() {
    RouteUtils.routeObserver.subscribe(this, ModalRoute.of(context));
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    RouteUtils.routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _onGetPassword(String password) async{
    WalletSchema wallet = await TimerAuth.loadCurrentWallet();
    TimerAuth.instance.enableAuth();

    print('chat.dart _onGetPassword');
    try{
      var eWallet = await wallet.exportWallet(password);
      var walletAddress = eWallet['address'];
      var publicKey = eWallet['publicKey'];

      if (walletAddress != null && publicKey != null){
        _authBloc.add(AuthToUserEvent(publicKey, walletAddress));
      }
      else{
        NLog.w('Wrong!!!!! walletAddress or publicKey is null');
      }
      if (_clientBloc.state is NKNNoConnectState){
        NLog.w('chat.dart onCreateClient__'+password.toString());
        _clientBloc.add(NKNCreateClientEvent(wallet, password));
      }
    }
    catch(e){
      NLog.w('chat.dart Export wallet E'+e.toString());
      showToast(NL10ns.of(context).password_wrong);
      _authBloc.add(AuthFailEvent());
    }
  }

  void _clickConnect() async{
    String password = await TimerAuth().onCheckAuthGetPassword(context);
    if (password == null || password.length == 0){
      showToast('Please input password');
    }
    else{
      _onGetPassword(password);
    }
  }

  _firstAutoShowAuth() {
    if (TimerAuth.authed == false && firstShowAuth == false){
      firstShowAuth = true;
      Timer(Duration(milliseconds: 200), () async {
        _clickConnect();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, walletState) {
        if (walletState is WalletsLoaded) {
          NLog.w('walletState is___'+walletState.toString());

          if (walletState.wallets.length > 0) {
            _firstAutoShowAuth();
            return BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                NLog.w('authState is___'+authState.toString());

                if (authState is AuthToFrontState){
                  return BlocBuilder<NKNClientBloc, NKNClientState>(
                    builder: (context, clientState) {
                      NLog.w('clientState is___'+clientState.toString());

                      if (clientState is NKNNoConnectState){
                        return _noConnectScreen();
                      }
                      return _chatHomeScreen();
                    },
                  );
                }
                if (authState is AuthToBackgroundState){
                  return _noConnectScreen();
                }
                if (authState is AuthToUserState){
                  return BlocBuilder<NKNClientBloc, NKNClientState>(
                    builder: (context, clientState) {
                      NLog.w('clientState is___'+clientState.toString());

                      if (clientState is NKNNoConnectState){
                        return _noConnectScreen();
                      }
                      return _chatHomeScreen();
                    },
                  );
                }
                return _noConnectScreen();
              },
            );
          }
          else{
            NLog.w('Wallet Length is '+walletState.wallets.length.toString());
          }
          return _noAccountScreen();
        }
        return _noAccountScreen();
      },
    );
  }


  /// NoAccountScreen
  ///
  ///
  Widget _noAccountScreen() {
    return Scaffold(
        backgroundColor: DefaultTheme.primaryColor,
        appBar: Header(
          titleChild: Label(NL10ns.of(context).menu_chat.toUpperCase(), type: LabelType.h2).pad(l: 20),
          hasBack: false,
          backgroundColor: DefaultTheme.primaryColor,
          leading: null,
        ),
        body: Builder(
            builder: (BuildContext context) => BodyBox(
                padding: EdgeInsets.only(left: 20, right: 20),
                color: DefaultTheme.backgroundColor1,
                child: Center(
                    child: SingleChildScrollView(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                        loadAssetChatPng('messages', width: 198.w, height: 144.h).pad(t: 0),
                        Expanded(
                          flex: 0,
                          child: Column(
                            children: <Widget>[
                              Label(
                                NL10ns.of(context).chat_no_wallet_title,
                                type: LabelType.h2,
                                textAlign: TextAlign.center,
                                softWrap: true,
                              ).pad(t: 12),
                            ],
                          ).pad(b: 32),
                        ),
                        Container(
                            padding: 16.pad(t: 24, b: 24),
                            decoration: BoxDecoration(
                              color: DefaultTheme.backgroundColor2,
                              borderRadius: BorderRadius.all(Radius.circular(32)),
                            ),
                            child: Form(
                                key: _formKey,
                                autovalidate: true,
                                onChanged: () {
                                  setState(() {
                                    _formValid = (_formKey.currentState as FormState).validate();
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Label(
                                          NL10ns.of(context).nickname,
                                          type: LabelType.h3,
                                          textAlign: TextAlign.start,
                                        ),
                                        TextSelector(
                                          NL10ns.of(context).import_wallet_as_account,
                                          DefaultTheme.bodySmallFontSize,
                                          Colours.blue_0f,
                                          Colours.gray_81,
                                          fontStyle: FontStyle.italic,
                                          decoration: TextDecoration.underline,
                                          onTap: () {
                                            Navigator.pushNamed(context, ImportWalletScreen.routeName, arguments: WalletType.nkn);
                                          },
                                        ),
                                      ],
                                    ),
                                    Textbox(
                                      hintText: NL10ns.of(context).input_nickname,
                                      focusNode: _nameFocusNode,
                                      onSaved: (v) => _name = v,
                                      onFieldSubmitted: (_) {
                                        FocusScope.of(context).requestFocus(_passwordFocusNode);
                                      },
                                      textInputAction: TextInputAction.next,
                                      validator: Validator.of(context).walletName(),
                                      borderColor: Colours.blue_0f,
                                    ),
                                    Label(
                                      NL10ns.of(context).wallet_password,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    Textbox(
                                      focusNode: _passwordFocusNode,
                                      controller: _passwordController,
                                      hintText: NL10ns.of(context).input_password,
                                      onSaved: (v) => _password = v,
                                      onFieldSubmitted: (_) {
                                        FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                                      },
                                      textInputAction: TextInputAction.next,
                                      validator: Validator.of(context).password(),
                                      password: true,
                                      padding: 0.pad(b: 8),
                                      borderColor: Colours.blue_0f,
                                    ),
                                    Text(
                                      NL10ns.of(context).wallet_password_mach,
                                      style: TextStyle(color: Color(0xFF8F92A1), fontSize: DefaultTheme.bodySmallFontSize),
                                    ),
                                    Label(
                                      NL10ns.of(context).confirm_password,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ).pad(t: 12),
                                    Textbox(
                                      focusNode: _confirmPasswordFocusNode,
                                      hintText: NL10ns.of(context).input_password_again,
                                      validator: Validator.of(context).confrimPassword(_passwordController.text),
                                      password: true,
                                      padding: 0.pad(b: 24),
                                      borderColor: Colours.blue_0f,
                                    ),
                                    Expanded(
                                        flex: 0,
                                        child: SafeArea(
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 48,
                                              child: FlatButton(
                                                padding: const EdgeInsets.all(0),
                                                disabledColor: Colours.light_e5,
                                                disabledTextColor: DefaultTheme.fontColor2,
                                                color: Colours.blue_0f,
                                                colorBrightness: Brightness.dark,
                                                child: Text(
                                                  NL10ns.of(context).create_account,
                                                  style: TextStyle(fontSize: DefaultTheme.h3FontSize, fontWeight: FontWeight.bold, color: null),
                                                ),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                onPressed: _createAccount,
                                              ),
                                            )))
                                  ],
                                ))),
                      ]).pad(b: 68),
                    )
                )
            )
        )
    );
  }

  /// NoConnectScreen
  ///
  ///
  GlobalKey _formKey = GlobalKey<FormState>();
  bool _formValid = false;
  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();
  var _name;
  var _password;
  Widget _noConnectScreen() {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Label(NL10ns.of(context).menu_chat.toUpperCase(), type: LabelType.h2).pad(l: 20.w.d),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        leading: null,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(left: 20.w, right: 20.w),
          color: DefaultTheme.backgroundColor1,
          child: Container(
            child: Flex(
              direction: Axis.vertical,
              children: [
                Expanded(
                  flex: 0,
                  child: Image(image: AssetImage("assets/chat/messages.png"), width: 198.w, height: 144.h).pad(t: 80.h.d),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: [
                      Label(
                        NL10ns.of(context).chat_no_wallet_title,
                        type: LabelType.h2,
                        textAlign: TextAlign.center,
                      ).pad(t: 32.h.d),
                      Label(
                        NL10ns.of(context).click_connect,
                        type: LabelType.bodyRegular,
                        textAlign: TextAlign.center,
                      ).pad(t: 8.h.d)
                    ],
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: BlocBuilder<WalletsBloc, WalletsState>(builder: (context, state) {
                          if (state is WalletsLoaded) {
                            return Button(
                              width: double.infinity,
                              text: NL10ns.of(context).connect,
                              onPressed:_clickConnect,
                            );
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _createAccount() async {
    if (_formValid == false){
      return;
    }
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      EasyLoading.show();

      String keystore = await NknWalletPlugin.createWallet(null, _password);
      var json = jsonDecode(keystore);

      String address = json['Address'];

      await SecureStorage().set('${SecureStorage.PASSWORDS_KEY}:$address', _password);
      _walletBloc.add(AddWallet(WalletSchema(address: address, type: WalletSchema.NKN_WALLET, name: _name), keystore));

      EasyLoading.dismiss();
    }
  }

  /// ChatHomeScreen
  ///
  ///
  Widget _blocHeader(){
    return Header(
      titleChild: GestureDetector(
        onTap: () async {
          if (TimerAuth.authed) {
            currentUser = await ContactSchema.fetchCurrentUser();
            if(currentUser != null){
              Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: currentUser);
            }
            else{
              showToast('database error, can not find contact');
            }
          } else {
            TimerAuth.instance.onCheckAuthGetPassword(context);
          }
        },
        child: Container(
          margin: EdgeInsets.only(left: 12),
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(right: 12),
                child: BlocBuilder<ContactBloc, ContactState>(builder: (context, contactState){
                  if (contactState is UpdateUserInfoState){
                    currentUser = contactState.userInfo;
                  }
                  if (currentUser != null){
                    return CommonUI.avatarWidget(
                      radiusSize: 24,
                      contact: currentUser,
                    );
                  }
                  return BlocBuilder<AuthBloc, AuthState>(builder: (context, authState){
                    if (currentUser == null){
                      if (authState is AuthToUserState){
                        currentUser = authState.currentUser;
                      }
                      if (authState is AuthToFrontState){
                        currentUser = authState.currentUser;
                      }
                    }
                    return Container();
                  });
                })
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BlocBuilder<ContactBloc, ContactState>(builder: (context, contactState){
                      if (contactState is UpdateUserInfoState){
                        currentUser = contactState.userInfo;
                      }
                      if (currentUser != null){
                        return Label(currentUser.name, type: LabelType.h3, dark: true);
                      }
                      return BlocBuilder<AuthBloc, AuthState>(builder: (context, authState){
                        if (currentUser == null){
                          if (authState is AuthToUserState){
                            currentUser = authState.currentUser;
                          }
                          if (authState is AuthToFrontState){
                            currentUser = authState.currentUser;
                          }
                        }
                        if (currentUser != null){
                          return Label(currentUser.name, type: LabelType.h3, dark: true);
                        }
                        return Container();
                      });
                    }),
                    BlocBuilder<NKNClientBloc, NKNClientState>(
                      builder: (context, clientState) {
                        if (clientState is NKNConnectedState) {
                          return Label(NL10ns.of(context).connected, type: LabelType.bodySmall, color: DefaultTheme.riseColor);
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Label(NL10ns.of(context).connecting, type: LabelType.bodySmall, color: DefaultTheme.fontLightColor.withAlpha(200)),
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
        icon: loadAssetIconsImage('addbook', color: Colors.white, width: 24),
        onPressed: () {
          if (TimerAuth.authed) {
            Navigator.of(context).pushNamed(ContactHome.routeName);
          } else {
            TimerAuth.instance.onCheckAuthGetPassword(context);
          }
        },
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
              padding: EdgeInsets.only(bottom: 76, right: 16),
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
                                      color: Colours.dark_0f_a3p,
                                    ),
                                    child: Label(
                                      NL10ns.of(context).new_group,
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
                                    padding: EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      color: Colours.dark_0f_a3p,
                                    ),
                                    child: Label(
                                      NL10ns.of(context).new_whisper,
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
                            color: DefaultTheme.primaryColor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Button(
                                child: loadAssetChatPng('group', width: 22, color: DefaultTheme.fontLightColor),
                                fontColor: DefaultTheme.fontLightColor,
                                backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
                                width: 48,
                                height: 48,
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape:
                                      RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
                                      builder: (context) {
                                        return CreateGroupDialog();
                                      });
//                                  await BottomDialog.of(context).showInputChannelDialog(title: NMobileLocalizations.of(context).create_channel);
                                },
                              ),
                              Button(
                                child: loadAssetIconsImage('user', width: 24, color: DefaultTheme.fontLightColor),
                                fontColor: DefaultTheme.fontLightColor,
                                backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(77),
                                width: 48,
                                height: 48,
                                onPressed: () async {
                                  var address = await BottomDialog.of(context)
                                      .showInputAddressDialog(title: NL10ns.of(context).new_whisper, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
                                  if (address != null) {
                                    ContactSchema contact = ContactSchema(type: ContactType.stranger, clientAddress: address);
                                    await contact.insertContact();
                                    var c = await ContactSchema.fetchContactByAddress(address);
                                    if (c != null) {
                                      Navigator.of(context)
                                          .pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: c));
                                    } else {
                                      Navigator.of(context)
                                          .pushReplacementNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
                                    }
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

  Widget _chatHomeScreen() {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: _blocHeader(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        key: _floatingActionKey,
        elevation: 12,
        backgroundColor: DefaultTheme.primaryColor,
        child: loadAssetIconsImage('pencil', width: 24),
        onPressed: () {
          if (TimerAuth.authed) {
            showBottomMenu();
          } else {
            TimerAuth.instance.onCheckAuthGetPassword(context);
          }
        },
      ).pad(b: MediaQuery.of(context).padding.bottom, r: 4),
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
                              color: DefaultTheme.backgroundLightColor,
//                              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                            ),
                            child: Flex(
                              direction: Axis.vertical,
                              children: <Widget>[
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 0.2),
                                    child: MessagesTab(TimerAuth.instance),
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

  @override
  bool get wantKeepAlive => true;
}

