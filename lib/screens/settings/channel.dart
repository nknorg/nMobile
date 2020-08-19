import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
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
import 'package:nmobile/schemas/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/schemas/topic.dart';
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

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> with AccountDependsBloc {
  ChatBloc _chatBloc;
  bool isUnSubscribed = false;

  initAsync() async {
    SubscriberRepo(db).getByTopicAndChatId(widget.arguments.topic, accountChatId).then((subs) {
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
//    isUnSubscribe = LocalStorage.getUnsubscribeTopicList(accountPubkey).contains(widget.arguments.topic);
    Global.removeTopicCache(widget.arguments.topic);
    initAsync();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
//    List<Widget> topicWidget = [
//      Label(widget.arguments.shortName, type: LabelType.h3, dark: true).pad(l: 6),
//    ];
//    if (widget.arguments.type == TopicType.private) {
//      topicWidget.insert(0, SvgPicture.asset('assets/icons/lock.svg', width: 18, color: DefaultTheme.fontLightColor));
//    }
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
                          child: TopicSchema.avatarWidget(
                            topicName: widget.arguments.topic,
                            size: 64,
                            avatar: widget.arguments.avatarUri == null ? null : File(widget.arguments.avatarUri),
                            options: widget.arguments.options ?? OptionsSchema.random(themeId: widget.arguments.themeId),
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
                              final topicRepo = TopicRepo(db);
                              await topicRepo.updateAvatar(widget.arguments.topic, savedImg.path);
//                              final topicSaved = topicRepo.getTopicByName(widget.arguments.topic);
                              setState(() {
                                widget.arguments = widget.arguments.copyWith(avatarUri: savedImg.path);
                              });
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
                                          child: Label(
                                            '${widget.arguments.numSubscribers} ' + NL10ns.of(context).members,
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

  unSubscriberAction() async {
    SimpleConfirm(
      context: context,
      buttonColor: Colors.red,
      content: NL10ns.of(context).leave_group_confirm_title,
      callback: (b) {
        if (b) {
          GroupChatHelper.unsubscribeTopic(
              account: account,
              topicName: widget.arguments.topic,
              chatBloc: _chatBloc,
              callback: (success, e) {
                if (success) {
                  showToast(NL10ns.of(context).unsubscribed);
                  Navigator.of(context).pop(true);
                } else {
                  showToast(NL10ns.of(context).something_went_wrong);
                }
              });
        }
      },
      buttonText: NL10ns.of(context).unsubscribe,
    ).show();
  }

  subscriberAction() {
    GroupChatHelper.subscribeTopic(
        account: account,
        topicName: widget.arguments.topic,
        chatBloc: _chatBloc,
        callback: (success, e) {
          if (success) {
            showToast(NL10ns.of(context).subscribed);
            Navigator.pop(context);
          } else {
            showToast(NL10ns.of(context).something_went_wrong);
          }
        });
  }

  acceptPrivateAction(address) async {
    // TODO: check address is a valid chatId.
    //if (!isValidChatId(address)) return;

    final topic = widget.arguments;
    // Anyone can invite anyone.
    var sendMsg = MessageSchema.fromSendData(from: accountChatId, content: topic.topic, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;
    _chatBloc.add(SendMessage(sendMsg));
    showToast(NL10ns.of(context).invitation_sent);

    if (topic.isPrivate && topic.isOwner(accountPubkey) && address != accountChatId) {
      await GroupChatHelper.moveSubscriberToWhiteList(
          account: account,
          topic: topic,
          chatId: address,
          callback: () {
            // refreshMembers();
          });
    }

    // This message will only be sent when yourself subscribe.
//    var sendMsg1 = MessageSchema.fromSendData(
//        from: accountChatId, topic: widget.arguments.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
//    sendMsg1.isOutbound = true;

//      _chatBloc.add(SendMessage(sendMsg1));
  }
}
