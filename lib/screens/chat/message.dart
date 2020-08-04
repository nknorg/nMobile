import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/components/button_icon.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/chat/system.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/view/burn_view_utils.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ChatSinglePage extends StatefulWidget {
  static const String routeName = '/chat/message';

  final ChatSchema arguments;

  ChatSinglePage({this.arguments});

  @override
  _ChatSinglePageState createState() => _ChatSinglePageState();
}

class _ChatSinglePageState extends State<ChatSinglePage> with AccountDependsBloc{
  ChatBloc _chatBloc;
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

  initAsync() async {
    var res = await MessageSchema.getAndReadTargetMessages(db, targetId, limit: _limit);
    _chatBloc.add(RefreshMessages(target: targetId));
    if (res != null) {
      setState(() {
        _messages = res;
      });
    }
    widget.arguments.contact.requestProfile(account.client);
  }

  Future _loadMore() async {
    var res = await MessageSchema.getAndReadTargetMessages(db, targetId, limit: _limit, skip: _skip);
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
      _messages.removeWhere((item) {
        if (item.deleteTime != null) {
          int afterSeconds = item.deleteTime.difference(DateTime.now()).inSeconds;
          item.burnAfterSeconds = afterSeconds;
          if (item.burnAfterSeconds < 0) {
            item.deleteMessage(db);
            return true;
          } else {
            return false;
          }
        } else {
          return false;
        }
      });
      setState(() {});
//      for (var item in _messages) {
//        setState(() {
//          if (item.deleteTime != null) {
//            int afterSeconds = item.deleteTime.difference(DateTime.now()).inSeconds;
//            item.burnAfterSeconds = afterSeconds;
//            if (item.burnAfterSeconds < 0) {
//              _messages.remove(item);
//              item.deleteMessage();
//            }
//          }
//        });
//      }

//      for (var i = 0, length = _messages.length; i < length; i++) {
//        var item = _messages[i];
//        if (item.deleteTime != null) {
//          setState(() {
//            int afterSeconds = item.deleteTime.difference(DateTime.now()).inSeconds;
//            item.burnAfterSeconds = afterSeconds;
//            if (item.burnAfterSeconds < 0) {
//              _messages.removeAt(i);
//              item.deleteMessage();
//            }
//          });
//        }
//      }
    });
  }

  @override
  void initState() {
    super.initState();
    targetId = widget.arguments.contact.clientAddress;
    Global.currentOtherChatId = targetId;
    _deleteTickHandle();
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
        if (state.message == null || state.message.topic != null) {
          return;
        }
        if (!state.message.isOutbound) {
          if (state.message.from == targetId && state.message.contentType == ContentType.text) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            state.message.readMessage(db).then((n) {
              _chatBloc.add(RefreshMessages());
            });
            setState(() {
              _messages.insert(0, state.message);
            });
          } else if (state.message.from == targetId && state.message.contentType == ContentType.ChannelInvitation) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            state.message.readMessage(db).then((n) {
              _chatBloc.add(RefreshMessages());
            });
            setState(() {
              _messages.insert(0, state.message);
            });
          } else if (state.message.contentType == ContentType.receipt && !state.message.isOutbound) {
            if (_messages != null && _messages.length > 0) {
              var msg = _messages.firstWhere((x) => x.msgId == state.message.content && x.isOutbound, orElse: () => null);
              if (msg != null) {
                setState(() {
                  msg.isSuccess = true;
                  if (state.message.deleteTime != null) {
                    msg.deleteTime = state.message.deleteTime;
                  }
                });
              }
            }
          } else if (state.message.from == targetId && state.message.contentType == ContentType.textExtension) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            if (state.message.options['deleteAfterSeconds'] != null) {
              state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
            }
            state.message.readMessage(db).then((n) {
              _chatBloc.add(RefreshMessages());
            });
            setState(() {
              _messages.insert(0, state.message);
            });
          } else if (state.message.from == targetId && state.message.contentType == ContentType.media) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            if (state.message.options != null && state.message.options['deleteAfterSeconds'] != null) {
              state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
            }
            state.message.readMessage(db).then((n) {
              _chatBloc.add(RefreshMessages());
            });
            setState(() {
              _messages.insert(0, state.message);
            });
          } else if (state.message.contentType == ContentType.eventContactOptions) {
            setState(() {
              _messages.insert(0, state.message);
            });
          }
        } else {
          if (state.message.contentType == ContentType.eventContactOptions) {
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
    Future.delayed(Duration(milliseconds: 100), () {
      String content = LocalStorage.getChatUnSendContentFromId(accountPubkey, targetId) ?? '';

      if (mounted)
        setState(() {
          _sendController.text = content;
          _canSend = content.length > 0;
        });
    });
  }

  @override
  void dispose() {
    Global.currentOtherChatId = null;
    LocalStorage.saveChatUnSendContentFromId(accountPubkey, targetId, content: _sendController.text);
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
    LocalStorage.saveChatUnSendContentFromId(accountPubkey, targetId);
    String text = _sendController.text;
    if (text == null || text.length == 0) return;
    _sendController.clear();
    _canSend = false;

    if (widget.arguments.type == ChatType.PrivateChat) {
      String dest = targetId;

      String contentType = ContentType.text;
      Duration deleteAfterSeconds;
      if (widget.arguments.contact?.options != null) {
        if (widget.arguments.contact?.options?.deleteAfterSeconds != null) {
          contentType = ContentType.textExtension;
          deleteAfterSeconds = Duration(seconds: widget.arguments.contact.options.deleteAfterSeconds);
        }
      }

      var sendMsg = MessageSchema.fromSendData(from: accountChatId, to: dest, content: text, contentType: contentType, deleteAfterSeconds: deleteAfterSeconds);
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
  }

  _sendImage(File savedImg) async {
    String dest = targetId;
    Duration deleteAfterSeconds;
    if (widget.arguments.contact?.options != null) {
      if (widget.arguments.contact?.options?.deleteAfterSeconds != null) deleteAfterSeconds = Duration(seconds: widget.arguments.contact.options.deleteAfterSeconds);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: accountChatId,
      to: dest,
      content: savedImg,
      contentType: ContentType.media,
      deleteAfterSeconds: deleteAfterSeconds,
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
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context).pushNamed(
              ContactScreen.routeName,
              arguments: widget.arguments.contact,
            );
          },
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: Container(
                  padding: EdgeInsets.only(right: 14.w),
                  alignment: Alignment.center,
                  child: widget.arguments.contact.avatarWidget(db, backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200), size: 24),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[Label(widget.arguments.contact.name, type: LabelType.h3, dark: true), getBurnTimeView()],
                ),
              )
            ],
          ),
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: PopupMenuButton(
          icon: loadAssetIconsImage('more', width: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (int result) {
            switch (result) {
              case 0:
//                Navigator.of(context).pushNamed(
//                  ContactScreen.routeName,
//                  arguments: widget.arguments.contact,
//                );
                BurnViewUtil.showBurnViewDialog(context, widget.arguments.contact, _chatBloc);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(
                NMobileLocalizations.of(context).burn_after_reading,
                type: LabelType.display,
              ),
            )
          ],
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
              child: Flex(
                direction: Axis.vertical,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: EdgeInsets.only(left: 12.w, right: 16.w, top: 4.h),
                      child: ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.only(bottom: 8.h),
                        controller: _scrollController,
                        itemCount: _messages.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int index) {
                          var message = _messages[index];
                          bool showTime;
                          var preMessage;
                          if (index + 1 >= _messages.length) {
                            showTime = true;
                          } else {
                            if (ContentType.text == message.contentType || ContentType.media == message.contentType) {
                              preMessage = index == _messages.length ? message : _messages[index + 1];
                              showTime = (message.timestamp.isAfter(preMessage.timestamp.add(Duration(minutes: 3))));
                            } else {
                              showTime = true;
                            }
                          }

                          if (message.contentType == ContentType.eventContactOptions) {
                            var content = jsonDecode(message.content);
                            if (content['content'] != null) {
                              var deleteAfterSeconds = content['content']['deleteAfterSeconds'];
                              if (deleteAfterSeconds != null && deleteAfterSeconds > 0) {
                                return ChatSystem(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              Padding(
                                                padding: const EdgeInsets.only(left: 4, right: 4),
                                                child: Icon(
                                                  Icons.alarm_on,
                                                  size: 14,
                                                  color: DefaultTheme.fontColor2,
                                                ),
                                              ),
                                              Label(' ${Format.durationFormatString(Duration(seconds: content['content']['deleteAfterSeconds']))}'),
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          accountUserBuilder(onUser: (context, user) {
                                            return Label(
                                                '${message.isOutbound ? user.name : widget.arguments.contact.name} ${NMobileLocalizations.of(context).update_burn_after_reading}');
                                          }),
                                        ],
                                      ),
//                                      Padding(
//                                        padding: const EdgeInsets.only(left: 8),
//                                        child: InkWell(
//                                          child: Label(
//                                            NMobileLocalizations.of(context).settings,
//                                            color: DefaultTheme.primaryColor,
//                                            type: LabelType.bodyRegular,
//                                          ),
//                                          onTap: () {
//                                            Navigator.of(context).pushNamed(
//                                              ContactScreen.routeName,
//                                              arguments: widget.arguments.contact,
//                                            );
//                                          },
//                                        ),
//                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                return ChatSystem(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              Padding(
                                                padding: const EdgeInsets.only(left: 4, right: 4),
                                                child: Icon(
                                                  Icons.alarm_off,
                                                  size: 14,
                                                  color: DefaultTheme.fontColor2,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Label('off'),
                                            ],
                                          ),
                                          accountUserBuilder(onUser: (context, user) {
                                            return Label(
                                                '${message.isOutbound ? user.name : widget.arguments.contact.name} ${NMobileLocalizations.of(context).close_burn_after_reading}');
                                          }),
                                        ],
                                      ),
//                                      Padding(
//                                        padding: const EdgeInsets.only(left: 8),
//                                        child: InkWell(
//                                          child: Label(
//                                            NMobileLocalizations.of(context).settings,
//                                            color: DefaultTheme.primaryColor,
//                                            type: LabelType.bodyRegular,
//                                          ),
//                                          onTap: () {
//                                            Navigator.of(context).pushNamed(
//                                              ContactScreen.routeName,
//                                              arguments: widget.arguments.contact,
//                                            );
//                                          },
//                                        ),
//                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else {
                              return Container();
                            }
                          } else {
                            return ChatBubble(
                              message: message,
                              showTime: showTime,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
                        constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
//                        decoration: BoxDecoration(
//                          border: Border(
//                            top: BorderSide(color: Colors.red),
//                          ),
//                        ),
                        child: Flex(
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
                                  icon: loadAssetIconsImage(
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
                                          hintText: NMobileLocalizations.of(context).type_a_message,
                                          contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
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
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: ExpansionLayout(
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  getBurnTimeView() {
    if (widget.arguments.contact?.options != null && widget.arguments.contact?.options?.deleteAfterSeconds != null) {
      return Container(
        padding: EdgeInsets.only(top: 2),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.alarm_on,
              size: 14,
              color: DefaultTheme.backgroundLightColor,
            ),
            SizedBox(width: 4),
            Label(Format.durationFormat(Duration(seconds: widget.arguments.contact?.options?.deleteAfterSeconds)), type: LabelType.bodySmall, color: DefaultTheme.backgroundLightColor),
          ],
        ),
      );
    } else {
      return Container();
    }
  }
}
