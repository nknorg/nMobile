import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

class WalletImportByKeystoreLayout extends StatefulWidget {
  final String walletType;

  const WalletImportByKeystoreLayout({this.walletType});

  @override
  _WalletImportByKeystoreLayoutState createState() => _WalletImportByKeystoreLayoutState();
}

class _WalletImportByKeystoreLayoutState extends State<WalletImportByKeystoreLayout> with SingleTickerProviderStateMixin {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _keystoreController = TextEditingController();
  FocusNode _keystoreFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();

  WalletBloc _walletBloc;
  String _keystore;
  String _name;
  String _password;

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);

    // TimerAuth.onOtherPage = true; // TODO:GG wallet lock
  }

  @override
  void dispose() {
    super.dispose();
    // TimerAuth.onOtherPage = true; // TODO:GG wallet unlock
  }

  _import() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      logger.d("keystore:$_keystore, name:$_name, password:$_password");

      Loading.show();
      S _localizations = S.of(context);

      try {
        if (widget.walletType == WalletType.nkn) {
          Wallet result = await Wallet.restore(_keystore, config: WalletConfig(password: _password));
          WalletSchema wallet = WalletSchema(name: _name, address: result?.address, type: WalletType.nkn);
          logger.d("import_nkn - ${wallet.toString()}");

          _walletBloc.add(AddWallet(wallet, result?.keystore, password: _password));
        } else {
          // TODO:GG import eth by keystore
          // final ethWallet = Ethereum.restoreWallet(name: _name, keystore: _keystore, password: _password);
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
                    focusNode: _keystoreFocusNode,
                    hintText: _localizations.input_keystore,
                    validator: widget.walletType == WalletType.nkn ? Validator.of(context).keystoreNKN() : Validator.of(context).keystoreETH(),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nameFocusNode),
                    onSaved: (v) => _keystore = v,
                    maxLines: 3,
                    suffixIcon: GestureDetector(
                      onTap: () async {
                        FilePickerResult result = await FilePicker.platform.pickFiles(
                          allowMultiple: false,
                          type: FileType.any,
                        );
                        logger.d("result:$result");
                        if (result != null && result.files != null && result.files.isNotEmpty) {
                          String path = result.files?.first?.path;
                          File picked = File(path);
                          String keystore = picked.readAsStringSync();
                          logger.d("picked:$keystore");

                          setState(() => _keystoreController.text = keystore);
                        }
                      },
                      child: Container(
                        width: 20,
                        child: Icon(
                          FontAwesomeIcons.paperclip,
                          size: 20,
                        ),
                      ),
                    ),
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
                    validator: Validator.of(context).walletName(),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                    onSaved: (v) => _name = v,
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
                    hintText: _localizations.input_password,
                    validator: Validator.of(context).password(),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                    onSaved: (v) => _password = v,
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
