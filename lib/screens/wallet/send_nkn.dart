import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class WalletSendNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/send_nkn';
  static final String argWallet = "wallet";

  static Future go(BuildContext context, WalletSchema wallet) {
    logger.d("wallet send NKN - $wallet");
    if (wallet == null) return null;
    return Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
    });
  }

  final Map<String, dynamic> arguments;

  WalletSendNKNScreen({Key key, this.arguments}) : super(key: key);

  @override
  _WalletSendNKNScreenState createState() => _WalletSendNKNScreenState();
}

class _WalletSendNKNScreenState extends State<WalletSendNKNScreen> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  WalletSchema _wallet;

  bool _formValid = false;
  TextEditingController _amountController = TextEditingController();
  TextEditingController _sendToController = TextEditingController();
  TextEditingController _feeController = TextEditingController();
  FocusNode _amountFocusNode = FocusNode();
  FocusNode _sendToFocusNode = FocusNode();
  FocusNode _feeToFocusNode = FocusNode();

  var _amount;
  var _sendTo;

  bool _showFeeLayout = false;
  double _sliderFeeMin = 0;
  double _sliderFeeMax = 10;
  double _sliderFee = 0.1;
  double _fee = 0.1;

  @override
  void initState() {
    super.initState();
    this._wallet = widget.arguments[WalletSendNKNScreen.argWallet];
    _feeController.text = _fee.toString();
    // balance query
    locator<TaskService>().queryWalletBalanceTask();
  }

  _sendNKN() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      logger.d("amount:$_amount, sendTo:$_sendTo, fee:$_fee");

      if (_wallet == null || _wallet.address == null || _wallet.address.isEmpty) return;

      S _localizations = S.of(context);
      WalletStorage _storage = WalletStorage();

      Future(() async {
        if (Settings.biometricsAuthentication) {
          return authorization.authenticationIfCan();
        }
        return false;
      }).then((bool authOk) async {
        String pwd = await _storage.getPassword(_wallet?.address);
        if (!authOk || pwd == null || pwd.isEmpty) {
          return BottomDialog.of(context).showInput(
            title: _localizations.verify_wallet_password,
            inputTip: _localizations.wallet_password,
            inputHint: _localizations.input_password,
            actionText: _localizations.continue_text,
            password: true,
          );
        }
        return pwd;
      }).then((password) async {
        if (password == null || password.isEmpty) {
          // no toast
          return;
        }
        String keystore = await _storage.getKeystore(_wallet?.address);

        if (_wallet.type == WalletType.eth) {
          final result = _transferETH(keystore, password);
          Navigator.pop(context, result);
        } else {
          final result = _transferNKN(keystore, password);
          Navigator.pop(context, result);
        }
      }).onError((error, stackTrace) {
        logger.e(error);
      });
    }
  }

  Future<bool> _transferNKN(String keystore, String password) async {
    if (keystore == null || password == null) return false;
    S _localizations = S.of(context);
    try {
      Wallet restore = await Wallet.restore(keystore, config: WalletConfig(password: password));
      if (restore == null || restore?.address != _wallet?.address) {
        Toast.show(_localizations.password_wrong);
        return false;
      }
      final txHash = await restore?.transfer(_sendTo, _amount, fee: _fee.toString());
      if (txHash != null) {
        locator<TaskService>().queryWalletBalanceTask();
        return txHash.length > 10;
      }
      return false;
    } catch (e) {
      if (e.toString() == "wrong password") {
        Toast.show(_localizations.password_wrong);
      } else if (e.toString() == 'INTERNAL ERROR, can not append tx to txpool: not sufficient funds') {
        Toast.show(e?.message ?? "");
      } else {
        Toast.show(_localizations.failure);
      }
      return false;
    }
  }

  Future<bool> _transferETH(String keystore, String password) async {
    // TODO:GG transfer eth
    return false;
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headIconHeight = MediaQuery.of(context).size.width / 5;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: _localizations.send_nkn,
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: assetIcon(
              'scan',
              width: 24,
              color: application.theme.backgroundLightColor,
            ),
            onPressed: () async {
              var qrData = await Navigator.pushNamed(context, ScannerScreen.routeName);
              logger.d("QR_DATA:$qrData");
              // json
              var jsonFormat;
              var jsonData;
              try {
                jsonData = jsonDecode(qrData);
                jsonFormat = true;
              } catch (e) {
                jsonFormat = false;
              }
              // data
              if (jsonFormat) {
                logger.d("wallet send NKN scan - address:${jsonData['address']} amount:${jsonData['amount']}");
                _sendToController.text = jsonData['address'];
                _amountController.text = jsonData['amount'].toString();
              } else if (verifyAddress(qrData)) {
                logger.d("wallet send NKN scan - address:$qrData");
                _sendToController.text = qrData;
              } else {
                ModalDialog.of(context).show(
                  content: _localizations.error_unknown_nkn_qrcode,
                  hasCloseButton: true,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        color: application.theme.backgroundColor4,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
                  child: Center(
                    child: assetImage("wallet/transfer-header.png", height: headIconHeight),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height - Header.height - headIconHeight - 10 - 20 - 30),
                decoration: BoxDecoration(
                  color: application.theme.backgroundLightColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, state) {
                    if (state is WalletLoaded) {
                      _wallet = state.getWalletByAddress(_wallet?.address ?? "");
                    }
                    return Form(
                      key: _formKey,
                      onChanged: () {
                        setState(() {
                          _formValid = (_formKey.currentState as FormState).validate();
                        });
                      },
                      autovalidateMode: AutovalidateMode.always,
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  WalletDropdown(
                                    selectTitle: _localizations.select_asset_to_receive,
                                    schema: _wallet,
                                    onSelected: (picked) {
                                      logger.d("wallet picked - $picked");
                                      if (picked == null) return;
                                      setState(() {
                                        _wallet = picked;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  Label(
                                    _localizations.amount,
                                    type: LabelType.h4,
                                    textAlign: TextAlign.start,
                                  ),
                                  FormText(
                                    controller: _amountController,
                                    focusNode: _amountFocusNode,
                                    hintText: _localizations.enter_amount,
                                    validator: Validator.of(context).amount(),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_sendToFocusNode),
                                    onSaved: (v) => _amount = v,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                    showErrorMessage: false,
                                    suffixIcon: GestureDetector(
                                      child: Container(
                                        width: 20,
                                        alignment: Alignment.centerRight,
                                        child: Label(_localizations.nkn, type: LabelType.label),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Label(_localizations.available + ': '),
                                          Label(
                                            nknFormat(_wallet?.balance ?? 0, decimalDigits: 8, symbol: 'NKN'),
                                            color: application.theme.fontColor1,
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        child: Label(
                                          _localizations.max,
                                          color: application.theme.primaryColor,
                                          type: LabelType.bodyRegular,
                                        ),
                                        onTap: () {
                                          _amountController.text = (_wallet?.balance ?? 0).toString();
                                        },
                                      )
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Label(
                                    _localizations.send_to,
                                    type: LabelType.h4,
                                    textAlign: TextAlign.start,
                                  ),
                                  FormText(
                                    controller: _sendToController,
                                    focusNode: _sendToFocusNode,
                                    hintText: _localizations.enter_receive_address,
                                    validator: Validator.of(context).addressNKN(),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_feeToFocusNode),
                                    onSaved: (v) => _sendTo = v,
                                    suffixIcon: GestureDetector(
                                      onTap: () async {
                                        // TODO:GG contact select
                                        // if (NKNClientCaller.currentChatId != null) {
                                        //   var contact = await Navigator.of(context).pushNamed(ContactHome.routeName, arguments: true);
                                        //   if (contact is ContactSchema) {
                                        //     _sendToController.text = contact.nknWalletAddress;
                                        //   }
                                        // } else {
                                        //   Toast.show('D-Chat not login');
                                        // }
                                      },
                                      child: Container(
                                        width: 20,
                                        alignment: Alignment.centerRight,
                                        child: Icon(FontAwesomeIcons.solidAddressBook),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _showFeeLayout = !_showFeeLayout;
                                          });
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: <Widget>[
                                            Label(
                                              _localizations.fee,
                                              color: application.theme.primaryColor,
                                              type: LabelType.h4,
                                              textAlign: TextAlign.start,
                                            ),
                                            RotatedBox(
                                              quarterTurns: _showFeeLayout ? 2 : 0,
                                              child: assetIcon('down', color: application.theme.primaryColor, width: 20),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width / 4,
                                        child: FormText(
                                          padding: EdgeInsets.only(top: 10),
                                          controller: _feeController,
                                          focusNode: _feeToFocusNode,
                                          onSaved: (v) => _fee = double.parse(v ?? 0),
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                                          onChanged: (v) {
                                            setState(() {
                                              double fee = v.isNotEmpty ? double.parse(v) : 0;
                                              if (fee > _sliderFeeMax) {
                                                fee = _sliderFeeMax;
                                              } else if (fee < _sliderFeeMin) {
                                                fee = _sliderFeeMin;
                                              }
                                              _sliderFee = fee;
                                            });
                                          },
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                          suffixIcon: GestureDetector(
                                            child: Container(
                                              width: 20,
                                              alignment: Alignment.centerRight,
                                              child: Label(_localizations.nkn, type: LabelType.label),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  ExpansionLayout(
                                    isExpanded: _showFeeLayout,
                                    child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(top: 0),
                                        child: Column(
                                          children: <Widget>[
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: <Widget>[
                                                Label(
                                                  _localizations.slow,
                                                  type: LabelType.bodySmall,
                                                  color: application.theme.primaryColor,
                                                ),
                                                Label(
                                                  _localizations.average,
                                                  type: LabelType.bodySmall,
                                                  color: application.theme.primaryColor,
                                                ),
                                                Label(
                                                  _localizations.fast,
                                                  type: LabelType.bodySmall,
                                                  color: application.theme.primaryColor,
                                                ),
                                              ],
                                            ),
                                            Slider(
                                              value: _sliderFee,
                                              onChanged: (v) {
                                                setState(() {
                                                  _sliderFee = _fee = v;
                                                  _feeController.text = _fee.toStringAsFixed(2);
                                                });
                                              },
                                              max: _sliderFeeMax,
                                              min: _sliderFeeMin,
                                            ),
                                          ],
                                        )),
                                  ),
                                ],
                              ),
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
                                        text: _localizations.continue_text,
                                        disabled: !_formValid,
                                        onPressed: _sendNKN,
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
