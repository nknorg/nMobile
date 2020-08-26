import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
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

class _ChannelMembersScreenState extends State<ChannelMembersScreen> with AccountDependsBloc {
  ScrollController _scrollController = ScrollController();
  List<MemberVo> _members = [];
  ChatBloc _chatBloc;
  int _topicCount;
  SubscriberRepo repoSub;
  BlackListRepo repoBla;

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    repoSub = SubscriberRepo(db);
    repoBla = BlackListRepo(db);
    _topicCount = widget.topic.numSubscribers;
    refreshMembers();
    uploadPermissionMeta();
  }

  uploadPermissionMeta() {
    if (widget.topic.isPrivate && widget.topic.isOwner(accountPubkey)) {
      GroupChatPrivateChannel.uploadPermissionMeta(
        client: account.client,
        topicName: widget.topic.topic,
        accountPubkey: account.client.pubkey,
        repoSub: repoSub,
        repoBlackL: repoBla,
      );
    }
  }

  refreshMembers() async {
    List<MemberVo> list = [];
    final subscribers = await repoSub.getByTopicExceptNone(widget.topic.topic);
    for (final sub in subscribers) {
//      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(sub.chatId));
      final contactType = sub.chatId == accountChatId ? ContactType.me : ContactType.stranger;
      final cta = await ContactSchema.getContactByAddress(db, sub.chatId) ?? ContactSchema(clientAddress: sub.chatId, type: contactType);
      list.add(MemberVo(
        name: cta.name,
        chatId: sub.chatId,
        indexPermiPage: sub.indexPermiPage,
        uploaded: sub.uploaded,
        subscribed: sub.subscribed,
        isBlack: false,
        contact: cta,
      ));
    }
    final blackList = await repoBla.getByTopic(widget.topic.topic);
    for (final sub in blackList) {
      final contactType = (sub.chatIdOrPubkey == accountChatId || sub.chatIdOrPubkey == accountPubkey) ? ContactType.me : ContactType.stranger;
      final cta = await ContactSchema.getContactByAddress(db, sub.chatIdOrPubkey) ?? ContactSchema(clientAddress: sub.chatIdOrPubkey, type: contactType);
      list.add(MemberVo(
        name: cta.name,
        chatId: sub.chatIdOrPubkey,
        indexPermiPage: sub.indexPermiPage,
        uploaded: sub.uploaded,
        subscribed: sub.subscribed,
        isBlack: true,
        contact: cta,
      ));
    }
    _members = list;
    _topicCount = _members.length;
    if (mounted) {
      setState(() {});
    }
    // TODO: ???
    Global.removeTopicCache(widget.topic.topic);
  }

  @override
  Widget build(BuildContext context) {
    if (_members.length > 0) {
      MemberVo owner = !widget.topic.isPrivate ? null : _members.firstWhere((c) => widget.topic.isOwner(c.chatId), orElse: () => null);
      if (owner != null) _members.remove(owner);
      MemberVo me = _members.firstWhere((c) => c.chatId == accountChatId, orElse: () => null);
      if (me != null) _members.remove(me);
      _members.sort((a, b) => (a.isBlack && b.isBlack || !a.isBlack && !b.isBlack) ? a.name.compareTo(b.name) : (!a.isBlack ? -1 : 1));
      if (me != null) _members.insert(0, me);
      if (owner != null && owner != me) _members.insert(0, owner);
    }
    List<Widget> topicWidget = [Label(widget.topic.shortName, type: LabelType.h3, dark: true)];
    if (widget.topic.type == TopicType.private) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 18, color: DefaultTheme.fontLightColor).pad(r: 2));
    }
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
                  .showInputAddressDialog(title: NL10ns.of(context).invite_members, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
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
                TopicSchema.avatarWidget(
                  topicName: widget.topic.topic,
//                      backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
                  size: 48,
//                      fontColor: DefaultTheme.fontLightColor,
                  avatar: widget.topic.avatarUri == null ? null : File(widget.topic.avatarUri),
                  options: widget.topic.options ?? OptionsSchema.random(themeId: widget.topic.themeId),
                ).pad(r: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: topicWidget),
                    BlocBuilder<ChannelMembersBloc, ChannelMembersState>(builder: (context, state) {
                      if (state.membersCount != null && state.membersCount.topicName == widget.topic.topic) {
                        final count = state.membersCount.subscriberCount;
                        if (_topicCount == null || count > _topicCount
                            // only count of white list(subscribers), but here contains black list.
                            /* || state.membersCount.isFinal*/) {
                          _topicCount = count;
                        }
                        if (state.membersCount.isFinal) {
                          // refreshMembers();
                        }
                      }
                      return Label(
                        '${(_topicCount == null || _topicCount < 0) ? '--' : _topicCount} ' + NL10ns.of(context).members,
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
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 4, bottom: 32),
                        controller: _scrollController,
                        itemCount: _members.length,
                        itemExtent: 72,
                        itemBuilder: (BuildContext context, int index) {
                          return getItemView(_members[index]);
                        },
                      ),
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

  getItemView(MemberVo member) {
    List<Widget> nameLabel = getNameLabels(member);
    List<Widget> toolBtns = getToolBtns(member);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: member.contact);
      },
      child: Container(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            member.contact
                .avatarWidget(
                  db,
                  size: 24,
                  backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                )
                .pad(l: 16, r: 16)
                .center,
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: Colours.light_e9))),
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
        if (member.chatId == accountChatId) {
          option = '(${NL10ns.of(context).you}, ${NL10ns.of(context).owner})';
        } else {
          option = '(${NL10ns.of(context).owner})';
        }
      } else if (member.chatId == accountChatId) {
        option = '(${NL10ns.of(context).you})';
      } else if (widget.topic.isOwner(accountPubkey)) {
        // Me is owner, but current user is not me.
        option = member.isBlack
            ? '(${NL10ns.of(context).rejected})'
            : (member.subscribed ? null /*'(${NL10ns.of(context).accepted})'*/ : '(${NL10ns.of(context).invitation_sent})');
      }
    } else if (member.chatId == accountChatId) {
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
                  : Label(option, type: LabelType.bodySmall, color: Colours.gray_81, fontWeight: FontWeight.w600).pad(l: 4)),
    ];
  }

  List<Widget> getToolBtns(MemberVo member) {
    List<Widget> toolBtns = <Widget>[];
    if (widget.topic.isPrivate && widget.topic.isOwner(accountPubkey) && member.chatId != accountChatId) {
      acceptAction() async {
        if (member.isBlack) {
          await GroupChatHelper.moveSubscriberToWhiteList(
              account: account,
              topic: widget.topic,
              chatId: member.chatId,
              callback: () {
                refreshMembers();
              });
        }
        showToast(NL10ns.of(context).accepted);
      }

      rejectAction() async {
        if (!member.isBlack) {
          await GroupChatHelper.moveSubscriberToBlackList(
              account: account,
              topic: widget.topic,
              chatId: member.chatId,
              callback: () {
                refreshMembers();
              });
        }
        showToast(NL10ns.of(context).rejected);
      }

      Widget acceptIcon = loadAssetIconsImage('check', width: 20, color: DefaultTheme.successColor);
      Widget rejectIcon = Icon(Icons.block, size: 20, color: Colours.red);

      if (member.isBlack) {
        toolBtns.add(InkWell(child: acceptIcon.pad(l: 6, r: 16).center.sized(h: double.infinity), onTap: acceptAction));
      } else if (!member.subscribed) {
        // pending...
        toolBtns.add(InkWell(child: rejectIcon.pad(l: 6, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
//        toolBtns.add(InkWell(child: acceptIcon.pad(l: 6, r: 8).center.sized(h: double.infinity), onTap: acceptAction));
//        toolBtns.add(InkWell(child: rejectIcon.pad(l: 8, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
      } else if (!member.isBlack) {
        toolBtns.add(InkWell(child: rejectIcon.pad(l: 6, r: 16).center.sized(h: double.infinity), onTap: rejectAction));
      }
    }
    return toolBtns;
  }

  inviteAndAcceptAction(address) async {
    // TODO: check address is a valid chatId.
    //if (!isValidChatId(address)) return;

    final topic = widget.topic;
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
            refreshMembers();
          });
    }

    // This message will only be sent when yourself subscribe.
//    var sendMsg1 = MessageSchema.fromSendData(
//        from: accountChatId, topic: widget.arguments.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
//    sendMsg1.isOutbound = true;

//      _chatBloc.add(SendMessage(sendMsg1));
  }
}
