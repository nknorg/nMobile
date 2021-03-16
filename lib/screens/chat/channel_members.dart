import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/chat/channel_bloc.dart';
import 'package:nmobile/blocs/chat/channel_event.dart';
import 'package:nmobile/blocs/chat/channel_state.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class ChannelMembersScreen extends StatefulWidget {
  static const String routeName = '/channel/members';

  final Topic topic;

  ChannelMembersScreen({this.topic});

  @override
  _ChannelMembersScreenState createState() => _ChannelMembersScreenState();
}

class MemberVo {
  final String name;
  final String chatId;
  final int indexPermiPage;
  final bool uploaded;
  final bool subscribed;
  final bool isBlack;
  final ContactSchema contact;

  const MemberVo({
    this.name,
    this.chatId,
    this.indexPermiPage,
    this.uploaded,
    this.subscribed,
    this.isBlack,
    this.contact,
  });
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> {
  ScrollController _scrollController = ScrollController();
  List<MemberVo> _members = [];

  int _topicCount;
  SubscriberRepo repoSub;
  BlackListRepo repoBla;

  ChatBloc _chatBloc;
  ChannelBloc _channelBloc;

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _channelBloc = BlocProvider.of<ChannelBloc>(context);

    repoSub = SubscriberRepo();
    repoBla = BlackListRepo();
    // _topicCount = widget.topic.numSubscribers;

    _refreshMemberList();
    NLog.w('MemberList called!!!!!');

    uploadPermissionMeta();
  }

  uploadPermissionMeta() {
    if (widget.topic.isPrivate &&
        widget.topic.isOwner(NKNClientCaller.currentChatId)) {
      GroupChatPrivateChannel.uploadPermissionMeta(
        topicName: widget.topic.topic,
        accountPubkey: NKNClientCaller.currentChatId,
        repoSub: repoSub,
        repoBlackL: repoBla,
      );
    }
  }

  _refreshMemberList() {
    // _channelBloc.add(ChannelMemberCountEvent(widget.topic.topic));
    _channelBloc.add(FetchChannelMembersEvent(widget.topic.topic));
  }

  // refreshMembers() async {
  //
  //   // _cha
  //   //
  //   // NLog.w('Got _members is____'+_members.length.toString());
  //   //
  //   // if (mounted) {
  //   //   setState(() {
  //   //     _members = list;
  //   //     NLog.w('Got _members is____'+_members.length.toString());
  //   //   });
  //   // }
  // }

  @override
  Widget build(BuildContext context) {
    List<Widget> topicWidget = [
      Label(widget.topic.shortName, type: LabelType.h3, dark: true)
    ];

    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
          title: NL10ns.of(context).channel_members,
          leading: BackButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          backgroundColor: DefaultTheme.backgroundColor4,
          action: FlatButton(
            child: loadAssetChatPng('group_add', width: 20),
            onPressed: () async {
              var address = await BottomDialog.of(context)
                  .showInputAddressDialog(
                      title: NL10ns.of(context).invite_members,
                      hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
              if (address != null) {
                inviteAndAcceptAction(address);
              }
            },
          ).sized(w: 72)),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 20.h, left: 16.w, right: 16.w),
            child: Row(
              children: [
                Container(
                  margin: EdgeInsets.only(right: 12),
                  child: CommonUI.avatarWidget(
                    radiusSize: 48,
                    topic: widget.topic,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: topicWidget),
                    BlocBuilder<ChannelBloc, ChannelState>(
                        builder: (context, state) {
                      if (state is ChannelMembersState) {
                        if (state.memberCount != null &&
                            state.topicName == widget.topic.topic) {
                          _topicCount = state.memberCount;
                        }
                      }
                      return Label(
                        '${(_topicCount == null || _topicCount < 0) ? '--' : _topicCount} ' +
                            NL10ns.of(context).members,
                        type: LabelType.bodyRegular,
                        color: DefaultTheme.successColor,
                      ).pad(l: widget.topic.isPrivate ? 20 : 0);
                    })
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              child: BodyBox(
                padding: 0.pad(),
                color: DefaultTheme.backgroundLightColor,
                child: Flex(
                  direction: Axis.vertical,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: _memberListWidget(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberListWidget() {
    List<Widget> topicWidget = [
      Label(widget.topic.shortName, type: LabelType.h3, dark: true)
    ];

    return BlocBuilder<ChannelBloc, ChannelState>(
        builder: (context, channelState) {
      NLog.w('channel state is___' + channelState.toString());
      if (channelState is FetchChannelMembersState) {
        _members = channelState.memberList;
        _topicCount = _members.length;

        if (_members.length > 0) {
          MemberVo owner = !widget.topic.isPrivate
              ? null
              : _members.firstWhere((c) => widget.topic.isOwner(c.chatId),
                  orElse: () => null);
          if (owner != null) _members.remove(owner);
          MemberVo me = _members.firstWhere(
              (c) => c.chatId == NKNClientCaller.currentChatId,
              orElse: () => null);
          if (me != null) _members.remove(me);
          _members.sort((a, b) =>
              (a.isBlack && b.isBlack || !a.isBlack && !b.isBlack)
                  ? a.name.compareTo(b.name)
                  : (!a.isBlack ? -1 : 1));
          if (me != null) _members.insert(0, me);
          if (owner != null && owner != me) _members.insert(0, owner);
        }
        if (widget.topic.type == TopicType.private) {
          topicWidget.insert(
              0,
              loadAssetIconsImage('lock',
                      width: 18, color: DefaultTheme.fontLightColor)
                  .pad(r: 2));
        }
      }
      return ListView.builder(
        padding: EdgeInsets.only(top: 4, bottom: 32),
        controller: _scrollController,
        itemCount: _members.length,
        itemExtent: 72,
        itemBuilder: (BuildContext context, int index) {
          return getItemView(_members[index]);
        },
      );
    });
  }

  getItemView(MemberVo member) {
    List<Widget> nameLabel = getNameLabels(member);
    List<Widget> toolBtns = getToolBtns(member);

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .pushNamed(ContactScreen.routeName, arguments: member.contact);
      },
      child: Container(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(left: 16, right: 16),
              child: CommonUI.avatarWidget(
                radiusSize: 24,
                contact: member.contact,
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(width: 0.6, color: Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: nameLabel).pad(b: 6),
                          Label(
                            member.chatId,
                            type: LabelType.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ).pad(r: toolBtns.isEmpty ? 16 : 0),
                    ),
                    Row(children: toolBtns),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> getNameLabels(MemberVo member) {
    String name = member.name;
    String option;
    if (widget.topic.type == TopicType.private) {
      if (widget.topic.isOwner(member.chatId /*.toPubkey*/)) {
        if (member.chatId == NKNClientCaller.currentChatId) {
          option = '(${NL10ns.of(context).you}, ${NL10ns.of(context).owner})';
        } else {
          option = '(${NL10ns.of(context).owner})';
        }
      } else if (member.chatId == NKNClientCaller.currentChatId) {
        option = '(${NL10ns.of(context).you})';
      } else if (widget.topic.isOwner(NKNClientCaller.currentChatId)) {
        // Me is owner, but current user is not me.
        option = member.isBlack
            ? '(${NL10ns.of(context).rejected})'
            : (member.subscribed
                ? null /*'(${NL10ns.of(context).accepted})'*/ : '(${NL10ns.of(context).invitation_sent})');
      }
    } else if (member.chatId == NKNClientCaller.currentChatId) {
      option = '(${NL10ns.of(context).you})';
    }
    return [
      Label(name, type: LabelType.h4, overflow: TextOverflow.ellipsis),
      option == null
          ? Space.empty
          : member.isBlack
              ? Text(option,
                  style: TextStyle(
                    fontSize: DefaultTheme.bodySmallFontSize,
                    color: Colours.pink_f8,
                    fontWeight: FontWeight.w600,
//                    decoration: TextDecoration.lineThrough,
//                    decorationStyle: TextDecorationStyle.solid,
//                    decorationThickness: 1.5,
                  )).pad(l: 4)
              : (option.contains(NL10ns.of(context).invitation_sent)
                  ? Text(option,
                      style: TextStyle(
                        fontSize: DefaultTheme.bodySmallFontSize,
                        color: Colours.green_06,
                        fontWeight: FontWeight.w600,
                      )).pad(l: 4)
                  : Label(option,
                          type: LabelType.bodySmall,
                          color: Colours.gray_81,
                          fontWeight: FontWeight.w600)
                      .pad(l: 4)),
    ];
  }

  List<Widget> getToolBtns(MemberVo member) {
    List<Widget> toolBtns = <Widget>[];
    if (widget.topic.isPrivate &&
        widget.topic.isOwner(NKNClientCaller.currentChatId) &&
        member.chatId != NKNClientCaller.currentChatId) {
      acceptAction() async {
        if (member.isBlack) {
          await GroupChatHelper.moveSubscriberToWhiteList(
              topic: widget.topic,
              chatId: member.chatId,
              callback: () {
                _refreshMemberList();
              });
        }
        showToast(NL10ns.of(context).accepted);
      }

      rejectAction() async {
        if (!member.isBlack) {
          await GroupChatHelper.moveSubscriberToBlackList(
              topic: widget.topic,
              chatId: member.chatId,
              callback: () {
                _refreshMemberList();
              });
        }
        showToast(NL10ns.of(context).rejected);
      }

      Widget acceptIcon = loadAssetIconsImage('check',
          width: 20, color: DefaultTheme.successColor);
      Widget rejectIcon = Icon(Icons.block, size: 20, color: Colours.red);

      if (member.isBlack) {
        toolBtns.add(InkWell(
            child: acceptIcon.pad(l: 6, r: 16).center.sized(h: double.infinity),
            onTap: acceptAction));
      } else if (!member.subscribed) {
        // pending...
        toolBtns.add(InkWell(
            child: rejectIcon.pad(l: 6, r: 16).center.sized(h: double.infinity),
            onTap: rejectAction));
//        toolBtns.add(InkWell(child: acceptIcon.pad(l: 6, r: 8).center.sized(h: double.infinity), onTap: acceptAction));
//        toolBtns.add(InkWell(child: rejectIcon.pad(l: 8, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
      } else if (!member.isBlack) {
        toolBtns.add(InkWell(
            child: rejectIcon.pad(l: 6, r: 16).center.sized(h: double.infinity),
            onTap: rejectAction));
      }
    }
    return toolBtns;
  }

  inviteAndAcceptAction(address) async {
    // TODO: check address is a valid chatId.
    //if (!isValidChatId(address)) return;

    final topic = widget.topic;
    // Anyone can invite anyone.
    var sendMsg = MessageSchema.fromSendData(
        from: NKNClientCaller.currentChatId,
        content: topic.topic,
        to: address,
        contentType: ContentType.channelInvitation);
    _chatBloc.add(SendMessageEvent(sendMsg));
    showToast(NL10ns.of(context).invitation_sent);

    if (topic.isPrivate &&
        topic.isOwner(NKNClientCaller.currentChatId) &&
        address != NKNClientCaller.currentChatId) {
      await GroupChatHelper.moveSubscriberToWhiteList(
          topic: topic,
          chatId: address,
          callback: () {
            _refreshMemberList();
          });
    }
  }
}
