import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class WalletImportBySeedLayout extends BaseStateFulWidget {
  final String walletType;
  final Stream<String>? qrStream;

  const WalletImportBySeedLayout({required this.walletType, this.qrStream});

  @override
  _WalletImportBySeedLayoutState createState() => _WalletImportBySeedLayoutState();
}

class _WalletImportBySeedLayoutState extends BaseStateFulWidgetState<WalletImportBySeedLayout> with SingleTickerProviderStateMixin, Tag {
  GlobalKey _formKey = new GlobalKey<FormState>();

  WalletBloc? _walletBloc;
  StreamSubscription? _qrSubscription;

  bool _formValid = false;
  TextEditingController _seedController = TextEditingController();
  TextEditingController _nameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  FocusNode _seedFocusNode = FocusNode();
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();

  @override
  void onRefreshArguments() {
    // _qrSubscription?.cancel();
    _qrSubscription = widget.qrStream?.listen((event) {
      setState(() {
        _seedController.text = event;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  @override
  void dispose() {
    _qrSubscription?.cancel();
    super.dispose();
  }

  _import() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      Loading.show();

      String seed = _seedController.text;
      String name = _nameController.text;
      String password = _passwordController.text;
      logger.i("$TAG - seed:$seed, name:$name, password:$password");

      try {
        if (widget.walletType == WalletType.nkn) {
          List<String> seedRpcList = await Global.getSeedRpcList(null, measure: true);
          Wallet nkn = await Wallet.create(hexDecode(seed), config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
          logger.i("$TAG - import_nkn - nkn:${nkn.toString()}");
          if (nkn.address.isEmpty || nkn.keystore.isEmpty) {
            Loading.dismiss();
            return;
          }

          WalletSchema wallet = WalletSchema(type: WalletType.nkn, address: nkn.address, publicKey: hexEncode(nkn.publicKey), name: name);
          logger.i("$TAG - import_nkn - wallet:${wallet.toString()}");

          _walletBloc?.add(AddWallet(wallet, nkn.keystore, password, hexEncode(nkn.seed)));
        } else {
          final eth = Ethereum.restoreByPrivateKey(name: name, privateKey: seed, password: password);
          String ethAddress = (await eth.address).hex;
          String ethKeystore = await eth.keystore();
          logger.i("$TAG - import_eth - address:$ethAddress - keystore:$ethKeystore - eth:${eth.toString()}");
          if (ethAddress.isEmpty || ethKeystore.isEmpty) {
            Loading.dismiss();
            return;
          }

          WalletSchema wallet = WalletSchema(type: WalletType.eth, address: ethAddress, publicKey: eth.pubKeyHex, name: name);
          logger.i("$TAG - import_eth - wallet:${wallet.toString()}");

          _walletBloc?.add(AddWallet(wallet, ethKeystore, password, eth.privateKeyHex));
        }
        walletCommon.queryBalance(delayMs: 3000); // await

        Loading.dismiss();
        Toast.show(Global.locale((s) => s.success));
        if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
      } catch (e) {
        Loading.dismiss();
        handleError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
                  child: Label(
                    Global.locale((s) => s.import_with_seed_title, ctx: context),
                    type: LabelType.h2,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32),
                  child: Label(
                    Global.locale((s) => s.import_with_seed_desc, ctx: context),
                    type: LabelType.bodyRegular,
                    textAlign: TextAlign.start,
                    softWrap: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    Global.locale((s) => s.seed, ctx: context),
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: FormText(
                    controller: _seedController,
                    focusNode: _seedFocusNode,
                    hintText: Global.locale((s) => s.input_seed, ctx: context),
                    validator: widget.walletType == WalletType.nkn ? Validator.of(context).seedNKN() : Validator.of(context).seedETH(),
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => FocusScope.of(context).requestFocus(_nameFocusNode),
                    maxLines: 10,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    Global.locale((s) => s.wallet_name, ctx: context),
                    type: LabelType.h4,
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
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Label(
                    Global.locale((s) => s.wallet_password, ctx: context),
                    type: LabelType.h4,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  child: FormText(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hintText: Global.locale((s) => s.input_password, ctx: context),
                    validator: Validator.of(context).password(),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                    password: true,
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
                      text: widget.walletType == WalletType.nkn ? Global.locale((s) => s.import_nkn_wallet, ctx: context) : Global.locale((s) => s.import_ethereum_wallet, ctx: context),
                      width: double.infinity,
                      disabled: !_formValid,
                      onPressed: _import,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
