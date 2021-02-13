import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/chat/channel_bloc.dart';
import 'package:nmobile/blocs/chat/channel_event.dart';
import 'package:nmobile/blocs/chat/channel_state.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class ChannelSettingsScreen extends StatefulWidget {
  static const String routeName = '/settings/channel';

  Topic arguments;

  ChannelSettingsScreen({this.arguments});

  @override
  _ChannelSettingsScreenState createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
  ChatBloc _chatBloc;
  ChannelBloc _channelBloc;

  bool isUnSubscribed = false;

  initAsync() async {
    SubscriberRepo().getByTopicAndChatId(widget.arguments.topic, NKNClientCaller.currentChatId).then((subs) {
      bool unSubs = subs == null;
      if (isUnSubscribed != unSubs) {
        if (mounted)
          setState(() {
            isUnSubscribed = unSubs;
          });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    initAsync();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _channelBloc = BlocProvider.of<ChannelBloc>(context);
    _channelBloc.add(ChannelMemberCountEvent(widget.arguments.topic));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NL10ns.of(context).channel_settings,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Container(
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor4),
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(bottom: 20),
                child: Stack(
                  children: <Widget>[
                    Container(
                      child: CommonUI.avatarWidget(
                        radiusSize: 48,
                        topic: widget.arguments,
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
                          File savedImg = await getHeaderImage(NKNClientCaller.currentChatId);
                          if (savedImg == null) return;
                          final topicRepo = TopicRepo();
                          await topicRepo.updateAvatar(widget.arguments.topic, savedImg.path);
                          setState(() {
                            widget.arguments = widget.arguments.copyWith(avatarUri: savedImg.path);
                          });
                          _chatBloc.add(RefreshMessageListEvent());
                        },
                      ),
                    )
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
                                          NL10ns.of(context).name,
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
                                          NL10ns.of(context).view_channel_members,
                                          type: LabelType.bodyRegular,
                                          color: DefaultTheme.fontColor1,
                                          height: 1,
                                        ),
                                        SizedBox(width: 20),
                                        Expanded(
                                          child: BlocBuilder<ChannelBloc, ChannelState>(builder: (context, state) {
                                            int memberCount = 0;
                                            if (state is ChannelMembersState){
                                              if (state.memberCount != null && state.topicName == widget.arguments.topic){
                                                memberCount = state.memberCount;
                                              }
                                            }
                                            return Label(
                                              '$memberCount' + NL10ns.of(context).members,
                                              type: LabelType.bodyRegular,
                                              textAlign: TextAlign.right,
                                              color: DefaultTheme.fontColor2,
                                              maxLines: 1,
                                            );
                                          })
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
                                      var address = await BottomDialog.of(context).showInputAddressDialog(
                                          title: NL10ns.of(context).invite_members, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
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
                                          NL10ns.of(context).invite_members,
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
    if (!isUnSubscribed) {
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
                  NL10ns.of(context).unsubscribe,
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
                  NL10ns.of(context).subscribe,
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

  _unSubscriberGoesSuccess(){
    showToast(NL10ns.of(context).unsubscribed);
    Timer(Duration(seconds: 1), () {
      Navigator.of(context).pop(true);
    });
  }

  unSubscriberAction() async {
    SimpleConfirm(
      context: context,
      buttonColor: Colors.red,
      content: NL10ns.of(context).leave_group_confirm_title,
      callback: (b) {
        if (b) {
          EasyLoading.show();
          GroupChatHelper.unsubscribeTopic(
              topicName: widget.arguments.topic,
              chatBloc: _chatBloc,
              callback: (success, e) {
                EasyLoading.dismiss();
                if (success) {
                  _unSubscriberGoesSuccess();
                } else {
                  if (e.toString().contains('can not append tx to txpool')){
                    _unSubscriberGoesSuccess();
                  }
                  else{
                    showToast(NL10ns.of(context).something_went_wrong);
                  }
                }
              });
        }
      },
      buttonText: NL10ns.of(context).unsubscribe,
    ).show();
  }

  subscriberAction() {
    EasyLoading.show();
    GroupChatHelper.subscribeTopic(
        topicName: widget.arguments.topic,
        chatBloc: _chatBloc,
        callback: (success, e) {
          EasyLoading.dismiss();
          if (success) {
            showToast(NL10ns().subscribed);
            Navigator.pop(context);
          } else {
            showToast(NL10ns().something_went_wrong);
          }
        });
  }

  acceptPrivateAction(address) async {
    final topic = widget.arguments;
    var sendMsg = MessageSchema.fromSendData(from: NKNClientCaller.currentChatId,
        content: topic.topic,
        to: address,
        contentType: ContentType.channelInvitation);
    _chatBloc.add(SendMessageEvent(sendMsg));
    showToast(NL10ns
        .of(context)
        .invitation_sent);

    if (topic.isPrivate && topic.isOwner(NKNClientCaller.currentChatId) &&
        address != NKNClientCaller.currentChatId) {
      await GroupChatHelper.moveSubscriberToWhiteList(
          topic: topic,
          chatId: address,
          callback: () {
            // refreshMembers();
          });
    }
  }
}
