import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/settings/terms.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class WalletCreateETHScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/create_eth';

  static Future go(BuildContext context) {
    return Navigator.pushNamed(context, routeName);
  }

  @override
  _WalletCreateETHScreenState createState() => _WalletCreateETHScreenState();
}

class _WalletCreateETHScreenState extends BaseStateFulWidgetState<WalletCreateETHScreen> with Tag {
  GlobalKey _formKey = new GlobalKey<FormState>();

  WalletBloc? _walletBloc;

  bool _formValid = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _termsChecked = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  _create() async {
    if (!_termsChecked) {
      Toast.show(Global.locale((s) => s.read_and_agree_terms, ctx: context));
      return;
    }
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String name = _nameController.text;
      String password = _passwordController.text;
      logger.i("$TAG - name:$name, password:$password");

      final eth = Ethereum.create(name: name, password: password);
      String ethAddress = (await eth.address).hex;
      String ethKeystore = await eth.keystore();
      logger.i("$TAG - wallet create - address:$ethAddress - keystore:$ethKeystore - eth:${eth.toString()}");
      if (ethAddress.isEmpty || ethKeystore.isEmpty) {
        Loading.dismiss();
        return;
      }

      WalletSchema wallet = WalletSchema(type: WalletType.eth, address: ethAddress, publicKey: eth.pubKeyHex, name: eth.name);
      logger.i("$TAG - wallet create - ${wallet.toString()}");

      _walletBloc?.add(AddWallet(wallet, ethKeystore, password, eth.privateKeyHex));

      Loading.dismiss();
      AppScreen.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double headIconSize = Global.screenWidth() / 3;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        title: Global.locale((s) => s.create_ethereum_wallet, ctx: context),
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
                                Global.locale((s) => s.wallet_name, ctx: context),
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: FormText(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                hintText: Global.locale((s) => s.hint_enter_wallet_name, ctx: context),
                                validator: Validator.of(context).walletName(),
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => FocusScope.of(context).requestFocus(_passwordFocusNode),
                              ),
                            ),
                            SizedBox(height: 14),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Label(
                                Global.locale((s) => s.wallet_password, ctx: context),
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: FormText(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                hintText: Global.locale((s) => s.input_password, ctx: context),
                                validator: Validator.of(context).password(),
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
                                password: true,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Text(
                                Global.locale((s) => s.wallet_password_mach, ctx: context),
                                style: application.theme.bodyText2,
                              ),
                            ),
                            SizedBox(height: 24),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20),
                              child: Label(
                                Global.locale((s) => s.confirm_password, ctx: context),
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
                              child: FormText(
                                focusNode: _confirmPasswordFocusNode,
                                hintText: Global.locale((s) => s.input_password_again, ctx: context),
                                validator: Validator.of(context).confirmPassword(_passwordController.text),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                                password: true,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 5, right: 0, bottom: 10),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _termsChecked,
                                    activeColor: Colors.blue,
                                    checkColor: Colors.white,
                                    onChanged: (checked) {
                                      setState(() {
                                        _termsChecked = checked ?? false;
                                      });
                                    },
                                  ),
                                  Label(
                                    Global.locale((s) => s.read_and_agree_terms_01, ctx: context),
                                    type: LabelType.bodyRegular,
                                  ),
                                  Button(
                                    child: Label(
                                      Global.locale((s) => s.read_and_agree_terms_02, ctx: context),
                                      color: Colors.blue,
                                      type: LabelType.bodyRegular,
                                      decoration: TextDecoration.underline,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    onPressed: () {
                                      Navigator.pushNamed(context, SettingsTermsScreen.routeName);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 30),
                                child: Button(
                                  text: Global.locale((s) => s.create_wallet, ctx: context),
                                  width: double.infinity,
                                  disabled: !_formValid,
                                  onPressed: _create,
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
            ],
          ),
        ),
      ),
    );
  }
}
