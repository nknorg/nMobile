import 'package:flutter/material.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/form_field_box.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';

class WalletImportBySeedLayout extends StatefulWidget {
  final String walletType;

  const WalletImportBySeedLayout({this.walletType});

  @override
  _WalletImportBySeedLayoutState createState() => _WalletImportBySeedLayoutState();
}

class _WalletImportBySeedLayoutState extends State<WalletImportBySeedLayout> with SingleTickerProviderStateMixin {
  // TODO:GG params
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _seedController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _seedFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _confirmPasswordFocusNode = FocusNode();

  // WalletsBloc _walletsBloc;
  var _seed;
  var _name;
  var _password;

  // StreamSubscription _qrSubscription;

  @override
  void initState() {
    super.initState();
    // TODO:GG wallet event
    // _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    // _qrSubscription = eventBus.on<QMScan>().listen((event) {
    //   setState(() {
    //     _seedController.text = event.content;
    //   });
    // });
  }

  @override
  void dispose() {
    super.dispose();
    // TODO:GG destroy
    // _qrSubscription.cancel();
  }

  _import() async {
    // TODO:GG create wallet
    // if ((_formKey.currentState as FormState).validate()) {
    //   (_formKey.currentState as FormState).save();
    //   EasyLoading.show();
    //   try {
    //     if (widget.type == WalletType.nkn) {
    //       String keystore = await NknWalletPlugin.createWallet(_seed, _password);
    //       var json = jsonDecode(keystore);
    //       String address = json['Address'];
    //       _walletsBloc.add(AddWallet(WalletSchema(address: address, type: WalletSchema.NKN_WALLET, name: _name), keystore));
    //     } else {
    //       final ethWallet = Ethereum.restoreWalletFromPrivateKey(name: _name, privateKey: _seed, password: _password);
    //       Ethereum.saveWallet(ethWallet: ethWallet, walletsBloc: _walletsBloc);
    //     }
    //     EasyLoading.dismiss();
    //     showToast(NL10ns.of(context).success);
    //
    //     Navigator.of(context).pop();
    //   } catch (e) {
    //     EasyLoading.dismiss();
    //     showToast(e.message);
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
                  child: FormFieldBox(
                    controller: _seedController,
                    focusNode: _seedFocusNode,
                    hintText: _localizations.input_seed,
                    onSaved: (v) => _seed = v,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_nameFocusNode);
                    },
                    // validator: Validator.of(context).seed(), // TODO:GG validator
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
                  child: FormFieldBox(
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
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  child: FormFieldBox(
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
