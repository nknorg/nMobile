import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/markdown.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/router/custom_router.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/theme/popup_menu.dart';
import 'package:nmobile/utils/chat_utils.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/nkn_time_utils.dart';
import 'package:oktoast/oktoast.dart';

enum BubbleStyle { Me, Other, SendError }

class ChatBubble extends StatefulWidget {
  MessageSchema message;
  MessageSchema preMessage;
  ContactSchema contact;
  BubbleStyle style;
  ValueChanged<String> onChanged;
  bool showTime;
  bool hideHeader;

  ChatBubble({this.message, this.contact, this.onChanged, this.preMessage, this.showTime = true, this.hideHeader = false}) {
    if (message.isOutbound) {
      if (message.isSendError) {
        style = BubbleStyle.SendError;
      } else {
        style = BubbleStyle.Me;
      }
    } else {
      style = BubbleStyle.Other;
    }
  }

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with AccountDependsBloc {
  GlobalKey popupMenuKey = GlobalKey();
  ChatBloc _chatBloc;

  _textPopupMenuShow() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      maxColumn: 4,
      items: [
        MenuItem(
          userInfo: 0,
          title: NL10ns
              .of(context)
              .copy,
          textStyle: TextStyle(
              color: DefaultTheme.fontLightColor, fontSize: 12),
        ),
      ],
      onClickMenu: (MenuItemProvider item) {
        var index = (item as MenuItem).userInfo;
        switch (index) {
          case 0:
            CopyUtils.copyAction(context, widget.message.content);
            break;
        }
      },
    );
    popupMenu.show(widgetKey: popupMenuKey);
  }

  _mediaPopupMenuShow() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      maxColumn: 4,
      items: [
        MenuItem(
          userInfo: 0,
          title: NL10ns
              .of(context)
              .done,
          textStyle: TextStyle(
              color: DefaultTheme.fontLightColor, fontSize: 12),
        ),
      ],
      onClickMenu: (MenuItemProvider item) {
        var index = (item as MenuItem).userInfo;
        switch (index) {
          case 0:
            break;
        }
      },
    );
    popupMenu.show(widgetKey: popupMenuKey);
  }

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    Widget timeWidget;
    Widget burnWidget = Container();
    String timeFormat = NKNTimeUtil.formatChatTime(
        context, widget.message.timestamp);
    List<Widget> content = <Widget>[];
    timeWidget = Label(
      timeFormat,
      type: LabelType.bodySmall,
      fontSize: DefaultTheme.chatTimeSize,
    );

    bool dark = false;
    if (widget.style == BubbleStyle.Me) {
      decoration = BoxDecoration(
        color: DefaultTheme.primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(2),
        ),
      );
      dark = true;
      if (widget.message.options != null &&
          widget.message.options['deleteAfterSeconds'] != null) {
        burnWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(FontAwesomeIcons.clock, size: 12,
                color: DefaultTheme.fontLightColor.withAlpha(178)).pad(
                b: 1, r: 4),
            Label(
              Format.timeFromNowFormat(widget.message.deleteTime ??
                  DateTime.now().add(Duration(
                      seconds: widget.message.options['deleteAfterSeconds'] +
                          1))),
              type: LabelType.bodySmall,
              fontSize: DefaultTheme.iconTextFontSize,
              color: DefaultTheme.fontLightColor.withAlpha(178),
            ),
          ],
        ).pad(t: 1);
      }
    } else if (widget.style == BubbleStyle.SendError) {
      decoration = BoxDecoration(
        color: DefaultTheme.fallColor.withAlpha(178),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(2),
        ),
      );
      dark = true;
    } else {
      decoration = BoxDecoration(
        color: DefaultTheme.backgroundColor1,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
      );

      if (widget.message.options != null &&
          widget.message.options['deleteAfterSeconds'] != null) {
        burnWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(FontAwesomeIcons.clock, size: 12,
                color: DefaultTheme.fontColor2).pad(b: 1, r: 4),
            Label(
              Format.timeFromNowFormat(widget.message.deleteTime ??
                  DateTime.now().add(Duration(
                      seconds: widget.message.options['deleteAfterSeconds'] +
                          1))),
              type: LabelType.bodySmall,
              fontSize: DefaultTheme.iconTextFontSize,
              color: DefaultTheme.fontColor2,
            ),
          ],
        ).pad(t: 1);
      }
    }
    EdgeInsetsGeometry contentPadding = EdgeInsets.zero;

    if (widget.message.contentType == ContentType.ChannelInvitation) {
      return getChannelInviteView(accountChatId);
    } else if (widget.message.contentType == ContentType.eventSubscribe) {
      return Container();
    }

    var popupMenu = _textPopupMenuShow;
    switch (widget.message.contentType) {
      case ContentType.text:
        List chatContent = ChatUtil.getFormatString(widget.message.content);
        if (chatContent.length > 0) {
          List<InlineSpan> children = [];
          for (String s in chatContent) {
            if (s.contains(ChatUtil.reg)) {
              children.add(TextSpan(
                  text: s,
                  style: TextStyle(height: 1.15,
                      color: Color(DefaultTheme.headerColor2),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold)));
            } else {
              if (widget.style == BubbleStyle.Me) {
                children.add(TextSpan(text: s,
                    style: TextStyle(
                        color: DefaultTheme.fontLightColor, height: 1.25)));
              } else {
                children.add(TextSpan(text: s,
                    style: TextStyle(
                        color: DefaultTheme.fontColor1, height: 1.25)));
              }
            }
          }
          content.add(
            Padding(
              padding: contentPadding,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: DefaultTheme.bodyRegularFontSize),
                  text: '',
                  children: children,
                ),
              ),
            ),
          );
        } else {
          content.add(
            Padding(
              padding: contentPadding,
              child: Markdown(
                data: widget.message.content,
                dark: dark,
              ),
            ),
          );
        }
        break;
      case ContentType.textExtension:
        content.add(
          Padding(
            padding: contentPadding,
            child: Markdown(
              data: widget.message.content,
              dark: dark,
            ),
          ),
        );
        break;
      case ContentType.media:
        popupMenu = () {};
        String path = (widget.message.content as File).path;
        content.add(
          InkWell(
            onTap: () {
              Navigator.push(context, CustomRoute(PhotoPage(arguments: path)));
            },
            child: Padding(
              padding: contentPadding,
              child: Image.file(widget.message.content as File),
            ),
          ),
        );
        break;
    }
    if (widget.message.options != null &&
        widget.message.options['deleteAfterSeconds'] != null) {
      content.add(burnWidget);
    }
    // fix by Wei.Chou
    // Avoid error:
    // 'package:flutter/src/rendering/sliver_multi_box_adaptor.dart':
    // Failed assertion: line 549 pos 12: 'child.hasSize': is not true.
    if (content.isEmpty) {
      content.add(Space.empty);
    }
    if (widget.contact != null) {
      List<Widget> contents = <Widget>[
        GestureDetector(
          key: popupMenuKey,
          onTap: popupMenu,
//          onLongPress: popupMenu,
          child: Opacity(
            opacity: widget.message.isSuccess ? 1 : 0.4,
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Visibility(
                    visible: !widget.hideHeader,
                    child: Column(
                      children: <Widget>[
                        SizedBox(height: 8.h),
                        Label(
                          widget.contact.name,
                          height: 1,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.primaryColor,
                        ),
                        SizedBox(height: 6.h),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: decoration,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 272.w),
                      child: Stack(
                        alignment: Alignment.topLeft,
                        children: content,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
      if (widget.style == BubbleStyle.Other) {
        contents.insert(
            0,
            Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: GestureDetector(
                onTap: () {
                  if (!widget.hideHeader) {
                    Navigator.of(context).pushNamed(
                        ContactScreen.routeName, arguments: widget.contact);
                  }
                },
                onLongPress: () {
                  if (!widget.hideHeader) {
                    widget.onChanged(widget.contact.name);
                  }
                },
                child: Opacity(
                  opacity: !widget.hideHeader ? 1.0 : 0.0,
                  child: widget.contact.avatarWidget(
                    _chatBloc.db,
                    size: 20,
                    backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                  ),
                ),
              ),
            ));
      }
      return Padding(
        padding: EdgeInsets.only(top: 4.h),
        child: Align(
          alignment: widget.style == BubbleStyle.Me ||
              widget.style == BubbleStyle.SendError
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Column(
            children: <Widget>[
              widget.showTime ? timeWidget : Container(),
              widget.showTime ? SizedBox(height: 4.h) : Container(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contents,
              ),
              !widget.hideHeader ? SizedBox(height: 8.h) : Container(),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(top: 4.h),
        child: Column(
          children: <Widget>[
            widget.showTime ? timeWidget : Container(),
            widget.showTime ? SizedBox(height: 4.h) : Container(),
            Align(
              alignment: widget.style == BubbleStyle.Me ||
                  widget.style == BubbleStyle.SendError
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: GestureDetector(
                key: popupMenuKey,
                onTap: popupMenu,
                child: Opacity(
                  opacity: widget.message.isSuccess ? 1 : 0.4,
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: decoration,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 272.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      );
    }
  }

  getChannelInviteView(String myChatId) {
    Topic topicSpotName = Topic.spotName(name: widget.message.content);
    // TODO: get other name from contact.
    final inviteDesc = widget.style != BubbleStyle.Me
        ? NL10ns.of(context).invites_desc_me(widget.message.to.substring(0, 6))
        : NL10ns.of(context).invites_desc_other(
        widget.message.to.substring(0, 6));

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Column(
            children: [
              Label(inviteDesc, type: LabelType.bodyRegular,
                  color: Colours.dark_2d),
              Label(topicSpotName.shortName, type: LabelType.bodyRegular,
                  color: Colours.blue_0f)
            ],
          ),
          SizedBox(width: 5),
          widget.style == BubbleStyle.Me
              ? Space.empty
              : InkWell(
            onTap: () async {
              final topicName = widget.message.content;
              BottomDialog.of(Global.appContext).showAcceptDialog(
                  title: NL10ns
                      .of(context)
                      .accept_invitation,
                  subTitle: inviteDesc,
                  content: topicName,
                  onPressed: () => _joinChannelByName(topicSpotName)
              );
            },
            child: Label(
              NL10ns
                  .of(context)
                  .accept,
              type: LabelType.bodyRegular,
              fontWeight: FontWeight.bold,
              color: DefaultTheme.primaryColor,
            ),
          )
        ],
      ),
    );
  }

  _joinChannelByName(Topic theTopic) {
    print("Channel name is "+theTopic.name);
    GroupChatHelper.subscribeTopic(
        account: account,
        topicName: theTopic.name,
        chatBloc: _chatBloc,
        callback: (success, e) async {
          if (success) {
            if (theTopic.isPrivate) {
              // TODO: delay pull action at least 3 minutes.
              GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                  client: account.client,
                  topicName: theTopic.name,
                  accountPubkey: accountPubkey,
                  myChatId: accountChatId,
                  repoSub: SubscriberRepo(db),
                  repoBlackL: BlackListRepo(db),
                  repoTopic: TopicRepo(db),
                  membersBloc: BlocProvider.of<ChannelMembersBloc>(
                      Global.appContext),
                  needUploadMetaCallback: (topicName) {
                    // The owner will not invite himself. In other words, current `account` is not the group owner.
                  });
            } else {
              GroupChatPublicChannel.pullSubscribersPublicChannel(
                client: account.client,
                topicName: theTopic.name,
                myChatId: accountChatId,
                repoSub: SubscriberRepo(db),
                repoTopic: TopicRepo(db),
                membersBloc: BlocProvider.of<ChannelMembersBloc>(
                    Global.appContext),
              );
            }
            showToast(NL10ns
                .of(context)
                .accepted);
            Navigator.pop(context);
          } else {
            final topicExists = await TopicRepo(db).getTopicByName(
                theTopic.topic);
            if (topicExists.nonNull) {
              showToast(NL10ns
                  .of(context)
                  .accepted_already);
              Navigator.pop(context);
            }
            else{
              showToast('bubble create topic failed');
            }
          }
        });
  }
}