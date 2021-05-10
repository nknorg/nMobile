import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class WalletImportBySeedLayout extends StatefulWidget {
  final String walletType;
  final Stream<String> qrStream;

  const WalletImportBySeedLayout({this.walletType, this.qrStream});

  @override
  _WalletImportBySeedLayoutState createState() => _WalletImportBySeedLayoutState();
}

class _WalletImportBySeedLayoutState extends State<WalletImportBySeedLayout> with SingleTickerProviderStateMixin {
  GlobalKey _formKey = new GlobalKey<FormState>();
  StreamSubscription _qrSubscription;
  bool _formValid = false;

  TextEditingController _seedController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _seedFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  WalletBloc _walletBloc;
  var _seed;
  var _name;
  var _password;

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
    _qrSubscription = widget.qrStream?.listen((event) {
      setState(() {
        _seedController.text = event;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _qrSubscription.cancel();
  }

  _import() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      logger.d("seed:$_seed, name:$_name, password:$_password");

      Loading.show();
      S _localizations = S.of(context);

      try {
        if (widget.walletType == WalletType.nkn) {
          Wallet result = await Wallet.create(_seed, config: WalletConfig(password: _password));
          WalletSchema wallet = WalletSchema(name: _name, address: result?.address, type: WalletType.nkn);
          logger.d("import_nkn:${wallet.toString()}");

          _walletBloc.add(AddWallet(wallet, result?.keystore, password: _password));
        } else {
          // TODO:GG import eth by seed
          // final ethWallet = Ethereum.restoreWalletFromPrivateKey(name: _name, privateKey: _seed, password: _password);
          // Ethereum.saveWallet(ethWallet: ethWallet, walletsBloc: _walletsBloc);
        }
        Loading.dismiss();
        Toast.show(_localizations.success);

        Navigator.pop(context);
      } catch (e) {
        logger.e("import_by_seed", e);
        Loading.dismiss();
        Toast.show(e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Form(
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
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
                  child: Label(
                    _localizations.import_with_seed_title,
                    type: LabelType.h2,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32),
                  child: Label(
                    _localizations.import_with_seed_desc,
                    type: LabelType.bodyRegular,
                    textAlign: TextAlign.start,
                    softWrap: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    _localizations.seed,
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: FormText(
                    controller: _seedController,
                    focusNode: _seedFocusNode,
                    hintText: _localizations.input_seed,
                    onSaved: (v) => _seed = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_nameFocusNode);
                    },
                    validator: Validator.of(context).seed(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    _localizations.wallet_name,
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: FormText(
                    focusNode: _nameFocusNode,
                    hintText: _localizations.hint_enter_wallet_name,
                    onSaved: (v) => _name = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    textInputAction: TextInputAction.next,
                    validator: Validator.of(context).walletName(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    _localizations.wallet_password,
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  child: FormText(
                    focusNode: _passwordFocusNode,
                    controller: _passwordController,
                    hintText: _localizations.input_password,
                    onSaved: (v) => _password = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                    },
                    validator: Validator.of(context).password(),
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
                        text: widget.walletType == WalletType.nkn ? _localizations.import_nkn_wallet : _localizations.import_ethereum_wallet,
                        disabled: !_formValid,
                        onPressed: _import,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
