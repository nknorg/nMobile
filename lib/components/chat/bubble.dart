import 'dart:async';
import 'dart:io';

import 'package:common_utils/common_utils.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/markdown.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/entity/topic_repo.dart';
import 'package:nmobile/router/custom_router.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/screens/chat/photo_page.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/theme/popup_menu.dart';
import 'package:nmobile/utils/chat_utils.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/nkn_time_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:permission_handler/permission_handler.dart';

enum BubbleStyle { Me, Other, SendError }

class ChatBubble extends StatefulWidget {
  MessageSchema message;
  MessageSchema preMessage;
  ContactSchema contact;
  BubbleStyle style;
  ValueChanged<String> onChanged;
  bool showTime;
  bool hideHeader;

  ChatBubble(
      {this.message,
      this.contact,
      this.onChanged,
      this.preMessage,
      this.showTime = true,
      this.hideHeader = false}) {
    if (message.messageStatus == MessageStatus.MessageReceived ||
        message.messageStatus == MessageStatus.MessageReceivedRead) {
      style = BubbleStyle.Other;
    } else if (message.messageStatus == MessageStatus.MessageSendFail) {
      style = BubbleStyle.SendError;
    } else {
      style = BubbleStyle.Me;
    }
  }

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  GlobalKey popupMenuKey = GlobalKey();
  ChatBloc _chatBloc;

  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  bool _mPlayerIsInited = false;

  String _mPath;
  StreamSubscription _playerSubscription;
  bool audioCellIsPlaying = false;
  double audioProgress = 0.0;
  double audioLeft = 0.0;

  void startPlay() async {
    _mPlayer
        .openAudioSession(
            focus: AudioFocus.requestFocusTransient,
            category: SessionCategory.playAndRecord,
            mode: SessionMode.modeDefault,
            device: AudioDevice.speaker)
        .then((value) {
      if (mounted) {
        setState(() {
          _mPlayerIsInited = true;
          _readyToPlay();
        });
      }
    });
  }

  _readyToPlay() async {
    if (widget.message.audioFileDuration == null) {
      NLog.w('Wrong!!! widget.message.audioFileDuration is null');
      return;
    }

    var status = await Permission.storage.request();
    if (status != PermissionStatus.granted) {
      NLog.w('no auth to storage!!!');
      showToast('open storage permission to this app');
    }

    await _mPlayer.setSubscriptionDuration(Duration(milliseconds: 30));
    _playerSubscription = _mPlayer.onProgress.listen((event) {
      double durationDV = event.duration.inMilliseconds / 1000;
      double currentDV = event.position.inMilliseconds / 1000;

      setState(() {
        if (widget.message.audioFileDuration == null) {
          widget.message.audioFileDuration = durationDV;
          widget.message.options['audioDuration'] =
              NumUtil.getNumByValueDouble(durationDV, 2).toString();
          widget.message.updateMessageOptions();
        }
        double cProgress = currentDV / durationDV + 0.1;
        audioLeft = widget.message.audioFileDuration - currentDV;

        audioLeft = NumUtil.getNumByValueDouble(audioLeft, 2);
        if (audioLeft < 0.0) {
          audioLeft = 0.0;
        }
        if (cProgress > 1) {
          audioProgress = 1;
        } else {
          audioProgress = cProgress;
        }
      });
    });

    File file = File(_mPath);
    if (file.existsSync()) {
      NLog.w('mPlayPath exists__' + _mPath);
    } else {
      NLog.w('mPlayPath does not exists__' + _mPath);
    }
    audioCellIsPlaying = true;

    if (Platform.isAndroid) {
      _mPath = 'file:///' + _mPath;
    }

    await _mPlayer.startPlayer(
        fromURI: _mPath,
        codec: Codec.defaultCodec,
        whenFinished: () {
          if (mounted) {
            setState(() {
              NLog.w('mPlayPath finished:__' + _mPath);
              audioCellIsPlaying = false;
              audioProgress = 0.0;
              audioLeft = widget.message.audioFileDuration;
              _mPlayer.closeAudioSession();
            });
          }
        });
    NLog.w('_mPlayer.startPlayer');
  }

  Future<void> stopPlayer() async {
    await _mPlayer.stopPlayer();
  }

  _textPopupMenuShow() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      maxColumn: 4,
      items: [
        MenuItem(
          userInfo: 0,
          title: NL10ns.of(context).copy,
          textStyle:
              TextStyle(color: DefaultTheme.fontLightColor, fontSize: 12),
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

  @override
  void dispose() {
    if (_mPlayer.isPlaying) {
      _mPlayer.stopPlayer();
    }
    if (_mPlayer.isOpen()) {
      _mPlayer.closeAudioSession();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _chatBloc = BlocProvider.of<ChatBloc>(context);
    audioLeft = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    Widget timeWidget;
    Widget burnWidget = Container();
    String timeFormat =
        NKNTimeUtil.formatChatTime(context, widget.message.timestamp);
    List<Widget> contentsWidget = <Widget>[];
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
            Icon(FontAwesomeIcons.clock,
                    size: 12, color: DefaultTheme.fontLightColor.withAlpha(178))
                .pad(b: 1, r: 4),
            Label(
              Format.timeFromNowFormat(widget.message.deleteTime ??
                  DateTime.now().add(Duration(
                      seconds:
                          widget.message.options['deleteAfterSeconds'] + 1))),
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
            Icon(FontAwesomeIcons.clock,
                    size: 12, color: DefaultTheme.fontColor2)
                .pad(b: 1, r: 4),
            Label(
              Format.timeFromNowFormat(widget.message.deleteTime ??
                  DateTime.now().add(Duration(
                      seconds:
                          widget.message.options['deleteAfterSeconds'] + 1))),
              type: LabelType.bodySmall,
              fontSize: DefaultTheme.iconTextFontSize,
              color: DefaultTheme.fontColor2,
            ),
          ],
        ).pad(t: 1);
      }
    }
    EdgeInsetsGeometry contentPadding = EdgeInsets.zero;

    if (widget.message.contentType == ContentType.channelInvitation) {
      return getChannelInviteView();
    } else if (widget.message.contentType == ContentType.eventSubscribe) {
      return Container();
    }

    if (widget.message.contentType == ContentType.nknAudio) {
      if (widget.message.audioFileDuration == null) {
        widget.message.audioFileDuration = 0.0;
      }
      setState(() {
        audioLeft = widget.message.audioFileDuration;
        audioLeft = NumUtil.getNumByValueDouble(audioLeft, 2);
        if (audioLeft < 0) {
          audioLeft = 0.0;
        }
      });
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
                  style: TextStyle(
                      height: 1.15,
                      color: Color(DefaultTheme.headerColor2),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold)));
            } else {
              if (widget.style == BubbleStyle.Me) {
                children.add(TextSpan(
                    text: s,
                    style: TextStyle(
                        color: DefaultTheme.fontLightColor, height: 1.25)));
              } else {
                children.add(TextSpan(
                    text: s,
                    style: TextStyle(
                        color: DefaultTheme.fontColor1, height: 1.25)));
              }
            }
          }
          contentsWidget.add(
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
          contentsWidget.add(
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
        contentsWidget.add(
          Padding(
            padding: contentPadding,
            child: Markdown(
              data: widget.message.content,
              dark: dark,
            ),
          ),
        );
        break;
      case ContentType.nknImage:
      case ContentType.media:
        popupMenu = () {};
        String path = (widget.message.content as File).path;
        contentsWidget.add(
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
      case ContentType.nknAudio:
        popupMenu = () {};
        contentsWidget.add(
          InkWell(
            onTap: () {
              if (audioCellIsPlaying) {
                _stopPlayAudio();
              } else {
                _playAudio();
              }
            },
            child: Container(
                child: Stack(
              children: [
                Row(
                  children: [
                    _playWidget(),
                    Spacer(),
                    Label('$audioLeft\"' + ''),
                  ],
                ),
                _progressWidget(),
              ],
            )),
          ),
        );
    }

    if (widget.message.options != null &&
        widget.message.options['deleteAfterSeconds'] != null) {
      if (widget.message.messageStatus != MessageStatus.MessageSendFail){
        contentsWidget.add(burnWidget);
      }
    }

    if (contentsWidget.isEmpty) {
      contentsWidget.add(Space.empty);
    }

    double bOpacity = 0.4;
    if (widget.message.messageStatus == MessageStatus.MessageSendReceipt ||
        widget.message.messageStatus == MessageStatus.MessageReceived ||
        widget.message.messageStatus == MessageStatus.MessageReceivedRead) {
      bOpacity = 1.0;
    }

    if (widget.contact != null) {
      List<Widget> contents = <Widget>[
        GestureDetector(
          key: popupMenuKey,
          onTap: popupMenu,
          child: Opacity(
            opacity: bOpacity,
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
                          widget.contact.getShowName,
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
                        children: contentsWidget,
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
              padding: EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  if (!widget.hideHeader) {
                    Navigator.of(context).pushNamed(ContactScreen.routeName,
                        arguments: widget.contact);
                  }
                },
                onLongPress: () {
                  if (!widget.hideHeader) {
                    widget.onChanged(widget.contact.getShowName);
                  }
                },
                child: Opacity(
                    opacity: !widget.hideHeader ? 1.0 : 0.0,
                    child: CommonUI.avatarWidget(
                      radiusSize: 24,
                      contact: widget.contact,
                    )),
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
                  opacity: bOpacity,
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: decoration,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 272.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: contentsWidget,
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

  Widget _progressWidget() {
    Color bgColor = Colors.blue;
    if (widget.style == BubbleStyle.Me) {
      bgColor = Color(0xFFF5F5DC);
    }
    return Container(
      child: Container(
        margin: EdgeInsets.only(left: 45, top: 10, right: 60),
        child: LinearProgressIndicator(
          minHeight: 10,
          backgroundColor: bgColor,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          value: audioProgress,
        ),
      ),
    );
  }

  Widget _playWidget() {
    if (audioCellIsPlaying) {
      return Container(
          // margin: EdgeInsets.only(left: 10,top: 10,right: 10),
          // height: 40,
          child: Icon(
        FontAwesomeIcons.pauseCircle,
        size: 30,
      ));
    }
    return Container(
        // margin: EdgeInsets.only(left: 10,top: 10,right: 10),
        // height: 40,
        child: Icon(
      FontAwesomeIcons.playCircle,
      size: 30,
    ));
  }

  _playAudio() {
    _mPath = (widget.message.content as File).path;

    bool isOpen = _mPlayer.isOpen();
    if (isOpen == false) {
      startPlay();
      return;
    }
    if (_mPlayer.isPaused) {
      _mPlayer.startPlayer();
      return;
    }
    if (_mPlayer.isPlaying) {
      return;
    }
    setState(() {
      audioCellIsPlaying = true;
    });
  }

  _stopPlayAudio() async {
    audioCellIsPlaying = false;
    await _mPlayer.pausePlayer();
    await _mPlayer.closeAudioSession();
  }

  getChannelInviteView() {
    Topic topicSpotName = Topic.spotName(name: widget.message.content);

    String inviteDesc = NL10ns.of(context).invites_desc_me(widget.message.from.substring(0, 6));
    if (widget.style == BubbleStyle.Me){
      inviteDesc = NL10ns.of(context)
          .invites_desc_other(widget.message.to.substring(0, 6));
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Column(
            children: [
              Label(inviteDesc,
                  type: LabelType.bodyRegular, color: Colours.dark_2d),
              Label(topicSpotName.topicShort,
                  type: LabelType.bodyRegular, color: Colours.blue_0f)
            ],
          ),
          SizedBox(width: 5),
          widget.style == BubbleStyle.Me
              ? Space.empty
              : InkWell(
                  onTap: () async {
                    final topicName = widget.message.content;
                    BottomDialog.of(Global.appContext).showAcceptDialog(
                        title: NL10ns.of(context).accept_invitation,
                        subTitle: inviteDesc,
                        content: topicName,
                        onPressed: () =>
                            _joinChannelByName(topicSpotName, topicName));
                  },
                  child: Label(
                    NL10ns.of(context).accept,
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                    color: DefaultTheme.primaryColor,
                  ),
                )
        ],
      ),
    );
  }

  _joinChannelByName(Topic theTopic, String topicName) async{
    EasyLoading.show();
    int blockHeight = await NKNClientCaller.fetchBlockHeight();
    NLog.w('blockHeight is+____'+blockHeight.toString());
    NLog.w('theTopic.blockHeightExpireAt is+____'+theTopic.blockHeightExpireAt.toString());
    if (theTopic.blockHeightExpireAt != null && theTopic.blockHeightExpireAt > 0 && theTopic.blockHeightExpireAt-blockHeight > 100000){
      showToast(NL10ns.of(context).group_member_already);
      return;
    }
    GroupChatHelper.subscribeTopic(
        topicName: topicName,
        chatBloc: _chatBloc,
        callback: (success, e) {
          EasyLoading.dismiss();
          if (success) {
            showToast(NL10ns().subscribed);
            Navigator.pop(context);
          } else {
            if (e
                .toString()
                .contains('duplicate subscription exist in block')) {
              NLog.w('duplicate subscription exist in block');
              showToast('Joining');
            } else {
              showToast(e.toString());
            }
          }
        });
  }
}

class LCPainter extends CustomPainter {
  final double amplitude;
  final int number;
  LCPainter({this.amplitude = 100.0, this.number = 20});
  @override
  void paint(Canvas canvas, Size size) {
    var centerY = 20.0;
    var width = (ScreenUtil.screenWidth - 200) / number;

    for (var a = 0; a < 4; a++) {
      var path = Path();
      path.moveTo(0.0, centerY);
      var i = 0;
      while (i < number) {
        path.cubicTo(width * i, centerY, width * (i + 1),
            centerY + amplitude - a * (20), width * (i + 2), centerY);
        path.cubicTo(width * (i + 2), centerY, width * (i + 3),
            centerY - amplitude + a * (20), width * (i + 4), centerY);
        i = i + 4;
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = a == 0 ? Colors.green : Colors.lightGreen.withAlpha(50)
            ..strokeWidth = a == 0 ? 3.0 : 2.0
            ..maskFilter = MaskFilter.blur(
              BlurStyle.solid,
              5,
            )
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
