import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/utils/asset.dart';

class WalletCreateETHScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/create_eth';

  static Future go(BuildContext context) {
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _WalletCreateETHScreenState createState() => _WalletCreateETHScreenState();
}

class _WalletCreateETHScreenState extends BaseStateFulWidgetState<WalletCreateETHScreen> {
  GlobalKey _formKey = new GlobalKey<FormState>();

  // WalletsBloc _walletsBloc;

  bool _formValid = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    // _walletsBloc = BlocProvider.of<WalletsBloc>(context);
  }

  _create() async {
    // TODO:GG eth create
    // if ((_formKey.currentState as FormState).validate()) {
    //   (_formKey.currentState as FormState).save();
    //   final eth = Ethereum.createWallet(name: _name, password: _password);
    //   Ethereum.saveWallet(ethWallet: eth, walletsBloc: _walletsBloc);
    //
    //   // Password
    //   Navigator.of(context).pushReplacementNamed(AppScreen.routeName, arguments: {
    //   AppScreen.argIndex: 1,
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headIconSize = Global.screenWidth() / 3;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        title: _localizations.create_ethereum_wallet,
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: Container(
        color: application.theme.backgroundColor4,
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
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Asset.svg('ethereum-logo', width: headIconSize),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints.expand(height: Global.screenHeight() - Header.height - headIconSize - 24 * 2 - 30),
                decoration: BoxDecoration(
                  color: application.theme.backgroundLightColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.always,
                  onChanged: () {
                    setState(() {
                      _formValid = (_formKey.currentState as FormState).validate();
                    });
                  },
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: ListView(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20, top: 32),
                              child: Label(
                                _localizations.wallet_name,
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: FormText(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                hintText: _localizations.hint_enter_wallet_name,
                                validator: Validator.of(context).walletName(),
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => FocusScope.of(context).requestFocus(_passwordFocusNode),
                              ),
                            ),
                            SizedBox(height: 14),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Label(
                                _localizations.wallet_password,
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: FormText(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                hintText: _localizations.input_password,
                                validator: Validator.of(context).password(),
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
                                password: true,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Text(
                                _localizations.wallet_password_mach,
                                style: application.theme.bodyText2,
                              ),
                            ),
                            SizedBox(height: 24),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Label(
                                _localizations.confirm_password,
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20, bottom: 32),
                              child: FormText(
                                focusNode: _confirmPasswordFocusNode,
                                hintText: _localizations.input_password_again,
                                validator: Validator.of(context).confirmPassword(_passwordController.text),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                                password: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 30),
                                  child: Button(
                                    text: _localizations.create_wallet,
                                    width: double.infinity,
                                    disabled: !_formValid,
                                    onPressed: _create,
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
            ],
          ),
        ),
      ),
    );
  }
}
