import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';

class WalletImportBySeedLayout extends StatefulWidget {
  final String walletType;
  final Stream<String> qrStream;

  const WalletImportBySeedLayout({this.walletType, this.qrStream});

  @override
  _WalletImportBySeedLayoutState createState() => _WalletImportBySeedLayoutState();
}

class _WalletImportBySeedLayoutState extends State<WalletImportBySeedLayout> with SingleTickerProviderStateMixin {
  GlobalKey _formKey = new GlobalKey<FormState>();

  WalletBloc _walletBloc;
  StreamSubscription _qrSubscription;

  bool _formValid = false;
  TextEditingController _seedController = TextEditingController();
  TextEditingController _nameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _seedFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();

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
    S _localizations = S.of(context);

    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String seed = _seedController?.text;
      String name = _nameController?.text;
      String password = _passwordController?.text;
      logger.d("seed:$seed, name:$name, password:$password");

      try {
        if (widget.walletType == WalletType.nkn) {
          Wallet result = await Wallet.create(hexDecode(seed), config: WalletConfig(password: password));
          WalletSchema wallet = WalletSchema(name: name, address: result?.address, type: WalletType.nkn);
          logger.d("import_nkn - ${wallet.toString()}");

          _walletBloc.add(AddWallet(wallet, result?.keystore, password: password));
        } else {
          // TODO:GG import eth by seed
          // final ethWallet = Ethereum.restoreWalletFromPrivateKey(name: _name, privateKey: _seed, password: _password);
          // Ethereum.saveWallet(ethWallet: ethWallet, walletsBloc: _walletsBloc);
        }

        Loading.dismiss();
        Toast.show(_localizations.success);
        Navigator.pop(context);
      } catch (e) {
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
                    validator: Validator.of(context).seed(),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nameFocusNode),
                    maxLines: 10,
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
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    hintText: _localizations.hint_enter_wallet_name,
                    validator: Validator.of(context).walletName(),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
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
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hintText: _localizations.input_password,
                    validator: Validator.of(context).password(),
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
                        text: widget.walletType == WalletType.nkn ? _localizations.import_nkn_wallet : _localizations.import_ethereum_wallet,
                        width: double.infinity,
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
