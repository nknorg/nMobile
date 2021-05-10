import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/logger.dart';

import '../../app.dart';

class WalletCreateNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/create_nkn';

  @override
  _WalletCreateNKNScreenState createState() => _WalletCreateNKNScreenState();
}

class _WalletCreateNKNScreenState extends State<WalletCreateNKNScreen> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  WalletBloc _walletBloc;
  var _name;
  var _password;

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  _create() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      logger.d("name:$_name, password:$_password");

      Loading.show();

      Wallet result = await Wallet.create(null, config: WalletConfig(password: _password));
      WalletSchema wallet = WalletSchema(name: _name, address: result?.address, type: WalletType.nkn);
      logger.d("create:${wallet.toString()}");

      _walletBloc.add(AddWallet(wallet, result?.keystore));

      Loading.dismiss();
      Navigator.pushReplacementNamed(context, AppScreen.routeName); // TODO:GG home_index
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: _localizations.create_nkn_wallet,
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: Container(
        color: application.theme.backgroundColor4,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: assetImage('wallet/create-wallet.png', width: MediaQuery.of(context).size.width / 2.5),
                ),
              ),
              // TODO:GG keyboard_adapt
              Expanded(
                flex: 1,
                child: Container(
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
                          flex: 1,
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
                                  hintText: _localizations.hint_enter_wallet_name,
                                  focusNode: _nameFocusNode,
                                  onSaved: (v) => _name = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                                  },
                                  textInputAction: TextInputAction.next,
                                  // validator: Validator.of(context).walletName(), // TODO:GG validator
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
                                  focusNode: _passwordFocusNode,
                                  controller: _passwordController,
                                  hintText: _localizations.input_password,
                                  onSaved: (v) => _password = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                                  },
                                  textInputAction: TextInputAction.next,
                                  // validator: Validator.of(context).password(), // TODO:GG validator
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
                                  // validator: Validator.of(context).confrimPassword(_passwordController.text), // TODO:GG validator
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
                              padding: EdgeInsets.only(bottom: 8, top: 8),
                              child: Column(
                                children: <Widget>[
                                  Padding(
                                    padding: EdgeInsets.only(left: 30, right: 30),
                                    child: Button(
                                      text: _localizations.create_wallet,
                                      disabled: !_formValid,
                                      // backgroundColor: _formValid ? application.theme.primaryColor : application.theme.fontColor2, // TODO:GG enable_color + wave
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
