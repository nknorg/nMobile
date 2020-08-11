import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:oktoast/oktoast.dart';

class ImportKeystoreNknWallet extends StatefulWidget {
  @override
  _ImportKeystoreNknWalletState createState() => _ImportKeystoreNknWalletState();
}

class _ImportKeystoreNknWalletState extends State<ImportKeystoreNknWallet> with SingleTickerProviderStateMixin {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  TextEditingController _keystoreController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _keystoreFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();
  WalletsBloc _walletsBloc;
  String _keystore;
  String _name;
  String _password;

  @override
  void initState() {
    super.initState();
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
  }

  next() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      EasyLoading.show();
      try {
        String keystoreJson = await NknWalletPlugin.restoreWallet(_keystore, _password);
        var keystore = jsonDecode(keystoreJson);
        String address = keystore['Address'];
        _walletsBloc.add(AddWallet(WalletSchema(address: address, type: 'nkn', name: _name), keystoreJson));
        EasyLoading.dismiss();
        showToast(NL10ns.of(context).success);
        Navigator.of(context).pushReplacementNamed(AppScreen.routeName);
      } catch (e) {
        EasyLoading.dismiss();
        if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
          showToast(NL10ns.of(context).password_wrong);
        }
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
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Label(
                                    NL10ns.of(context).import_keystore_nkn_wallet_title,
                                    type: LabelType.h2,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 32),
                                  child: Label(
                                    NL10ns.of(context).import_keystore_nkn_wallet_desc,
                                    type: LabelType.bodyRegular,
                                    textAlign: TextAlign.start,
                                    softWrap: true,
                                  ),
                                ),
                                Label(
                                  NL10ns.of(context).keystore,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  multi: true,
                                  controller: _keystoreController,
                                  hintText: NL10ns.of(context).input_keystore,
                                  focusNode: _keystoreFocusNode,
                                  onSaved: (v) => _keystore = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                                  },
                                  suffixIcon: GestureDetector(
                                    onTap: () async {
                                      File file = await FilePicker.getFile();
                                      if (file != null) {
                                        _keystoreController.text = file.readAsStringSync();
                                      }
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
                                  validator: Validator.of(context).keystore(),
                                ),
                                Label(
                                  NL10ns.of(context).wallet_name,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Textbox(
                                  focusNode: _nameFocusNode,
                                  hintText: NL10ns.of(context).hint_enter_wallet_name,
                                  onSaved: (v) => _name = v,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
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
                                    FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
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
                        text: NL10ns.of(context).import_wallet,
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
