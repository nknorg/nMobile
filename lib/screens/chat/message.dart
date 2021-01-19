import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button_icon.dart';
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
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class ChatSinglePage extends StatefulWidget {
  static const String routeName = '/chat/message';

  final ChatSchema arguments;

  ChatSinglePage({this.arguments});

  @override
  _ChatSinglePageState createState() => _ChatSinglePageState();
}

class _ChatSinglePageState extends State<ChatSinglePage>{
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

  bool _acceptNotification = false;
  Color notiBellColor;
  static const fcmGapString = '__FCMToken__:';

  TimerAuth timerAuth;

  ContactSchema chatContact;


  initAsync() async {
    var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit);
    _chatBloc.add(RefreshMessageListEvent(target: targetId));
    if (res != null) {
      if (mounted){
        setState(() {
          _messages = res;
        });
      }
    }
    chatContact.requestProfile();
  }

  Future _loadMore() async {
    var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit, skip: _skip);
    _chatBloc.add(RefreshMessageListEvent(target: targetId));
    if (res != null) {
      _skip += res.length;
      if (mounted){
        setState(() {
          _messages.addAll(res);
        });
      }
    }
  }

  _deleteTickHandle() {
    _deleteTick = Timer.periodic(Duration(seconds: 1), (timer) {
      _messages.removeWhere((item) {
        if (item.deleteTime != null) {
          int afterSeconds = item.deleteTime.difference(DateTime.now()).inSeconds;
          item.burnAfterSeconds = afterSeconds;
          if (item.burnAfterSeconds < 0) {
            item.deleteMessage();
            return true;
          }
        }
        return false;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    chatContact = widget.arguments.contact;
    if (chatContact.notificationOpen == null){
      chatContact.setNotificationOpen(false);
      chatContact.notificationOpen = false;
    }

    targetId = chatContact.clientAddress;
    if (chatContact.notificationOpen == null){
      chatContact.setNotificationOpen(false);
      _acceptNotification = false;
    }
    else{
      _acceptNotification = chatContact.notificationOpen;
    }
    Global.currentOtherChatId = targetId;

    _deleteTickHandle();
    initAsync();

    _sendFocusNode.addListener(() {
      if (_sendFocusNode.hasFocus) {
        if (mounted){
          setState(() {
            _showBottomMenu = false;
          });
        }
      }
    });

    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _chatSubscription = _chatBloc.listen((state) {
      if (state is MessageUpdateState) {
        if (state.message == null || state.message.topic != null) {
          return;
        }
        if (!state.message.isOutbound) {
          if (state.message.from == targetId && state.message.contentType == ContentType.text) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            state.message.readMessage().then((n) {
              _chatBloc.add(RefreshMessageListEvent());
            });
            if (mounted){
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else if (state.message.from == targetId && state.message.contentType == ContentType.ChannelInvitation) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            state.message.readMessage().then((n) {
              _chatBloc.add(RefreshMessageListEvent());
            });
            if (mounted){
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else if (state.message.contentType == ContentType.receipt && !state.message.isOutbound) {
            if (_messages != null && _messages.length > 0) {
              var msg = _messages.firstWhere((x) => x.msgId == state.message.content && x.isOutbound, orElse: () => null);
              if (msg != null) {
                if (mounted){
                  setState(() {
                    msg.isSuccess = true;
                    if (state.message.deleteTime != null) {
                      msg.deleteTime = state.message.deleteTime;
                    }
                  });
                }
              }
            }
          } else if (state.message.from == targetId && state.message.contentType == ContentType.textExtension) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            if (state.message.options['deleteAfterSeconds'] != null) {
              state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
            }
            state.message.readMessage().then((n) {
              _chatBloc.add(RefreshMessageListEvent());
            });
            if (mounted){
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else if (state.message.from == targetId && state.message.contentType == ContentType.media) {
            state.message.isSuccess = true;
            state.message.isRead = true;
            if (state.message.options != null && state.message.options['deleteAfterSeconds'] != null) {
              state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
            }
            state.message.readMessage().then((n) {
              _chatBloc.add(RefreshMessageListEvent());
            });
            if (mounted){
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          } else if (state.message.contentType == ContentType.eventContactOptions) {
            if (mounted){
              setState(() {
                _messages.insert(0, state.message);
              });
            }
          }
        } else {
          if (mounted){
            if (state.message.contentType == ContentType.eventContactOptions) {
              setState(() {
                _messages.insert(0, state.message);
              });
            }
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
      String content = LocalStorage.getChatUnSendContentFromId(NKNClientCaller.pubKey, targetId) ?? '';

      if (mounted)
        setState(() {
          _sendController.text = content;
          _canSend = content.length > 0;
        });
    });
    print('end Message');
  }

  @override
  void dispose() {
    Global.currentOtherChatId = null;
    LocalStorage.saveChatUnSendContentWithId(NKNClientCaller.pubKey, targetId, content: _sendController.text);
    _chatBloc.add(RefreshMessageListEvent());
    _chatSubscription?.cancel();
    _scrollController?.dispose();
    _sendController?.dispose();
    _sendFocusNode?.dispose();
    _deleteTick?.cancel();
    super.dispose();
  }

  _send() async {
    LocalStorage.saveChatUnSendContentWithId(NKNClientCaller.pubKey, targetId);
    String text = _sendController.text;
    if (text == null || text.length == 0) return;
    _sendController.clear();
    _canSend = false;

    if (widget.arguments.type == ChatType.PrivateChat) {
      String dest = targetId;

      String contentType = ContentType.text;
      Duration deleteAfterSeconds;
      if (chatContact?.options != null) {
        if (chatContact?.options?.deleteAfterSeconds != null) {
          contentType = ContentType.textExtension;
          deleteAfterSeconds = Duration(seconds: chatContact.options.deleteAfterSeconds);
        }
      }
      var sendMsg = MessageSchema.fromSendData(
        from: NKNClientCaller.currentChatId,
        to: dest,
        content: text,
        contentType: contentType,
        deleteAfterSeconds: deleteAfterSeconds,
      );
      sendMsg.isOutbound = true;
      try {
        _chatBloc.add(SendMessageEvent(sendMsg));
        if (mounted){
          setState(() {
            _messages.insert(0, sendMsg);
          });
        }
      } catch (e) {
        print('send message error: $e');
      }
    }
  }

  _sendImage(File savedImg) async {
    String dest = targetId;
    Duration deleteAfterSeconds;
    if (chatContact?.options != null) {
      if (chatContact?.options?.deleteAfterSeconds != null)
        deleteAfterSeconds = Duration(seconds: chatContact.options.deleteAfterSeconds);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: dest,
      content: savedImg,
      contentType: ContentType.media,
      deleteAfterSeconds: deleteAfterSeconds,
    );
    sendMsg.isOutbound = true;
    try {
      _chatBloc.add(SendMessageEvent(sendMsg));
      if (mounted){
        setState(() {
          _messages.insert(0, sendMsg);
        });
      }
    } catch (e) {
      print('send message error: $e');
    }
  }

  getImageFile({@required ImageSource source}) async {
    FocusScope.of(context).requestFocus(FocusNode());
    try {
      File image = await getCameraFile(NKNClientCaller.pubKey, source: source);
      if (image != null) {
        _sendImage(image);
      }
    } catch (e) {
      Global.debugLog('message.dart getImageFile E:'+e.toString());
    }
  }

  _toggleBottomMenu() async {
    if (mounted){
      setState(() {
        _showBottomMenu = !_showBottomMenu;
      });
    }
  }

  _hideAll() {
    FocusScope.of(context).requestFocus(FocusNode());
    if (mounted){
      setState(() {
        _showBottomMenu = false;
      });
    }
  }

  _saveAndSendDeviceToken() async{
    String deviceToken = '';
    if (_acceptNotification == true){
      deviceToken = await NKNClientCaller.fetchDeviceToken();
      if (Platform.isIOS){
        String fcmToken = await NKNClientCaller.fetchFcmToken();
        if (fcmToken != null && fcmToken.length > 0){
          deviceToken = deviceToken+"$fcmGapString$fcmToken";
        }
      }
      if (Platform.isAndroid && deviceToken.length == 0){
        showToast('暂不支持没有Google服务的机型');
      }
    }
    else{
      deviceToken = '';
      showToast(NL10ns().off);
    }
    chatContact.setNotificationOpen(_acceptNotification);

    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: chatContact.clientAddress,
      contentType: ContentType.eventContactOptions,
      deviceToken: deviceToken,
    );
    sendMsg.isOutbound = true;
    sendMsg.content = sendMsg.toContentOptionData(1);
    sendMsg.deviceToken = deviceToken;
    _chatBloc.add(SendMessageEvent(sendMsg));
  }

  @override
  Widget build(BuildContext context) {
    notiBellColor = DefaultTheme.primaryColor;
    if (_acceptNotification == false){
      notiBellColor = Colors.white38;
    }
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact);
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
                  child: Container(
                    child: CommonUI.avatarWidget(
                        radiusSize: 24,
                        contact: chatContact,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[Label(chatContact.name, type: LabelType.h3, dark: true), getBurnTimeView()],
                ),
              ),
              // Spacer(),
              FlatButton(
                child: loadAssetIconsImage('notification_bell', color: notiBellColor, width: 24),
                onPressed: () {
                  if (mounted){
                    setState(() {
                      _acceptNotification = !_acceptNotification;
                      _saveAndSendDeviceToken();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: Container(
          margin: EdgeInsets.only(left: 8, right: 8),
          child: GestureDetector(
            child: loadAssetIconsImage('more', width: 24),
            onTap: ()=> {
              Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact)
            },
          ),
        )
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
                            return _contactOptionWidget(index);
                          }
                          else {
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
                                          if (mounted){
                                            setState(() {
                                              _canSend = val.isNotEmpty;
                                            });
                                          }
                                        },
                                        style: TextStyle(fontSize: 14, height: 1.4),
                                        decoration: InputDecoration(
                                          hintText: NL10ns.of(context).type_a_message,
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

  Widget _contactOptionWidget(int index){
    var message = _messages[index];
    Map optionData = jsonDecode(message.content);
    if (optionData['content'] != null) {
      var deleteAfterSeconds = optionData['content']['deleteAfterSeconds'];
      if (deleteAfterSeconds != null && deleteAfterSeconds > 0) {
        return ChatSystem(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm_on, size: 16, color: DefaultTheme.fontColor2).pad(b: 1, r: 4),
                      Label(Format.durationFormat(Duration(seconds: optionData['content']['deleteAfterSeconds'])),
                          type: LabelType.bodySmall),
                    ],
                  ).pad(b: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Label(
                        message.isOutbound ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label(' ${NL10ns.of(context).update_burn_after_reading}', softWrap: true),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact);
                    },
                  ),
                ],
              ),
            ],
          ),
        );

      }
      else if (optionData['content']['deviceToken'] != null){
        String deviceToken = optionData['content']['deviceToken'];

        String deviceDesc = "";
        if (deviceToken.length == 0){
          deviceDesc = ' ${NL10ns.of(context).setting_deny_notification}';
        }
        else{
          deviceDesc = ' ${NL10ns.of(context).setting_accept_notification}';
        }
        return ChatSystem(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Label(
                        message.isOutbound ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label('$deviceDesc'),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }
      else {
        return ChatSystem(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm_off, size: 16, color: DefaultTheme.fontColor2).pad(b: 1, r: 4),
                      Label(NL10ns.of(context).off, type: LabelType.bodySmall, fontWeight: FontWeight.bold),
                    ],
                  ).pad(b: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Label(
                        message.isOutbound ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label(' ${NL10ns.of(context).close_burn_after_reading}'),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } else {
      return Container();
    }
  }

  getBurnTimeView() {
    if (chatContact?.options != null && chatContact?.options?.deleteAfterSeconds != null) {
      return Row(
        children: [
          Icon(Icons.alarm_on, size: 16, color: DefaultTheme.backgroundLightColor).pad(r: 4),
          Label(
            Format.durationFormat(Duration(seconds: chatContact?.options?.deleteAfterSeconds)),
            type: LabelType.bodySmall,
            color: DefaultTheme.backgroundLightColor,
          ),
        ],
      ).pad(t: 2);
    } else {
      return Container();
    }
  }
}
