import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
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
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/logger.dart';

class ChatNoWalletLayout extends BaseStateFulWidget {
  @override
  _ChatNoWalletLayoutState createState() => _ChatNoWalletLayoutState();
}

class _ChatNoWalletLayoutState extends BaseStateFulWidgetState<ChatNoWalletLayout> with Tag {
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

      List<String> seedRpcList = await Global.getRpcServers(null, measure: true);
      Wallet nkn = await Wallet.create(null, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
      logger.i("$TAG - wallet create - nkn:${nkn.toString()}");
      if (nkn.address.isEmpty || nkn.keystore.isEmpty) {
        Loading.dismiss();
        return;
      }

      WalletSchema wallet = WalletSchema(type: WalletType.nkn, address: nkn.address, publicKey: hexEncode(nkn.publicKey), name: name);
      logger.i("$TAG - wallet create - wallet:${wallet.toString()}");

      _walletBloc?.add(AddWallet(wallet, nkn.keystore, password, hexEncode(nkn.seed)));

      Loading.dismiss();
      // AppScreen.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            Global.locale((s) => s.menu_chat, ctx: context),
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 40, bottom: 110),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: <Widget>[
                  Label(
                    Global.locale((s) => s.chat_no_wallet_title, ctx: context),
                    type: LabelType.h2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 8, left: 48, right: 48),
                    child: Label(
                      Global.locale((s) => s.chat_no_wallet_desc, ctx: context),
                      type: LabelType.bodySmall,
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  )
                ],
              ),
              SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.only(left: 20, right: 20),
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                decoration: BoxDecoration(
                  color: application.theme.backgroundColor2,
                  borderRadius: BorderRadius.all(Radius.circular(32)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(left: 20, right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Label(
                              Global.locale((s) => s.wallet_name, ctx: context),
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            TextButton(
                                onPressed: () {
                                  WalletImportScreen.go(context, WalletType.nkn);
                                },
                                child: Label(
                                  Global.locale((s) => s.import_wallet_as_account, ctx: context),
                                  type: LabelType.bodyRegular,
                                  color: application.theme.primaryColor,
                                  decoration: TextDecoration.underline,
                                  fontStyle: FontStyle.italic,
                                )),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 20, right: 20),
                        child: FormText(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: Global.locale((s) => s.hint_enter_wallet_name, ctx: context),
                          textInputAction: TextInputAction.next,
                          validator: Validator.of(context).walletName(),
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
                          textInputAction: TextInputAction.next,
                          validator: Validator.of(context).password(),
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
                          textInputAction: TextInputAction.done,
                          validator: Validator.of(context).confirmPassword(_passwordController.text),
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
    );
  }
}
