import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class WalletCreateNKNScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/create_nkn';

  static Future go(BuildContext context) {
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _WalletCreateNKNScreenState createState() => _WalletCreateNKNScreenState();
}

class _WalletCreateNKNScreenState extends BaseStateFulWidgetState<WalletCreateNKNScreen> with Tag {
  GlobalKey _formKey = new GlobalKey<FormState>();

  late WalletBloc _walletBloc;

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
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  _create() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String name = _nameController.text;
      String password = _passwordController.text;
      logger.d("$TAG - name:$name, password:$password");

      Wallet result = await Wallet.create(null, config: WalletConfig(password: password));
      if (result.address.isEmpty || result.keystore.isEmpty) return;

      WalletSchema wallet = WalletSchema(name: name, address: result.address, type: WalletType.nkn);
      logger.d("$TAG - wallet create - ${wallet.toString()}");

      _walletBloc.add(AddWallet(wallet, result.keystore, password: password));

      Loading.dismiss();
      AppScreen.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headIconSize = MediaQuery.of(context).size.width / 2.5;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
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
                    child: Asset.image('wallet/create-wallet.png', width: headIconSize),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height - Header.height - headIconSize - 24 * 2 - 30),
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
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                hintText: _localizations.hint_enter_wallet_name,
                                textInputAction: TextInputAction.next,
                                validator: Validator.of(context).walletName(),
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
                                textInputAction: TextInputAction.next,
                                validator: Validator.of(context).password(),
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
                                textInputAction: TextInputAction.done,
                                validator: Validator.of(context).confirmPassword(_passwordController.text),
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
