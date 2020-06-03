import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/l10n/localization_intl.dart';
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

class _InputChannelDialogState extends State<InputChannelDialog> {
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
                                  NMobileLocalizations.of(context).topic,
                                  type: LabelType.h4,
                                  textAlign: TextAlign.start,
                                ),
                                Row(
                                  children: <Widget>[
                                    Label(
                                      NMobileLocalizations.of(context).private_channel,
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
                          Padding(
                            padding: EdgeInsets.only(left: 20, right: 20),
                            child: Textbox(
                              controller: _topicController,
                              validator: Validator.of(context).required(),
                              hintText: NMobileLocalizations.of(context).enter_topic,
                              suffixIcon: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(context, PopularGroupPage.routeName).then((v) {
                                    if (v != null) {
                                      _topicController.text = v;
                                    }
                                  });
                                },
                                child: Icon(
                                  Icons.group,
                                  size: 20,
                                  color: DefaultTheme.primaryColor,
                                ),
                              ),
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
                                        NMobileLocalizations.of(context).advanced,
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
                                              NMobileLocalizations.of(context).fee,
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
                                                  NMobileLocalizations.of(context).nkn,
                                                  type: LabelType.label,
                                                ),
                                              ),
                                            ),
                                            keyboardType: TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            textInputAction: TextInputAction.done,
                                            inputFormatters: [WhitelistingTextInputFormatter(RegExp('^[0-9]*.?[0-9]{0,8}'))],
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
                                          NMobileLocalizations.of(context).slow,
                                          type: LabelType.bodySmall,
                                          color: DefaultTheme.primaryColor,
                                        ),
                                        Label(
                                          NMobileLocalizations.of(context).average,
                                          type: LabelType.bodySmall,
                                          color: DefaultTheme.primaryColor,
                                        ),
                                        Label(
                                          NMobileLocalizations.of(context).fast,
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
                  text: NMobileLocalizations.of(context).continue_text,
                  width: double.infinity,
                  disabled: _loading,
                  onPressed: () async {
                    if (_formValid) {
                      String topic = _topicController.text;
                      if (topic == null || topic.isEmpty) {
                        return;
                      }
                      String type = TopicType.public;
                      String owner;
                      if (_privateSelected) {
                        if (!isPrivateTopic(topic)) {
                          topic = '$topic.${Global.currentClient.publicKey}';
                          owner = Global.currentClient.publicKey;
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
                      var hash = await TopicSchema.subscribe(topic: topic, duration: duration);
                      if (hash != null) {
                        var sendMsg = MessageSchema.fromSendData(
                          from: Global.currentClient.address,
                          topic: topic,
                          contentType: ContentType.dchatSubscribe,
                        );
                        sendMsg.isOutbound = true;
                        sendMsg.content = sendMsg.toDchatSubscribeData();
                        _chatBloc.add(SendMessage(sendMsg));

                        DateTime now = DateTime.now();
                        var topicSchema = TopicSchema(topic: topic, type: type, owner: owner, expiresAt: now.add(blockToExpiresTime(duration)));
                        if (type == TopicType.private) {
                          topicSchema.acceptPrivateMember(addr: Global.currentClient.publicKey);
                        }

                        await topicSchema.insertOrUpdate();
                        topicSchema = await TopicSchema.getTopic(topic);
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
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
