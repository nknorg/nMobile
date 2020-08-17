import 'dart:async';
import 'dart:ui';

import 'package:badges/badges.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/popular_channel.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/message_item.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

class MessagesTab extends StatefulWidget {
  final TimerAuth timerAuth;

  MessagesTab(this.timerAuth);

  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin, AccountDependsBloc, Tag {
  List<MessageItem> _messagesList = <MessageItem>[];
  ChatBloc _chatBloc;
  ContactBloc _contactBloc;
  StreamSubscription _chatSubscription;
  ScrollController _scrollController = ScrollController();
  int _limit = 20;
  int _skip = 20;
  bool loading = false;
  List<PopularChannel> populars;
  bool isHideTip = false;

  int timeBegin = 0;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  @override
  void initState() {
    super.initState();
    _LOG = LOG(tag);

    timeBegin = DateTime.now().millisecondsSinceEpoch;

    widget.timerAuth.addOnStateChanged(onStateChanged);
    isHideTip = SpUtil.getBool(LocalStorage.WALLET_TIP_STATUS, defValue: false);
    populars = PopularChannel.defaultData();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _contactBloc = BlocProvider.of<ContactBloc>(context);
    if (_chatSubscription == null) {
      _chatSubscription = _chatBloc.listen((state) async {
        if (state is MessagesUpdated) {
          if (state.target != null) {
            initAsync();
          } else {
            initAsync();
          }
        } else if (state is Connected) {
          initAsync();
        } else if (state is NotConnect) {
          initAsync();
        }
      });
    }
    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50 && !loading) {
        loading = true;
        _loadMore().then((v) {
          loading = false;
        });
      }
    });
  }

  void onStateChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    widget.timerAuth.removeOnStateChanged(onStateChanged);
    super.dispose();
  }

  initAsync() async {
    final duration = ((DateTime.now().millisecondsSinceEpoch - timeBegin) / 1000.0).toStringAsFixed(3);
    _LOG.w("initAsync | timeDuration: ${duration}s");
    var res = await MessageItem.getLastChat(db, limit: _limit);
    _contactBloc.add(LoadContact(address: res.map((x) => x.topic != null ? x.sender : x.targetId).toList()));
    final duration2 = ((DateTime.now().millisecondsSinceEpoch - timeBegin) / 1000.0).toStringAsFixed(3);
    _LOG.w("initAsync | timeDuration2: ${duration2}s");
    if (mounted) {
      setState(() {
        try {
          _skip = 20;
          _messagesList = (res);
        } catch (e) {
          _LOG.e('initAsync', e);
        }
      });
    }
  }

  _updateTargetChatItem(targetId) async {
    var res = await MessageItem.getTargetChat(db, targetId);
    if (res != null) {
      var index = _messagesList.indexWhere((x) => x.targetId == res.targetId);
      setState(() {
        if (index < 0) {
          _messagesList.add(res);
        } else {
          _messagesList[index] = res;
        }
      });
    }
  }

  Future _loadMore() async {
    var res = await MessageItem.getLastChat(db, limit: _limit, offset: _skip);
    if (res != null) {
      _skip += res.length;
      _contactBloc.add(LoadContact(address: res.map((x) => x.topic != null ? x.sender : x.targetId).toList()));
      setState(() {
        _messagesList.addAll(res);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.timerAuth.enabled && _messagesList != null && _messagesList.length > 0) {
      final duration = ((DateTime.now().millisecondsSinceEpoch - timeBegin) / 1000.0).toStringAsFixed(3);
      _LOG.w("timeDuration: ${duration}s");
      _messagesList.sort((a, b) => a.isTop ? (b.isTop ? -1 /*hold position original*/ : -1) : (b.isTop ? 1 : b.lastReceiveTime.compareTo(a.lastReceiveTime)));
      return Flex(
        direction: Axis.vertical,
        children: [
          getTipView(),
          Expanded(
            flex: 1,
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 72),
              controller: _scrollController,
              itemCount: _messagesList.length,
              itemBuilder: (BuildContext context, int index) {
                var item = _messagesList[index];
                return BlocBuilder<ContactBloc, ContactState>(
                  builder: (context, state) {
                    if (state is ContactLoaded) {
                      Widget widget;
                      if (item.topic != null) {
                        widget = getTopicItemView(item, state);
                      } else {
                        widget = getSingleChatItemView(item, state);
                      }
                      return InkWell(
                        onLongPress: () {
                          showMenu(item, index);
                        },
                        child: widget,
                      );
                    } else {
                      return Container();
                    }
                  },
                );
              },
            ),
          ),
        ],
      );
    } else {
      return Flex(
        direction: Axis.vertical,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(top: 0),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Container(
                      child: Flex(
                        direction: Axis.vertical,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Label(
                                NL10ns.of(context).popular_channels,
                                type: LabelType.h3,
                                textAlign: TextAlign.left,
                              ).pad(l: 20)
                            ],
                          ),
                          Container(
                            height: 180,
                            margin: 0.pad(t: 8),
                            child: ListView.builder(
                                itemCount: populars.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  return getPopularItemView(index, populars.length, populars[index]);
                                }),
                          ),
                          Expanded(
                            flex: 0,
                            child: Column(
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.only(top: 32),
                                  child: Label(
                                    NL10ns.of(context).chat_no_messages_title,
                                    type: LabelType.h2,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 8, left: 0, right: 0),
                                  child: Label(
                                    NL10ns.of(context).chat_no_messages_desc,
                                    type: LabelType.bodyRegular,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              ],
                            ),
                          ),
                          Button(
                            width: -1,
                            height: 54,
                            padding: 0.pad(l: 36, r: 36),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                loadAssetIconsImage('pencil', width: 24, color: DefaultTheme.backgroundLightColor).pad(r: 12),
                                Label(NL10ns.of(context).new_message, type: LabelType.h3)
                              ],
                            ),
                            onPressed: () async {
                              if (widget.timerAuth.enabled) {
                                var address = await BottomDialog.of(context)
                                    .showInputAddressDialog(title: NL10ns.of(context).new_whisper, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
                                if (address != null) {
                                  ContactSchema contact = ContactSchema(type: ContactType.stranger, clientAddress: address);
                                  await contact.createContact(db);
                                  Navigator.of(context)
                                      .pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
                                }
                              } else {
                                widget.timerAuth.ensureVerifyPassword(context);
                              }
                            },
                          ).pad(t: 54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  showMenu(MessageItem item, int index) {
    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
          children: [
            SimpleDialogOption(
              child: Row(
                children: [
                  Icon(item.isTop ? Icons.vertical_align_bottom : Icons.vertical_align_top).pad(r: 12),
                  Text(item.isTop ? NL10ns.of(context).top_cancel : NL10ns.of(context).top),
                ],
              ).pad(t: 8, b: 4),
              onPressed: () async {
                Navigator.of(context).pop();
                final top = !item.isTop;
                final numChanges = await (item.topic == null ? ContactSchema.setTop(db, item.targetId, top) : TopicSchema.setTop(db, item.topic.topic, top));
                if (numChanges > 0) {
                  setState(() {
                    item.isTop = top;
                    _messagesList.remove(item);
                    _messagesList.insert(0, item);
                  });
                }
              },
            ),
            SimpleDialogOption(
              child: Row(
                children: [
                  Icon(Icons.delete_outline).pad(r: 12),
                  Text(NL10ns.of(context).delete),
                ],
              ).pad(t: 4, b: 8),
              onPressed: () {
                Navigator.of(context).pop();
                MessageItem.deleteTargetChat(db, item.targetId).then((numChanges) {
                  if (numChanges > 0) {
                    setState(() {
                      _messagesList.remove(item);
                    });
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget getPopularItemView(int index, int length, PopularChannel model) {
    return Container(
      child: Container(
        width: 136,
        height: 172,
        margin: 8.pad(l: 20, r: index == length - 1 ? 20 : 12),
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              margin: 0.pad(t: 20),
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: model.titleBgColor, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Label(
                  model.title,
                  type: LabelType.h3,
                  color: model.titleColor,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Label(
              model.subTitle,
              type: LabelType.h4,
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 90.w,
                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
                  decoration: BoxDecoration(color: Color(0xFF5458F7), borderRadius: BorderRadius.circular(100)),
                  child: InkWell(
                    onTap: () {
                      if (widget.timerAuth.enabled) {
                        _subscription(model);
                      } else {
                        widget.timerAuth.ensureVerifyPassword(context);
                      }
                    },
                    child: Center(
                      child: Text(
                        NL10ns.of(context).subscribe,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  _subscription(PopularChannel popular) async {
    var duration = 400000;
    try {
      TopicSchema.subscribe(account, topic: popular.topic, duration: duration);
//      if (hash != null) {
      var sendMsg = MessageSchema.fromSendData(
        from: accountChatId,
        topic: popular.topic,
        contentType: ContentType.dchatSubscribe,
      );
      sendMsg.isOutbound = true;
      sendMsg.content = sendMsg.toDchatSubscribeData();
      _chatBloc.add(SendMessage(sendMsg));
      DateTime now = DateTime.now();
      var topicSchema = TopicSchema(topic: popular.topic, expiresAt: now.add(blockToExpiresTime(duration)));
      await topicSchema.insertOrUpdate(db, accountPubkey);
      topicSchema = await TopicSchema.getTopic(db, popular.topic);
      Navigator.of(context).pushNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.Channel, topic: topicSchema));
//      }
    } catch (e) {
      showToast(NL10ns.of(context).failure);
    }
  }

  getTipView() {
    if (isHideTip) {
      return Container();
    } else {
      return Container(
        margin: 20.pad(t: 25, b: 0),
        padding: 0.pad(b: 16),
        width: double.infinity,
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor2, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colours.blue_0f_a1p, borderRadius: BorderRadius.circular(8)),
              child: Center(child: loadAssetIconsImage('lock', width: 24, color: DefaultTheme.primaryColor)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Label(
                    NL10ns.of(context).private_messages,
                    type: LabelType.h3,
                  ).pad(t: 16),
                  Label(
                    NL10ns.of(context).private_messages_desc,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ).pad(t: 4),
                  Label(
                    NL10ns.of(context).learn_more,
                    type: LabelType.bodySmall,
                    color: DefaultTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ).pad(t: 6),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                SpUtil.putBool(LocalStorage.WALLET_TIP_STATUS, true);
                setState(() {
                  isHideTip = true;
                });
              },
              child: loadAssetIconsImage('close', width: 16, color: Colours.gray_81).center.sized(w: 48, h: 48),
            )
          ],
        ),
      );
    }
  }

  Widget getTopicItemView(MessageItem item, ContactLoaded state) {
    var contact = state.getContactByAddress(item.sender);
    if (contact == null) {
      return Container();
    }
    Widget contentWidget;
    String draft = LocalStorage.getChatUnSendContentFromId(_chatBloc.accountPubkey, item.targetId);
    if (draft != null && draft.length > 0) {
      contentWidget = Row(
        children: <Widget>[
          Label(
            NL10ns.of(context).placeholder_draft,
            type: LabelType.bodySmall,
            color: Colors.red,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 5),
          Label(
            draft,
            type: LabelType.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (item.contentType == ContentType.media) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(
              contact.name + ': ',
              maxLines: 1,
              type: LabelType.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            loadAssetIconsImage('image', width: 14, color: DefaultTheme.fontColor2),
          ],
        ),
      );
    } else if (item.contentType == ContentType.ChannelInvitation) {
      contentWidget = Label(
        contact.name + ': ' + NL10ns.of(context).channel_invitation,
        type: LabelType.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (item.contentType == ContentType.eventSubscribe) {
      return Container();
//      contentWidget = Label(
//        item.content,
//        type: LabelType.bodySmall,
//        maxLines: 1,
//        overflow: TextOverflow.ellipsis,
//      );
    } else if (item.contentType == ContentType.dchatSubscribe) {
      contentWidget = Label(
        NL10ns.of(context).joined_channel,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      contentWidget = Label(
        contact.name + ': ' + item.content,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    }
    List<Widget> topicWidget = [
      Label(item.topic.shortName, type: LabelType.h4),
    ];
    if (item.topic.type == TopicType.private) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 18, color: DefaultTheme.primaryColor));
    }
    return InkWell(
      onTap: () async {
        TopicSchema topic = await TopicSchema.getTopic(db, item.topic.topic);
        Navigator.of(context).pushNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.Channel, topic: topic));
      },
      child: Container(
        color: item.isTop ? Colours.light_fb : Colours.transparent,
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            item.topic
                .avatarWidget(
                  db,
                  size: 48,
                  backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                  fontColor: DefaultTheme.primaryColor,
                )
                .pad(l: 20, r: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: item.isTop ? Colours.light_e5 : Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: topicWidget),
                          contentWidget.pad(t: 6),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Label(
                          Format.timeFormat(item.lastReceiveTime),
                          type: LabelType.bodySmall,
                          fontSize: DefaultTheme.chatTimeSize,
                        ).pad(r: 20, b: 6),
                        item.notReadCount > 0
                            ? Badge(
                                padding: EdgeInsets.only(left: 6, right: 6, top: 3, bottom: 3),
                                badgeColor: Colours.purple_57,
                                shape: BadgeShape.square,
                                borderRadius: 24,
                                toAnimate: true,
                                elevation: 0,
                                badgeContent: Text(item.notReadCount.toString(), style: TextStyle(fontSize: 10, color: Colours.white)),
                              ).pad(r: 20)
                            : SizedBox(height: 16),
                      ],
                    ).pad(l: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getSingleChatItemView(MessageItem item, ContactLoaded state) {
    var contact = state.getContactByAddress(item.targetId);
    if (contact == null) return Container();

    Widget contentWidget;
    String draft = LocalStorage.getChatUnSendContentFromId(_chatBloc.accountPubkey, item.targetId);
    if (draft != null && draft.length > 0) {
      contentWidget = Row(
        children: <Widget>[
          Label(
            NL10ns.of(context).placeholder_draft,
            type: LabelType.bodySmall,
            color: Colors.red,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 5.w),
          Label(
            draft,
            type: LabelType.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (item.contentType == ContentType.media) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            loadAssetIconsImage('image', width: 16.w, color: DefaultTheme.fontColor2),
          ],
        ),
      );
    } else if (item.contentType == ContentType.ChannelInvitation) {
      contentWidget = Label(
        NL10ns.of(context).channel_invitation,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    } else if (item.contentType == ContentType.dchatSubscribe) {
      contentWidget = Label(
        NL10ns.of(context).joined_channel,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      contentWidget = Label(
        item.content,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    }
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
      },
      child: Container(
        color: item.isTop ? Colours.light_fb : Colours.transparent,
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            contact
                .avatarWidget(
                  db,
                  size: 24,
                  backgroundColor: DefaultTheme.primaryColor.withAlpha(25),
                )
                .pad(l: 20, r: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: item.isTop ? Colours.light_e5 : Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Label(contact.name, type: LabelType.h4),
                          contentWidget.pad(t: 6),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Label(
                          Format.timeFormat(item.lastReceiveTime),
                          type: LabelType.bodySmall,
                          fontSize: DefaultTheme.chatTimeSize,
                        ).pad(r: 20, b: 6),
                        item.notReadCount > 0
                            ? Badge(
                                padding: EdgeInsets.only(left: 6, right: 6, top: 3, bottom: 3),
                                badgeColor: Colours.purple_57,
                                shape: BadgeShape.square,
                                borderRadius: 24,
                                toAnimate: true,
                                elevation: 0,
                                badgeContent: Text(item.notReadCount.toString(), style: TextStyle(fontSize: 10, color: Colours.white)),
                              ).pad(r: 20)
                            : SizedBox(height: 16),
                      ],
                    ).pad(l: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
