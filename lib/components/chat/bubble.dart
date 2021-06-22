import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/text/markdown.dart';
import 'package:nmobile/components/tip/popup_menu.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/services/task.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/chat.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../text/markdown.dart';

class ChatBubble extends BaseStateFulWidget {
  final MessageSchema message;
  final ContactSchema? contact;
  final bool showProfile;
  final Function(ContactSchema, MessageSchema)? onLonePress;
  final Function(String)? onResend;

  ChatBubble({
    required this.message,
    required this.contact,
    this.showProfile = false,
    this.onLonePress,
    this.onResend,
  });

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends BaseStateFulWidgetState<ChatBubble> with Tag {
  GlobalKey _contentKey = GlobalKey();
  StreamSubscription? _onPieceOutStreamSubscription;
  StreamSubscription? _onPlayStateChangedSubscription;
  StreamSubscription? _onPlayPositionChangedSubscription;

  late MessageSchema _message;
  ContactSchema? _contact;
  late int _msgStatus;

  double _uploadProgress = 1;

  PlayerState _playState = PlayerState.STOPPED;
  double _playProgress = 0;

  @override
  void initState() {
    super.initState();
    // pieces
    _onPieceOutStreamSubscription = chatOutCommon.onPieceOutStream.listen((Map<String, dynamic> event) {
      String? msgId = event["msg_id"];
      double? percent = event["percent"];
      if (msgId == null || msgId != this._message.msgId || percent == null || _msgStatus != MessageStatus.Sending || !(_message.content is File)) {
        // logger.d("onPieceOutStream - percent:$percent - send_msgId:$msgId - receive_msgId:${this._message.msgId}");
        if (_uploadProgress != 1) {
          setState(() {
            _uploadProgress = 1;
          });
        }
        return;
      }
      if (_uploadProgress >= 1 || percent <= _uploadProgress) return;
      this.setState(() {
        _uploadProgress = percent;
      });
    });
    // player
    _onPlayStateChangedSubscription = audioHelper.onPlayStateChangedStream.listen((Map<String, dynamic> event) {
      String? playerId = event["id"];
      PlayerState? state = event["state"];
      if (playerId == null || playerId != this._message.msgId || state == null) {
        if (_playState != PlayerState.STOPPED) {
          setState(() {
            _playState = PlayerState.STOPPED;
            _playProgress = 0;
          });
        }
        return;
      }
      if (state == _playState) return;
      this.setState(() {
        _playState = state;
        _playProgress = 0;
      });
    });
    _onPlayPositionChangedSubscription = audioHelper.onPlayPositionChangedStream.listen((Map<String, dynamic> event) {
      String? playerId = event["id"];
      // int? duration = event["duration"];
      // Duration? position = event["position"];
      double? percent = event["percent"];
      if (playerId == null || playerId != this._message.msgId || percent == null) {
        if (_playProgress != 0) {
          setState(() {
            _playProgress = 0;
          });
        }
        return;
      }
      if (percent == _playProgress) return;
      this.setState(() {
        _playProgress = percent;
      });
    });
  }

  @override
  void onRefreshArguments() {
    _message = widget.message;
    _contact = widget.contact;
    _msgStatus = MessageStatus.get(_message);
    _uploadProgress = ((_message.content is File) && (_msgStatus == MessageStatus.Sending)) ? (_uploadProgress == 1 ? 0 : _uploadProgress) : 1;
    // _playProgress = 0;
    // burn
    List<int?> burningOptions = MessageOptions.getContactBurning(_message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    if (_message.deleteTime == null && burnAfterSeconds != null && burnAfterSeconds > 0) {
      _message.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
      chatCommon.burningHandle(_message); // await
    }
    if (_message.deleteTime != null) {
      DateTime deleteTime = _message.deleteTime ?? DateTime.now();
      if (deleteTime.millisecondsSinceEpoch > DateTime.now().millisecondsSinceEpoch) {
        String taskKey = "${TaskService.KEY_MSG_BURNING}:${_message.msgId}";
        taskService.addTask1(taskKey, (String key) async {
          if (_message.originalId != contactCommon.currentUser?.clientAddress) {
            taskService.removeTask1(key);
            // onRefreshArguments(); // refresh task (will dead loop)
            return;
          }
          if (deleteTime.millisecondsSinceEpoch > DateTime.now().millisecondsSinceEpoch) {
            // logger.d("$TAG - tick - key:$key - msgId:${_message.msgId} - deleteTime:${_message.deleteTime?.toString()} - now:${DateTime.now()}");
          } else {
            logger.i("$TAG - delete(tick) - key:$key - msgId:${_message.msgId} - deleteTime:${_message.deleteTime?.toString()} - now:${DateTime.now()}");
            await chatCommon.msgDelete(_message.msgId, notify: true);
            taskService.removeTask1(key);
          }
          setState(() {}); // async need
        });
      } else {
        logger.i("$TAG - delete(now) - msgId:${_message.msgId} - deleteTime:${_message.deleteTime?.toString()} - now:${DateTime.now()}");
        chatCommon.msgDelete(_message.msgId, notify: true); // await
      }
    }
    // resend
    int _status = MessageStatus.get(_message);
    if (_status == MessageStatus.Sending && _message.sendTime != null && DateTime.now().isAfter(_message.sendTime!.add(Settings.msgResendDuration))) {
      chatCommon.updateMessageStatus(_message, MessageStatus.SendFail, notify: true); // await
    }
  }

  @override
  void dispose() {
    // taskService.removeTask1("${TaskService.KEY_MSG_BURNING}:${_message.msgId}");
    _onPlayStateChangedSubscription?.cancel();
    _onPlayPositionChangedSubscription?.cancel();
    _onPieceOutStreamSubscription?.cancel();
    super.dispose();
  }

  _onContentTextTap() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      items: [
        MenuItem(
          userInfo: 0,
          title: S.of(context).copy,
          textStyle: TextStyle(color: application.theme.fontLightColor, fontSize: 12),
        ),
      ],
      onClickMenu: (MenuItemProvider item) {
        var index = (item as MenuItem).userInfo;
        switch (index) {
          case 0:
            copyText(_message.content, context: context);
            break;
        }
      },
    );
    popupMenu.show(widgetKey: _contentKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_message.deleteTime != null) {
      DateTime deleteTime = _message.deleteTime ?? DateTime.now();
      if (deleteTime.millisecondsSinceEpoch <= DateTime.now().millisecondsSinceEpoch) {
        return SizedBox.shrink();
      }
    }

    bool isSendOut = _message.isOutbound;

    List styles = _getStyles();
    BoxDecoration decoration = styles[0];
    bool dark = styles[1];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSendOut ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSendOut ? SizedBox.shrink() : _getAvatar(isSendOut),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: isSendOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  _getName(isSendOut),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: isSendOut ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      isSendOut ? _getTip(isSendOut) : SizedBox.shrink(),
                      _getContent(decoration, dark),
                      isSendOut ? SizedBox.shrink() : _getTip(isSendOut),
                    ],
                  ),
                ],
              ),
            ),
          ),
          isSendOut ? _getAvatar(isSendOut) : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _getAvatar(bool self) {
    return self || !widget.showProfile || _contact == null
        ? SizedBox.shrink()
        : GestureDetector(
            onTap: () async {
              File? file = await _contact!.displayAvatarFile;
              PhotoScreen.go(context, filePath: file?.path);
            },
            onLongPress: () => widget.onLonePress?.call(_contact!, _message),
            child: ContactAvatar(
              contact: _contact!,
              radius: 24,
            ),
          );
  }

  Widget _getName(bool self) {
    return self || !widget.showProfile || _contact == null
        ? SizedBox.shrink()
        : Label(
            _contact!.displayName,
            type: LabelType.h3,
            color: application.theme.primaryColor,
          );
  }

  Widget _getTip(bool self) {
    S _localizations = S.of(context);
    bool isSending = _msgStatus == MessageStatus.Sending;
    bool hasProgress = _message.content is File;

    bool showSending = isSending && !hasProgress;
    bool showProgress = isSending && hasProgress && _uploadProgress < 1;
    bool showFail = _msgStatus == MessageStatus.SendFail;

    return Expanded(
      flex: 1,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: self ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          showSending
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SpinKitRing(
                    color: application.theme.fontColor4,
                    lineWidth: 1,
                    size: 15,
                  ),
                )
              : SizedBox.shrink(),
          showProgress
              ? Container(
                  width: 40,
                  height: 40,
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    backgroundColor: application.theme.fontColor4.withAlpha(80),
                    color: application.theme.primaryColor.withAlpha(200),
                    strokeWidth: 2,
                    value: _uploadProgress,
                  ),
                )
              : SizedBox.shrink(),
          showFail
              ? ButtonIcon(
                  icon: Icon(
                    FontAwesomeIcons.exclamationCircle,
                    size: 20,
                    color: application.theme.fallColor,
                  ),
                  width: 50,
                  height: 50,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    ModalDialog.of(context).confirm(
                      title: "confirm resend?", // TODO:GG locale resend title
                      agree: Button(
                        text: _localizations.send_message, // TODO:GG locale resend action
                        backgroundColor: application.theme.strongColor,
                        width: double.infinity,
                        onPressed: () {
                          widget.onResend?.call(_message.msgId);
                          Navigator.pop(this.context);
                        },
                      ),
                      hasCloseButton: true,
                    );
                  },
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _getContent(BoxDecoration decoration, bool dark) {
    double maxWidth = MediaQuery.of(context).size.width - 12 * 2 * 2 - (24 * 2) * 2 - 8 * 2;

    List<Widget> _bodyList = [SizedBox.shrink()];
    var onTap;
    switch (_message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        _bodyList = _getContentBodyText(dark);
        onTap = () => _onContentTextTap();
        break;
      case ContentType.media:
      case ContentType.image:
      case ContentType.nknImage:
        _bodyList = _getContentBodyImage(dark);
        if (_message.content is File) {
          File file = _message.content as File;
          onTap = () => PhotoScreen.go(context, filePath: file.path);
        }
        break;
      case ContentType.audio:
        _bodyList = _getContentBodyAudio(dark);
        if (_message.content is File) {
          double? durationS = MessageOptions.getAudioDuration(_message);
          int? durationMs = durationS == null ? null : ((durationS * 1000).round());
          File file = _message.content as File;
          onTap = () => audioHelper.playStart(_message.msgId, file.path, durationMs: durationMs);
        }
        break;
    }

    return GestureDetector(
      key: _contentKey,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: decoration,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._bodyList,
              _burnWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _burnWidget() {
    if (_message.deleteTime == null) return SizedBox.shrink();
    List<int?> burningOptions = MessageOptions.getContactBurning(_message);
    int? burnAfterSeconds = burningOptions.length >= 1 ? burningOptions[0] : null;
    DateTime deleteTime = _message.deleteTime ?? DateTime.now().add(Duration(seconds: (burnAfterSeconds ?? 0) + 1));
    Color clockColor = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);
    return Column(
      children: [
        SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(FontAwesomeIcons.clock, size: 12, color: clockColor),
            SizedBox(width: 4),
            Label(
              timeFromNowFormat(deleteTime),
              type: LabelType.bodySmall,
              fontSize: application.theme.iconTextFontSize,
              color: clockColor,
            ),
          ],
        )
      ],
    );
  }

  List<Widget> _getContentBodyText(bool dark) {
    List contents = getChatFormatString(_message.content);
    if (contents.isNotEmpty) {
      List<InlineSpan> children = [];
      for (String s in contents) {
        if (s.contains(chatRegSpecial)) {
          children.add(TextSpan(text: s, style: TextStyle(height: 1.15, color: Color(0xFFF5B800), fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)));
        } else {
          children.add(TextSpan(text: s, style: TextStyle(color: dark ? application.theme.fontLightColor : application.theme.fontColor3, height: 1.25)));
        }
      }
      return [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 16),
            text: '',
            children: children,
          ),
        )
      ];
    } else {
      return [Markdown(data: _message.content, dark: dark)];
    }
  }

  List<Widget> _getContentBodyImage(bool dark) {
    if (!(_message.content is File)) {
      return [SizedBox.shrink()];
    }
    File file = _message.content as File;
    double maxWidth = MediaQuery.of(context).size.width * (widget.showProfile ? 0.5 : 0.55);
    double maxHeight = MediaQuery.of(context).size.height * 0.3;

    return [
      Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minWidth: maxWidth / 4,
          minHeight: maxWidth / 4,
        ),
        child: Image.file(file),
      )
    ];
  }

  List<Widget> _getContentBodyAudio(bool dark) {
    bool isPlaying = _playState == PlayerState.PLAYING;

    Color iconColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.primaryColor.withAlpha(200);
    Color textColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.fontColor2.withAlpha(200);
    Color progressBgColor = _message.isOutbound ? Colors.white.withAlpha(230) : application.theme.primaryColor.withAlpha(30);
    Color progressValueColor = _message.isOutbound ? application.theme.backgroundColor4.withAlpha(127) : application.theme.primaryColor.withAlpha(200);

    double? durationS = MessageOptions.getAudioDuration(_message);
    double maxDurationS = AudioHelper.MessageRecordMaxDurationS;
    double durationRatio = ((durationS ?? (maxDurationS / 2)) > maxDurationS ? maxDurationS : (durationS ?? (maxDurationS / 2))) / maxDurationS;
    double minWidth = MediaQuery.of(context).size.width * 0.1;
    double maxWidth = MediaQuery.of(context).size.width * (widget.showProfile ? 0.35 : 0.4);
    double progressWidth = minWidth + (maxWidth - minWidth) * durationRatio;

    num durationText = getNumByValueDouble(durationS ?? 0, 2) ?? 0;

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          isPlaying
              ? Icon(
                  FontAwesomeIcons.pauseCircle,
                  size: 25,
                  color: iconColor,
                )
              : Icon(
                  FontAwesomeIcons.playCircle,
                  size: 25,
                  color: iconColor,
                ),
          SizedBox(width: 8),
          Container(
            width: progressWidth,
            child: LinearProgressIndicator(
              minHeight: 10,
              backgroundColor: progressBgColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressValueColor),
              value: _playProgress,
            ),
          ),
          SizedBox(width: 8),
          Label('$durationText\"', type: LabelType.bodyRegular, color: textColor),
        ],
      ),
    ];
  }

  List<dynamic> _getStyles() {
    SkinTheme _theme = application.theme;

    BoxDecoration decoration;
    bool dark = false;
    if (_msgStatus == MessageStatus.Sending || _msgStatus == MessageStatus.SendSuccess) {
      decoration = BoxDecoration(
        color: _theme.primaryColor.withAlpha(50),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(2),
        ),
      );
      dark = true;
    } else if (_msgStatus == MessageStatus.SendFail) {
      decoration = BoxDecoration(
        color: _theme.primaryColor.withAlpha(50),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(2),
        ),
      );
      dark = true;
    } else if (_msgStatus == MessageStatus.SendWithReceipt) {
      decoration = BoxDecoration(
        color: _theme.primaryColor,
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
        color: _theme.backgroundColor2,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
      );
    }
    return [decoration, dark];
  }
}
