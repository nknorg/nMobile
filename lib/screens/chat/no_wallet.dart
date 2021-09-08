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
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/logger.dart';

class ChatNoWalletLayout extends BaseStateFulWidget {
  @override
  _ChatNoWalletLayoutState createState() => _ChatNoWalletLayoutState();
}

class _ChatNoWalletLayoutState extends BaseStateFulWidgetState<ChatNoWalletLayout> with Tag {
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
      logger.i("$TAG - name:$name, password:$password");

      List<String> seedRpcList = await Global.getSeedRpcList(null, measure: true);
      Wallet nkn = await Wallet.create(null, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
      logger.i("$TAG - wallet create - nkn:${nkn.toString()}");
      if (nkn.address.isEmpty || nkn.keystore.isEmpty) {
        Loading.dismiss();
        return;
      }

      WalletSchema wallet = WalletSchema(type: WalletType.nkn, address: nkn.address, publicKey: hexEncode(nkn.publicKey), name: name);
      logger.i("$TAG - wallet create - wallet:${wallet.toString()}");

      _walletBloc.add(AddWallet(wallet, nkn.keystore, password, hexEncode(nkn.seed)));

      Loading.dismiss();
      // AppScreen.go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            _localizations.menu_chat,
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
                    _localizations.chat_no_wallet_title,
                    type: LabelType.h2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 8, left: 48, right: 48),
                    child: Label(
                      _localizations.chat_no_wallet_desc,
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
                              _localizations.wallet_name,
                              type: LabelType.h3,
                              textAlign: TextAlign.start,
                            ),
                            TextButton(
                                onPressed: () {
                                  WalletImportScreen.go(context, WalletType.nkn);
                                },
                                child: Label(
                                  _localizations.import_wallet_as_account,
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
            ],
          ),
        ),
      ),
    );
  }
}
