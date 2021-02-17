import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
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
import 'package:nmobile/screens/chat/record_audio.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:vibration/vibration.dart';

class ChatSinglePage extends StatefulWidget {
  static const String routeName = '/chat/message';

  final ChatSchema arguments;

  ChatSinglePage({this.arguments});

  @override
  _ChatSinglePageState createState() => _ChatSinglePageState();
}

class _ChatSinglePageState extends State<ChatSinglePage>{
  /// block provider
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
  bool _showAudioInput = false;
  Timer _deleteTick;

  bool _acceptNotification = false;
  Color notiBellColor;
  static const fcmGapString = '__FCMToken__:';

  RecordAudio _recordAudio;
  DateTime cTime;
  bool _showAudioLock = false;

  double _audioLockHeight = 90;
  bool _audioLongPressEndStatus = false;

  TimerAuth timerAuth;

  ContactSchema chatContact;

  Future _loadMore() async {
    NLog.w('ChatMessage _loadMore called');
    var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit, skip: _skip);
    _chatBloc.add(RefreshMessageListEvent(target: targetId));
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
            item.deleteMessage();
            return true;
          } else {
            return false;
          }
        } else {
          return false;
        }
      });
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();

    chatContact = widget.arguments.contact;
    targetId = chatContact.clientAddress;

    if (chatContact.notificationOpen == null){
      chatContact.setNotificationOpen(false);
      _acceptNotification = false;
    }
    else{
      _acceptNotification = chatContact.notificationOpen;
    }
    Global.currentOtherChatId = targetId;

    _sendFocusNode.addListener(() {
      if (_sendFocusNode.hasFocus) {
        setState(() {
          _showBottomMenu = false;
        });
      }
    });

    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _chatBloc.add(UpdateChatEvent(targetId));

    _deleteTickHandle();

    _chatSubscription = _chatBloc.listen((state) {
      if (state is UpdateChatMessageState){
        if (state.messageList.isNotEmpty){
          setState(() {
            _messages = state.messageList;
          });
        }
      }
      if (state is MessageUpdateState) {
        MessageSchema updateMessage = state.message;
        if (updateMessage == null || updateMessage.topic != null) {
          return;
        }

        if (updateMessage.contentType == ContentType.receipt){
          if (_messages != null && _messages.length > 0) {
            var msg = _messages.firstWhere((x) => x.msgId == updateMessage.content.toString() && x.isSendMessage(), orElse: () => null);
            if (msg != null) {
              setState(() {
                msg.messageStatus = MessageStatus.MessageSendReceipt;
                if (state.message.deleteTime != null) {
                  msg.deleteTime = state.message.deleteTime;
                }
              });
            }
          }
        }
        if (updateMessage.isSendMessage()){
          if (updateMessage.contentType == ContentType.eventContactOptions) {
            var receivedMessage = _messages.firstWhere((x) =>
            x.msgId == updateMessage.msgId,
                orElse: () => null);
            if (receivedMessage == null) {
              setState(() {
                NLog.w('SingleChat MessageUpdateState duplicate');
              });
              setState(() {
                _messages.insert(0, updateMessage);
              });
              return;
            }
          }
        }
        else {
          if (updateMessage.from == targetId){
            if (updateMessage.contentType == ContentType.text ||
                updateMessage.contentType == ContentType.textExtension ||
                updateMessage.contentType == ContentType.nknImage ||
                updateMessage.contentType == ContentType.media ||
                updateMessage.contentType == ContentType.nknAudio ||
                updateMessage.contentType == ContentType.channelInvitation ||
                updateMessage.contentType == ContentType.eventContactOptions){

              if (updateMessage.contentType == ContentType.textExtension ||
                  updateMessage.contentType == ContentType.nknImage ||
                  updateMessage.contentType == ContentType.media ||
                  updateMessage.contentType == ContentType.nknAudio){
                if (state.message.options != null && state.message.options['deleteAfterSeconds'] != null) {
                  state.message.deleteTime = DateTime.now().add(Duration(seconds: state.message.options['deleteAfterSeconds'] + 1));
                }
              }

              setState(() {
                _messages.insert(0, updateMessage);
              });

              updateMessage.setMessageStatus(MessageStatus.MessageReceived);
              updateMessage.markMessageRead().then((value) {
                _chatBloc.add(RefreshMessageListEvent());
                updateMessage.setMessageStatus(MessageStatus.MessageReceivedRead);
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
      String content = LocalStorage.getChatUnSendContentFromId(NKNClientCaller.currentChatId, targetId) ?? '';
      setState(() {
        _sendController.text = content;
        _canSend = content.length > 0;
      });
    });
  }

  @override
  void dispose() {
    Global.currentOtherChatId = null;
    LocalStorage.saveChatUnSendContentWithId(NKNClientCaller.currentChatId, targetId, content: _sendController.text);
    _chatBloc.add(RefreshMessageListEvent());
    _chatSubscription?.cancel();
    _scrollController?.dispose();
    _sendController?.dispose();
    _sendFocusNode?.dispose();
    _deleteTick?.cancel();

    super.dispose();
  }

  _sendAction() async {
    if (_sendFocusNode.hasFocus){
      /// do nothing
    }
    else{
      setState(() {
        // _showInputText = true;
        Timer(Duration(milliseconds: 200), () async {
          FocusScope.of(context).requestFocus(_sendFocusNode);
        });
      });
    }
    LocalStorage.saveChatUnSendContentWithId(NKNClientCaller.currentChatId, targetId);
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
      try {
        _addMessageToList(sendMsg);
      } catch (e) {
        showToast('Wrong!!! sendMsg E:'+e.toString());
        NLog.w('Send Message E:'+e.toString());
      }
    }
  }

  _sendAudio(File audioFile,double audioDuration) async{
    String dest = targetId;
    Duration deleteAfterSeconds;
    if (chatContact?.options != null) {
      if (chatContact?.options?.deleteAfterSeconds != null)
        deleteAfterSeconds = Duration(seconds: chatContact.options.deleteAfterSeconds);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: dest,
      content: audioFile,
      contentType: ContentType.nknAudio,
      audioFileDuration: audioDuration,
      deleteAfterSeconds: deleteAfterSeconds,
    );
    try {
      _addMessageToList(sendMsg);
    } catch (e) {
      NLog.w('Send AudioMessage E:'+e.toString());
    }
  }

  _addMessageToList(MessageSchema sendMsg) async{
    if (mounted){
      setState(() {
        _messages.insert(0, sendMsg);
      });
    }
    _chatBloc.add(SendMessageEvent(sendMsg));

    String savedKey = LocalStorage.NKN_MESSAGE_NOTIFICATION_ALERT+':'+targetId.toString();
    /// No Alert of Notification2Open before
    print('LocalKey is___'+savedKey);

    if (_messages.length > 0){
      String isNotificationOpenAlert = await LocalStorage().get(savedKey);
      if (isNotificationOpenAlert == null && _acceptNotification == false){
        _judgeIfAlertOpenNotification();
      }
    }
  }

  _judgeIfAlertOpenNotification(){
    int sendCount = 0;
    int receiveCount = 0;
    for (MessageSchema message in _messages){
      if (message.isSendMessage()){
        sendCount++;
      }
      else{
        receiveCount++;
      }
    }

    if (sendCount >= 3 && receiveCount >= 3){
      SimpleConfirm(
        context: context,
        buttonColor: DefaultTheme.primaryColor,
        content: 'Send your device token to him?\nThen he can send you remote notification!',
        callback: (b) {
          if (b) {
            _acceptNotification = true;
            _saveAndSendDeviceToken();
          }
          String savedKey = LocalStorage.NKN_MESSAGE_NOTIFICATION_ALERT+':'+targetId.toString();
          LocalStorage().set(savedKey, 'YES');
        },
        buttonText: NL10ns.of(context).ok,
      ).show();
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
    try {
      _addMessageToList(sendMsg);
    } catch (e) {
      NLog.w('Send Image Message E:'+e.toString());
    }
  }

  getImageFile({@required ImageSource source}) async {
    FocusScope.of(context).requestFocus(FocusNode());
    try {
      File image = await getCameraFile(NKNClientCaller.currentChatId, source: source);
      if (image != null) {
        _sendImage(image);
      }
    } catch (e) {
      NLog.w('message.dart getImageFile E:'+e.toString());
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
    deviceToken = await NKNClientCaller.fetchDeviceToken();
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
    sendMsg.deviceToken = deviceToken;
    sendMsg.content = sendMsg.toContactNoticeOptionData();

    _addMessageToList(sendMsg);
  }

  @override
  Widget build(BuildContext context) {
    notiBellColor = DefaultTheme.primaryColor;
    if (_acceptNotification == false){
      notiBellColor = Colors.white38;
    }
    double wWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            _pushToContactSettingPage();
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
              _pushToContactSettingPage(),
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
              child: Stack(
                children: [
                  Flex(
                    direction: Axis.vertical,
                    children: <Widget>[
                      _messageList(),
                      Container(
                        height: 90,
                        margin: EdgeInsets.only(bottom: 0),
                        child: GestureDetector(
                          child: _menuWidget(),
                          onTapUp: (details) {
                            int afterSeconds = DateTime.now().difference(cTime).inSeconds;
                            setState(() {
                              _showAudioLock = false;
                              if (afterSeconds > 1){
                                /// send AudioMessage Here
                                NLog.w('Audio record less than 1s'+afterSeconds.toString());
                              }
                              else{
                                /// add viberation Here
                                _showAudioInput = false;
                              }
                              // _recordAudio.showLongPressState = false;
                            });
                          },
                          onLongPressStart: (details) {
                            cTime = DateTime.now();
                            _showAudioLock = false;
                            Vibration.vibrate();
                            _setAudioInputOn(true);
                          },
                          onLongPressEnd: (details) {
                            int afterSeconds = DateTime.now().difference(cTime).inSeconds;
                            setState(() {
                              if (afterSeconds > 0.2 && _recordAudio.cOpacity > 0){
                                if (_recordAudio.showLongPressState == false){

                                }
                                else{
                                  _recordAudio.stopAndSendAudioMessage();
                                }
                              }
                              else{
                                _showAudioInput = false;
                              }
                              if (_showAudioLock){
                                _showAudioLock = false;
                              }
                            });
                          },
                          onLongPressMoveUpdate: (details) {
                            int afterSeconds = DateTime.now().difference(cTime).inSeconds;
                            if (afterSeconds > 0.2){
                              setState(() {
                                _showAudioLock = true;
                              });
                            }
                            if (details.globalPosition.dx < (wWidth)/3*2 && details.globalPosition.dx > 0){
                              if (_recordAudio != null){
                                _recordAudio.cancelCurrentRecord();
                                _recordAudio.cOpacity = 1;
                              }
                            }
                            else if (details.globalPosition.dx > (wWidth)/3*2 && details.globalPosition.dx < wWidth-80){
                              double cX = details.globalPosition.dx;
                              double tW = wWidth-80;
                              double mL = (wWidth)/3*2;
                              double tL = tW-mL;
                              double opacity = (cX-mL)/tL;
                              if (opacity < 0){
                                opacity = 0;
                              }
                              if (opacity > 1){
                                opacity = 1;
                              }

                              setState(() {
                                _recordAudio.cOpacity = opacity;
                              });
                            }
                            else if (details.globalPosition.dx > wWidth-80){
                              setState(() {
                                _recordAudio.cOpacity = 1;
                              });
                            }

                            double gapHeight = 90;
                            double tL = 50;
                            double mL = 60;
                            if (details.globalPosition.dy > MediaQuery.of(context).size.height-(gapHeight+tL) && details.globalPosition.dy < MediaQuery.of(context).size.height-gapHeight){
                              setState(() {
                                double currentL = (tL-(MediaQuery.of(context).size.height-details.globalPosition.dy-gapHeight));
                                _audioLockHeight = mL+currentL-10;
                                if (_audioLockHeight < mL) {
                                  _audioLockHeight = mL;
                                }
                              });
                            }
                            if (details.globalPosition.dy < MediaQuery.of(context).size.height-(gapHeight+tL)) {
                              setState(() {
                                _audioLockHeight = mL;
                                _recordAudio.showLongPressState = false;
                                _audioLongPressEndStatus = true;
                              });
                            }
                            if (details.globalPosition.dy > MediaQuery.of(context).size.height-(gapHeight)){
                              _audioLockHeight = 90;
                            }
                          },
                          onHorizontalDragEnd: (details) {
                            _cancelAudioRecord();
                          },
                          onHorizontalDragCancel: (){
                            _cancelAudioRecord();
                          },
                          onVerticalDragCancel: (){
                            _cancelAudioRecord();
                          },
                          onVerticalDragEnd: (details) {
                            _cancelAudioRecord();
                          },
                        ),
                      ),
                      _bottomMenuWidget(),
                    ],
                  ),
                  _audioLockWidget(),
                ],
              )
            ),
          ),
        ),
      ),
    );
  }

  _cancelAudioRecord(){
    if (_audioLongPressEndStatus == false){
      if (_recordAudio != null){
        _recordAudio.cancelCurrentRecord();
      }
    }
    setState(() {
      _showAudioLock = false;
    });
  }

  Widget _audioLockWidget() {
    double wWidth = MediaQuery.of(context).size.width;
    double wHeight = MediaQuery.of(context).size.height;
    if (_showAudioLock){
      return Container(
        color: Colors.transparent,
        width: wWidth,
        height: wHeight,
        child: Column(
          children: [
            Container(
              height: wHeight-(kToolbarHeight+90+100+10+MediaQuery.of(context).padding.top),
            ),
            Container(
              height: _audioLockHeight,
              child: Row(
                children: [
                  Container(
                    height: _audioLockHeight,
                    width: wWidth-45,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    height: _audioLockHeight,
                    // margin: EdgeInsets.only(right: 5,bottom: 160-_autoLockHeight),
                    width: 40,
                    child: Column(
                      children: [
                        Container(
                          margin:EdgeInsets.only(top: 5),
                          child: loadAssetIconsImage('lock', color: Colors.red, width: 20,),
                        ),
                        Spacer(),
                        Container(
                          margin: EdgeInsets.only(bottom: 5,),
                          child: Label(
                            '^',
                            type: LabelType.bodyLarge,
                            fontWeight: FontWeight.normal,
                            color: Colors.red,
                            textAlign: TextAlign.right,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            Container(
              height: 88,
            )
          ],
        )
      );
    }
    return Container(
      color: Colors.transparent,
      width: 0,
      height: 1,
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height-1),
    );
  }

  Widget _messageList() {
    return Expanded(
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
              if (message.contentType == ContentType.text ||
                  message.contentType == ContentType.textExtension ||
                  message.contentType == ContentType.nknImage ||
                  message.contentType == ContentType.media ||
                  message.contentType == ContentType.nknAudio) {

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
    );
  }

  Widget _menuWidget() {
    double audioHeight = 65;
    if (_showAudioInput == true){
      if (_recordAudio == null){
        _recordAudio = RecordAudio(
          height: audioHeight,
          margin: EdgeInsets.only(top: 15, bottom:15, right: 0),
          startRecord:  startRecord,
          stopRecord:  stopRecord,
          cancelRecord: _cancelRecord,
        );
      }
      return Container(
        height: audioHeight,
        margin: EdgeInsets.only(top: 15,right: 0),
        child: _recordAudio,
      );
    }
    return Container(
      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
      child: Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            flex: 0,
            child: Container(
              margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
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
          _sendWidget(),
          _voiceAndSendWidget(),
        ],
      ),
    );
  }

  Widget _bottomMenuWidget() {
    return Expanded(
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
          child:_pictureWidget(),
        ),
      )
    );
  }

  Widget _sendWidget() {
    return Expanded(
      flex: 1,
      child: Container(
        margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
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
    );
  }

  Widget _voiceAndSendWidget(){
    if (_canSend){
      return Expanded(
        flex: 0,
        child: Container(
          margin: EdgeInsets.only(top: 15, bottom: 15),
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: ButtonIcon(
            width: 50,
            height: 50,
            icon: loadAssetIconsImage(
              'send',
              width: 24,
              color: DefaultTheme.primaryColor,
            ),
            onPressed: () {
              _sendAction();
            },
          ),
        ),
      );
    }
    return Expanded(
      flex: 0,
      child: Container(
        margin: EdgeInsets.only(top: 15, bottom: 15),
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: _voiceWidget(),
      ),
    );
  }

  _setAudioInputOn(bool audioInputOn) {
    setState(() {
      if (audioInputOn){
        _showAudioInput = true;
      }
      else{
        _showAudioInput = false;
      }
    });
  }

  Widget _voiceWidget() {
    return Container(
      width: 50,
      height: 50,
      margin: EdgeInsets.only(right: 0),
      child: ButtonIcon(
        width: 50,
        height: 50,
        icon:
        loadAssetIconsImage('microphone', color: DefaultTheme.primaryColor, width: 24,),
        onPressed: () {
          _voiceAction();
        },
      ),
    );
  }

  _voiceAction(){
    _setAudioInputOn(true);
    Vibration.vibrate();
    Timer(Duration(milliseconds: 350), () async {
      _setAudioInputOn(false);
    });
  }

  _cancelRecord() {
    _setAudioInputOn(false);
    Vibration.vibrate();
  }

  startRecord() {
    NLog.w('startRecord called');
  }

  stopRecord(String path, double audioTimeLength) async{
    NLog.w('stopRecord called');
    _setAudioInputOn(false);

    File audioFile = File(path);
    if(!audioFile.existsSync()){
      audioFile.createSync();
      audioFile = File(path);
    }
    int fileLength = await audioFile.length();

    if (fileLength != null && audioTimeLength != null){
      NLog.w('Record finished with fileLength__'+fileLength.toString()+'audioTimeLength is__'+audioTimeLength.toString());
    }

    if (audioTimeLength > 1.0){
      _sendAudio(audioFile,audioTimeLength);
    }
  }

  Widget _pictureWidget(){
    return Flex(
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  _pushToContactSettingPage() {
    Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: chatContact).then((v) {
      _chatBloc.add(UpdateChatEvent(targetId));
    });
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
                        message.isSendMessage() ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label(' ${NL10ns.of(context).update_burn_after_reading}', softWrap: true),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      _pushToContactSettingPage();
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
                        message.isSendMessage() ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label('$deviceDesc'),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      _pushToContactSettingPage();
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
                        message.isSendMessage() ? NL10ns.of(context).you : chatContact.name,
                        fontWeight: FontWeight.bold,
                      ),
                      Label(' ${NL10ns.of(context).close_burn_after_reading}'),
                    ],
                  ).pad(b: 4),
                  InkWell(
                    child: Label(NL10ns.of(context).click_to_change, color: DefaultTheme.primaryColor, type: LabelType.bodyRegular),
                    onTap: () {
                      _pushToContactSettingPage();
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
