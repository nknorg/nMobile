import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatTopicSearchLayout extends BaseStateFulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends BaseStateFulWidgetState<ChatTopicSearchLayout> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _topicController = TextEditingController();
  bool _privateSelected = false;

  TextEditingController _feeController = TextEditingController();
  FocusNode _feeFocusNode = FocusNode();
  bool _showFeeLayout = false;
  double _fee = 0;
  double _sliderFee = 0.1;
  double _sliderFeeMin = 0;
  double _sliderFeeMax = 10;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _feeController.text = _fee.toString();
  }

  Future<bool> createOrJoinTopic(String? topicName, double fee) async {
    if (topicName == null || topicName.isEmpty) return false;

    if (_privateSelected) {
      if (clientCommon.publicKey == null || clientCommon.publicKey!.isEmpty) return false;
      if (Validate.isPrivateTopicOk(topicName)) {
        int index = topicName.lastIndexOf('.');
        String owner = topicName.substring(index + 1);
        if (owner != hexEncode(clientCommon.publicKey!)) return false;
      } else {
        topicName = '$topicName.${hexEncode(clientCommon.publicKey!)}';
      }
    }

    Loading.show();
    TopicSchema? _topic = await topicCommon.subscribe(topicName, fetchSubscribers: true, fee: fee);
    Loading.dismiss();

    if (_topic == null) return false;
    if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    ChatMessagesScreen.go(Global.appContext, _topic);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: () {
        _formValid = (_formKey.currentState as FormState).validate();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(width: 20),
                  Label(
                    _localizations.name,
                    type: LabelType.bodyRegular,
                    color: _theme.fontColor1,
                    textAlign: TextAlign.start,
                  ),
                  Spacer(),
                  Row(
                    children: <Widget>[
                      Label(
                        _localizations.private_channel,
                        type: LabelType.bodyRegular,
                        color: _theme.fontColor1,
                      ),
                      CupertinoSwitch(
                        value: _privateSelected,
                        activeColor: _theme.primaryColor,
                        onChanged: (value) async {
                          setState(() {
                            _privateSelected = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(width: 20),
                ],
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: FormText(
                        controller: _topicController,
                        hintText: _localizations.input_name,
                        validator: Validator.of(context).required(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFeeLayout = !_showFeeLayout;
                      });
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(width: 20),
                        Label(
                          _localizations.advanced,
                          type: LabelType.bodyRegular,
                          color: _theme.fontColor1,
                          textAlign: TextAlign.start,
                        ),
                        RotatedBox(
                          quarterTurns: _showFeeLayout ? 2 : 0,
                          child: Asset.iconSvg('down', color: _theme.primaryColor, width: 20),
                        ),
                        SizedBox(width: 20),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionLayout(
                isExpanded: _showFeeLayout,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(width: 20),
                        Label(
                          _localizations.fee,
                          type: LabelType.bodyRegular,
                          color: _theme.fontColor1,
                          textAlign: TextAlign.start,
                        ),
                        Spacer(),
                        SizedBox(
                          width: Global.screenWidth() / 3,
                          child: FormText(
                            controller: _feeController,
                            focusNode: _feeFocusNode,
                            padding: const EdgeInsets.only(bottom: 0),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [FilteringTextInputFormatter.allow(Validate.regWalletAmount)],
                            onSaved: (v) => _fee = double.tryParse(v ?? '0') ?? 0,
                            onChanged: (v) {
                              setState(() {
                                double fee = v.isNotEmpty ? (double.tryParse(v) ?? 0) : 0;
                                if (fee > _sliderFeeMax) {
                                  fee = _sliderFeeMax;
                                } else if (fee < _sliderFeeMin) {
                                  fee = _sliderFeeMin;
                                }
                                _sliderFee = fee;
                              });
                            },
                            suffixIcon: GestureDetector(
                              onTap: () {},
                              child: Container(
                                width: 20,
                                alignment: Alignment.centerRight,
                                child: Label(_localizations.nkn, type: LabelType.label),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        SizedBox(width: 16),
                        Label(
                          _localizations.slow,
                          type: LabelType.bodySmall,
                          color: _theme.primaryColor,
                        ),
                        Spacer(),
                        Label(
                          _localizations.average,
                          type: LabelType.bodySmall,
                          color: _theme.primaryColor,
                        ),
                        Spacer(),
                        Label(
                          _localizations.fast,
                          type: LabelType.bodySmall,
                          color: _theme.primaryColor,
                        ),
                        SizedBox(width: 20),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 6),
                      child: Slider(
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
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16, top: 16),
                child: Label(
                  _localizations.popular_channels,
                  type: LabelType.h4,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: _getPopularListView(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 18),
              child: Button(
                width: double.infinity,
                text: _localizations.continue_text,
                onPressed: () {
                  if (_formValid) createOrJoinTopic(_topicController.text, _fee);
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  _getPopularListView() {
    double itemHeight = 40;
    List<Widget> list = [];

    for (PopularChannel item in PopularChannel.defaultData()) {
      list.add(InkWell(
        onTap: () {
          createOrJoinTopic(item.topic, 0);
        },
        child: Container(
          width: double.infinity,
          height: itemHeight,
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: itemHeight,
                width: itemHeight,
                decoration: BoxDecoration(
                  color: item.titleBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Label(
                    item.title,
                    type: LabelType.h4,
                    color: item.titleColor,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Label(
                      item.topic,
                      type: LabelType.bodyRegular,
                      color: application.theme.fontColor1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Label(
                      item.desc,
                      height: 1,
                      type: LabelType.bodySmall,
                    ),
                  ],
                ),
              ),
              Asset.svg(
                'icons/chat',
                width: 24,
                color: application.theme.primaryColor,
              ),
            ],
          ),
        ),
      ));
    }
    return SingleChildScrollView(
      child: Column(
        children: list,
      ),
    );
  }
}
