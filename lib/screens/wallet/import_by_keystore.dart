import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';

class WalletImportByKeystoreLayout extends StatefulWidget {
  final String walletType;

  const WalletImportByKeystoreLayout({this.walletType});

  @override
  _WalletImportByKeystoreLayoutState createState() => _WalletImportByKeystoreLayoutState();
}

class _WalletImportByKeystoreLayoutState extends State<WalletImportByKeystoreLayout> with SingleTickerProviderStateMixin {
  // TODO:GG params
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _keystoreController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _keystoreFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  // WalletsBloc _walletsBloc;
  String _keystore;
  String _name;
  String _password;

  @override
  void initState() {
    super.initState();
    // _walletsBloc = BlocProvider.of<WalletsBloc>(context);

    // TODO:GG lock
    // TimerAuth.onOtherPage = true;
  }

  @override
  void dispose() {
    super.dispose();
    // TODO:GG unlock
    // TimerAuth.onOtherPage = true;
  }

  _import() async {
    // TODO:GG create wallet
    // if ((_formKey.currentState as FormState).validate()) {
    //   (_formKey.currentState as FormState).save();
    //   EasyLoading.show();
    //   try {
    //     if (widget.type == WalletType.nkn) {
    //       String keystoreJson = await NknWalletPlugin.restoreWallet(_keystore, _password);
    //       var keystore = jsonDecode(keystoreJson);
    //       String address = keystore['Address'];
    //
    //       await SecureStorage().set('${SecureStorage.PASSWORDS_KEY}:$address', _password);
    //       _walletsBloc.add(AddWallet(WalletSchema(address: address, type: WalletSchema.NKN_WALLET, name: _name), keystoreJson));
    //     } else {
    //       final ethWallet = Ethereum.restoreWallet(name: _name, keystore: _keystore, password: _password);
    //       Ethereum.saveWallet(ethWallet: ethWallet, walletsBloc: _walletsBloc);
    //     }
    //     EasyLoading.dismiss();
    //     showToast(NL10ns.of(context).success);
    //
    //     Navigator.of(context).pop();
    //   } catch (e) {
    //     EasyLoading.dismiss();
    //     showToast(NL10ns.of(context).password_wrong);
    //     NLog.w('ImportKeystoreWallet__ E:' + e.toString());
    //   }
    // }
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
                    _localizations.import_with_keystore_title,
                    type: LabelType.h2,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32),
                  child: Label(
                    _localizations.import_with_keystore_desc,
                    type: LabelType.bodyRegular,
                    textAlign: TextAlign.start,
                    softWrap: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    _localizations.keystore,
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: FormText(
                    controller: _keystoreController,
                    hintText: _localizations.input_keystore,
                    maxLines: 3,
                    focusNode: _keystoreFocusNode,
                    onSaved: (v) => _keystore = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    suffixIcon: GestureDetector(
                      onTap: () async {
                        // TODO:GG file_picker keystore
                        // File file = await FilePicker.getFile();
                        // if (file != null) {
                        //   String fileText = file.readAsStringSync();
                        //   NLog.w('FileText is_-_____' + fileText.toString());
                        //   NLog.w('FileText length is______' + fileText.length.toString());
                        //   setState(() {
                        //     _keystoreController.text = fileText;
                        //   });
                        // }
                      },
                      child: Container(
                        width: 20,
                        alignment: Alignment.bottomCenter,
                        child: Icon(
                          FontAwesomeIcons.paperclip,
                          size: 20,
                        ),
                      ),
                    ),
                    // validator: widget.walletType == WalletType.nkn ? Validator.of(context).keystore() : Validator.of(context).keystoreEth(), // TODO:GG validator
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
                    // validator: Validator.of(context).walletName(), // TODO:GG validator
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
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: FormText(
                    focusNode: _passwordFocusNode,
                    controller: _passwordController,
                    hintText: _localizations.input_password,
                    onSaved: (v) => _password = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                    },
                    // validator: Validator.of(context).password(), // TODO:GG validator
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
                      // TODO:GG wave
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
