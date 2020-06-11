import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
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
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

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
      SizedBox(width: 6.w),
      Label(widget.arguments.topicName, type: LabelType.h3, dark: true),
    ];
    if (widget.arguments.type == TopicType.private) {
      topicWidget.insert(
        0,
        SvgPicture.asset(
          'assets/icons/lock.svg',
          width: 22,
          color: DefaultTheme.fontLightColor,
        ),
      );
    }
    return Scaffold(
      appBar: Header(
        title: NMobileLocalizations.of(context).channel_settings,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'user-plus',
            color: DefaultTheme.backgroundLightColor,
            width: 24,
          ),
          onPressed: () async {
            var address = await BottomDialog.of(context).showInputAddressDialog(title: NMobileLocalizations.of(context).invite_members, hint: NMobileLocalizations.of(context).enter_or_select_a_user_pubkey);
            if (address != null) {
              acceptPrivateAction(address);
            }
          },
        ),
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
                          padding: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 20.w),
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(right: 16.w),
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
                padding: const EdgeInsets.only(top: 12),
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
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.line))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Label(
                                                NMobileLocalizations.of(context).topic,
                                                type: LabelType.h4,
                                                overflow: TextOverflow.ellipsis,
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
                                          SizedBox(
                                            height: 10.h,
                                          ),
                                          InkWell(
                                              onTap: () {
                                                CopyUtils.copyAction(context, widget.arguments.topic);
                                              },
                                              child: Label(
                                                widget.arguments.topic,
                                                type: LabelType.bodyRegular,
                                                color: DefaultTheme.fontColor1,
                                              )),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.line))),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: widget.arguments);
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
                                    getTopicStatusView()
                                  ],
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
        onTap: () async {
          unSubscriberAction();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          width: double.infinity,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.line))),
          child: Column(
            children: <Widget>[
              Label(
                NMobileLocalizations.of(context).unsubscribe,
                type: LabelType.bodyLarge,
                color: Colors.red,
                fontWeight: FontWeight.bold,
                height: 1,
              )
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          subscriberAction();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          width: double.infinity,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.line))),
          child: Column(
            children: <Widget>[
              Label(
                NMobileLocalizations.of(context).subscribe,
                type: LabelType.bodyLarge,
                color: DefaultTheme.primaryColor,
                fontWeight: FontWeight.bold,
                height: 1,
              )
            ],
          ),
        ),
      );
    }
  }

  unSubscriberAction() async {
    var result = await ModalDialog.of(context).confirm(
      height: 350.h,
      title: Label(
        NMobileLocalizations.of(context).leave_group_confirm_title,
        type: LabelType.h2,
        softWrap: true,
      ),
      content: Container(),
      agree: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Button(
          child: Label(
            NMobileLocalizations.of(context).unsubscribe,
            type: LabelType.h3,
          ),
          backgroundColor: DefaultTheme.strongColor,
          width: double.infinity,
          onPressed: () {
            widget.arguments.unsubscribe();
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

  acceptPrivateAction(address) async {
    showToast(NMobileLocalizations.of(context).invitation_sent);
    if (widget.arguments.type == TopicType.private) {
      await widget.arguments.acceptPrivateMember(addr: address);
    }

    var sendMsg = MessageSchema.fromSendData(from: Global.currentClient.address, content: widget.arguments.topic, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;

    var sendMsg1 = MessageSchema.fromSendData(from: Global.currentClient.address, topic: widget.arguments.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
    sendMsg1.isOutbound = true;

    try {
      _chatBloc.add(SendMessage(sendMsg));
      _chatBloc.add(SendMessage(sendMsg1));
    } catch (e) {
      print('send message error: $e');
    }
  }
}
