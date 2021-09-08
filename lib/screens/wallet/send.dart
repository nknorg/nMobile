import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class WalletSendScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/send';
  static final String argWallet = "wallet";

  static Future go(BuildContext context, WalletSchema wallet) {
    logger.d("WalletSendScreen - go - $wallet");
    return Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
    });
  }

  final Map<String, dynamic>? arguments;

  WalletSendScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _WalletSendScreenState createState() => _WalletSendScreenState();
}

class _WalletSendScreenState extends BaseStateFulWidgetState<WalletSendScreen> with Tag {
  GlobalKey _formKey = new GlobalKey<FormState>();

  late WalletSchema _wallet;
  final _ethClient = EthErc20Client();

  bool _formValid = false;
  TextEditingController _amountController = TextEditingController();
  TextEditingController _sendToController = TextEditingController();
  TextEditingController _feeController = TextEditingController();
  FocusNode _amountFocusNode = FocusNode();
  FocusNode _sendToFocusNode = FocusNode();
  FocusNode _feeToFocusNode = FocusNode();

  String? _sendTo;
  num? _amount;
  bool _showFeeLayout = false;

  // nkn
  final double _sliderFeeMin = 0;
  final double _sliderFeeMax = 10;
  double _sliderFee = 0.1;
  double _fee = 0.1;

  // eth
  bool _ethTrueTokenFalse = false;
  int _gasPriceInGwei = 72;
  final int _sliderGasPriceMin = 10;
  final int _sliderGasPriceMax = 1000;
  int _maxGas = 100000; // default: 90000
  final int _sliderMaxGasMinEth = 21000; // Actual: 21,000
  final int _sliderMaxGasMinNkn = 30000; // Actual: 29,561
  final int _sliderMaxGasMax = 300000;

  @override
  void onRefreshArguments() {
    this._wallet = widget.arguments![WalletSendScreen.argWallet];
  }

  @override
  void initState() {
    super.initState();
    // balance query
    walletCommon.queryBalance(); // await
    // init
    _init(this._wallet.type == WalletType.eth);
    _updateFee(this._wallet.type == WalletType.eth);
  }

  @override
  void dispose() {
    _ethClient.close();
    super.dispose();
  }

  _init(bool eth) async {
    if (eth) {
      final gasPrice = await _ethClient.getGasPrice;
      _gasPriceInGwei = (gasPrice.gwei * 1).round(); // * 0.8
      logger.i('$TAG - _init - erc20gasPrice:$_gasPriceInGwei GWei');
    } else {
      _feeController.text = _fee.toString();
    }
    _updateFee(eth);
  }

  _checkFeeForm(bool eth, value) {
    if (_wallet.type == WalletType.eth) {
      int gasPrice = ((num.tryParse(value) ?? 0).ETH.gwei / _maxGas).round();
      if (gasPrice < _sliderGasPriceMin) {
        gasPrice = _sliderGasPriceMin;
      }
      if (gasPrice > _sliderGasPriceMax) {
        gasPrice = _sliderGasPriceMax;
      }
      if (_gasPriceInGwei != gasPrice) {
        _gasPriceInGwei = gasPrice;
        _updateFee(true);
      }
    } else {
      double fee = value.isNotEmpty ? (double.tryParse(value) ?? 0) : 0;
      if (fee > _sliderFeeMax) {
        fee = _sliderFeeMax;
      } else if (fee < _sliderFeeMin) {
        fee = _sliderFeeMin;
      }
      setState(() {
        _sliderFee = fee;
      });
    }
  }

  _updateFee(bool eth, {gweiFee, gasFee, nknFee}) {
    if (eth) {
      _feeController.text = nknFormat((_gasPriceInGwei.gwei.ether * _maxGas), decimalDigits: 8).trim();
      if (_ethTrueTokenFalse && _amountController.text.isNotEmpty) {
        _amountController.text = nknFormat((_wallet.balanceEth - (_gasPriceInGwei.gwei.ether * _maxGas)), decimalDigits: 8).trim();
      }
      setState(() {
        if (gasFee != null) {
          _maxGas = gasFee;
        }
        if (gweiFee != null) {
          _gasPriceInGwei = gweiFee;
        }
      });
    } else {
      setState(() {
        if (nknFee != null) {
          _sliderFee = _fee = nknFee;
          _feeController.text = _fee.toStringAsFixed(2);
        }
      });
    }
  }

  _setAmountToMax(bool eth) {
    if (eth) {
      _amountController.text = nknFormat(_ethTrueTokenFalse ? (_wallet.balanceEth - (_gasPriceInGwei.gwei.ether * _maxGas)) : _wallet.balance, decimalDigits: 8).trim();
    } else {
      _amountController.text = _wallet.balance.toString();
    }
  }

  double get _maxGasGet {
    final min = _ethTrueTokenFalse ? _sliderMaxGasMinEth : _sliderMaxGasMinNkn;
    _maxGas = _maxGas < min
        ? min
        : _maxGas > _sliderMaxGasMax
            ? _sliderMaxGasMax
            : _maxGas;
    return _maxGas.toDouble();
  }

  _goToTransfer() async {
    if ((_formKey.currentState as FormState).validate()) {
      (_formKey.currentState as FormState).save();
      logger.i("$TAG - amount:$_amount, sendTo:$_sendTo, fee:$_fee");

      authorization.getWalletPassword(_wallet.address, context: context).then((String? password) async {
        if (password == null || password.isEmpty) return;
        String keystore = await walletCommon.getKeystore(_wallet.address);
        if (keystore.isEmpty || password.isEmpty) {
          Toast.show(S.of(context).password_wrong);
          return;
        }

        if (_wallet.type == WalletType.eth) {
          final result = _transferETH(_wallet.name ?? "", keystore, password);
          Navigator.pop(this.context, result);
        } else {
          final result = _transferNKN(_wallet.name ?? "", keystore, password);
          Navigator.pop(this.context, result);
        }
      }).onError((error, stackTrace) {
        handleError(error, stackTrace: stackTrace);
      });
    }
  }

  Future<bool> _transferETH(String name, String keystore, String password) async {
    S _localizations = S.of(context);
    Loading.show();
    try {
      final eth = await Ethereum.restoreByKeyStore(name: name, keystore: keystore, password: password);
      String ethAddress = (await eth.address).hex;
      if (ethAddress.isEmpty || ethAddress != _wallet.address) {
        Toast.show(_localizations.password_wrong);
        return false;
      }

      String amount = _amount?.toString() ?? '0';
      // String fee = _fee.toString();
      if (_sendTo == null || _sendTo!.isEmpty || amount == '0') {
        Toast.show(_localizations.enter_amount);
        return false;
      }

      double? balanceEth = (await _ethClient.getBalanceEth(address: ethAddress))?.ether as double?;
      double? balanceNkn = (await _ethClient.getBalanceNkn(address: ethAddress))?.ether as double?;
      double? balance = _ethTrueTokenFalse ? balanceEth : balanceNkn;
      double tradeAmount = double.tryParse(amount) ?? 0;
      // double tradeFee = (double.tryParse(fee) ?? 0);
      double tradeTotal = tradeAmount; // + tradeFee
      if (tradeAmount <= 0 || balance == null || balance < tradeTotal) {
        Toast.show(_localizations.balance_not_enough);
        return false;
      }

      final txHash = _ethTrueTokenFalse
          ? await _ethClient.sendEthereum(
              eth.credt,
              address: _sendTo!,
              amountEth: _amount!,
              gasLimit: _maxGas,
              gasPriceInGwei: _gasPriceInGwei,
            )
          : await _ethClient.sendNknToken(
              eth.credt,
              address: _sendTo!,
              amountNkn: _amount!,
              gasLimit: _maxGas,
              gasPriceInGwei: _gasPriceInGwei,
            );
      return txHash.length > 10;
    } catch (e) {
      handleError(e, toast: _localizations.failure);
      return false;
    } finally {
      Loading.dismiss();
    }
  }

  Future<bool> _transferNKN(String name, String keystore, String password, {int? nonce}) async {
    S _localizations = S.of(context);
    Loading.show();
    try {
      List<String> seedRpcList = await Global.getSeedRpcList(this._wallet.address);
      Wallet nkn = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
      if (nkn.address.isEmpty || nkn.address != _wallet.address) {
        Toast.show(_localizations.password_wrong);
        return false;
      }

      String amount = _amount?.toString() ?? '0';
      String fee = _fee.toString();
      if (_sendTo == null || _sendTo!.isEmpty || amount == '0') {
        Toast.show(_localizations.enter_amount);
        return false;
      }

      double balance = await nkn.getBalance();
      double tradeAmount = double.tryParse(amount) ?? 0;
      double tradeFee = (double.tryParse(fee) ?? 0);
      double tradeTotal = tradeAmount + tradeFee;
      if (tradeAmount <= 0 || balance < tradeTotal) {
        Toast.show(_localizations.balance_not_enough);
        return false;
      }

      nonce = nonce ?? await Global.getNonce(walletAddress: this._wallet.address);
      String? txHash = await nkn.transfer(_sendTo!, amount, fee: fee, nonce: nonce);
      if (txHash != null) {
        walletCommon.queryBalance(); // await
        return txHash.length > 10;
      }
      Toast.show(_localizations.failure);
      return false;
    } catch (e) {
      if (e.toString().contains("nonce is not continuous")) {
        // can not append tx to txpool: nonce is not continuous
        int? nonce = await Global.getNonce(walletAddress: this._wallet.address, forceFetch: true);
        return _transferNKN(name, keystore, password, nonce: nonce);
      }
      Global.refreshNonce(walletAddress: this._wallet.address);
      handleError(e, toast: _localizations.failure);
      return false;
    } finally {
      Loading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headIconHeight = Global.screenWidth() / 5;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        title: _wallet.type == WalletType.eth ? _localizations.send_eth : _localizations.send_nkn,
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg(
              'scan',
              width: 24,
              color: application.theme.backgroundLightColor,
            ),
            onPressed: () async {
              var qrData = await Navigator.pushNamed(context, ScannerScreen.routeName);
              logger.i("$TAG - QR_DATA:$qrData");
              if (qrData == null) return;
              // json
              var jsonFormat;
              var jsonData;
              try {
                jsonData = jsonFormat(qrData);
                jsonFormat = true;
              } catch (e) {
                jsonFormat = false;
              }
              // data
              if (jsonFormat) {
                logger.i("$TAG - wallet send scan - address:${jsonData['address']} amount:${jsonData['amount']}");
                _sendToController.text = jsonData['address'] ?? "";
                _amountController.text = jsonData['amount']?.toString() ?? "";
              } else if (_wallet.type == WalletType.nkn && verifyNknAddress(qrData.toString())) {
                logger.i("$TAG - wallet send scan NKN - address:$qrData");
                _sendToController.text = qrData.toString();
              } else if (_wallet.type == WalletType.eth && verifyEthAddress(qrData.toString())) {
                logger.i("$TAG - wallet send scan ETH - address:$qrData");
                _sendToController.text = qrData.toString();
              } else {
                ModalDialog.of(this.context).show(
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
                    child: Asset.image("wallet/transfer-header.png", height: headIconHeight),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints.expand(height: Global.screenHeight() - Header.height - headIconHeight - 10 - 20 - 30),
                decoration: BoxDecoration(
                  color: application.theme.backgroundLightColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, state) {
                    if (state is WalletLoaded) {
                      // refresh balance
                      List<WalletSchema> finds = state.wallets.where((w) => w.address == _wallet.address).toList();
                      if (finds.isNotEmpty) {
                        _wallet = finds[0];
                      }
                      // else {
                      //   Navigator.pop(this.context);
                      // }
                      if (_wallet.type == WalletType.nkn) {
                        _ethTrueTokenFalse = false;
                      }
                    }
                    bool useETH = _wallet.type == WalletType.eth && _ethTrueTokenFalse;
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
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// wallet
                                  WalletDropdown(
                                    selectTitle: _localizations.select_asset_to_send,
                                    wallet: _wallet,
                                    onTapWave: false,
                                    onSelected: (WalletSchema picked) {
                                      logger.i("$TAG - wallet picked - $picked");
                                      setState(() {
                                        _wallet = picked;
                                      });
                                      _init(_wallet.type == WalletType.eth);
                                    },
                                  ),
                                  Divider(height: 3),
                                  SizedBox(height: 20),

                                  /// amount
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
                                    onSaved: (String? v) => _amount = num.tryParse(v ?? "0") ?? 0,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                    showErrorMessage: false,
                                    suffixIcon: GestureDetector(
                                      child: Container(
                                        width: 20,
                                        alignment: Alignment.centerRight,
                                        child: Label(
                                          useETH ? _localizations.eth : _localizations.nkn,
                                          type: LabelType.bodyRegular,
                                          color: application.theme.primaryColor,
                                        ),
                                      ),
                                      onTap: () {
                                        if (_wallet.type == WalletType.eth) {
                                          _amountController.text = '';
                                          setState(() {
                                            _ethTrueTokenFalse = !_ethTrueTokenFalse;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 4),

                                  /// available
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Label(_localizations.available + ': '),
                                          Label(
                                            nknFormat(
                                              useETH ? _wallet.balanceEth : _wallet.balance,
                                              decimalDigits: 8,
                                              symbol: useETH ? 'ETH' : 'NKN',
                                            ),
                                            maxWidth: Global.screenWidth() * 0.5,
                                            maxLines: 10,
                                            softWrap: true,
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
                                          _setAmountToMax(_wallet.type == WalletType.eth);
                                        },
                                      )
                                    ],
                                  ),
                                  SizedBox(height: 20),

                                  /// sendTo
                                  Label(
                                    _localizations.send_to,
                                    type: LabelType.h4,
                                    textAlign: TextAlign.start,
                                  ),
                                  FormText(
                                    controller: _sendToController,
                                    focusNode: _sendToFocusNode,
                                    hintText: _localizations.enter_receive_address,
                                    validator: _wallet.type == WalletType.eth ? Validator.of(context).addressETH() : Validator.of(context).addressNKN(),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_feeToFocusNode),
                                    onSaved: (v) => _sendTo = v,
                                    suffixIcon: _wallet.type == WalletType.eth
                                        ? SizedBox.shrink()
                                        : GestureDetector(
                                            onTap: () async {
                                              if (clientCommon.status == ClientConnectStatus.connected) {
                                                var contact = await ContactHomeScreen.go(context, isSelect: true);
                                                if (contact != null && (contact is ContactSchema)) {
                                                  _sendToController.text = contact.nknWalletAddress ?? (await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(contact.clientAddress))) ?? "";
                                                }
                                              } else {
                                                Toast.show(_localizations.d_chat_not_login);
                                              }
                                            },
                                            child: Container(
                                              width: 20,
                                              alignment: Alignment.centerRight,
                                              child: Icon(FontAwesomeIcons.solidAddressBook),
                                            ),
                                          ),
                                  ),

                                  /// fee
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
                                              child: Asset.iconSvg('down', color: application.theme.primaryColor, width: 20),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: Global.screenWidth() / 4,
                                        child: FormText(
                                          padding: EdgeInsets.only(top: 10),
                                          controller: _feeController,
                                          focusNode: _feeToFocusNode,
                                          onSaved: (v) => _fee = double.tryParse(v ?? "0") ?? 0,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(null),
                                          onChanged: (v) {
                                            _checkFeeForm(_wallet.type == WalletType.eth, v);
                                          },
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+\.?[0-9]{0,8}'))],
                                          suffixIcon: GestureDetector(
                                            child: Container(
                                              width: 20,
                                              alignment: Alignment.centerRight,
                                              child: Label(
                                                _wallet.type == WalletType.eth ? _localizations.eth : _localizations.nkn,
                                                type: LabelType.label,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),

                                  /// fee slider
                                  _wallet.type == WalletType.eth
                                      ? ExpansionLayout(
                                          isExpanded: _showFeeLayout,
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 16),
                                                    child: Label(
                                                      _localizations.gas_price,
                                                      type: LabelType.h4,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: <Widget>[
                                                            Label(
                                                              _sliderGasPriceMin.toString() + ' ' + _localizations.gwei,
                                                              type: LabelType.bodySmall,
                                                              color: application.theme.primaryColor,
                                                            ),
                                                            Label(
                                                              _sliderGasPriceMax.toString() + ' ' + _localizations.gwei,
                                                              type: LabelType.bodySmall,
                                                              color: application.theme.primaryColor,
                                                            ),
                                                          ],
                                                        ),
                                                        Slider(
                                                          value: _gasPriceInGwei.toDouble(),
                                                          onChanged: (v) {
                                                            _updateFee(true, gweiFee: v.toInt());
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
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 22),
                                                    child: Label(
                                                      _localizations.gas_max,
                                                      type: LabelType.h4,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: <Widget>[
                                                            Label(
                                                              (_ethTrueTokenFalse ? _sliderMaxGasMinEth : _sliderMaxGasMinNkn).toString(),
                                                              type: LabelType.bodySmall,
                                                              color: application.theme.primaryColor,
                                                            ),
                                                            Label(
                                                              _sliderMaxGasMax.toString(),
                                                              type: LabelType.bodySmall,
                                                              color: application.theme.primaryColor,
                                                            ),
                                                          ],
                                                        ),
                                                        Slider(
                                                          value: _maxGasGet,
                                                          onChanged: (v) {
                                                            _updateFee(true, gasFee: v.round());
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
                                        )
                                      : ExpansionLayout(
                                          isExpanded: _showFeeLayout,
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
                                                  _updateFee(false, nknFee: v);
                                                },
                                                max: _sliderFeeMax,
                                                min: _sliderFeeMin,
                                              ),
                                            ],
                                          ),
                                        ),
                                ],
                              ),
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
                                      text: _localizations.continue_text,
                                      width: double.infinity,
                                      disabled: !_formValid,
                                      onPressed: _goToTransfer,
                                    ),
                                  ),
                                ],
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
