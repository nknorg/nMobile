import 'dart:async';
import 'dart:io';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/chat/system.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/settings/channel.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class ChatGroupPage extends StatefulWidget {
  static const String routeName = '/chat/channel';

  final ChatSchema arguments;

  ChatGroupPage({this.arguments});

  @override
  _ChatGroupPageState createState() => _ChatGroupPageState();
}

class _ChatGroupPageState extends State<ChatGroupPage> {
  ChatBloc _chatBloc;
  ContactBloc _contactBloc;
  String targetId;
  StreamSubscription _chatSubscription;
  ScrollController _scrollController = ScrollController();
  FocusNode _sendFocusNode = FocusNode();
  TextEditingController _sendController = TextEditingController();
  String currentAddress = Global.currentClient.address;
  List<MessageSchema> _messages = <MessageSchema>[];
  bool _canSend = false;
  int _limit = 20;
  int _skip = 20;
  bool loading = false;
  bool _showBottomMenu = false;
  Timer _deleteTick;
  int _topicCount = 0;
  bool isUnSubscribe;

  initAsync() async {
    var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit);
    _contactBloc.add(LoadContact(address: res.where((x) => !x.isOutbound).map((x) => x.from).toList()));
    _chatBloc.add(RefreshMessages(target: targetId));

    if (res != null) {
      setState(() {
        _messages = res;
      });
    }

    var topic = await TopicSchema.getTopic(widget.arguments.topic.topic);
    if (topic != null && topic.count != 0) {
      if (mounted) {
        setState(() {
          if (topic.count == 0) {
            _topicCount = 1;
          } else {
            _topicCount = topic.count;
          }
        });
      }
    }

    if (topic != null) {
      topic.getTopicCount().then((v) {
        if (mounted) {
          setState(() {
            if (v == 0 || v == null) {
              _topicCount = 1;
            } else {
              _topicCount = v;
            }
          });
        }
      });
    }
  }

  Future _loadMore() async {
    var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit, skip: _skip);
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
              item.deleteMessage();
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
    isUnSubscribe = LocalStorage.getUnsubscribeTopicList().contains(targetId);
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
        if (state is MessagesUpdated) {
          setState(() {
            isUnSubscribe = LocalStorage.getUnsubscribeTopicList().contains(targetId);
          });
          if (state.message == null || state.message.topic == null) {
            return;
          }
          if (!state.message.isOutbound) {
            _contactBloc.add(LoadContact(address: [state.message.from]));
            if (state.message.topic == targetId && state.message.contentType == ContentType.text) {
              state.message.isSuccess = true;
              state.message.isRead = true;
              state.message.readMessage().then((n) {
                _chatBloc.add(RefreshMessages());
              });
              setState(() {
                _messages.insert(0, state.message);
              });
            } else if (state.message.contentType == ContentType.receipt && !state.message.isOutbound) {
              var msg = _messages.firstWhere((x) => x.msgId == state.message.content && x.isOutbound, orElse: () => null);
              if (msg != null) {
                LogUtil.e('message send success');
                setState(() {
                  msg.isSuccess = true;
                });
              }
            } else if (state.message.topic == targetId && state.message.contentType == ContentType.media) {
              state.message.isSuccess = true;
              state.message.isRead = true;
              if (state.message.options != null && state.message.options['deleteAfterSeconds'] != null) {
                state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
              }
              state.message.readMessage().then((n) {
                _chatBloc.add(RefreshMessages());
              });
              setState(() {
                _messages.insert(0, state.message);
              });
            } else if (state.message.topic == targetId && state.message.contentType == ContentType.dchatSubscribe) {
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else {
            if (state.message.topic == targetId && state.message.contentType == ContentType.dchatSubscribe) {
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

      String content = LocalStorage.getChatUnSendContentFromId(targetId) ?? '';
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
    LocalStorage.saveChatUnSendContentFromId(targetId, content: _sendController.text);
    _chatBloc.add(RefreshMessages());
    _chatSubscription?.cancel();
    _scrollController?.dispose();
    _sendController?.dispose();
    _sendFocusNode?.dispose();
    _deleteTick?.cancel();
    super.dispose();
  }

  _scrollBottom() {
    Timer(Duration(milliseconds: 100), () {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: Duration(milliseconds: 300), curve: Curves.ease);
    });
  }

  _send() async {
    LocalStorage.saveChatUnSendContentFromId(targetId);
    String text = _sendController.text;
    _sendController.clear();
    _canSend = false;

    String dest = targetId;

    String contentType = ContentType.text;
    Duration deleteAfterSeconds;

    var sendMsg = MessageSchema.fromSendData(from: currentAddress, topic: dest, content: text, contentType: contentType, deleteAfterSeconds: deleteAfterSeconds);
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
      from: currentAddress,
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
      File image = await getCameraFile(source: source);
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
    List<Widget> topicWidget = <Widget>[
      Label(widget.arguments.topic.topicName, type: LabelType.h3, dark: true),
    ];
    if (widget.arguments.topic.type == TopicType.private) {
      topicWidget.insert(
        0,
        loadAssetIconsImage(
          'lock',
          width: 18,
          color: DefaultTheme.fontLightColor,
        ),
      );
    }

    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context)
                .pushNamed(
              ChannelSettingsScreen.routeName,
              arguments: widget.arguments.topic,
            )
                .then((v) {
              isUnSubscribe = LocalStorage.getUnsubscribeTopicList().contains(targetId);
            });
          },
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: Container(
                  padding: EdgeInsets.only(right: 10.w),
                  alignment: Alignment.center,
                  child: Hero(
                    tag: 'avatar:${targetId}',
                    child: widget.arguments.topic.avatarWidget(
                      size: 48,
                      backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200),
                      fontColor: DefaultTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: topicWidget,
                    ),
                    Label('${_topicCount ?? 1} ' + NMobileLocalizations.of(context).members, type: LabelType.bodySmall, color: DefaultTheme.riseColor)
                  ],
                ),
              )
            ],
          ),
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
                          return BlocBuilder<ContactBloc, ContactState>(builder: (context, state) {
                            ContactSchema contact;
                            if (state is ContactLoaded) {
                              contact = state.getContactByAddress(message.from);
                            }
                            if (message.contentType == ContentType.dchatSubscribe) {
                              return ChatSystem(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Label('${message.isOutbound ? Global.currentUser.name : contact?.name} ${NMobileLocalizations.of(context).joined_channel}'),
                                  ],
                                ),
                              );
                            } else {
                              if (message.isOutbound) {
                                return ChatBubble(
                                  message: message,
                                  showTime: showTime,
                                );
                              } else {
                                return ChatBubble(
                                  message: message,
                                  showTime: showTime,
                                  contact: contact,
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
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
                      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: DefaultTheme.backgroundColor2),
                        ),
                      ),
                      child: getBottomView(),
                    ),
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

  acceptPrivateAction(address) async {
    showToast(NMobileLocalizations.of(context).invitation_sent);
    if (widget.arguments.topic.type == TopicType.private) {
      await widget.arguments.topic.acceptPrivateMember(addr: address);
    }

    var sendMsg = MessageSchema.fromSendData(from: currentAddress, content: targetId, to: address, contentType: ContentType.ChannelInvitation);
    sendMsg.isOutbound = true;

    var sendMsg1 = MessageSchema.fromSendData(from: currentAddress, topic: widget.arguments.topic.topic, contentType: ContentType.eventSubscribe, content: 'Accepting user $address');
    sendMsg1.isOutbound = true;

    try {
      _chatBloc.add(SendMessage(sendMsg));
      _chatBloc.add(SendMessage(sendMsg1));
    } catch (e) {
      print('send message error: $e');
    }
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      NMobileLocalizations.of(context).pictures,
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
                      NMobileLocalizations.of(context).camera,
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
                      padding: const EdgeInsets.all(0),
                      color: DefaultTheme.backgroundColor1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      child: loadAssetIconsImage(
                        'paperclip2',
                        width: 35,
                        color: DefaultTheme.fontColor2,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      NMobileLocalizations.of(context).files,
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
                        'pin',
                        width: 24,
                        color: DefaultTheme.fontColor2,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      NMobileLocalizations.of(context).location,
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
    if (isUnSubscribe) {
      return Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
        ),
        child: Button(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Label(
                NMobileLocalizations.of(context).subscribe,
                type: LabelType.h3,
              )
            ],
          ),
          backgroundColor: DefaultTheme.primaryColor,
          width: double.infinity,
          onPressed: () {
            var duration = 400000;
            LocalStorage.removeTopicFromUnsubscribeList(targetId);
            Global.removeTopicCache(targetId);
            setState(() {
              isUnSubscribe = LocalStorage.getUnsubscribeTopicList().contains(targetId);
            });
            TopicSchema.subscribe(topic: targetId, duration: duration).then((hash) {
              if (hash != null) {
                var sendMsg = MessageSchema.fromSendData(
                  from: Global.currentClient.address,
                  topic: targetId,
                  contentType: ContentType.dchatSubscribe,
                );
                sendMsg.isOutbound = true;
                sendMsg.content = sendMsg.toDchatSubscribeData();
                _chatBloc.add(SendMessage(sendMsg));
                DateTime now = DateTime.now();
                var topicSchema = TopicSchema(topic: targetId, expiresAt: now.add(blockToExpiresTime(duration)));
                topicSchema.insertIfNoData();
              }
            });
          },
        ),
      );
    }
    return Flex(
      direction: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 0,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Button(
              size: 50,
              icon: true,
              child: loadAssetIconsImage(
                'grid',
                width: 24,
                color: DefaultTheme.primaryColor,
              ),
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
                      hintText: NMobileLocalizations.of(context).type_a_message,
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
            child: Button(
              size: 50,
              icon: true,
              child: loadAssetIconsImage(
                'send',
                width: 24,
                color: _canSend ? DefaultTheme.primaryColor : DefaultTheme.fontColor2,
              ),
              disabled: !_canSend,
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
