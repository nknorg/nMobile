import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/eth_erc20_token.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

class SendErc20Screen extends StatefulWidget {
  static const String routeName = '/wallet/send_erc_20';
  final WalletSchema arguments;

  SendErc20Screen({this.arguments});

  @override
  _SendErc20ScreenState createState() => _SendErc20ScreenState();
}

class _SendErc20ScreenState extends State<SendErc20Screen> with Tag {
  final GetIt locator = GetIt.instance;
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  TextEditingController _amountController = TextEditingController();
  TextEditingController _sendToController = TextEditingController();
  TextEditingController _feeController = TextEditingController();
  FocusNode _amountFocusNode = FocusNode();
  FocusNode _sendToFocusNode = FocusNode();
  FocusNode _feeToFocusNode = FocusNode();

  WalletSchema wallet;
  bool _showFeeLayout = false;
  FilteredWalletsBloc _filteredWalletsBloc;
  num _amount;
  String _sendTo;
  int _gasPriceInGwei = 72;
  int _sliderGasPriceMin = 10;
  int _sliderGasPriceMax = 1000;
  int _maxGas = 60000; // default: 90000
  int _sliderMaxGasMinEth = 21000;  // Actual: 21,000
  int _sliderMaxGasMinNkn = 30000;  // Actual: 29,561
  int _sliderMaxGasMax = 300000;
  bool _ethTrueTokenFalse = false;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  _initAsync() async {
    final gasPrice = await EthErc20Client().getGasPrice;
    _gasPriceInGwei = (gasPrice.gwei * 0.8).round();
    _LOG.i('gasPrice:$_gasPriceInGwei GWei');
    _updateFee();
  }

  _updateFee() {
    _feeController.text = Format.nknFormat((_gasPriceInGwei.gwei.ether * _maxGas), decimalDigits: 8).trim();
    if (_ethTrueTokenFalse && _amountController.text.isNotEmpty) {
      _amountController.text = Format.nknFormat(
        (wallet.balanceEth - (_gasPriceInGwei.gwei.ether * _maxGas)),
        decimalDigits: 8,
      ).trim();
    }
  }

  double get _maxGasGet {
    final min = _ethTrueTokenFalse ? _sliderMaxGasMinEth : _sliderMaxGasMinNkn;
    _maxGas = _maxGas < min ? min : _maxGas > _sliderMaxGasMax ? _sliderMaxGasMax : _maxGas;
    return _maxGas.toDouble();
  }

  _updateAmount() {
    if (wallet != null) {
      _amountController.text = Format.nknFormat(
        _ethTrueTokenFalse ? (wallet.balanceEth - (_gasPriceInGwei.gwei.ether * _maxGas)) : wallet.balance,
        decimalDigits: 8,
      ).trim();
    } else {
      _amountController.text = '';
    }
  }

  @override
  void initState() {
    super.initState();
    _LOG = LOG(tag);
    _initAsync();
    locator<TaskService>().queryNknWalletBalanceTask();
    _filteredWalletsBloc = BlocProvider.of<FilteredWalletsBloc>(context);
    _updateFee();
  }

  next() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();

      var password = await TimerAuth.instance.onCheckAuthGetPassword(context);
      if (password != null) {
        final result = transferAction(password);
        Navigator.pop(context, result);
      }
    }
  }

  Future<bool> transferAction(password) async {
    try {
      final ethWallet = await Ethereum.restoreWalletSaved(schema: wallet, password: password);
      final ethClient = EthErc20Client();
      final txHash = _ethTrueTokenFalse
          ? await ethClient.sendEthereum(ethWallet.credt, address: _sendTo, amountEth: _amount, gasLimit: _maxGas, gasPriceInGwei: _gasPriceInGwei)
          : await ethClient.sendNknToken(ethWallet.credt, address: _sendTo, amountNkn: _amount, gasLimit: _maxGas, gasPriceInGwei: _gasPriceInGwei);
      return txHash.length > 10;
    } catch (e) {
      showToast(e.message);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        title: NL10ns.of(context).send_eth,
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'scan',
            width: 24,
            color: DefaultTheme.backgroundLightColor,
          ),
          onPressed: () async {
            var qrData = await Navigator.of(context).pushNamed(ScannerScreen.routeName);
            var jsonFormat;
            var jsonData;
            try {
              jsonData = jsonDecode(qrData);
              jsonFormat = true;
            } on Exception catch (e) {
              jsonFormat = false;
            }
            if (jsonFormat) {
              _sendToController.text = jsonData['address'];
              _amountController.text = jsonData['amount'].toString();
            } else if (isValidEthAddress(qrData)) {
              _sendToController.text = qrData;
            } else {
              await ModalDialog.of(context).show(
                height: 240,
                content: Label(
                  NL10ns.of(context).error_unknown_nkn_qrcode,
                  type: LabelType.bodyRegular,
                ),
              );
            }
          },
        ),
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height),
                  color: DefaultTheme.backgroundColor4,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32, left: 20, right: 20),
                        child: Image(image: AssetImage("assets/wallet/transfer-header.png")),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 400),
                child: Container(
                  constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height - 200),
                  color: DefaultTheme.backgroundColor4,
                  child: Flex(
                    direction: Axis.vertical,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: BlocBuilder<FilteredWalletsBloc, FilteredWalletsState>(
                          builder: (context, state) {
                            if (state is FilteredWalletsLoaded) {
                              wallet = state.filteredWallets.first;
                              if (wallet.type == WalletSchema.NKN_WALLET) {
                                _ethTrueTokenFalse = false;
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: DefaultTheme.backgroundLightColor,
//                                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                                ),
                                child: Form(
                                  key: _formKey,
                                  autovalidate: true,
                                  onChanged: () {
                                    setState(() {
                                      _formValid = (_formKey.currentState as FormState).validate();
                                    });
                                  },
                                  child: Column(
                                    children: <Widget>[
                                      Expanded(
                                        flex: 1,
                                        child: Scrollbar(
                                          child: SingleChildScrollView(
                                            child: Padding(
                                              padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 32),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
//                                                  Label(
//                                                    NMobileLocalizations.of(context).from,
//                                                    type: LabelType.h4,
//                                                    textAlign: TextAlign.start,
//                                                  ),
                                                  WalletDropdown(
                                                    title: NL10ns.of(context).select_asset_to_receive,
                                                    schema: widget.arguments ?? wallet,
                                                  ),
                                                  Label(
                                                    NL10ns.of(context).amount,
                                                    type: LabelType.h4,
                                                    textAlign: TextAlign.start,
                                                  ).pad(t: 20),
                                                  Textbox(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    controller: _amountController,
                                                    focusNode: _amountFocusNode,
                                                    onSaved: (v) => _amount = num.parse(v),
                                                    onFieldSubmitted: (_) {
                                                      FocusScope.of(context).requestFocus(_sendToFocusNode);
                                                    },
                                                    validator: Validator.of(context).amount(),
                                                    showErrorMessage: false,
                                                    hintText: NL10ns.of(context).enter_amount,
                                                    suffixIcon: GestureDetector(
                                                      onTap: () {
                                                        _ethTrueTokenFalse = !_ethTrueTokenFalse;
                                                        _amountController.text = '';
                                                        _filteredWalletsBloc.add(LoadWalletFilter((x) => x.address == wallet.address));
                                                      },
                                                      child: Container(
                                                        width: 20,
                                                        alignment: Alignment.centerRight,
                                                        child: Label(
                                                          _ethTrueTokenFalse ? NL10ns.of(context).eth : NL10ns.of(context).nkn,
                                                          color: wallet.type == WalletSchema.ETH_WALLET ? Colours.blue_0f : null,
                                                          type: wallet.type == WalletSchema.ETH_WALLET ? LabelType.bodyRegular : LabelType.label,
                                                        ),
                                                      ),
                                                    ),
                                                    textInputAction: TextInputAction.next,
                                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                    inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 20),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Label(NL10ns.of(context).available + ': '),
                                                            BlocBuilder<WalletsBloc, WalletsState>(
                                                              builder: (context, state) {
                                                                if (state is WalletsLoaded) {
                                                                  var w = state.wallets.firstWhere((x) => x == wallet, orElse: () => null);
                                                                  if (w != null) {
                                                                    return Label(
                                                                      Format.nknFormat(_ethTrueTokenFalse ? w.balanceEth : w.balance,
                                                                          decimalDigits: 8, symbol: _ethTrueTokenFalse ? 'ETH' : 'NKN'),
                                                                      color: DefaultTheme.fontColor1,
                                                                    );
                                                                  }
                                                                }
                                                                return Label(_ethTrueTokenFalse ? '-- ETH' : '-- NKN', color: DefaultTheme.fontColor1);
                                                              },
                                                            )
                                                          ],
                                                        ),
                                                        InkWell(
                                                          child: Label(
                                                            NL10ns.of(context).max,
                                                            color: DefaultTheme.primaryColor,
                                                            type: LabelType.bodyRegular,
                                                          ),
                                                          onTap: () {
                                                            _updateAmount();
                                                          },
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Label(
                                                    NL10ns.of(context).send_to,
                                                    type: LabelType.h4,
                                                    textAlign: TextAlign.start,
                                                  ),
                                                  Textbox(
                                                    focusNode: _sendToFocusNode,
                                                    controller: _sendToController,
                                                    onSaved: (v) => _sendTo = v,
                                                    onFieldSubmitted: (_) {
                                                      FocusScope.of(context).requestFocus(_feeToFocusNode);
                                                    },
                                                    validator: Validator.of(context).ethAddress(),
                                                    textInputAction: TextInputAction.next,
                                                    hintText: NL10ns.of(context).enter_receive_address,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 20),
                                                    child: Row(
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
                                                                NL10ns.of(context).fee,
                                                                color: DefaultTheme.primaryColor,
                                                                type: LabelType.h4,
                                                                textAlign: TextAlign.start,
                                                              ),
                                                              RotatedBox(
                                                                quarterTurns: _showFeeLayout ? 2 : 0,
                                                                child: loadAssetIconsImage('down', color: DefaultTheme.primaryColor, width: 20),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 120,
                                                          child: Textbox(
                                                            controller: _feeController,
                                                            focusNode: _feeToFocusNode,
                                                            padding: const EdgeInsets.only(bottom: 0),
                                                            onSaved: (v) {},
                                                            onFieldSubmitted: (v) {
                                                              int gasPrice = (num.parse(v).ETH.gwei / _maxGas).round();
                                                              if (gasPrice < _sliderGasPriceMin) {
                                                                gasPrice = _sliderGasPriceMin;
                                                              }
                                                              if (gasPrice > _sliderGasPriceMax) {
                                                                gasPrice = _sliderGasPriceMax;
                                                              }
                                                              _LOG.w('fee field | gasPrice:$gasPrice');
                                                              if (_gasPriceInGwei != gasPrice) {
                                                                _gasPriceInGwei = gasPrice;
                                                                _updateFee();
                                                              }
                                                            },
                                                            suffixIcon: GestureDetector(
                                                              onTap: () {},
                                                              child: Container(
                                                                width: 20,
                                                                alignment: Alignment.centerRight,
                                                                child: Label(
                                                                  wallet.type == WalletSchema.ETH_WALLET
                                                                      ? NL10ns.of(context).eth
                                                                      : NL10ns.of(context).nkn,
                                                                  type: LabelType.label,
                                                                ),
                                                              ),
                                                            ),
                                                            keyboardType: TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                            textInputAction: TextInputAction.done,
                                                            inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  ExpansionLayout(
                                                    isExpanded: _showFeeLayout,
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Label(
                                                              NL10ns.of(context).gas_price,
                                                              type: LabelType.h4,
                                                              fontWeight: FontWeight.w600,
                                                            ).pad(r: 16),
                                                            Expanded(
                                                              flex: 1,
                                                              child: Column(
                                                                children: [
                                                                  Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: <Widget>[
                                                                      Label(
                                                                        _sliderGasPriceMin.toString() + ' ' + NL10ns.of(context).gwei,
                                                                        type: LabelType.bodySmall,
                                                                        color: DefaultTheme.primaryColor,
                                                                      ),
                                                                      Label(
                                                                        _sliderGasPriceMax.toString() + ' ' + NL10ns.of(context).gwei,
                                                                        type: LabelType.bodySmall,
                                                                        color: DefaultTheme.primaryColor,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Slider(
                                                                    value: _gasPriceInGwei.toDouble(),
                                                                    onChanged: (v) {
                                                                      _gasPriceInGwei = v.toInt();
                                                                      _updateFee();
                                                                    },
                                                                    min: _sliderGasPriceMin.toDouble(),
                                                                    max: _sliderGasPriceMax.toDouble(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Label(
                                                              NL10ns.of(context).gas_max,
                                                              type: LabelType.h4,
                                                              fontWeight: FontWeight.w600,
                                                            ).pad(r: 22),
                                                            Expanded(
                                                              flex: 1,
                                                              child: Column(
                                                                children: [
                                                                  Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: <Widget>[
                                                                      Label(
                                                                        (_ethTrueTokenFalse ? _sliderMaxGasMinEth : _sliderMaxGasMinNkn).toString(),
                                                                        type: LabelType.bodySmall,
                                                                        color: DefaultTheme.primaryColor,
                                                                      ),
                                                                      Label(
                                                                        _sliderMaxGasMax.toString(),
                                                                        type: LabelType.bodySmall,
                                                                        color: DefaultTheme.primaryColor,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Slider(
                                                                    value: _maxGasGet,
                                                                    onChanged: (v) {
                                                                      _maxGas = v.round();
                                                                      _updateFee();
                                                                    },
                                                                    min: (_ethTrueTokenFalse ? _sliderMaxGasMinEth : _sliderMaxGasMinNkn).toDouble(),
                                                                    max: _sliderMaxGasMax.toDouble(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
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
                                                    text: NL10ns.of(context).continue_text,
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
                                ),
                              );
                            } else {
                              return null;
                            }
                          },
                        ),
                      )
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
