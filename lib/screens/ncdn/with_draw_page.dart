import 'dart:convert';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/tweetnacl/tools.dart';
import 'package:oktoast/oktoast.dart';

import '../../consts/theme.dart';

class WithDrawPage extends StatefulWidget {
  static final String routeName = "WithDrawPage";
  final Map arguments;

  const WithDrawPage({Key key, this.arguments}) : super(key: key);

  @override
  WithDrawPageState createState() => new WithDrawPageState();
}

class WithDrawPageState extends State<WithDrawPage> {
  bool _formValid = false;
  final String SERVER_PUBKEY = 'eb08c2a27cb61fe414654a1e9875113d715737247addf01db06ea66cafe0b5c8';
  GlobalKey _formKey = new GlobalKey<FormState>();
  TextEditingController amountController;
  TextEditingController addressController;
  String _publicKey;
  String _seed;
  FocusNode _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    LogUtil.v('onCreate', tag: 'WithDrawPage');
    _publicKey = widget.arguments['publicKey'];
    _seed = widget.arguments['seed'];
    amountController = TextEditingController();
    addressController = TextEditingController();
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_commentFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '申请提现',
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 2, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Form(
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
                    Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            children: <Widget>[
                              Label(
                                '可提现余额: ',
                                type: LabelType.h4,
                                color: DefaultTheme.fontColor2,
                              ),
                              SizedBox(width: 10),
                              Label(
                                Format.currencyFormat(widget.arguments['maxBalance'], decimalDigits: 3) + 'USDT',
                                type: LabelType.h4,
                              )
                            ],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              '提现金额（USDT）',
                              type: LabelType.h4,
                              color: DefaultTheme.fontColor2,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                child: Textbox(
                                  controller: amountController,
                                  showErrorMessage: true,
                                  padding: EdgeInsets.zero,
                                  focusNode: _commentFocus,
                                  validator: Validator.of(context).amount(max: widget.arguments['maxBalance']),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'^[0-9]*\\.?[0-9]{0,3}'))],
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  amountController.text = widget.arguments['maxBalance'].floor().toString();
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 5),
                                child: Label(
                                  '全部',
                                  color: DefaultTheme.primaryColor,
                                  type: LabelType.bodyLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              '提现地址(ERC-20)',
                              type: LabelType.h4,
                              color: DefaultTheme.fontColor2,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                        Textbox(
                          controller: addressController,
                          showErrorMessage: true,
                          validator: Validator.of(context).ethIdentifier(),
//                inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'/^0x[a-fA-F0-9]{40}$/'))],
                        ),
                        SizedBox(height: 20.h),
                        Button(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Label(
                                NMobileLocalizations.of(context).ok,
                                type: LabelType.h3,
                              )
                            ],
                          ),
                          backgroundColor: DefaultTheme.primaryColor,
                          width: double.infinity,
                          onPressed: () async {
                            verifyWithdraw();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  verifyWithdraw() {
    if ((_formKey.currentState as FormState).validate()) {
      Api _api = Api(mySecretKey: hexDecode(_seed), myPublicKey: hexDecode(_publicKey), otherPubkey: hexDecode(SERVER_PUBKEY));
      var data = {
        'beneficiary': widget.arguments['address'],
        'amount': num.parse(amountController.text),
        'eth_beneficiary': addressController.text,
        'id': uuid.v4(),
      };

//      String url = 'http://10.0.1.4:6080/api/v2/verify_withdraw/';
      String url = 'http://39.100.108.44:6443/api/v2/verify_withdraw/';
      try {
        _api.post(url, data, isEncrypted: true, getResponse: true).then((res) {
          LogUtil.v(res);
          if (res.data['success']) {
            Navigator.of(context).pop(true);
            showToast('提现申请提交成功，请等待工作人员处理。');
          } else {
            var s = _api.decryptData(res.data['result']);
            showToast(jsonDecode(s)['err']);
          }
        });
      } catch (e) {
        showToast('请稍后重试');
      }
    }
  }
}
