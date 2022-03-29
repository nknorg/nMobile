import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/fixed_text_field.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/storages/settings.dart';

class SettingsSubscribeScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/subscribe';

  @override
  _SettingsSubscribeScreenState createState() => _SettingsSubscribeScreenState();
}

class _SettingsSubscribeScreenState extends BaseStateFulWidgetState<SettingsSubscribeScreen> {
  TextEditingController _feeController = TextEditingController();
  FocusNode _feeFocusNode = FocusNode();

  double _fee = 0;
  bool _subscribeSpeedEnable = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _refreshSubscribeFee();
    _refreshSubscribeSpeedEnable();
  }

  @override
  void dispose() {
    _saveSubscribeFee();
    super.dispose();
  }

  _refreshSubscribeFee() async {
    _fee = double.tryParse(await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_SUBSCRIBE_FEE)) ?? 0;
    if (_fee <= 0) _fee = Global.topicSubscribeFeeDefault;
    _feeController.text = _fee.toStringAsFixed(8);
  }

  _refreshSubscribeSpeedEnable() async {
    var enable = await SettingsStorage.getSettings(SettingsStorage.DEFAULT_TOPIC_SUBSCRIBE_SPEED_ENABLE);
    _subscribeSpeedEnable = (enable?.toString() == "true") || (enable == true);
  }

  _saveSubscribeFee() async {
    await SettingsStorage.setSettings(SettingsStorage.DEFAULT_TOPIC_SUBSCRIBE_FEE, _fee.toStringAsFixed(8));
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Global.locale((s) => s.fee, ctx: context),
        backgroundColor: application.theme.headBarColor2,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      style: _buttonStyle(top: true, bottom: true),
                      onPressed: () async {
                        FocusScope.of(context).requestFocus(_feeFocusNode);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Global.locale((s) => s.fee, ctx: context),
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              SizedBox(
                                width: Global.screenWidth() / 3,
                                child: FixedTextField(
                                  controller: _feeController,
                                  focusNode: _feeFocusNode,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [FilteringTextInputFormatter.allow(Validate.regWalletAmount)],
                                  textAlign: TextAlign.end,
                                  style: TextStyle(fontSize: 14, height: 1.4),
                                  decoration: InputDecoration(
                                    hintText: Global.locale((s) => s.enter_amount, ctx: context),
                                    hintStyle: TextStyle(color: application.theme.fontColor2.withAlpha(100)),
                                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    border: UnderlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(20)),
                                      borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    double fee = v.isNotEmpty ? (double.tryParse(v) ?? 0) : 0;
                                    if (fee <= 0) fee = Global.topicSubscribeFeeDefault;
                                    _fee = fee;
                                  },
                                ),
                              ),
                              Container(
                                alignment: Alignment.centerRight,
                                child: Label(Global.locale((s) => s.nkn), type: LabelType.bodyRegular),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 6),
              child: Label(
                Global.locale((s) => s.transfer_speed_up_fee, ctx: context),
                type: LabelType.bodySmall,
                fontWeight: FontWeight.w600,
                softWrap: true,
              ),
            ),
            SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      style: _buttonStyle(top: true, bottom: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Global.locale((s) => s.topic_resubscribe_speed_enable, ctx: context),
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              CupertinoSwitch(
                                  value: _subscribeSpeedEnable,
                                  activeColor: application.theme.primaryColor,
                                  onChanged: (bool value) async {
                                    SettingsStorage.setSettings('${SettingsStorage.DEFAULT_TOPIC_SUBSCRIBE_SPEED_ENABLE}', value);
                                    setState(() {
                                      _subscribeSpeedEnable = value;
                                    });
                                  }),
                            ],
                          ),
                        ],
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  _buttonStyle({bool top = false, bool bottom = false}) {
    return ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: top ? Radius.circular(12) : Radius.zero, bottom: bottom ? Radius.circular(12) : Radius.zero)),
      ),
    );
  }
}
