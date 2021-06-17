import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class CreateGroupDialog extends BaseStateFulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends BaseStateFulWidgetState<CreateGroupDialog> {
  TextEditingController _topicController = TextEditingController();
  TextEditingController _feeController = TextEditingController();
  FocusNode _feeToFocusNode = FocusNode();
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;
  bool _showFeeLayout = false;
  double _fee = 0;
  double _sliderFee = 0.1;
  double _sliderFeeMin = 0;
  double _sliderFeeMax = 10;
  bool _loading = false;
  bool _privateSelected = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _feeController.text = _fee.toString();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.always,
      onChanged: () {
        _formValid = (_formKey.currentState as FormState).validate();
      },
      child: Flex(
        direction: Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Label(
                      _localizations.name,
                      type: LabelType.bodyRegular,
                      color: _theme.fontColor1,
                      textAlign: TextAlign.start,
                    ),
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
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: FormText(
                        controller: _topicController,
                        validator: Validator.of(context).required(),
                        hintText: _localizations.input_name,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionLayout(
                isExpanded: _showFeeLayout,
                child: Container(
                  width: double.infinity,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Label(
                                  _localizations.fee,
                                  type: LabelType.bodyRegular,
                                  color: _theme.fontColor1,
                                  textAlign: TextAlign.start,
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 160,
                              child: FormText(
                                controller: _feeController,
                                focusNode: _feeToFocusNode,
                                padding: const EdgeInsets.only(bottom: 0),
                                onSaved: (v) => _fee = double.parse(v ?? '0'),
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
                                suffixIcon: GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    width: 20,
                                    alignment: Alignment.centerRight,
                                    child: Label(
                                      _localizations.nkn,
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
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8, top: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Label(
                              _localizations.slow,
                              type: LabelType.bodySmall,
                              color: _theme.primaryColor,
                            ),
                            Label(
                              _localizations.average,
                              type: LabelType.bodySmall,
                              color: _theme.primaryColor,
                            ),
                            Label(
                              _localizations.fast,
                              type: LabelType.bodySmall,
                              color: _theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 6, top: 0),
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
            flex: 1,
            child: getPopularView(),
          ),
          Expanded(
            flex: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                child: Button(
                  text: _localizations.continue_text,
                  width: double.infinity,
                  disabled: _loading,
                  onPressed: () async {
                    if (_formValid) {
                      createOrJoinGroup(_topicController.text);
                    }
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  getPopularView() {
    List<Widget> list = [];
    for (PopularChannel item in PopularChannel.defaultData()) {
      list.add(InkWell(
        onTap: () async {
          createOrJoinGroup(item.topic);
        },
        child: Container(
          height: 40,
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(color: item.titleBgColor, borderRadius: BorderRadius.circular(8)),
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
                child: Row(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      height: 40,
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
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/chat.svg',
                width: 24,
                color: application.theme.primaryColor,
              ),
            ],
          ),
        ),
      ));
    }
    return Container(
      height: 200,
      child: SingleChildScrollView(
        child: Column(
          children: list,
        ),
      ),
    );
  }

  _createOrJoinGroupSuccess(String topicName) async {
    // todo
    // await GroupChatHelper.insertTopicIfNotExists(topicName);
    // var group = await GroupChatHelper.fetchTopicInfoByName(topicName);
    //
    // Navigator.of(context).pushNamed(MessageChatPage.routeName,
    //     arguments: group);
  }

  createOrJoinGroup(topicName) async {
    // todo
    // if (isEmpty(topicName)) {
    //   return;
    // }
    // if (_privateSelected) {
    //   if (!isPrivateTopicReg(topicName)) {
    //     String pubKey = NKNClientCaller.currentChatId;
    //     topicName = '$topicName.$pubKey';
    //   }
    // }
    // var group = await GroupChatHelper.fetchTopicInfoByName(topicName);
    // if (group != null) {
    //   _createOrJoinGroupSuccess(topicName);
    // } else {
    //   setState(() {
    //     _loading = true;
    //   });
    //   EasyLoading.show();
    //   await GroupDataCenter.subscribeTopic(
    //       topicName: topicName,
    //       chatBloc: _chatBloc,
    //       callback: (success, e) async {
    //         if (success) {
    //           NLog.w('SubscriberTopic Success____'+topicName.toString());
    //           final topicSpotName = Topic.spotName(name: topicName);
    //           if (topicSpotName.isPrivate) {
    //             GroupDataCenter.pullPrivateSubscribers(topicName);
    //             GroupDataCenter.addPrivatePermissionList(topicName, NKNClientCaller.currentChatId);
    //           } else {
    //             GroupDataCenter.pullSubscribersPublicChannel(topicName);
    //           }
    //           _createOrJoinGroupSuccess(topicName);
    //         } else {
    //           if (e != null) {
    //             NLog.w('Create Or join Group E:' + e.toString());
    //           }
    //           showToast('create_input_group topic failed');
    //         }
    //       });
    //   EasyLoading.dismiss();
    Navigator.pop(context);
    setState(() {
      _loading = false;
    });
  }
}
