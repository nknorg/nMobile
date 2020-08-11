import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/popular_channel.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/populai_group_page.dart';
import 'package:nmobile/utils/image_utils.dart';

class InputChannelDialog extends StatefulWidget {
  @override
  _InputChannelDialogState createState() => _InputChannelDialogState();

  final String title;
  Function updateHeight;

  InputChannelDialog({
    @required this.title,
    this.updateHeight,
  });
}

class _InputChannelDialogState extends State<InputChannelDialog> with AccountDependsBloc {
  ChatBloc _chatBloc;
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
  double _height = 320;
  bool _loading = false;
  bool _privateSelected = false;

  @override
  void initState() {
    super.initState();
    _feeController.text = _fee.toString();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Form(
        key: _formKey,
        autovalidate: true,
        onChanged: () {
          _formValid = (_formKey.currentState as FormState).validate();
        },
        child: Flex(
          direction: Axis.vertical,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(
                constraints: BoxConstraints(minHeight: _height - 20, maxHeight: _height - 20),
                child: Flex(
                  direction: Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
                        child: Label(
                          widget.title,
                          type: LabelType.h2,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Label(
                                  NL10ns.of(context).topic,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Row(
                                  children: <Widget>[
                                    Label(
                                      NL10ns.of(context).private_channel,
                                      type: LabelType.h4,
                                      color: DefaultTheme.fontColor1,
                                    ),
                                    CupertinoSwitch(
                                      value: _privateSelected,
                                      activeColor: DefaultTheme.primaryColor,
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
                                  child: Textbox(
                                    controller: _topicController,
                                    validator: Validator.of(context).required(),
                                    hintText: NL10ns.of(context).enter_topic,
                                  ),
                                ),
                                Container(
                                  child: InkWell(
                                    child: loadAssetChatPng('group_blue', width: 24),
                                    onTap: () {
                                      Navigator.pushNamed(context, PopularGroupPage.routeName).then((v) {
                                        if (v != null) {
                                          _topicController.text = v;
                                        }
                                      });
                                    },
                                  ),
                                )
                              ],
                            ),
                          ),
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
                                    if (_showFeeLayout) {
                                      _height = 450;
                                    } else {
                                      _height = 350;
                                    }
                                    widget.updateHeight(_height);
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Label(
                                        NL10ns.of(context).advanced,
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
                              ],
                            ),
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
                                              NL10ns.of(context).fee,
                                              color: DefaultTheme.fontColor1,
                                              type: LabelType.h4,
                                              textAlign: TextAlign.start,
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          width: 160,
                                          child: Textbox(
                                            controller: _feeController,
                                            focusNode: _feeToFocusNode,
                                            padding: const EdgeInsets.only(bottom: 0),
                                            onSaved: (v) => _fee = double.parse(v ?? 0),
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
                                                  NL10ns.of(context).nkn,
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
                                          NL10ns.of(context).slow,
                                          type: LabelType.bodySmall,
                                          color: DefaultTheme.primaryColor,
                                        ),
                                        Label(
                                          NL10ns.of(context).average,
                                          type: LabelType.bodySmall,
                                          color: DefaultTheme.primaryColor,
                                        ),
                                        Label(
                                          NL10ns.of(context).fast,
                                          type: LabelType.bodySmall,
                                          color: DefaultTheme.primaryColor,
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
                          ExpansionLayout(
                            isExpanded: true,
                            child: getPopularView(),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
                child: Button(
                  text: NL10ns.of(context).continue_text,
                  width: double.infinity,
                  disabled: _loading,
                  onPressed: () async {
                    if (_formValid) {
                      createOrJoinGroup(_topicController.text);
                    }
                  },
                ),
              ),
            )
          ],
        ),
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
          height: 40.h,
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 40.h,
                width: 50.w,
                decoration: BoxDecoration(color: item.titleBgColor, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Label(
                    item.title,
                    type: LabelType.h4,
                    color: item.titleColor,
                  ),
                ),
              ),
              SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.only(),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      height: 44,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(),
                              Label(
                                item.topic,
                                type: LabelType.h3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Label(
                            item.topic,
                            height: 1,
                            type: LabelType.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return Column(
      children: list,
    );
  }

  createOrJoinGroup(topic) async {
    if (topic == null || topic.isEmpty) {
      return;
    }
    String type = TopicType.public;
    String owner;
    if (_privateSelected) {
      if (!isPrivateTopic(topic)) {
        topic = '$topic.$accountPubkey';
        owner = accountPubkey;
      } else {
        owner = getOwnerPubkeyByTopic(topic);
      }
      type = TopicType.private;
    }

    setState(() {
      _loading = true;
    });
    EasyLoading.show();
    var duration = 400000;
    var hash = await TopicSchema.subscribe(account, topic: topic, duration: duration);
    if (hash != null) {
      var sendMsg = MessageSchema.fromSendData(
        from: accountChatId,
        topic: topic,
        contentType: ContentType.dchatSubscribe,
      );
      sendMsg.isOutbound = true;
      sendMsg.content = sendMsg.toDchatSubscribeData();
      _chatBloc.add(SendMessage(sendMsg));

      DateTime now = DateTime.now();
      var topicSchema = TopicSchema(topic: topic, type: type, owner: owner, expiresAt: now.add(blockToExpiresTime(duration)));
      if (type == TopicType.private) {
        topicSchema.acceptPrivateMember(account, addr: accountPubkey);
      }

      await topicSchema.insertOrUpdate(db, accountPubkey);
      topicSchema = await TopicSchema.getTopic(db, topic);
      EasyLoading.dismiss();
      if (type == TopicType.private) {
        Navigator.of(context).pushReplacementNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.PrivateChannel, topic: topicSchema));
      } else {
        Navigator.of(context).pushReplacementNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.Channel, topic: topicSchema));
      }
    }
    setState(() {
      _loading = false;
    });
  }
}
