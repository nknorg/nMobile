import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class ChannelSettingsScreen extends StatefulWidget {
  static const String routeName = '/settings/channel';

  final TopicSchema arguments;

  ChannelSettingsScreen({this.arguments});

  @override
  _ChannelSettingsScreenState createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> with AccountDependsBloc {
  ChatBloc _chatBloc;
  bool isUnSubscribe = false;

  initAsync() async {
    widget.arguments.getTopicCount(account).then((count) {
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    isUnSubscribe = LocalStorage.getUnsubscribeTopicList(accountPubkey).contains(widget.arguments.topic);
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
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NMobileLocalizations.of(context).channel_settings,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Container(
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
        child: ConstrainedBox(
          constraints: BoxConstraints.expand(),
          child: Column(
            children: <Widget>[
              Container(
                height: 100,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        Container(
                          child: widget.arguments.avatarWidget(db,
                            backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                            size: 64,
                            fontColor: DefaultTheme.fontLightColor,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
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
                              File savedImg = await getHeaderImage(accountPubkey);
                              if (savedImg == null) return;

                              setState(() {
                                widget.arguments.avatar = savedImg;
                              });
                              await widget.arguments.setAvatar(await db, accountPubkey, savedImg);
                              _chatBloc.add(RefreshMessages());
                            },
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  child: BodyBox(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Container(
                              decoration: BoxDecoration(color: DefaultTheme.backgroundLightColor, borderRadius: BorderRadius.circular(12)),
                              margin: EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  FlatButton(
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                                    onPressed: () {
                                      CopyUtils.copyAction(context, widget.arguments.topic);
                                    },
                                    child: Row(
                                      children: <Widget>[
                                        loadAssetIconsImage(
                                          'user',
                                          color: DefaultTheme.primaryColor,
                                          width: 24,
                                        ),
                                        SizedBox(width: 10),
                                        Label(
                                          NMobileLocalizations.of(context).name,
                                          type: LabelType.bodyRegular,
                                          color: DefaultTheme.fontColor1,
                                          height: 1,
                                        ),
                                        SizedBox(width: 20),
                                        Expanded(
                                          child: Label(
                                            widget.arguments.topic,
                                            type: LabelType.bodyRegular,
                                            color: DefaultTheme.fontColor2,
                                            overflow: TextOverflow.fade,
                                            textAlign: TextAlign.right,
                                            height: 1,
                                          ),
                                        ),
                                        SvgPicture.asset(
                                          'assets/icons/right.svg',
                                          width: 24,
                                          color: DefaultTheme.fontColor2,
                                        )
                                      ],
                                    ),
                                  ).sized(h: 48),
                                  FlatButton(
                                    padding: const EdgeInsets.only(left: 16, right: 16),
                                    onPressed: () {
                                      Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: widget.arguments);
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: <Widget>[
                                        loadAssetChatPng('group_blue', width: 22.w),
                                        SizedBox(width: 10),
                                        Label(
                                          NMobileLocalizations.of(context).view_channel_members,
                                          type: LabelType.bodyRegular,
                                          color: DefaultTheme.fontColor1,
                                          height: 1,
                                        ),
                                        SizedBox(width: 20),
                                        Expanded(
                                          child: Label(
                                            '${widget.arguments.count} ' + NMobileLocalizations.of(context).members,
                                            type: LabelType.bodyRegular,
                                            textAlign: TextAlign.right,
                                            color: DefaultTheme.fontColor2,
                                            maxLines: 1,
                                          ),
                                        ),
                                        SvgPicture.asset(
                                          'assets/icons/right.svg',
                                          width: 24,
                                          color: DefaultTheme.fontColor2,
                                        )
                                      ],
                                    ),
                                  ).sized(h: 48),
                                  FlatButton(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                                    onPressed: () async {
                                      var address = await BottomDialog.of(context).showInputAddressDialog(title: NMobileLocalizations.of(context).invite_members, hint: NMobileLocalizations.of(context).enter_or_select_a_user_pubkey);
                                      if (address != null) {
                                        acceptPrivateAction(address);
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        loadAssetChatPng('invisit_blue', width: 20.w),
                                        SizedBox(width: 10),
                                        Label(
                                          NMobileLocalizations.of(context).invite_members,
                                          type: LabelType.bodyRegular,
                                          color: DefaultTheme.fontColor1,
                                          height: 1,
                                        ),
                                        SizedBox(width: 20),
                                        Spacer(),
                                        SvgPicture.asset(
                                          'assets/icons/right.svg',
                                          width: 24,
                                          color: DefaultTheme.fontColor2,
                                        )
                                      ],
                                    ),
                                  ).sized(h: 48),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            getTopicStatusView()
                          ],
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
    );
  }

  getTopicStatusView() {
    if (!isUnSubscribe) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 12, right: 12, top: 10),
        child: FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.exit_to_app,
                  color: Colors.red,
                ),
                SizedBox(width: 10),
                Text(
                  NMobileLocalizations.of(context).unsubscribe,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.red, fontSize: DefaultTheme.bodyRegularFontSize),
                ),
                Spacer(),
              ],
            ),
          ),
          onPressed: () {
            unSubscriberAction();
          },
        ).sized(h: 50, w: double.infinity),
      );
    } else {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 16, right: 16, top: 10),
        child: FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
          child: Container(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.person_add,
                  color: DefaultTheme.primaryColor,
                ),
                SizedBox(width: 10),
                Text(
                  NMobileLocalizations.of(context).subscribe,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: DefaultTheme.primaryColor, fontSize: DefaultTheme.bodyRegularFontSize),
                ),
                Spacer(),
              ],
            ),
          ),
          onPressed: () {
            subscriberAction();
          },
        ).sized(h: 50, w: double.infinity),
      );
    }
  }

  unSubscriberAction() async {
    SimpleConfirm(
            context: context,
            buttonColor: Colors.red,
            content: NMobileLocalizations.of(context).leave_group_confirm_title,
            callback: (b) {
              if (b) {
                widget.arguments.unsubscribe(account);
                Navigator.of(context).pop(true);
              }
            },
            buttonText: NMobileLocalizations.of(context).unsubscribe)
        .show();
  }

  subscriberAction() {
    var duration = 400000;
    String topic = widget.arguments.topic;
    LocalStorage.removeTopicFromUnsubscribeList(accountPubkey, topic);
    Navigator.pop(context);
    TopicSchema.subscribe(account, topic: topic, duration: duration);
    var sendMsg = MessageSchema.fromSendData(
      from: accountChatId,
      topic: topic,
      contentType: ContentType.dchatSubscribe,
    );
    sendMsg.isOutbound = true;
    sendMsg.content = sendMsg.toDchatSubscribeData();
    _chatBloc.add(SendMessage(sendMsg));
    DateTime now = DateTime.now();
    // todo topic type
    var topicSchema = TopicSchema(topic: topic, expiresAt: now.add(blockToExpiresTime(duration)));
    topicSchema.insertIfNoData(db, accountPubkey);
  }

  acceptPrivateAction(address) async {
    showToast(NMobileLocalizations.of(context).invitation_sent);
    if (widget.arguments.type == TopicType.private) {
      await widget.arguments.acceptPrivateMember(account, addr: address);
    }

    var sendMsg = MessageSchema.fromSendData(
        from: accountChatId, content: widget.arguments.topic, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;

    var sendMsg1 = MessageSchema.fromSendData(
        from: accountChatId, topic: widget.arguments.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
    sendMsg1.isOutbound = true;

    try {
      _chatBloc.add(SendMessage(sendMsg));
      _chatBloc.add(SendMessage(sendMsg1));
    } catch (e) {
      print('send message error: $e');
    }
  }
}
