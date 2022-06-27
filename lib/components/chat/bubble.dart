import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
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
import 'package:nmobile/components/tip/popup_menu.dart' as PopMenu;
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/screens/common/video.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/time.dart';
import 'package:nmobile/utils/util.dart';
import 'package:open_file/open_file.dart';

class ChatBubble extends BaseStateFulWidget {
  final MessageSchema message;
  final TopicSchema? topic;
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
    required this.topic,
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
  StreamSubscription? _onProgressStreamSubscription;
  StreamSubscription? _onPlayProgressSubscription;

  bool initialized = false;
  late MessageSchema _message;
  ContactSchema? _contact;

  bool _showProfile = false;
  bool _hideProfile = false;
  bool _showTimeAndStatus = true;
  bool _timeFormatBetween = false;
  bool _hideTopMargin = false;
  bool _hideBotMargin = false;

  double _upDownloadProgress = -1;

  double _playProgress = 0;
  String? thumbnailPath;

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
    // progress
    _onProgressStreamSubscription = chatCommon.onProgressStream.listen((Map<String, dynamic> event) {
      String? msgId = event["msg_id"];
      double? percent = event["percent"];
      if (msgId == null || msgId != this._message.msgId) {
        // just skip
      } else if ((percent == null) || (percent < 0) || !(_message.content is File)) {
        if (_upDownloadProgress != -1) {
          setState(() {
            _upDownloadProgress = -1;
          });
        }
      } else {
        // logger.d("onPieceOutStream - percent:$percent - send_msgId:$msgId - receive_msgId:${this._message.msgId}");
        if (_upDownloadProgress != percent) {
          this.setState(() {
            _upDownloadProgress = percent;
          });
        }
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
    bool sameBubble = initialized && (_message.msgId == widget.message.msgId);
    _message = widget.message;
    initialized = true;
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
    _upDownloadProgress = sameBubble ? _upDownloadProgress : -1;
    // _playProgress = 0;
    // burn
    _message = chatCommon.burningStart(_message, () {
      // logger.i("$TAG - tick - :${_message.msgId}");
      setState(() {});
    });
    // thumbnail
    _refreshVideoThumbnail(); // await
  }

  @override
  void dispose() {
    // taskService.removeTask1("${TaskService.KEY_MSG_BURNING}:${_message.msgId}");
    _contactUpdateStreamSubscription?.cancel();
    _onPlayProgressSubscription?.cancel();
    _onProgressStreamSubscription?.cancel();
    super.dispose();
  }

  _onContentTextTap() {
    PopMenu.PopupMenu popupMenu = PopMenu.PopupMenu(
      context: context,
      items: [
        PopMenu.MenuItem(
          userInfo: 0,
          title: Global.locale((s) => s.copy, ctx: context),
          textStyle: TextStyle(color: application.theme.fontLightColor, fontSize: 12),
        ),
      ],
      onClickMenu: (PopMenu.MenuItemProvider item) {
        var index = (item as PopMenu.MenuItem).userInfo;
        switch (index) {
          case 0:
            Util.copyText(_message.content?.toString() ?? "");
            break;
        }
      },
    );
    popupMenu.show(widgetKey: _contentKey);
  }

  Future _refreshVideoThumbnail() async {
    String? path = MessageOptions.getVideoThumbnailPath(_message.options);
    if (path != null && path.isNotEmpty) {
      File file = File(path);
      if (!file.existsSync()) path = null;
    }
    if (thumbnailPath != path) {
      setState(() {
        thumbnailPath = path;
      });
    }
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

    BoxDecoration decoration = _getStyles();

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
                    _getContent(decoration),
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
            title: Global.locale((s) => s.confirm_resend, ctx: context),
            hasCloseButton: true,
            agree: Button(
              width: double.infinity,
              text: Global.locale((s) => s.send_message, ctx: context),
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

  Widget _getContent(BoxDecoration decoration) {
    double maxWidth = Global.screenWidth() - (12 + 20 * 2 + 8) * 2;

    String contentType = _message.contentType;
    if (contentType == MessageContentType.ipfs) {
      int? type = MessageOptions.getFileType(_message.options);
      if (type == MessageOptions.fileTypeImage) {
        contentType = MessageContentType.image;
      } else if (type == MessageOptions.fileTypeVideo) {
        contentType = MessageContentType.video;
      } else {
        // ipfs_file + ipfs_audio
        contentType = MessageContentType.file;
      }
    }

    List<Widget> _bodyList = [SizedBox.shrink()];
    var onTap;
    switch (contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        _bodyList = _getContentBodyText();
        _bodyList.add(SizedBox(height: 1));
        onTap = () => _onContentTextTap();
        break;
      case MessageContentType.media:
      case MessageContentType.image:
        // image + ipfs_image
        _bodyList = _getContentBodyImage();
        _bodyList.add(SizedBox(height: 4));
        if (_message.isOutbound || (_message.contentType != MessageContentType.ipfs)) {
          if (_message.content is File) {
            File file = _message.content as File;
            onTap = () => PhotoScreen.go(context, filePath: file.path);
          }
        } else {
          int state = MessageOptions.getIpfsState(_message.options);
          if (state == MessageOptions.ipfsStateNo) {
            onTap = () {
              setState(() {
                _upDownloadProgress = 0;
              });
              chatCommon.startIpfsDownload(_message);
            };
          } else if (state == MessageOptions.ipfsStateIng) {
            // FUTURE: cancel download and update UI
          } else {
            if (_message.content is File) {
              File file = _message.content as File;
              onTap = () => PhotoScreen.go(context, filePath: file.path);
            }
          }
        }
        break;
      case MessageContentType.audio:
        // just audio, no ipfs_audio
        _bodyList = _getContentBodyAudio();
        if (_message.content is File) {
          double? durationS = MessageOptions.getAudioDuration(_message.options);
          int? durationMs = durationS == null ? null : ((durationS * 1000).round());
          File file = _message.content as File;
          onTap = () => audioHelper.playStart(_message.msgId, file.path, durationMs: durationMs);
        }
        break;
      case MessageContentType.video:
        // just ipfs_video, no video
        _bodyList = _getContentBodyVideo();
        _bodyList.add(SizedBox(height: 4));
        if (_message.isOutbound || (_message.contentType != MessageContentType.ipfs)) {
          if (_message.content is File) {
            File file = _message.content as File;
            onTap = () => VideoScreen.go(context, filePath: file.path);
          }
        } else {
          int state = MessageOptions.getIpfsState(_message.options);
          if (state == MessageOptions.ipfsStateNo) {
            onTap = () {
              setState(() {
                _upDownloadProgress = 0;
              });
              chatCommon.startIpfsDownload(_message);
            };
          } else if (state == MessageOptions.ipfsStateIng) {
            // FUTURE: cancel download and update UI
          } else {
            if (_message.content is File) {
              File file = _message.content as File;
              onTap = () => VideoScreen.go(context, filePath: file.path);
            }
          }
        }
        break;
      case MessageContentType.file:
        _bodyList = _getContentBodyFile();
        _bodyList.add(SizedBox(height: 4));
        if (_message.isOutbound) {
          // nothing
          if (_message.content is File) {
            File file = _message.content as File;
            onTap = () {
              try {
                OpenFile.open(file.path);
              } catch (e) {
                handleError(e);
              }
            };
          }
        } else {
          int state = MessageOptions.getIpfsState(_message.options);
          if (state == MessageOptions.ipfsStateNo) {
            onTap = () {
              setState(() {
                _upDownloadProgress = 0;
              });
              chatCommon.startIpfsDownload(_message);
            };
          } else if (state == MessageOptions.ipfsStateIng) {
            // FUTURE: delete download and update UI
          } else {
            if (_message.content is File) {
              File file = _message.content as File;
              onTap = () {
                try {
                  OpenFile.open(file.path);
                } catch (e) {
                  handleError(e);
                }
              };
            }
          }
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

    int? sendAt = _message.isOutbound ? _message.sendAt : (_message.sendAt ?? MessageOptions.getInAt(_message.options));
    String sendTime = ((sendAt != null) && (sendAt != 0)) ? Time.formatChatTime(DateTime.fromMillisecondsSinceEpoch(sendAt)) : "";
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

    bool showProgress = isSending && (_message.content is File) && (_upDownloadProgress < 1) && (_upDownloadProgress > 0);
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
          value: _upDownloadProgress,
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

    int? burnAfterSeconds = MessageOptions.getContactBurningDeleteSec(_message.options);
    int deleteAfterMs = (burnAfterSeconds ?? 1) * 1000;

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

  List<Widget> _getContentBodyText() {
    List<String> contents = Format.chatText(_message.content?.toString());
    if (contents.isNotEmpty) {
      List<InlineSpan> children = [];
      for (String s in contents) {
        if (s.contains(Format.chatRegSpecial)) {
          children.add(TextSpan(text: s, style: TextStyle(height: 1.15, color: Color(0xFFF5B800), fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)));
        } else {
          children.add(TextSpan(text: s, style: TextStyle(color: _message.isOutbound ? application.theme.fontLightColor : application.theme.fontColor3, height: 1.25)));
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
      return [Markdown(data: content, dark: _message.isOutbound)];
    }
  }

  List<Widget> _getContentBodyImage() {
    double iconSize = min(Global.screenWidth() * 0.1, Global.screenHeight() * 0.06);

    double maxWidth = Global.screenWidth() * (widget.showProfile ? 0.5 : 0.55);
    double maxHeight = Global.screenHeight() * 0.3;
    double minWidth = maxWidth / 2;
    double minHeight = maxHeight / 2;

    List<double> realWH = MessageOptions.getMediaWH(_message.options);
    List<double?> ratioWH = _getPlaceholderWH([maxWidth, maxHeight], realWH);
    double placeholderWidth = ratioWH[0] ?? minWidth;
    double placeholderHeight = ratioWH[1] ?? minHeight;

    if (_message.isOutbound == false && _message.contentType == MessageContentType.ipfs) {
      int _size = MessageOptions.getFileSize(_message.options) ?? MessageOptions.getIpfsResultSize(_message.options) ?? 0;
      String? fileSize = _size > 0 ? Format.flowSize(_size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'], decimalDigits: 0) : null;
      int state = MessageOptions.getIpfsState(_message.options);
      if (state == MessageOptions.ipfsStateNo) {
        return [
          Stack(
            children: [
              Container(
                width: placeholderWidth,
                height: placeholderHeight,
                color: Colors.black,
                child: Icon(
                  CupertinoIcons.arrow_down_circle,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              (fileSize != null && fileSize.isNotEmpty)
                  ? Positioned(
                      right: 5,
                      bottom: 2,
                      child: Label(
                        fileSize,
                        type: LabelType.bodyLarge,
                        color: Colors.white,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ];
      } else if (state == MessageOptions.ipfsStateIng) {
        bool showProgress = (_upDownloadProgress < 1) && (_upDownloadProgress > 0);
        return [
          Stack(
            children: [
              Container(
                width: placeholderWidth,
                height: placeholderHeight,
                color: Colors.black,
                alignment: Alignment.center,
                child: Container(
                  width: iconSize * 0.66,
                  height: iconSize * 0.66,
                  child: showProgress
                      ? CircularProgressIndicator(
                          backgroundColor: application.theme.fontColor4.withAlpha(80),
                          color: Colors.white,
                          strokeWidth: 3,
                          value: _upDownloadProgress,
                        )
                      : SpinKitRing(
                          color: Colors.white,
                          lineWidth: 3,
                          size: iconSize,
                        ),
                ),
              ),
              (fileSize != null && fileSize.isNotEmpty)
                  ? Positioned(
                      right: 5,
                      bottom: 2,
                      child: Label(
                        fileSize,
                        type: LabelType.bodyLarge,
                        color: Colors.white,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ];
      } else {
        // file is exits
      }
    }

    // file
    if (!(_message.content is File)) {
      return [SizedBox.shrink()];
    }
    File file = _message.content as File;

    return [
      Container(
        width: ratioWH[0],
        height: ratioWH[1],
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minWidth: minWidth,
          minHeight: minHeight,
        ),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: ratioWH[0]?.toInt(),
          cacheHeight: ratioWH[1]?.toInt(),
        ),
      )
    ];
  }

  List<Widget> _getContentBodyAudio() {
    bool isPlaying = _playProgress > 0;

    Color iconColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.primaryColor.withAlpha(200);
    Color textColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.fontColor2.withAlpha(200);
    Color progressBgColor = _message.isOutbound ? Colors.white.withAlpha(230) : application.theme.primaryColor.withAlpha(30);
    Color progressValueColor = _message.isOutbound ? application.theme.backgroundColor4.withAlpha(127) : application.theme.primaryColor.withAlpha(200);

    double? durationS = MessageOptions.getAudioDuration(_message.options);
    double maxDurationS = AudioHelper.MessageRecordMaxDurationS;
    double durationRatio = ((durationS ?? (maxDurationS / 2)) > maxDurationS ? maxDurationS : (durationS ?? (maxDurationS / 2))) / maxDurationS;
    double minWidth = Global.screenWidth() * 0.05;
    double maxWidth = Global.screenWidth() * (widget.showProfile ? 0.3 : 0.35);
    double progressWidth = minWidth + (maxWidth - minWidth) * durationRatio;

    num durationText = Util.getNumByValueDouble(durationS ?? 0, 2) ?? 0;

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

  List<Widget> _getContentBodyVideo() {
    double iconSize = min(Global.screenWidth() * 0.1, Global.screenHeight() * 0.06);

    double maxWidth = Global.screenWidth() * (widget.showProfile ? 0.5 : 0.55);
    double maxHeight = Global.screenHeight() * 0.3;
    double minWidth = maxWidth / 2;
    double minHeight = maxHeight / 2;

    List<double> realWH = MessageOptions.getMediaWH(_message.options);
    List<double?> ratioWH = _getPlaceholderWH([maxWidth, maxHeight], realWH);
    double placeholderWidth = ratioWH[0] ?? minWidth;
    double placeholderHeight = ratioWH[1] ?? minHeight;

    double? duration = MessageOptions.getMediaDuration(_message.options) ?? MessageOptions.getAudioDuration(_message.options);
    String? durationText;
    if ((duration != null) && (duration >= 0)) {
      int min = duration ~/ 60;
      int sec = (duration % 60).toInt();
      String minText = (min >= 10) ? "$min" : "0$min";
      String secText = (sec >= 10) ? "$sec" : "0$sec";
      durationText = "$minText:$secText";
    }

    int state = MessageOptions.getIpfsState(_message.options);
    bool showProgress = (_upDownloadProgress < 1) && (_upDownloadProgress > 0);

    return [
      Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: ratioWH[0],
              height: ratioWH[1],
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                minWidth: minWidth,
                minHeight: minHeight,
              ),
              child: (thumbnailPath != null)
                  ? Image.file(
                      File(thumbnailPath!),
                      fit: BoxFit.cover,
                      cacheWidth: ratioWH[0]?.toInt(),
                      cacheHeight: ratioWH[1]?.toInt(),
                    )
                  : SizedBox(width: placeholderWidth, height: placeholderHeight),
            ),
            (durationText != null && durationText.isNotEmpty)
                ? Positioned(
                    right: 5,
                    bottom: 2,
                    child: Label(
                      durationText,
                      type: LabelType.bodyLarge,
                      color: Colors.white,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : SizedBox.shrink(),
            Positioned(
              child: (_message.isOutbound == true)
                  ? Icon(
                      CupertinoIcons.play_circle,
                      color: Colors.white,
                      size: iconSize,
                    )
                  : (state == MessageOptions.ipfsStateNo)
                      ? Icon(
                          CupertinoIcons.arrow_down_circle,
                          color: Colors.white,
                          size: iconSize,
                        )
                      : (state == MessageOptions.ipfsStateIng)
                          ? Container(
                              width: iconSize * 0.66,
                              height: iconSize * 0.66,
                              child: showProgress
                                  ? CircularProgressIndicator(
                                      backgroundColor: application.theme.fontColor4.withAlpha(80),
                                      color: Colors.white,
                                      strokeWidth: 3,
                                      value: _upDownloadProgress,
                                    )
                                  : SpinKitRing(
                                      color: Colors.white,
                                      lineWidth: 3,
                                      size: iconSize,
                                    ),
                            )
                          : Icon(
                              CupertinoIcons.play_circle,
                              color: Colors.white,
                              size: iconSize,
                            ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _getContentBodyFile() {
    double iconSize = min(Global.screenWidth() * 0.1, Global.screenHeight() * 0.06);

    double labelWidth = Global.screenWidth() * 0.35;

    String fileName = MessageOptions.getFileName(_message.options) ?? "---";
    int _size = MessageOptions.getFileSize(_message.options) ?? MessageOptions.getIpfsResultSize(_message.options) ?? 0;
    String fileSize = _size > 0 ? Format.flowSize(_size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'], decimalDigits: 0) : "--";

    int state = MessageOptions.getIpfsState(_message.options);
    bool showProgress = (_upDownloadProgress < 1) && (_upDownloadProgress > 0);

    return [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelWidth, minWidth: labelWidth),
                  child: Label(
                    fileName,
                    type: LabelType.bodyRegular,
                    color: _message.isOutbound ? Colors.white : application.theme.fontColor1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelWidth, minWidth: labelWidth),
                  child: Label(
                    fileSize,
                    type: LabelType.bodyRegular,
                    color: _message.isOutbound ? Colors.white : application.theme.fontColor1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            (_message.isOutbound == true)
                ? Icon(
                    CupertinoIcons.doc,
                    color: Colors.white,
                    size: iconSize,
                  )
                : (state == MessageOptions.ipfsStateNo)
                    ? Icon(
                        CupertinoIcons.arrow_down_circle,
                        color: application.theme.fontColor1.withAlpha(200),
                        size: iconSize,
                      )
                    : (state == MessageOptions.ipfsStateIng)
                        ? Container(
                            width: iconSize,
                            height: iconSize,
                            child: UnconstrainedBox(
                              alignment: Alignment.center,
                              child: Container(
                                width: iconSize * 0.66,
                                height: iconSize * 0.66,
                                child: showProgress
                                    ? CircularProgressIndicator(
                                        backgroundColor: application.theme.fontColor1.withAlpha(40),
                                        color: application.theme.fontColor1,
                                        strokeWidth: 3,
                                        value: _upDownloadProgress,
                                      )
                                    : SpinKitRing(
                                        color: application.theme.fontColor1,
                                        lineWidth: 3,
                                        size: iconSize,
                                      ),
                              ),
                            ),
                          )
                        : Icon(
                            CupertinoIcons.doc,
                            color: application.theme.fontColor1.withAlpha(200),
                            size: iconSize,
                          ),
          ],
        ),
      ),
    ];
  }

  List<double?> _getPlaceholderWH(List<double> maxWH, List<double> realWH) {
    if (maxWH.length < 2 || maxWH[0] <= 0 || maxWH[1] <= 0) return [null, null];
    if (realWH.length < 2 || realWH[0] <= 0 || realWH[1] <= 0) return [null, null];
    double widthRatio = maxWH[0] / realWH[0];
    double heightRatio = maxWH[1] / realWH[1];
    double minRatio = min(widthRatio, heightRatio);
    return [realWH[0] * minRatio, realWH[1] * minRatio];
  }

  BoxDecoration _getStyles() {
    BoxDecoration decoration;
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
    }
    return decoration;
  }

  Color _getBgColor() {
    return _message.isOutbound ? application.theme.primaryColor : application.theme.backgroundColor2;
  }
}
