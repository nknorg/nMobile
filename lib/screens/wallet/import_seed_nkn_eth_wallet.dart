import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/event/eventbus.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/eth_erc20_token.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/model/entity/wallet.dart';
import 'package:oktoast/oktoast.dart';

class ImportSeedWallet extends StatefulWidget {
  final WalletType type;

  const ImportSeedWallet({this.type});

  @override
  _ImportSeedWalletState createState() => _ImportSeedWalletState();
}

class _ImportSeedWalletState extends State<ImportSeedWallet>
    with SingleTickerProviderStateMixin {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  TextEditingController _seedController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _seedFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();
  WalletsBloc _walletsBloc;
  var _seed;
  var _name;
  var _password;
  StreamSubscription _qrSubscription;

  @override
  void initState() {
    super.initState();
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _qrSubscription = eventBus.on<QMScan>().listen((event) {
      setState(() {
        _seedController.text = event.content;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _qrSubscription.cancel();
  }

  next() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      EasyLoading.show();
      try {
        if (widget.type == WalletType.nkn) {
          String keystore =
              await NknWalletPlugin.createWallet(_seed, _password);
          var json = jsonDecode(keystore);
          String address = json['Address'];
          _walletsBloc.add(AddWallet(
              WalletSchema(
                  address: address, type: WalletSchema.NKN_WALLET, name: _name),
              keystore));
        } else {
          final ethWallet = Ethereum.restoreWalletFromPrivateKey(
              name: _name, privateKey: _seed, password: _password);
          Ethereum.saveWallet(ethWallet: ethWallet, walletsBloc: _walletsBloc);
        }
        EasyLoading.dismiss();
        showToast(NL10ns.of(context).success);

        Navigator.of(context).pop();
      } catch (e) {
        EasyLoading.dismiss();
        showToast(e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
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
              padding: EdgeInsets.only(top: 0),
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
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Label(
                                    NL10ns.of(context).import_with_seed_title,
                                    type: LabelType.h2,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 32),
                                  child: Label(
                                    NL10ns.of(context).import_with_seed_desc,
                                    type: LabelType.bodyRegular,
                                    textAlign: TextAlign.start,
                                    softWrap: true,
                                  ),
                                ),
                                Label(
                                  NL10ns.of(context).seed,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  controller: _seedController,
                                  focusNode: _seedFocusNode,
                                  hintText: NL10ns.of(context).input_seed,
                                  onSaved: (v) => _seed = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context)
                                        .requestFocus(_nameFocusNode);
                                  },
                                  validator: Validator.of(context).seed(),
                                ),
                                Label(
                                  NL10ns.of(context).wallet_name,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  focusNode: _nameFocusNode,
                                  hintText:
                                      NL10ns.of(context).hint_enter_wallet_name,
                                  onSaved: (v) => _name = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context)
                                        .requestFocus(_passwordFocusNode);
                                  },
                                  textInputAction: TextInputAction.next,
                                  validator: Validator.of(context).walletName(),
                                ),
                                Label(
                                  NL10ns.of(context).wallet_password,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  focusNode: _passwordFocusNode,
                                  controller: _passwordController,
                                  hintText: NL10ns.of(context).input_password,
                                  onSaved: (v) => _password = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(
                                        _confirmPasswordFocusNode);
                                  },
                                  validator: Validator.of(context).password(),
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
                        text: widget.type == WalletType.nkn
                            ? NL10ns.of(context).import_nkn_wallet
                            : NL10ns.of(context).import_ethereum_wallet,
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
    );
  }
}
