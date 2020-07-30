import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/image_utils.dart';

class CreateNknWalletScreen extends StatefulWidget {
  static const String routeName = '/wallet/create_nkn_wallet';

  @override
  _CreateNknWalletScreenState createState() => _CreateNknWalletScreenState();
}

class _CreateNknWalletScreenState extends State<CreateNknWalletScreen> {
  final GetIt locator = GetIt.instance;
  GlobalKey _formKey = new GlobalKey<FormState>();
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

  next() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      String keystore = await NknWalletPlugin.createWallet(null, _password);
      var json = jsonDecode(keystore);
      String address = json['Address'];
      _walletsBloc.add(AddWallet(WalletSchema(address: address, type: WalletSchema.NKN_WALLET, name: _name), keystore));
      Navigator.of(context).pushReplacementNamed(AppScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        title: NMobileLocalizations.of(context).create_nkn_wallet_title,
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height),
                  color: DefaultTheme.backgroundColor4,
                  child: Flex(direction: Axis.vertical, children: <Widget>[
                    Expanded(
                      flex: 0,
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(bottom: 32),
                            child: loadAssetWalletImage('create-wallet', width: 142),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 400),
                child: Container(
                  constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height - 280),
                  color: DefaultTheme.backgroundColor4,
                  child: Flex(
                    direction: Axis.vertical,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: DefaultTheme.backgroundLightColor,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Form(
                            key: _formKey,
                            autovalidate: true,
                            onChanged: () {
                              setState(() {
                                _formValid = (_formKey.currentState as FormState).validate();
                              });
                            },
                            child: Flex(
                              direction: Axis.vertical,
                              children: <Widget>[
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Scrollbar(
                                      child: SingleChildScrollView(
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 32, left: 20, right: 20),
                                          child: Flex(
                                            direction: Axis.vertical,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Expanded(
                                                flex: 0,
                                                child: Padding(
                                                  padding: EdgeInsets.only(bottom: 32),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: <Widget>[
                                                      Label(
                                                        NMobileLocalizations.of(context).wallet_name,
                                                        type: LabelType.h3,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      Textbox(
                                                        hintText: NMobileLocalizations.of(context).hint_enter_wallet_name,
                                                        focusNode: _nameFocusNode,
                                                        onSaved: (v) => _name = v,
                                                        onFieldSubmitted: (_) {
                                                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                                                        },
                                                        textInputAction: TextInputAction.next,
                                                        validator: Validator.of(context).walletName(),
                                                      ),
                                                      SizedBox(height: 14.h),
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
                                                      ),
                                                      Text(
                                                        NMobileLocalizations.of(context).wallet_password_mach,
                                                        style: TextStyle(color: Colours.gray_81, fontSize: DefaultTheme.bodySmallFontSize),
                                                      ),
                                                      SizedBox(height: 24.h),
                                                      Label(
                                                        NMobileLocalizations.of(context).confirm_password,
                                                        type: LabelType.h3,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      Textbox(
                                                        focusNode: _confirmPasswordFocusNode,
                                                        hintText: NMobileLocalizations.of(context).input_password_again,
                                                        validator: Validator.of(context).confrimPassword(_passwordController.text),
                                                        password: true,
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
                                ),
                                Expanded(
                                  flex: 0,
                                  child: SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 8, top: 8),
                                      child: Column(
                                        children: <Widget>[
                                          Padding(
                                            padding: EdgeInsets.only(left: 30, right: 30),
                                            child: Button(
                                              text: NMobileLocalizations.of(context).create_wallet,
                                              disabled: !_formValid,
                                              onPressed: next,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
