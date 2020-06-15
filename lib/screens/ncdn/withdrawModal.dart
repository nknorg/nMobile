import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/validation.dart';

class WithdrawModal extends StatefulWidget {
  double maxBalance;
  GlobalKey formKey;
  TextEditingController amount;
  TextEditingController address;
  WithdrawModal({this.maxBalance, this.formKey, this.amount, this.address});

  @override
  _WithdrawModalState createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<WithdrawModal> {
  bool _formValid = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: widget.formKey,
        autovalidate: true,
        onChanged: () {
          setState(() {
            _formValid = (widget.formKey.currentState as FormState).validate();
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
                      Label(
                        Format.currencyFormat(widget.maxBalance, decimalDigits: 3),
                        type: LabelType.h4,
                      )
                    ],
                  ),
                ),
                Row(
                  children: <Widget>[
                    Label(
                      '提现金额',
                      type: LabelType.h4,
                      color: DefaultTheme.fontColor2,
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
                Textbox(
                  controller: widget.amount,
                  showErrorMessage: true,
                  validator: Validator.of(context).amount(max: widget.maxBalance),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'^[0-9]*\\.?[0-9]{0,3}'))],
                  textInputAction: TextInputAction.next,
                ),
                Row(
                  children: <Widget>[
                    Label(
                      '提现地址',
                      type: LabelType.h4,
                      color: DefaultTheme.fontColor2,
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
                Textbox(
                  controller: widget.address,
                  showErrorMessage: true,
                  validator: Validator.of(context).ethIdentifier(),
//                inputFormatters: [WhitelistingTextInputFormatter(RegExp(r'/^0x[a-fA-F0-9]{40}$/'))],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
