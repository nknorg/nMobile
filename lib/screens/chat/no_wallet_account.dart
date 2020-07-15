import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/selector_text.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/chat/home.dart';
import 'package:nmobile/screens/wallet/import_nkn_wallet.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';

class NoWalletAccount extends StatefulWidget {
  static const String routeName = '/chat/no_wallet_account';

  final ActivePage activePage;

  NoWalletAccount(this.activePage);

  @override
  _NoWalletAccountState createState() => _NoWalletAccountState();
}

class _NoWalletAccountState extends State<NoWalletAccount> {
  GlobalKey _formKey = GlobalKey<FormState>();
  bool _formValid = false;
  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();
  WalletsBloc _walletsBloc;
  var _name;
  var _password;

  @override
  void initState() {
    super.initState();
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
  }

  _createAccount() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      EasyLoading.show();
      String keystore = await NknWalletPlugin.createWallet(null, _password);
      var json = jsonDecode(keystore);
      String address = json['Address'];
      _walletsBloc.add(AddWallet(WalletSchema(address: address, type: WalletSchema.NKN_WALLET, name: _name), keystore));
      EasyLoading.dismiss();
      Navigator.of(context).pushReplacementNamed(ChatHome.routeName, arguments: widget.activePage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: DefaultTheme.primaryColor,
        appBar: Header(
          titleChild: Label(NMobileLocalizations.of(context).menu_chat.toUpperCase(), type: LabelType.h2).pad(l: 20),
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
                            NMobileLocalizations.of(context).chat_no_wallet_title,
                            type: LabelType.h2,
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ).pad(t: 12),
//                          Label(
//                            NMobileLocalizations.of(context).chat_no_wallet_desc,
//                            type: LabelType.bodyRegular,
//                            textAlign: TextAlign.center,
//                            softWrap: true,
//                          ).padd(48.pad(t: 8, b: 0)),
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
                                      NMobileLocalizations.of(context).nickname,
                                      type: LabelType.h3,
                                      textAlign: TextAlign.start,
                                    ),
                                    TextSelector(
                                      NMobileLocalizations.of(context).import_wallet_as_account,
                                      DefaultTheme.bodySmallFontSize,
                                      Colours.blue_0f,
                                      Colours.gray_81,
                                      fontStyle: FontStyle.italic,
                                      decoration: TextDecoration.underline,
                                      onTap: () {
                                        Navigator.pushNamed(context, ImportNknWalletScreen.routeName);
                                      },
                                    ),
                                  ],
                                ),
                                Textbox(
                                  hintText: NMobileLocalizations.of(context).input_nickname,
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
                                  NMobileLocalizations.of(context).wallet_password,
                                  type: LabelType.h3,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  focusNode: _passwordFocusNode,
                                  controller: _passwordController,
                                  hintText: NMobileLocalizations.of(context).input_password,
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
                                  NMobileLocalizations.of(context).wallet_password_mach,
                                  style: TextStyle(color: Color(0xFF8F92A1), fontSize: DefaultTheme.bodySmallFontSize),
                                ),
                                Label(
                                  NMobileLocalizations.of(context).confirm_password,
                                  type: LabelType.h3,
                                  textAlign: TextAlign.start,
                                ).pad(t: 12),
                                Textbox(
                                  focusNode: _confirmPasswordFocusNode,
                                  hintText: NMobileLocalizations.of(context).input_password_again,
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
                                          NMobileLocalizations.of(context).create_account,
                                          style: TextStyle(fontSize: DefaultTheme.h3FontSize, fontWeight: FontWeight.bold, color: null),
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        onPressed: _formValid ? _createAccount : null,
                                      ),
                                    )))
                              ],
                            ))),
                  ]).pad(b: 68),
                )))));
  }
}
