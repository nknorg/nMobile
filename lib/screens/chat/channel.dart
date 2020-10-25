import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/button_icon.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/chat/system.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/settings/channel.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class ChatGroupPage extends StatefulWidget {
  static const String routeName = '/chat/channel';

  final ChatSchema arguments;

  ChatGroupPage({this.arguments});

  @override
  _ChatGroupPageState createState() => _ChatGroupPageState();
}

class _ChatGroupPageState extends State<ChatGroupPage> with AccountDependsBloc {
  ChatBloc _chatBloc;
  ContactBloc _contactBloc;
  String targetId;
  StreamSubscription _chatSubscription;
  ScrollController _scrollController = ScrollController();
  FocusNode _sendFocusNode = FocusNode();
  TextEditingController _sendController = TextEditingController();
  List<MessageSchema> _messages = <MessageSchema>[];
  bool _canSend = false;
  int _limit = 20;
  int _skip = 20;
  bool loading = false;
  bool _showBottomMenu = false;
  Timer _deleteTick;
  Timer refreshSubscribersTimer;
  int _topicCount;
  bool isUnSubscribed = false;
  bool isInBlackList = false;

  initAsync() async {
    var res = await MessageSchema.getAndReadTargetMessages(db, targetId, limit: _limit);
    _contactBloc.add(LoadContact(address: res.where((x) => !x.isOutbound).map((x) => x.from).toList()));
    _chatBloc.add(RefreshMessages(target: targetId));
    if (res != null) {
      if (mounted)
        setState(() {
          _messages = res;
        });
    }
//    isUnSubscribe = LocalStorage.getUnsubscribeTopicList(accountPubkey).contains(targetId);
//    final topic = await TopicRepo(db).getTopicByName(widget.arguments.topic.topic);
    final topic = widget.arguments.topic;
    _refreshUnSubscribed(topic.topic);
    _refreshSubscribers(topic);
    refreshSubscribersTimer = Timer.periodic(Duration(minutes: 3), (timer) {
      _refreshSubscribers(topic);
    });
  }

  _refreshSubscribers(Topic topic) async {
    if (topic.isPrivate) {
      await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
          client: account.client,
          topicName: topic.topic,
          accountPubkey: accountPubkey,
          myChatId: accountChatId,
          repoSub: SubscriberRepo(db),
          repoBlackL: BlackListRepo(db),
          repoTopic: TopicRepo(db),
          membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
          needUploadMetaCallback: (topicName) {
            GroupChatPrivateChannel.uploadPermissionMeta(
              client: account.client,
              topicName: topicName,
              accountPubkey: accountPubkey,
              repoSub: SubscriberRepo(db),
              repoBlackL: BlackListRepo(db),
            );
          });
      _refreshUnSubscribed(topic.topic);
    } else {
      await GroupChatPublicChannel.pullSubscribersPublicChannel(
        client: account.client,
        topicName: topic.topic,
        myChatId: accountChatId,
        repoSub: SubscriberRepo(db),
        repoTopic: TopicRepo(db),
        membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
      );
      _refreshUnSubscribed(topic.topic);
    }
  }

  _refreshUnSubscribed(String topicName) {
    if (!ownerIsMeFunc(topicName, accountPubkey)) {
      SubscriberRepo(db).getByTopicAndChatId(topicName, accountChatId).then((subs) {
        bool unSubs = subs == null;
        if (isUnSubscribed != unSubs) {
          if (mounted)
            setState(() {
              isUnSubscribed = unSubs;
            });
        }
        if (unSubs) {
          BlackListRepo(db).getByTopicAndChatId(topicName, accountChatId).then((bl) {
            bool blackL = bl != null;
            if (isInBlackList != blackL) {
              if (mounted)
                setState(() {
                  isInBlackList = blackL;
                });
            }
          });
          if (accountPubkey != accountChatId) {
            BlackListRepo(db).getByTopicAndChatId(topicName, accountPubkey).then((bl) {
              bool blackL = bl != null;
              if (isInBlackList != blackL) {
                if (mounted)
                  setState(() {
                    isInBlackList = blackL;
                  });
              }
            });
          }
        }
      });
    } else {
      if (isUnSubscribed != false || isInBlackList != false) {
        if (mounted)
          setState(() {
            isUnSubscribed = false;
            isInBlackList = false;
          });
      }
    }
  }

  Future _loadMore() async {
    var res = await MessageSchema.getAndReadTargetMessages(db, targetId, limit: _limit, skip: _skip);
    _contactBloc.add(LoadContact(address: res.where((x) => !x.isOutbound).map((x) => x.from).toList()));
    _chatBloc.add(RefreshMessages(target: targetId));
    if (res != null) {
      _skip += res.length;
      setState(() {
        _messages.addAll(res);
      });
    }
  }

  _deleteTickHandle() {
    _deleteTick = Timer.periodic(Duration(seconds: 1), (timer) {
      for (var i = 0, length = _messages.length; i < length; i++) {
        var item = _messages[i];
        if (item.deleteTime != null) {
          setState(() {
            int afterSeconds = item.deleteTime.difference(DateTime.now()).inSeconds;
            item.burnAfterSeconds = afterSeconds;
            if (item.burnAfterSeconds < 0) {
              _messages.removeAt(i);
              item.deleteMessage(db);
            }
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    targetId = widget.arguments.topic.topic;
    Global.currentOtherChatId = targetId;
    _topicCount = widget.arguments.topic.numSubscribers;
    _contactBloc = BlocProvider.of<ContactBloc>(context);
    Future.delayed(Duration(milliseconds: 200), () {
      initAsync();
      _sendFocusNode.addListener(() {
        if (_sendFocusNode.hasFocus) {
          setState(() {
            _showBottomMenu = false;
          });
        }
      });
      _chatBloc = BlocProvider.of<ChatBloc>(context);
      _chatSubscription = _chatBloc.listen((state) {
        if (state is MessagesUpdated && mounted) {
//          setState(() {
//            isUnSubscribed = LocalStorage.getUnsubscribeTopicList(accountPubkey).contains(targetId);
//          });
          if (state.message == null || state.message.topic == null) {
            return;
          }
          if (!state.message.isOutbound) {
            _contactBloc.add(LoadContact(address: [state.message.from]));
            if (state.message.topic == targetId && state.message.contentType == ContentType.text) {
              state.message.isSuccess = true;
              state.message.isRead = true;
              state.message.readMessage(db).then((n) {
                _chatBloc.add(RefreshMessages());
              });
              setState(() {
                _messages.insert(0, state.message);
              });
            } else if (state.message.contentType == ContentType.receipt && !state.message.isOutbound) {
              var msg = _messages.firstWhere((x) => x.msgId == state.message.content && x.isOutbound, orElse: () => null);
              if (msg != null) {
                NLog.d('message send success');
                setState(() {
                  msg.isSuccess = true;
                });
              }
            } else if (state.message.topic == targetId && state.message.contentType == ContentType.media) {
              state.message.isSuccess = true;
              state.message.isRead = true;
              if (state.message.options != null && state.message.options['deleteAfterSeconds'] != null) {
                print("YYYYYYY look here "+state.message.options['deleteAfterSeconds'].toString());
                state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
              }
              state.message.readMessage(db).then((n) {
                _chatBloc.add(RefreshMessages());
              });
              setState(() {
                _messages.insert(0, state.message);
              });
            } else if (state.message.topic == targetId && state.message.contentType == ContentType.eventSubscribe) {
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else {
            if (state.message.topic == targetId && state.message.contentType == ContentType.eventSubscribe) {
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          }
        }
      });
      _scrollController.addListener(() {
        double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
        if (offsetFromBottom < 50 && !loading) {
          loading = true;
          _loadMore().then((v) {
            loading = false;
          });
        }
      });

      String content = LocalStorage.getChatUnSendContentFromId(accountPubkey, targetId) ?? '';
      if (mounted)
        setState(() {
          _sendController.text = content;
//          _sendController.selection = TextSelection.fromPosition(TextPosition(offset: _sendController.text.length));
//          FocusScope.of(context).requestFocus(_sendFocusNode);
          _canSend = content.length > 0;
        });
    });
  }

  @override
  void dispose() {
    Global.currentOtherChatId = null;
    LocalStorage.saveChatUnSendContentWithId(accountPubkey, targetId, content: _sendController.text);
    _chatBloc.add(RefreshMessages());
    _chatSubscription?.cancel();
    _scrollController?.dispose();
    _sendController?.dispose();
    _sendFocusNode?.dispose();
    _deleteTick?.cancel();
    refreshSubscribersTimer?.cancel();
    super.dispose();
  }

  _scrollBottom() {
    Timer(Duration(milliseconds: 100), () {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: Duration(milliseconds: 300), curve: Curves.ease);
    });
  }

  _send() async {
    LocalStorage.saveChatUnSendContentWithId(accountPubkey, targetId);
    String text = _sendController.text;
    if (text == null || text.length == 0) return;
    _sendController.clear();
    _canSend = false;

    String dest = targetId;

    String contentType = ContentType.text;
    Duration deleteAfterSeconds;

    var sendMsg = MessageSchema.fromSendData(from: accountChatId, topic: dest, content: text, contentType: contentType, deleteAfterSeconds: deleteAfterSeconds);
    sendMsg.isOutbound = true;
    try {
      _chatBloc.add(SendMessage(sendMsg));
      setState(() {
        _messages.insert(0, sendMsg);
      });
    } catch (e) {
      print('send message error: $e');
    }
  }

  _sendImage(File savedImg) async {
    String dest = targetId;

    var sendMsg = MessageSchema.fromSendData(
      from: accountChatId,
      topic: dest,
      content: savedImg,
      contentType: ContentType.media,
    );
    sendMsg.isOutbound = true;
    try {
      _chatBloc.add(SendMessage(sendMsg));
      setState(() {
        _messages.insert(0, sendMsg);
      });
    } catch (e) {
      print('send message error: $e');
    }
  }

  getImageFile({@required ImageSource source}) async {
    FocusScope.of(context).requestFocus(FocusNode());
    try {
      File image = await getCameraFile(accountPubkey, source: source);
      if (image != null) {
        _sendImage(image);
      }
    } catch (e) {
      debugPrintStack();
      debugPrint(e);
    }
  }

  _toggleBottomMenu() async {
    setState(() {
      _showBottomMenu = !_showBottomMenu;
    });
  }

  _hideAll() {
    FocusScope.of(context).requestFocus(FocusNode());
    setState(() {
      _showBottomMenu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> topicWidget = [Label(widget.arguments.topic.shortName, type: LabelType.h3, dark: true)];
    if (widget.arguments.topic.isPrivate) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 18, color: DefaultTheme.fontLightColor).pad(r: 2));
    }
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context).pushNamed(ChannelSettingsScreen.routeName, arguments: widget.arguments.topic).then((v) {
//              setState(() {
//                isUnSubscribed = LocalStorage.getUnsubscribeTopicList(accountPubkey).contains(targetId);
//                NLog.d(isUnSubscribed);
//              });
            });
          },
          child: Flex(direction: Axis.horizontal, mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
//              Label(
//                '${widget.arguments.topic.topicName} （${_topicCount ?? 1}）',
//                type: LabelType.bodyLarge,
//                color: Colors.white,
//              )
            Expanded(
              flex: 0,
              child: Container(
                padding: EdgeInsets.only(right: 10.w),
                alignment: Alignment.center,
                child: Hero(
                  tag: 'avatar:${targetId}',
                  child: TopicSchema.avatarWidget(
                    topicName: widget.arguments.topic.topic,
                    size: 48,
                    avatar: widget.arguments.topic.avatarUri == null ? null : File(widget.arguments.topic.avatarUri),
                    options: widget.arguments.topic.options ?? OptionsSchema.random(themeId: widget.arguments.topic.themeId),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: topicWidget),
                  BlocBuilder<ChannelMembersBloc, ChannelMembersState>(builder: (context, state) {
                    if (state.membersCount != null && state.membersCount.topicName == targetId) {
                      final count = state.membersCount.subscriberCount;
                      if (_topicCount == null || count > _topicCount || state.membersCount.isFinal) {
                        _topicCount = count;
                      }
                      if (state.membersCount.isFinal) {
                        _refreshUnSubscribed(state.membersCount.topicName);
                      }
                    }
                    return Label(
                      '${(_topicCount == null || _topicCount < 0) ? '--' : _topicCount} ' + NL10ns.of(context).members,
                      type: LabelType.bodySmall,
                      color: DefaultTheme.riseColor,
                    ).pad(l: widget.arguments.topic.type == TopicType.private ? 20 : 0);
                  })
                ],
              ),
            )
          ]),
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: FlatButton(
          onPressed: () {
            Navigator.of(context).pushNamed(ChannelMembersScreen.routeName, arguments: widget.arguments.topic);
          },
          child: loadAssetChatPng('group', width: 22),
        ).sized(w: 72),
      ),
      body: GestureDetector(
        onTap: () {
          _hideAll();
        },
        child: BodyBox(
          padding: const EdgeInsets.only(top: 0),
          color: DefaultTheme.backgroundLightColor,
          child: Container(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 16, top: 4),
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        controller: _scrollController,
                        itemCount: _messages.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int index) {
                          var message = _messages[index];
                          bool showTime;
                          bool hideHeader = false;
                          if (index + 1 >= _messages.length) {
                            showTime = true;
                          } else {
                            var preMessage = index == _messages.length ? message : _messages[index + 1];
                            if (preMessage.contentType == ContentType.text || preMessage.contentType == ContentType.media) {
                              showTime = (message.timestamp.isAfter(preMessage.timestamp.add(Duration(minutes: 3))));
                            } else {
                              showTime = true;
                            }
                          }

                          if (!showTime) {
                            var preMessage = index == _messages.length ? message : _messages[index + 1];
                            hideHeader = message.from == preMessage.from;
                          }
                          return BlocBuilder<ContactBloc, ContactState>(builder: (context, state) {
                            ContactSchema contact;
                            if (state is ContactLoaded) {
                              contact = state.getContactByAddress(message.from);
                            }
                            if (message.contentType == ContentType.eventSubscribe) {
                              return ChatSystem(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    accountUserBuilder(onUser: (ctx, user) {
                                      return Label('${message.isOutbound ? user.name : contact?.name} ${NL10ns.of(context).joined_channel}');
                                    }),
                                  ],
                                ),
                              );
                            } else {
                              if (message.isOutbound) {
                                return ChatBubble(
                                  message: message,
                                  showTime: showTime,
                                  hideHeader: hideHeader,
                                );
                              } else {
                                return ChatBubble(
                                  message: message,
                                  showTime: showTime,
                                  contact: contact,
                                  hideHeader: hideHeader,
                                  onChanged: (String v) {
                                    setState(() {
                                      _sendController.text = _sendController.text + ' @$v ';
                                      _canSend = true;
                                    });
                                  },
                                );
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
                    constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
//                      decoration: BoxDecoration(
//                        border: Border(
//                          top: BorderSide(color: DefaultTheme.backgroundColor2),
//                        ),
//                      ),
                    child: getBottomView(),
                  ),
                  getBottomMenuView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  getBottomMenuView() {
    return ExpansionLayout(
      isExpanded: _showBottomMenu,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: DefaultTheme.backgroundColor2),
          ),
        ),
        child: Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 71,
                    height: 71,
                    child: FlatButton(
                      color: DefaultTheme.backgroundColor1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      child: loadAssetIconsImage(
                        'image',
                        width: 32,
                        color: DefaultTheme.fontColor2,
                      ),
                      onPressed: () {
                        getImageFile(source: ImageSource.gallery);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      NL10ns.of(context).pictures,
                      type: LabelType.bodySmall,
                      color: DefaultTheme.fontColor2,
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              flex: 0,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 71,
                    height: 71,
                    child: FlatButton(
                      color: DefaultTheme.backgroundColor1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      child: loadAssetIconsImage(
                        'camera',
                        width: 32,
                        color: DefaultTheme.fontColor2,
                      ),
                      onPressed: () {
                        getImageFile(source: ImageSource.camera);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      NL10ns.of(context).camera,
                      type: LabelType.bodySmall,
                      color: DefaultTheme.fontColor2,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  getBottomView() {
    if (isUnSubscribed) {
      return Button(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[Label(NL10ns.of(context).subscribe_or_waiting, type: LabelType.h3)],
        ),
        backgroundColor: DefaultTheme.primaryColor,
        width: double.infinity,
        onPressed: () {
          if (isInBlackList) {
            // TODO:
          } else {
            EasyLoading.show();
            Global.removeTopicCache(targetId);
            GroupChatHelper.subscribeTopic(
                account: account,
                topicName: widget.arguments.topic.topic,
                chatBloc: _chatBloc,
                callback: (success, e) {
                  _refreshUnSubscribed(widget.arguments.topic.topic);
                  EasyLoading.dismiss();
                  if (!success && e != null) {
                    showToast('channel subscribe failed');
                    // showToast(NL10ns.of(context).something_went_wrong);
                  }
                });
          }
        },
      ).pad(l: 20, r: 20);
    }
    return Flex(
      direction: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 0,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: ButtonIcon(
              width: 50,
              height: 50,
              icon: loadAssetIconsImage('grid', width: 24, color: DefaultTheme.primaryColor),
              onPressed: () {
                _toggleBottomMenu();
              },
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: DefaultTheme.backgroundColor1,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: TextField(
                    maxLines: 5,
                    minLines: 1,
                    controller: _sendController,
                    focusNode: _sendFocusNode,
                    textInputAction: TextInputAction.newline,
                    onChanged: (val) {
                      setState(() {
                        _canSend = val.isNotEmpty;
                      });
                    },
                    style: TextStyle(fontSize: 14, height: 1.4),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                      hintText: NL10ns.of(context).type_a_message,
                      border: UnderlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.w)),
                        borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 0,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: ButtonIcon(
              width: 50,
              height: 50,
              icon: loadAssetIconsImage(
                'send',
                width: 24,
                color: _canSend ? DefaultTheme.primaryColor : DefaultTheme.fontColor2,
              ),
              //disabled: !_canSend,
              onPressed: () {
                _send();
              },
            ),
          ),
        ),
      ],
    );
  }
}
