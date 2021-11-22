import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/text/markdown.dart';
import 'package:nmobile/components/tip/popup_menu.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/chat.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class ChatBubble extends BaseStateFulWidget {
  final MessageSchema message;
  final ContactSchema? contact;
  final bool showProfile;
  final bool hideProfile;
  final bool showTimeAndStatus;
  final bool timeFormatBetween;
  final bool hideTopMargin;
  final bool hideBotMargin;
  final Function(ContactSchema, MessageSchema)? onAvatarLonePress;
  final Function(String)? onResend;

  ChatBubble({
    required this.message,
    required this.contact,
    this.showProfile = false,
    this.hideProfile = false,
    this.showTimeAndStatus = true,
    this.timeFormatBetween = false,
    this.hideTopMargin = false,
    this.hideBotMargin = false,
    this.onAvatarLonePress,
    this.onResend,
  });

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends BaseStateFulWidgetState<ChatBubble> with Tag {
  GlobalKey _contentKey = GlobalKey();
  StreamSubscription? _contactUpdateStreamSubscription;
  StreamSubscription? _onPieceOutStreamSubscription;
  StreamSubscription? _onPlayProgressSubscription;

  late MessageSchema _message;
  ContactSchema? _contact;

  bool _showProfile = false;
  bool _hideProfile = false;
  bool _showTimeAndStatus = true;
  bool _timeFormatBetween = false;
  bool _hideTopMargin = false;
  bool _hideBotMargin = false;

  double _uploadProgress = 1;

  double _playProgress = 0;

  @override
  void initState() {
    super.initState();
    // contact
    _contactUpdateStreamSubscription = contactCommon.updateStream.listen((event) {
      if (_contact?.id == event.id) {
        setState(() {
          _contact = event;
        });
      }
    });
    // pieces
    _onPieceOutStreamSubscription = chatOutCommon.onPieceOutStream.listen((Map<String, dynamic> event) {
      String? msgId = event["msg_id"];
      double? percent = event["percent"];
      if (msgId == null || (percent == null) || (_message.status != MessageStatus.Sending) || !(_message.content is File)) {
        // logger.d("onPieceOutStream - percent:$percent - send_msgId:$msgId - receive_msgId:${this._message.msgId}");
        if (_uploadProgress != 1) {
          setState(() {
            _uploadProgress = 1;
          });
        }
        return;
      } else if (msgId != this._message.msgId) {
        // just skip
      } else {
        this.setState(() {
          _uploadProgress = percent;
        });
      }
    });
    // player
    _onPlayProgressSubscription = audioHelper.onPlayProgressStream.listen((Map<String, dynamic> event) {
      String? playerId = event["id"]?.toString();
      // int? duration = event["duration"];
      // Duration? position = event["position"];
      double? percent = double.tryParse(event["percent"]?.toString() ?? "0");
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
    // visible
    _showProfile = widget.showProfile;
    _hideProfile = widget.hideProfile;
    _showTimeAndStatus = widget.showTimeAndStatus;
    _timeFormatBetween = widget.timeFormatBetween;
    _hideTopMargin = widget.hideTopMargin;
    _hideBotMargin = widget.hideBotMargin;
    // contact
    if (_showProfile) {
      if (widget.contact != null) {
        _contact = widget.contact;
      } else {
        _message.getSender(emptyAdd: true).then((value) {
          if (_contact?.clientAddress == null || _contact?.clientAddress != value?.clientAddress) {
            setState(() {
              _contact = value;
            });
          }
        });
      }
    } else {
      _contact = null;
    }
    // progress
    _uploadProgress = ((_message.content is File) && (_message.status == MessageStatus.Sending)) ? (_uploadProgress == 1 ? 0 : _uploadProgress) : 1;
    // _playProgress = 0;
    // burn
    _message = chatCommon.burningStart(_message, () {
      // logger.i("$TAG - tick - :${_message.msgId}");
      setState(() {});
    });
  }

  @override
  void dispose() {
    // taskService.removeTask1("${TaskService.KEY_MSG_BURNING}:${_message.msgId}");
    _contactUpdateStreamSubscription?.cancel();
    _onPlayProgressSubscription?.cancel();
    _onPieceOutStreamSubscription?.cancel();
    super.dispose();
  }

  _onContentTextTap() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      items: [
        MenuItem(
          userInfo: 0,
          title: Global.locale((s) => s.copy),
          textStyle: TextStyle(color: application.theme.fontLightColor, fontSize: 12),
        ),
      ],
      onClickMenu: (MenuItemProvider item) {
        var index = (item as MenuItem).userInfo;
        switch (index) {
          case 0:
            copyText(_message.content?.toString() ?? "", context: Global.appContext);
            break;
        }
      },
    );
    popupMenu.show(widgetKey: _contentKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_message.isDelete) {
      return SizedBox.shrink();
    } else if (_message.canBurning && (_message.content == null)) {
      return SizedBox.shrink();
    } else if (_message.deleteAt != null) {
      int deleteAt = _message.deleteAt ?? DateTime.now().millisecondsSinceEpoch;
      if (deleteAt <= DateTime.now().millisecondsSinceEpoch) {
        return SizedBox.shrink();
      }
    }

    bool isSendOut = _message.isOutbound;
    bool isTipBottom = _message.status == MessageStatus.SendSuccess || _message.status == MessageStatus.SendReceipt;

    List styles = _getStyles();
    BoxDecoration decoration = styles[0];
    bool dark = styles[1];

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: _hideTopMargin ? 0.5 : (isSendOut ? 4 : 8),
        bottom: _hideBotMargin ? 0.5 : (isSendOut ? 4 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSendOut ? SizedBox.shrink() : _getAvatar(),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: isSendOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                SizedBox(height: _hideTopMargin ? 0 : 4),
                _getName(),
                SizedBox(height: (_showProfile && !_hideProfile) ? 4 : 0),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: isSendOut ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: isTipBottom ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                  children: [
                    isSendOut ? _getStatusTip(isSendOut) : SizedBox.shrink(),
                    _getContent(decoration, dark),
                    isSendOut ? SizedBox.shrink() : _getStatusTip(isSendOut),
                  ],
                ),
                SizedBox(height: _hideBotMargin ? 0 : 4),
              ],
            ),
          ),
          SizedBox(width: 8),
          isSendOut ? _getAvatar() : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _getAvatar() {
    return _showProfile
        ? Opacity(
            opacity: _hideProfile ? 0 : 1,
            child: GestureDetector(
              onTap: () async {
                if (_hideProfile || (_contact == null)) return;
                ContactProfileScreen.go(context, schema: _contact);
              },
              onLongPress: () {
                if (_hideProfile || (_contact == null)) return;
                widget.onAvatarLonePress?.call(_contact!, _message);
              },
              child: _contact != null
                  ? ContactAvatar(
                      contact: _contact!,
                      radius: 20,
                    )
                  : SizedBox(width: 20 * 2, height: 20 * 2),
            ),
          )
        : SizedBox.shrink();
  }

  Widget _getName() {
    return _showProfile && !_hideProfile
        ? Label(
            _contact?.displayName ?? " ",
            maxWidth: Global.screenWidth() * 0.5,
            type: LabelType.h3,
            color: application.theme.primaryColor,
          )
        : SizedBox.shrink();
  }

  Widget _getStatusTip(bool self) {
    // bool isSending = _message.status == MessageStatus.Sending;
    bool isSendFail = _message.status == MessageStatus.SendFail;
    // bool isSendSuccess = _message.status == MessageStatus.SendSuccess;
    // bool isSendReceipt = _message.status == MessageStatus.SendReceipt;

    // bool canProgress = (_message.content is File) && !_message.isTopic;

    // bool showSending = isSending && !canProgress;
    // bool showProgress = isSending && canProgress && _uploadProgress < 1;

    // if (showSending) {
    //   return Padding(
    //     padding: const EdgeInsets.symmetric(horizontal: 10),
    //     child: SpinKitRing(
    //       color: application.theme.fontColor4,
    //       lineWidth: 1,
    //       size: 15,
    //     ),
    //   );
    // } else if (showProgress) {
    //   return Container(
    //     width: 40,
    //     height: 40,
    //     padding: EdgeInsets.all(10),
    //     child: CircularProgressIndicator(
    //       backgroundColor: application.theme.fontColor4.withAlpha(80),
    //       color: application.theme.primaryColor.withAlpha(200),
    //       strokeWidth: 2,
    //       value: _uploadProgress,
    //     ),
    //   );
    // } else
    if (isSendFail) {
      return ButtonIcon(
        icon: Icon(
          FontAwesomeIcons.exclamationCircle,
          size: 20,
          color: application.theme.fallColor,
        ),
        width: 50,
        height: 50,
        padding: EdgeInsets.zero,
        onPressed: () {
          ModalDialog.of(Global.appContext).confirm(
            title: Global.locale((s) => s.confirm_resend),
            hasCloseButton: true,
            agree: Button(
              width: double.infinity,
              text: Global.locale((s) => s.send_message),
              backgroundColor: application.theme.strongColor,
              onPressed: () {
                widget.onResend?.call(_message.msgId);
                if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
              },
            ),
          );
        },
      );
    }
    // else if (isSendSuccess) {
    //   return Container(
    //     width: 5,
    //     height: 5,
    //     margin: EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
    //     decoration: BoxDecoration(
    //       borderRadius: BorderRadius.circular(5),
    //       color: application.theme.strongColor.withAlpha(127),
    //     ),
    //   );
    // } else if (isSendReceipt) {
    //   return Container(
    //     width: 5,
    //     height: 5,
    //     margin: EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
    //     decoration: BoxDecoration(
    //       borderRadius: BorderRadius.circular(5),
    //       color: application.theme.successColor.withAlpha(127),
    //     ),
    //   );
    // }
    return SizedBox.shrink();
  }

  Widget _getContent(BoxDecoration decoration, bool dark) {
    double maxWidth = Global.screenWidth() - (12 + 20 * 2 + 8) * 2;

    List<Widget> _bodyList = [SizedBox.shrink()];
    var onTap;
    switch (_message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        _bodyList = _getContentBodyText(dark);
        _bodyList.add(SizedBox(height: 1));
        onTap = () => _onContentTextTap();
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        _bodyList = _getContentBodyImage(dark);
        _bodyList.add(SizedBox(height: 4));
        if (_message.content is File) {
          File file = _message.content as File;
          onTap = () => PhotoScreen.go(context, filePath: file.path);
        }
        break;
      case MessageContentType.audio:
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
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 5),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ..._bodyList,
            _bottomRightWidget(),
          ],
        ),
      ),
    );
  }

  Widget _bottomRightWidget() {
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    int? sendAt = _message.isOutbound ? _message.sendAt : (_message.sendAt ?? MessageOptions.getInAt(_message));
    String sendTime = ((sendAt != null) && (sendAt != 0)) ? formatChatTime(DateTime.fromMillisecondsSinceEpoch(sendAt)) : "";
    bool isSending = _message.status == MessageStatus.Sending;

    bool showTime = isSending || _showTimeAndStatus;
    bool showBurn = _message.canBurning && (_message.deleteAt != null) && (_message.deleteAt != 0);
    bool showStatus = (isSending || _showTimeAndStatus) && _message.isOutbound;

    return (showTime || showBurn || showStatus)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              (showTime || showBurn)
                  ? Label(
                      sendTime,
                      type: LabelType.bodySmall,
                      height: 1,
                      fontSize: application.theme.iconTextFontSize,
                      color: color,
                    )
                  : SizedBox.shrink(),
              ((showTime || showBurn) && showBurn) ? SizedBox(width: 4) : SizedBox.shrink(),
              showBurn ? _burnWidget() : SizedBox.shrink(),
              ((showTime || showBurn) && showStatus) ? SizedBox(width: 4) : SizedBox.shrink(),
              showStatus ? _bottomRightStatusWidget() : SizedBox.shrink(),
            ],
          )
        : SizedBox(height: 3);
  }

  Widget _bottomRightStatusWidget() {
    double iconSize = 10;
    double borderSize = iconSize / 10;
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    bool isSending = _message.status == MessageStatus.Sending;
    bool isSendSuccess = _message.status == MessageStatus.SendSuccess;
    bool isSendReceipt = _message.status == MessageStatus.SendReceipt;
    bool isSendRead = _message.status == MessageStatus.Read;

    bool showProgress = isSending && (_message.content is File) && (_uploadProgress < 1) && (_uploadProgress > 0);
    bool showSending = isSending && !showProgress;

    if (showSending) {
      return SpinKitRing(
        color: color,
        lineWidth: 1.5,
        size: iconSize,
      );
    } else if (showProgress) {
      return Container(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          backgroundColor: application.theme.fontColor4.withAlpha(80),
          color: color,
          strokeWidth: 2,
          value: _uploadProgress,
        ),
      );
    } else if (isSendSuccess) {
      return Icon(FontAwesomeIcons.checkCircle, size: iconSize, color: color);
    } else if (isSendReceipt || isSendRead) {
      return Container(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: iconSize / 2 + borderSize,
              top: borderSize,
              child: Icon(
                isSendReceipt ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.solidCheckCircle,
                size: iconSize,
                color: color,
              ),
            ),
            Row(
              children: [
                SizedBox(width: iconSize / 2),
                Container(
                  decoration: BoxDecoration(
                    color: _getBgColor(),
                    border: Border.all(color: _getBgColor(), width: borderSize),
                    borderRadius: BorderRadius.all(Radius.circular(iconSize)),
                  ),
                  child: Icon(
                    isSendReceipt ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.solidCheckCircle,
                    size: iconSize,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _burnWidget() {
    double iconSize = 10;
    double borderSize = iconSize / 10;
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    final burningOptions = MessageOptions.getContactBurning(_message);
    int deleteAfterMs = (burningOptions.length >= 1 ? (burningOptions[0] ?? 1) : 1) * 1000;

    int deleteAt = _message.deleteAt ?? DateTime.now().millisecondsSinceEpoch;
    int nowAt = DateTime.now().millisecondsSinceEpoch;

    double percent = (deleteAfterMs - (deleteAt - nowAt)) / deleteAfterMs;
    percent = percent >= 0 ? (percent <= 1 ? percent : 1) : 0;

    // spinner
    return Stack(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: borderSize),
            borderRadius: BorderRadius.all(Radius.circular(iconSize)),
          ),
          child: UnconstrainedBox(
            child: Transform.rotate(
              angle: pi * percent * 2,
              child: Column(
                children: [
                  Container(
                    width: borderSize,
                    height: iconSize / 3,
                    decoration: BoxDecoration(color: color),
                  ),
                  Container(
                    width: borderSize,
                    height: iconSize / 3,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent, width: borderSize),
            borderRadius: BorderRadius.all(Radius.circular(iconSize)),
          ),
          child: CircularProgressIndicator(
            backgroundColor: Colors.transparent,
            color: _getBgColor(),
            strokeWidth: borderSize * 2,
            value: percent,
          ),
        ),
      ],
    );
  }

  List<Widget> _getContentBodyText(bool dark) {
    List<String> contents = getChatFormatString(_message.content?.toString());
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
      String content = _message.content?.toString() ?? "";
      if (content.isEmpty) content = " ";
      return [Markdown(data: content, dark: dark)];
    }
  }

  List<Widget> _getContentBodyImage(bool dark) {
    if (!(_message.content is File)) {
      return [SizedBox.shrink()];
    }
    File file = _message.content as File;
    double maxWidth = Global.screenWidth() * (widget.showProfile ? 0.5 : 0.55);
    double maxHeight = Global.screenHeight() * 0.3;

    return [
      Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minWidth: maxWidth / 5,
          minHeight: maxWidth / 5,
        ),
        child: Image.file(file, cacheWidth: maxWidth.toInt()),
      )
    ];
  }

  List<Widget> _getContentBodyAudio(bool dark) {
    bool isPlaying = _playProgress > 0;

    Color iconColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.primaryColor.withAlpha(200);
    Color textColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.fontColor2.withAlpha(200);
    Color progressBgColor = _message.isOutbound ? Colors.white.withAlpha(230) : application.theme.primaryColor.withAlpha(30);
    Color progressValueColor = _message.isOutbound ? application.theme.backgroundColor4.withAlpha(127) : application.theme.primaryColor.withAlpha(200);

    double? durationS = MessageOptions.getAudioDuration(_message);
    double maxDurationS = AudioHelper.MessageRecordMaxDurationS;
    double durationRatio = ((durationS ?? (maxDurationS / 2)) > maxDurationS ? maxDurationS : (durationS ?? (maxDurationS / 2))) / maxDurationS;
    double minWidth = Global.screenWidth() * 0.05;
    double maxWidth = Global.screenWidth() * (widget.showProfile ? 0.3 : 0.35);
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
    BoxDecoration decoration;
    bool dark;
    if (_message.isOutbound) {
      decoration = BoxDecoration(
        color: _getBgColor(),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          topRight: Radius.circular(_hideTopMargin ? 1 : 12),
          bottomRight: Radius.circular(_hideBotMargin ? 1 : (_hideTopMargin ? 12 : 2)),
        ),
      );
      dark = true;
    } else {
      decoration = BoxDecoration(
        color: _getBgColor(),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_hideTopMargin ? 1 : (_hideBotMargin ? 12 : 2)),
          bottomLeft: Radius.circular(_hideBotMargin ? 1 : 12),
          topRight: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
      );
      dark = false;
    }
    return [decoration, dark];
  }

  Color _getBgColor() {
    return _message.isOutbound ? application.theme.primaryColor : application.theme.backgroundColor2;
  }
}
