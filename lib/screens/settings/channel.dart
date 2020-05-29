import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/utils/copy_utils.dart';

class ChannelSettingsScreen extends StatefulWidget {
  static const String routeName = '/settings/channel';

  final TopicSchema arguments;
  ChannelSettingsScreen({this.arguments});

  @override
  _ChannelSettingsScreenState createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
  ChatBloc _chatBloc;
  bool isUnSubscribe = false;
  initAsync() async {
    widget.arguments.getTopicCount().then((count) {
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    isUnSubscribe = LocalStorage.getUnsubscribeTopicList().contains(widget.arguments.topic);
    Global.removeTopicCache(widget.arguments.topic);
    initAsync();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> topicWidget = <Widget>[
      Label(widget.arguments.topicName, type: LabelType.h2, dark: true),
    ];
    if (widget.arguments.type == TopicType.private) {
      topicWidget.insert(
        0,
        SvgPicture.asset(
          'assets/icons/lock.svg',
          width: 24,
          color: DefaultTheme.fontLightColor,
        ),
      );
    }
    return Scaffold(
      appBar: Header(
        title: NMobileLocalizations.of(context).channel_settings.toUpperCase(),
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height),
                color: DefaultTheme.backgroundColor4,
                child: Flex(direction: Axis.vertical, children: <Widget>[
                  Expanded(
                    flex: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(bottom: 24, left: 20, right: 20),
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: widget.arguments.avatarWidget(
                                  backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                                  size: 48,
                                  fontColor: DefaultTheme.fontLightColor,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: topicWidget,
                                  ),
                                  Label('${widget.arguments.count} ' + NMobileLocalizations.of(context).members, type: LabelType.bodyRegular, color: DefaultTheme.successColor)
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            Positioned(
              top: 30,
              left: 50,
              child: Button(
                padding: const EdgeInsets.all(0),
                width: 24,
                height: 24,
                backgroundColor: DefaultTheme.primaryColor,
                child: SvgPicture.asset(
                  'assets/icons/camera.svg',
                  width: 16,
                ),
                onPressed: () async {
                  File savedImg = await getHeaderImage();
                  if (savedImg == null) return;

                  setState(() {
                    widget.arguments.avatar = savedImg;
                  });
                  await widget.arguments.setAvatar(savedImg);
                  _chatBloc.add(RefreshMessages());
                },
              ),
            ),
            Container(
              constraints: BoxConstraints.expand(height: MediaQuery.of(context).size.height - 190),
              child: BodyBox(
                padding: const EdgeInsets.only(top: 32),
                color: DefaultTheme.backgroundLightColor,
                child: Flex(
                  direction: Axis.vertical,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.only(top: 0),
                        child: SingleChildScrollView(
                          child: Flex(
                            direction: Axis.vertical,
                            children: <Widget>[
                              Expanded(
                                flex: 0,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 0),
                                  child: Column(
                                    children: <Widget>[
                                      Expanded(
                                        flex: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: <Widget>[
                                                  Label(
                                                    NMobileLocalizations.of(context).topic,
                                                    type: LabelType.h4,
                                                    textAlign: TextAlign.start,
                                                  ),
                                                  InkWell(
                                                    child: Label(
                                                      NMobileLocalizations.of(context).copy,
                                                      color: DefaultTheme.primaryColor,
                                                      type: LabelType.bodyRegular,
                                                    ),
                                                    onTap: () {
                                                      CopyUtils.copyAction(context, widget.arguments.topic);
                                                    },
                                                  ),
                                                ],
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  CopyUtils.copyAction(context, widget.arguments.topic);
                                                },
                                                child: Textbox(
                                                  value: widget.arguments.topic,
                                                  readOnly: true,
                                                  padding: EdgeInsets.zero,
                                                  enabled: false,
                                                  textInputAction: TextInputAction.next,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50.h,
                                        child: FlatButton(
                                          padding: const EdgeInsets.only(left: 16, right: 16),
                                          onPressed: () async {
                                            Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: TopicSchema(topic: widget.arguments.topic));
                                          },
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Label(
                                                NMobileLocalizations.of(context).view_channel_members,
                                                type: LabelType.bodyRegular,
                                                color: DefaultTheme.fontColor1,
                                                height: 1,
                                              ),
                                              SvgPicture.asset(
                                                'assets/icons/right.svg',
                                                width: 24,
                                                color: DefaultTheme.fontColor2,
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 1,
                                        margin: const EdgeInsets.only(left: 16, right: 16),
                                        color: DefaultTheme.line,
                                      ),
                                      getTopicStatusView()
                                    ],
                                  ),
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
            ),
            Positioned(
              top: 60,
              right: 20,
              child: Button(
                padding: const EdgeInsets.all(0),
                width: 56,
                height: 56,
                backgroundColor: DefaultTheme.primaryColor,
                child: SvgPicture.asset(
                  'assets/icons/chat.svg',
                  width: 24,
                ),
                onPressed: () async {
                  Navigator.of(context).pushNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, topic: widget.arguments));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  getTopicStatusView() {
    if (!isUnSubscribe) {
      return InkWell(
        onTap: () {
          unSubscriberAction();
        },
        child: Column(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: FlatButton(
                padding: const EdgeInsets.only(left: 16, right: 16),
                onPressed: () async {
                  Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: TopicSchema(topic: widget.arguments.topic));
                },
                child: Label(
                  NMobileLocalizations.of(context).unsubscribe,
                  type: LabelType.bodyRegular,
                  color: Colors.red,
                  height: 1,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 1,
              margin: const EdgeInsets.only(left: 16, right: 16),
              color: DefaultTheme.line,
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          subscriberAction();
        },
        child: Column(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: FlatButton(
                padding: const EdgeInsets.only(left: 16, right: 16),
                onPressed: () async {
                  Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: TopicSchema(topic: widget.arguments.topic));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Label(
                      NMobileLocalizations.of(context).subscribe,
                      type: LabelType.bodyRegular,
                      color: DefaultTheme.fontColor1,
                      height: 1,
                    ),
                    SvgPicture.asset(
                      'assets/icons/right.svg',
                      width: 24,
                      color: DefaultTheme.fontColor2,
                    )
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 1,
              margin: const EdgeInsets.only(left: 16, right: 16),
              color: DefaultTheme.line,
            ),
          ],
        ),
      );
    }
  }

  unSubscriberAction() async {
    var result = await ModalDialog.of(context).confirm(
      height: 380.h,
      title: Label(
        NMobileLocalizations.of(context).delete_chennel_confirm_title,
        type: LabelType.h2,
        softWrap: true,
      ),
      content: Column(
        children: <Widget>[
          Container(
            child: Container(
              height: 50.h,
              padding: const EdgeInsets.only(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.only(right: 16),
                    alignment: Alignment.center,
                    child: widget.arguments.avatarWidget(
                      backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                      fontColor: DefaultTheme.primaryColor,
                      size: 48,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Label(
                          widget.arguments.topic,
                          type: LabelType.h3,
                        ),
                        Label(
                          '${widget.arguments.count} ' + NMobileLocalizations.of(context).members,
                          type: LabelType.bodyRegular,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      agree: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Button(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SvgPicture.asset(
                  'assets/icons/trash.svg',
                  color: DefaultTheme.backgroundLightColor,
                  width: 24,
                ),
              ),
              Label(
                NMobileLocalizations.of(context).unsubscribe,
                type: LabelType.h3,
              )
            ],
          ),
          backgroundColor: DefaultTheme.strongColor,
          width: double.infinity,
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ),
      reject: Button(
        backgroundColor: DefaultTheme.backgroundLightColor,
        fontColor: DefaultTheme.fontColor2,
        text: NMobileLocalizations.of(context).cancel,
        width: double.infinity,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
    if (result == true) {

    }
  }

  subscriberAction() {
    var duration = 400000;
    String topic = widget.arguments.topic;
    LocalStorage.removeTopicFromUnsubscribeList(topic);
    Navigator.pop(context);
    TopicSchema.subscribe(topic: topic, duration: duration);
    var sendMsg = MessageSchema.fromSendData(
      from: Global.currentClient.address,
      topic: topic,
      contentType: ContentType.dchatSubscribe,
    );
    sendMsg.isOutbound = true;
    sendMsg.content = sendMsg.toDchatSubscribeData();
    _chatBloc.add(SendMessage(sendMsg));
    DateTime now = DateTime.now();
    // todo topic type
    var topicSchema = TopicSchema(topic: topic, expiresAt: now.add(blockToExpiresTime(duration)));
    topicSchema.insertIfNoData();
  }
}
