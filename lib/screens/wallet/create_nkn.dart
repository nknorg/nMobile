import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/text_box.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/assets.dart';

class WalletCreateNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/create_nkn';

  @override
  _WalletCreateNKNScreenState createState() => _WalletCreateNKNScreenState();
}

class _WalletCreateNKNScreenState extends State<WalletCreateNKNScreen> {
  // TODO:GG
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  // WalletsBloc _walletsBloc;
  var _name;
  var _password;

  @override
  void initState() {
    super.initState();
    // TODO:GG
    // _walletsBloc = BlocProvider.of<WalletsBloc>(context);
  }

  next() async {
    // TODO:GG
    // if ((_formKey.currentState as FormState).validate()) {
    //   (_formKey.currentState as FormState).save();
    //   EasyLoading.show();
    //
    //   String keystore = await NknWalletPlugin.createWallet(null, _password);
    //   var json = jsonDecode(keystore);
    //
    //   String address = json['Address'];
    //   _walletsBloc.add(AddWallet(
    //       WalletSchema(
    //           address: address, type: WalletSchema.NKN_WALLET, name: _name),
    //       keystore));
    //
    //   await SecureStorage()
    //       .set('${SecureStorage.PASSWORDS_KEY}:$address', _password);
    //   var wallet = WalletSchema(name: _name, address: address);
    //
    //   try {
    //     var w = await wallet.exportWallet(_password);
    //   } catch (e) {
    //     NLog.w('create_nkn_wallet.dart exportWallet E:' + e.toString());
    //   }
    //
    //   EasyLoading.dismiss();
    //   Navigator.of(context).pushReplacementNamed(AppScreen.routeName);
    // }
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
      child: Container(
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
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: application.theme.backgroundLightColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Form(
                    autovalidateMode: AutovalidateMode.always,
                    key: _formKey,
                    onChanged: () {
                      setState(() {
                        _formValid = (_formKey.currentState as FormState).validate();
                      });
                    },
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: EdgeInsets.only(top: 32, left: 20, right: 20, bottom: 10),
                            child: ListView(
                              children: [
                                Label(
                                  _localizations.wallet_name,
                                  type: LabelType.h3,
                                  textAlign: TextAlign.start,
                                ),
                                TextBox(
                                  hintText: _localizations.hint_enter_wallet_name,
                                  focusNode: _nameFocusNode,
                                  onSaved: (v) => _name = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                                  },
                                  textInputAction: TextInputAction.next,
                                  // validator: Validator.of(context).walletName(), // TODO:GG
                                ),
                                SizedBox(height: 14),
                                Label(
                                  _localizations.wallet_password,
                                  type: LabelType.h3,
                                  textAlign: TextAlign.start,
                                ),
                                TextBox(
                                  focusNode: _passwordFocusNode,
                                  controller: _passwordController,
                                  hintText: _localizations.input_password,
                                  onSaved: (v) => _password = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                                  },
                                  textInputAction: TextInputAction.next,
                                  // validator: Validator.of(context).password(), // TODO:GG
                                  password: true,
                                ),
                                Text(
                                  _localizations.wallet_password_mach,
                                  style: application.theme.bodyText2,
                                ),
                                SizedBox(height: 24),
                                Label(
                                  _localizations.confirm_password,
                                  type: LabelType.h3,
                                  textAlign: TextAlign.start,
                                ),
                                TextBox(
                                  focusNode: _confirmPasswordFocusNode,
                                  hintText: _localizations.input_password_again,
                                  // validator: Validator.of(context).confrimPassword(_passwordController.text), // TODO:GG
                                  password: true,
                                ),
                              ],
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
                                      text: _localizations.create_wallet,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
