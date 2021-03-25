import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/blocs/channel/channel_bloc.dart';
import 'package:nmobile/blocs/channel/channel_event.dart';
import 'package:nmobile/blocs/channel/channel_state.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
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
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/nkn_image_utils.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/data/group_data_center.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/screens/chat/record_audio.dart';
import 'package:nmobile/screens/settings/channel.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:vibration/vibration.dart';

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
  ChannelBloc _channelBloc;

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

  bool showJoin = true;
  bool isInBlackList = false;

  bool _showAudioInput = false;
  RecordAudio _recordAudio;
  DateTime cTime;
  bool _showAudioLock = false;
  double _audioLockHeight = 90;
  bool _audioLongPressEndStatus = false;

  Topic currentTopic;

  initAsync() async {
    var res =
        await MessageSchema.getAndReadTargetMessages(targetId, limit: _limit);
    if (res != null) {
      setState(() {
        _messages = res;
      });
    }

    _contactBloc.add(LoadContact(
        address:
        res.where((x) => !x.isSendMessage()).map((x) => x.from).toList()));

    if (currentTopic == null) {
      Navigator.pop(context);
      EasyLoading.dismiss();
    }
    refreshTop(currentTopic.topic);
  }

  _refreshSubscribers() async {
    final topic = widget.arguments.topic;
    NLog.w('_refreshSubscribers topic is___'+topic.topic);
    if (topic.isPrivateTopic()) {
      GroupChatPrivateChannel.pullSubscribersPrivateChannel(
          topicName: topic.topic,
          membersBloc: BlocProvider.of<ChannelBloc>(Global.appContext),
          needUploadMetaCallback: (topicName) {
            GroupChatPrivateChannel.uploadPermissionMeta(
              topicName: topicName,
              repoSub: SubscriberRepo(),
              repoBlackL: BlackListRepo(),
            );
          });
    } else {
      NLog.w('11_refreshSubscribers topic is___'+topic.topic);
      GroupDataCenter.pullSubscribersPublicChannel(topic.topic);
    }
  }

  String genTopicHash(String topic) {
    if (topic == null || topic.isEmpty) {
      return null;
    }
    var t = unleadingHashIt(topic);
    return 'dchat' + hexEncode(sha1(t));
  }
  
  refreshTop(String topicName) async {
    if (topicName != null) {
      NLog.w('refreshTop topic Name__' + topicName);
    }
    Topic topic = await GroupChatHelper.fetchTopicInfoByName(topicName);
    if (topic != null){
      if (topic.isPrivateTopic()) {
        NLog.w('Enter Private Topic___'+topicName);
        GroupDataCenter.pullPrivateSubscribers(topic);
      }
      else{
        NLog.w('Enter Public Topic___'+topicName);
        GroupDataCenter.pullSubscribersPublicChannel(topic.topic);
      }
    }
    return;
  }

  Future _loadMore() async {
    var res = await MessageSchema.getAndReadTargetMessages(targetId,
        limit: _limit, skip: _skip);

    if (res == null) {
      return;
    }
    _contactBloc.add(LoadContact(
        address:
            res.where((x) => !x.isSendMessage()).map((x) => x.from).toList()));
    _chatBloc.add(RefreshMessageListEvent(target: targetId));
    if (res != null) {
      _skip += res.length;
      setState(() {
        _messages.addAll(res);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    targetId = widget.arguments.topic.topic;
    Global.currentOtherChatId = targetId;

    currentTopic = widget.arguments.topic;

    _contactBloc = BlocProvider.of<ContactBloc>(context);
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _channelBloc = BlocProvider.of<ChannelBloc>(context);

    _chatBloc.add(RefreshMessageListEvent(target: targetId));
    _channelBloc.add(ChannelMemberCountEvent(currentTopic.topic));

    Future.delayed(Duration(milliseconds: 200), () {
      initAsync();
      _sendFocusNode.addListener(() {
        if (_sendFocusNode.hasFocus) {
          setState(() {
            _showBottomMenu = false;
          });
        }
      });

      _chatSubscription = _chatBloc.listen((state) {
        if (state is MessageUpdateState && mounted) {
          MessageSchema updateMessage = state.message;

          if (updateMessage != null) {
            if (_messages != null && _messages.length > 0) {
              if (updateMessage.contentType == ContentType.receipt) {
                var receiptMessage = _messages.firstWhere(
                    (x) =>
                        x.msgId == updateMessage.content && x.isSendMessage(),
                    orElse: () => null);
                if (receiptMessage != null) {
                  setState(() {
                    receiptMessage
                        .setMessageStatus(MessageStatus.MessageSendReceipt);
                  });
                }
                return;
              }
            }
          }
          else{
            return;
          }

          var receivedMessage = _messages.firstWhere(
              (x) =>
                  x.msgId == updateMessage.msgId && x.isSendMessage() == false,
              orElse: () => null);
          if (receivedMessage != null) {
            receivedMessage.setMessageStatus(MessageStatus.MessageReceived);
            return;
          }

          if (updateMessage.isSendMessage() == false &&
              updateMessage.topic == targetId) {
            _contactBloc.add(LoadContact(address: [updateMessage.from]));

            if (updateMessage.contentType == ContentType.text ||
                updateMessage.contentType == ContentType.textExtension ||
                updateMessage.contentType == ContentType.nknImage ||
                updateMessage.contentType == ContentType.media ||
                updateMessage.contentType == ContentType.nknAudio) {
              updateMessage.messageStatus = MessageStatus.MessageReceived;
              updateMessage.markMessageRead().then((n) {
                updateMessage.messageStatus = MessageStatus.MessageReceivedRead;
                _chatBloc.add(RefreshMessageListEvent());
              });
              setState(() {
                _messages.insert(0, updateMessage);
              });
            }
            if (updateMessage.contentType == ContentType.eventSubscribe) {
              setState(() {
                _messages.insert(0, updateMessage);
              });
            }
          }
        }
      });

      _scrollController.addListener(() {
        double offsetFromBottom = _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels;
        if (offsetFromBottom < 50 && !loading) {
          loading = true;
          _loadMore().then((v) {
            loading = false;
          });
        }
      });

      String content = LocalStorage.getChatUnSendContentFromId(
              NKNClientCaller.currentChatId, targetId) ??
          '';
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
    LocalStorage.saveChatUnSendContentWithId(
        NKNClientCaller.currentChatId, targetId,
        content: _sendController.text);
    _chatBloc.add(RefreshMessageListEvent());
    _chatSubscription?.cancel();
    _scrollController?.dispose();
    _sendController?.dispose();
    _sendFocusNode?.dispose();
    _deleteTick?.cancel();
    refreshSubscribersTimer?.cancel();
    super.dispose();
  }

  _sendText() async {
    LocalStorage.saveChatUnSendContentWithId(
        NKNClientCaller.currentChatId, targetId);
    String text = _sendController.text;
    if (text == null || text.length == 0) return;
    _sendController.clear();
    _canSend = false;

    String dest = targetId;

    String contentType = ContentType.text;
    Duration deleteAfterSeconds;

    var sendMsg = MessageSchema.fromSendData(
        from: NKNClientCaller.currentChatId,
        topic: dest,
        content: text,
        contentType: contentType,
        deleteAfterSeconds: deleteAfterSeconds);
    try {
      _chatBloc.add(SendMessageEvent(sendMsg));
      setState(() {
        _messages.insert(0, sendMsg);
      });
    } catch (e) {
      if (e != null) {
        NLog.w('_sendText E' + e.toString());
      }
    }
  }

  _sendAudio(File audioFile, double audioDuration) async {
    String dest = targetId;

    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      topic: dest,
      content: audioFile,
      contentType: ContentType.nknAudio,
      audioFileDuration: audioDuration,
    );
    try {
      setState(() {
        _messages.insert(0, sendMsg);
      });
      _chatBloc.add(SendMessageEvent(sendMsg));
    } catch (e) {
      if (e != null) {
        NLog.w('_sendAudio E:' + e.toString());
      }
    }
  }

  _sendImage(File savedImg) async {
    String dest = targetId;

    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      topic: dest,
      content: savedImg,
      contentType: ContentType.media,
    );
    try {
      _chatBloc.add(SendMessageEvent(sendMsg));
      setState(() {
        _messages.insert(0, sendMsg);
      });
    } catch (e) {
      NLog.w('Send Image Message E:' + e.toString());
    }
  }

  getImageFile({@required ImageSource source}) async {
    FocusScope.of(context).requestFocus(FocusNode());
    try {
      File image =
          await getCameraFile(NKNClientCaller.currentChatId, source: source);
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
    List<Widget> topicWidget = [
      Label(widget.arguments.topic.topicShort, type: LabelType.h3, dark: true)
    ];
    if (widget.arguments.topic.isPrivateTopic()) {
      topicWidget.insert(
          0,
          loadAssetIconsImage('lock',
                  width: 18, color: DefaultTheme.fontLightColor)
              .pad(r: 2));
    }
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            Navigator.of(context)
                .pushNamed(ChannelSettingsScreen.routeName,
                    arguments: widget.arguments.topic)
                .then((v) {
              if (v == true) {
                Navigator.of(context).pop(true);
                EasyLoading.dismiss();
              }
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
                      child: Container(
                        child: CommonUI.avatarWidget(
                          radiusSize: 24,
                          topic: widget.arguments.topic,
                        ),
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
                      BlocBuilder<ChannelBloc, ChannelState>(
                          builder: (context, state) {
                        if (state is ChannelMembersState) {
                          if (state.memberCount != null &&
                              state.topicName == targetId) {
                            _topicCount = state.memberCount;
                          }
                        }
                        return Label(
                          '${(_topicCount == null || _topicCount < 0) ? '--' : _topicCount} ' +
                              NL10ns.of(context).members,
                          type: LabelType.bodySmall,
                          color: DefaultTheme.riseColor,
                        ).pad(
                            l: widget.arguments.topic.isPrivateTopic()
                                ? 20
                                : 0);
                      })
                    ],
                  ),
                )
              ]),
        ),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: FlatButton(
          onPressed: () {
            Navigator.of(context).pushNamed(ChannelMembersScreen.routeName,
                arguments: widget.arguments.topic);
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
                      padding:
                          const EdgeInsets.only(left: 12, right: 16, top: 4),
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        controller: _scrollController,
                        itemCount: _messages.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int index) {
                          var message = _messages[index];

                          String fromShow = '';

                          bool showTime;
                          bool hideHeader = false;
                          if (index + 1 >= _messages.length) {
                            showTime = true;
                          } else {
                            var preMessage = index == _messages.length
                                ? message
                                : _messages[index + 1];
                            if (preMessage.contentType == ContentType.text ||
                                preMessage.contentType ==
                                    ContentType.nknImage ||
                                preMessage.contentType == ContentType.media ||
                                preMessage.contentType ==
                                    ContentType.nknAudio) {
                              showTime = (message.timestamp.isAfter(preMessage
                                  .timestamp
                                  .add(Duration(minutes: 3))));
                            } else {
                              showTime = true;
                            }
                          }

                          if (!showTime) {
                            if (index == _messages.length) {
                              hideHeader = false;
                            } else {
                              var preMessage = _messages[index + 1];
                              if (preMessage.contentType == ContentType.text ||
                                  preMessage.contentType == ContentType.media ||
                                  preMessage.contentType ==
                                      ContentType.nknAudio ||
                                  preMessage.contentType ==
                                      ContentType.nknImage) {
                                if (message.from == preMessage.from) {
                                  hideHeader = true;
                                }
                              }
                            }
                          }
                          return BlocBuilder<ContactBloc, ContactState>(
                              builder: (context, state) {
                            ContactSchema contact;
                            if (state is ContactLoaded) {
                              if (contact == null) {
                                contact =
                                    state.getContactByAddress(message.from);
                                if (message.from != null &&
                                    message.from.length > 6) {
                                  fromShow = message.from.substring(0, 6);
                                }
                              } else {
                                fromShow = contact.getShowName;
                              }
                            }
                            if (message.contentType ==
                                ContentType.eventSubscribe) {
                              return ChatSystem(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Label(
                                        '${message.isSendMessage() ? NL10ns.of(context).you : fromShow} ${NL10ns.of(context).joined_channel}'),
                                  ],
                                ),
                              );
                            } else if (message.contentType ==
                                ContentType.eventUnsubscribe) {
                              return Container();
                            } else {
                              if (message.isSendMessage()) {
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
                                      _sendController.text =
                                          _sendController.text + ' @$v ';
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
                  _audioInputWidget(),
                  _pictureWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuWidget() {
    double audioHeight = 65;
    if (_showAudioInput == true) {
      if (_recordAudio == null) {
        _recordAudio = RecordAudio(
          height: audioHeight,
          margin: EdgeInsets.only(top: 15, bottom: 15, right: 0),
          startRecord: startRecord,
          stopRecord: stopRecord,
          cancelRecord: _cancelRecord,
        );
      }
      return Container(
        height: audioHeight,
        margin: EdgeInsets.only(top: 15, right: 0),
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
              margin:
              const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
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

  Widget _voiceAndSendWidget() {
    if (_canSend) {
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
              _sendText();
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

  Widget _voiceWidget() {
    return Container(
      width: 50,
      height: 50,
      margin: EdgeInsets.only(right: 0),
      child: ButtonIcon(
        width: 50,
        height: 50,
        icon: loadAssetIconsImage(
          'microphone',
          color: DefaultTheme.primaryColor,
          width: 24,
        ),
        onPressed: () {
          _voiceAction();
        },
      ),
    );
  }

  Widget _bottomMenuWidget() {
    return Expanded(
        flex: 0,
        child: ExpansionLayout(
          isExpanded: _showBottomMenu,
          child: Container(
            padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: DefaultTheme.backgroundColor2),
              ),
            ),
            child: _pictureWidget(),
          ),
        ));
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
                  if (mounted) {
                    setState(() {
                      _canSend = val.isNotEmpty;
                    });
                  }
                },
                style: TextStyle(fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  hintText: NL10ns.of(context).type_a_message,
                  contentPadding:
                  EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                  border: UnderlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.w)),
                    borderSide:
                    const BorderSide(width: 0, style: BorderStyle.none),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioInputWidget(){
    double wWidth = MediaQuery.of(context).size.width;
    return Container(
      height: 90,
      margin: EdgeInsets.only(bottom: 0),
      child: GestureDetector(
        child: _menuWidget(),
        onTapUp: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          setState(() {
            _showAudioLock = false;
            if (afterSeconds > 1) {
              /// send AudioMessage Here
              NLog.w('Audio record less than 1s' +
                  afterSeconds.toString());
            } else {
              /// add viberation Here
              _showAudioInput = false;
            }
          });
        },
        onLongPressStart: (details) {
          cTime = DateTime.now();
          _showAudioLock = false;
          Vibration.vibrate();
          _setAudioInputOn(true);
        },
        onLongPressEnd: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          setState(() {
            if (details.globalPosition.dx < (wWidth - 80)){
              if (_recordAudio != null) {
                _recordAudio.cancelCurrentRecord();
                _recordAudio.cOpacity = 1;
              }
            }
            else{
              if (_recordAudio.showLongPressState == false) {

              } else {
                _recordAudio.stopAndSendAudioMessage();
              }
            }
            if (afterSeconds > 0.2 &&
                _recordAudio.cOpacity > 0) {
            } else {
              _showAudioInput = false;
            }
            if (_showAudioLock) {
              _showAudioLock = false;
            }
          });
        },
        onLongPressMoveUpdate: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          if (afterSeconds > 0.2) {
            setState(() {
              _showAudioLock = true;
            });
          }
          if (details.globalPosition.dx >
              (wWidth) / 3 * 2 &&
              details.globalPosition.dx < wWidth - 80) {
            double cX = details.globalPosition.dx;
            double tW = wWidth - 80;
            double mL = (wWidth) / 3 * 2;
            double tL = tW - mL;
            double opacity = (cX - mL) / tL;
            if (opacity < 0) {
              opacity = 0;
            }
            if (opacity > 1) {
              opacity = 1;
            }

            setState(() {
              _recordAudio.cOpacity = opacity;
            });
          } else if (details.globalPosition.dx > wWidth - 80) {
            setState(() {
              _recordAudio.cOpacity = 1;
            });
          }
          double gapHeight = 90;
          double tL = 50;
          double mL = 60;
          if (details.globalPosition.dy >
              MediaQuery.of(context).size.height -
                  (gapHeight + tL) &&
              details.globalPosition.dy <
                  MediaQuery.of(context).size.height -
                      gapHeight) {
            setState(() {
              double currentL = (tL -
                  (MediaQuery.of(context).size.height -
                      details.globalPosition.dy -
                      gapHeight));
              _audioLockHeight = mL + currentL - 10;
              if (_audioLockHeight < mL) {
                _audioLockHeight = mL;
              }
            });
          }
          if (details.globalPosition.dy <
              MediaQuery.of(context).size.height -
                  (gapHeight + tL)) {
            setState(() {
              _audioLockHeight = mL;
              _recordAudio.showLongPressState = false;
              _audioLongPressEndStatus = true;
            });
          }
          if (details.globalPosition.dy >
              MediaQuery.of(context).size.height -
                  (gapHeight)) {
            _audioLockHeight = 90;
          }
        },
        onHorizontalDragEnd: (details) {
          _cancelAudioRecord();
        },
        onHorizontalDragCancel: () {
          _cancelAudioRecord();
        },
        onVerticalDragCancel: () {
          _cancelAudioRecord();
        },
        onVerticalDragEnd: (details) {
          _cancelAudioRecord();
        },
      ),
    );
  }

  _cancelAudioRecord() {
    if (_audioLongPressEndStatus == false) {
      if (_recordAudio != null) {
        _recordAudio.cancelCurrentRecord();
      }
    }
    setState(() {
      _showAudioLock = false;
    });
  }

  _setAudioInputOn(bool audioInputOn) {
    setState(() {
      if (audioInputOn) {
        _showAudioInput = true;
      } else {
        _showAudioInput = false;
      }
    });
  }

  _voiceAction() {
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

  stopRecord(String path, double audioTimeLength) async {
    NLog.w('stopRecord called');
    _setAudioInputOn(false);

    File audioFile = File(path);
    if (!audioFile.existsSync()) {
      audioFile.createSync();
      audioFile = File(path);
    }
    int fileLength = await audioFile.length();

    if (fileLength != null && audioTimeLength != null) {
      NLog.w('Record finished with fileLength__' +
          fileLength.toString() +
          'audioTimeLength is__' +
          audioTimeLength.toString());
    }
    if (fileLength == 0) {
      showToast('Record file wrong.Please record again.');
      return;
    }
    if (audioTimeLength > 1.0) {
      _sendAudio(audioFile, audioTimeLength);
    }
  }

  Widget _pictureWidget() {
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8))),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8))),
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

  // getBottomMenuView() {
  //   return ExpansionLayout(
  //     isExpanded: _showBottomMenu,
  //     child: Container(
  //       padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
  //       decoration: BoxDecoration(
  //         border: Border(
  //           top: BorderSide(color: DefaultTheme.backgroundColor2),
  //         ),
  //       ),
  //       child: Flex(
  //         direction: Axis.horizontal,
  //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //         children: <Widget>[
  //           Expanded(
  //             flex: 0,
  //             child: Column(
  //               children: <Widget>[
  //                 SizedBox(
  //                   width: 71,
  //                   height: 71,
  //                   child: FlatButton(
  //                     color: DefaultTheme.backgroundColor1,
  //                     shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.all(Radius.circular(8))),
  //                     child: loadAssetIconsImage(
  //                       'image',
  //                       width: 32,
  //                       color: DefaultTheme.fontColor2,
  //                     ),
  //                     onPressed: () {
  //                       getImageFile(source: ImageSource.gallery);
  //                     },
  //                   ),
  //                 ),
  //                 Padding(
  //                   padding: const EdgeInsets.only(top: 8),
  //                   child: Label(
  //                     NL10ns.of(context).pictures,
  //                     type: LabelType.bodySmall,
  //                     color: DefaultTheme.fontColor2,
  //                   ),
  //                 )
  //               ],
  //             ),
  //           ),
  //           Expanded(
  //             flex: 0,
  //             child: Column(
  //               children: <Widget>[
  //                 SizedBox(
  //                   width: 71,
  //                   height: 71,
  //                   child: FlatButton(
  //                     color: DefaultTheme.backgroundColor1,
  //                     shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.all(Radius.circular(8))),
  //                     child: loadAssetIconsImage(
  //                       'camera',
  //                       width: 32,
  //                       color: DefaultTheme.fontColor2,
  //                     ),
  //                     onPressed: () {
  //                       getImageFile(source: ImageSource.camera);
  //                     },
  //                   ),
  //                 ),
  //                 Padding(
  //                   padding: const EdgeInsets.only(top: 8),
  //                   child: Label(
  //                     NL10ns.of(context).camera,
  //                     type: LabelType.bodySmall,
  //                     color: DefaultTheme.fontColor2,
  //                   ),
  //                 )
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  getBottomView() {
    if (showJoin == false) {
      return Button(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Label(NL10ns.of(context).subscribe_or_waiting, type: LabelType.h3)
          ],
        ),
        backgroundColor: DefaultTheme.primaryColor,
        width: double.infinity,
        onPressed: () {
          if (isInBlackList) {
            // TODO:
          } else {
            EasyLoading.show();
            NLog.w('GroupChat getBottomView on called');
            GroupChatHelper.subscribeTopic(
                topicName: widget.arguments.topic.topic,
                chatBloc: _chatBloc,
                callback: (success, e) {
                  if (success) {
                    NLog.w('getBottomView joinChannel success');
                  }
                  EasyLoading.dismiss();
                  refreshTop(widget.arguments.topic.topic);
                  if (!success && e != null) {
                    showToast('channel subscribe failed');
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
              icon: loadAssetIconsImage('grid',
                  width: 24, color: DefaultTheme.primaryColor),
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
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                      hintText: NL10ns.of(context).type_a_message,
                      border: UnderlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.w)),
                        borderSide:
                            const BorderSide(width: 0, style: BorderStyle.none),
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
                color: _canSend
                    ? DefaultTheme.primaryColor
                    : DefaultTheme.fontColor2,
              ),
              //disabled: !_canSend,
              onPressed: () {
                _sendText();
              },
            ),
          ),
        ),
      ],
    );
  }
}
