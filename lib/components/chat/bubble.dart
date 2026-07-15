import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/text/markdown.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/common/media.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/time.dart';
import 'package:nmobile/utils/util.dart';
import 'package:open_filex/open_filex.dart';

class ChatBubble extends BaseStateFulWidget {
  final MessageSchema message;
  final bool showTimeAndStatus;
  final bool hideTopMargin;
  final bool hideBotMargin;
  final bool lastMessageHasReceipt;
  final Function(String)? onResend;

  ChatBubble({
    required this.message,
    this.showTimeAndStatus = true,
    this.hideTopMargin = false,
    this.hideBotMargin = false,
    this.lastMessageHasReceipt = false,
    this.onResend,
  });

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends BaseStateFulWidgetState<ChatBubble> with Tag {
  GlobalKey _contentKey = GlobalKey();
  final MenuController _menuController = MenuController();
  static const double _menuMinWidth = 180;

  StreamSubscription? _onProgressStreamSubscription;
  StreamSubscription? _onPlayProgressSubscription;

  late MessageSchema _message;

  double _fetchProgress = -1;
  double _playProgress = -1;
  String? _thumbnailPath;
  Offset _menuAlignmentOffset = Offset.zero;

  @override
  void onRefreshArguments() {
    _message = widget.message;
    // burning
    _message = chatCommon.burningHandle(_message);
    _message = chatCommon.burningTick(_message, true, onTick: () => setState(() {}));
    // progress
    _refreshProgress();
    // thumbnail
    _refreshMediaThumbnail();
  }

  @override
  void initState() {
    super.initState();
    // progress
    _onProgressStreamSubscription = messageCommon.onProgressStream.listen((Map<String, dynamic> event) {
      String? msgId = event["msg_id"];
      double? percent = event["percent"];
      if ((msgId == null) || (msgId != this._message.msgId)) {
        // just skip
      } else if ((percent == null) || (percent < 0)) {
        _message.temp?["mediaFetchProgress"] = 0;
        if (_fetchProgress != 0) {
          setState(() {
            _fetchProgress = 0;
          });
        }
      } else {
        // logger.v("onPieceOutStream - percent:$percent - msgId:$msgId - receive_msgId:${this._message.msgId}");
        _message.temp?["mediaFetchProgress"] = percent;
        if (_fetchProgress != percent) {
          this.setState(() {
            _fetchProgress = percent;
          });
        }
      }
    });
    // player
    _onPlayProgressSubscription = audioHelper.onPlayProgressStream.listen((Map<String, dynamic> event) {
      String? playerId = event["id"]?.toString();
      double? percent = double.tryParse(event["percent"]?.toString() ?? "0");
      if ((playerId == null) || (playerId != this._message.msgId)) {
        // just skip
      } else if ((percent == null) || (percent < 0)) {
        _message.temp?["mediaPlayProgress"] = 0;
        if (_playProgress != 0) {
          setState(() {
            _playProgress = 0;
          });
        }
      } else {
        // logger.v("onPlayProgressStream - percent:$percent - playerId:$playerId - receive_msgId:${this._message.msgId}");
        _message.temp?["mediaPlayProgress"] = percent;
        if (_playProgress != percent) {
          this.setState(() {
            _playProgress = percent;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _onProgressStreamSubscription?.cancel();
    _onPlayProgressSubscription?.cancel();
    _message.temp?["mediaPlayProgress"] = 0; // need init
    super.dispose();
  }

  void _refreshProgress() {
    if (_message.temp == null) _message.temp = Map();
    Map? temp = _message.temp;
    // fetchProgress
    double fetchProgress = double.tryParse(temp?["mediaFetchProgress"]?.toString() ?? "0") ?? 0;
    if ((_fetchProgress < 0) || (_fetchProgress > 1) || (_fetchProgress != fetchProgress)) {
      _fetchProgress = (_message.status == MessageStatus.Sending) ? fetchProgress : -1;
    }
    // playProgress
    double playProgress = double.tryParse(temp?["mediaPlayProgress"]?.toString() ?? "0") ?? 0;
    if ((_playProgress < 0) || (_playProgress > 1) || (_playProgress != playProgress)) {
      _playProgress = playProgress;
    }
  }

  void _refreshMediaThumbnail() {
    if (_message.temp == null) _message.temp = Map();
    Map? temp = _message.temp;
    if ((_thumbnailPath?.isNotEmpty == true) && (_thumbnailPath == temp?["existsMediaThumbnailPath"])) return;
    if (temp?["existsMediaThumbnailPath"] == null) {
      String? path = MessageOptions.getMediaThumbnailPath(_message.options);
      if ((path != null) && path.isNotEmpty) {
        File file = File(path);
        if (!(file.existsSync())) {
          path = null;
        }
      }
      widget.message.temp?["existsMediaThumbnailPath"] = path;
      if (_thumbnailPath != path) {
        _thumbnailPath = path;
      }
    } else {
      _thumbnailPath = temp?["existsMediaThumbnailPath"];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_message.isDelete) {
      return SizedBox.shrink();
    } else if (_message.canBurning && (_message.content == null)) {
      return SizedBox.shrink();
    } else if ((_message.deleteAt ?? 0) != 0) {
      int deleteAt = _message.deleteAt ?? DateTime.now().millisecondsSinceEpoch;
      if (deleteAt <= DateTime.now().millisecondsSinceEpoch) {
        return SizedBox.shrink();
      }
    }

    bool isSendOut = _message.isOutbound;
    bool isTipBottom = (_message.status == MessageStatus.Success) || (_message.status == MessageStatus.Receipt);

    var widget = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: isSendOut ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: isTipBottom ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        isSendOut ? _widgetStatusTip(isSendOut) : SizedBox.shrink(),
        _widgetBubble(_getStyles()),
        isSendOut ? SizedBox.shrink() : _widgetStatusTip(isSendOut),
      ],
    );

    if (Settings.messageDebugInfo) {
      return Column(children: [widget, _widgetMessageDebugInfo()]);
    }
    return widget;
  }

  Widget _widgetStatusTip(bool self) {
    bool isSendFail = _message.status == MessageStatus.Error;
    bool shouldShowResend = isSendFail;
    if (!shouldShowResend && widget.lastMessageHasReceipt && _message.isOutbound) {
      if (_message.status >= MessageStatus.Success && _message.status < MessageStatus.Receipt) {
        shouldShowResend = true;
      }
    }

    if (shouldShowResend) {
      return ButtonIcon(
        icon: Icon(
          FontAwesomeIcons.circleExclamation,
          size: 20,
          color: application.theme.fallColor,
        ),
        width: 50,
        height: 50,
        padding: EdgeInsets.zero,
        onPressed: () {
          ModalDialog.of(Settings.appContext).confirm(
            title: Settings.locale((s) => s.confirm_resend, ctx: context),
            hasCloseButton: true,
            agree: Button(
              width: double.infinity,
              text: Settings.locale((s) => s.send_message, ctx: context),
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
    return SizedBox.shrink();
  }

  Widget _widgetBubble(BoxDecoration decoration) {
    double maxWidth = Settings.screenWidth() - (12 + 20 * 2 + 8) * 2;

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

    var onTap = _onTapBubble(contentType);
    bool includeCopy = contentType == MessageContentType.text || contentType == MessageContentType.textExtension;

    List<Widget> childs = [SizedBox.shrink()];
    switch (contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        childs = _widgetBubbleText();
        childs.add(SizedBox(height: 1));
        break;
      case MessageContentType.image:
        childs = _widgetBubbleImage();
        childs.add(SizedBox(height: 4));
        break;
      case MessageContentType.audio:
        childs = _widgetBubbleAudio();
        break;
      case MessageContentType.video:
        childs = _widgetBubbleVideo();
        childs.add(SizedBox(height: 4));
        break;
      case MessageContentType.file:
        childs = _widgetBubbleFile();
        childs.add(SizedBox(height: 4));
        break;
    }

    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: MaterialStatePropertyAll(application.theme.backgroundColor4),
        surfaceTintColor: MaterialStatePropertyAll(Colors.transparent),
        elevation: MaterialStatePropertyAll(6),
        shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        padding: MaterialStatePropertyAll(EdgeInsets.zero),
      ),
      alignmentOffset: _menuAlignmentOffset,
      menuChildren: _buildMenuChildren(includeCopy),
      builder: (context, anchorController, child) {
        return Semantics(
          label: 'chat_bubble',
          button: true,
          child: GestureDetector(
            key: _contentKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPressStart: (_) => _openMenu(),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 5),
              decoration: decoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ...childs,
                  _widgetBubbleInfoBottom(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _onTapBubble(String contentType) {
    var onTap;
    switch (contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
        onTap = null; // Open menu via MenuAnchor
        break;
      case MessageContentType.image:
        // image + ipfs_image
        int state = MessageOptions.getIpfsState(_message.options);
        bool fileNative = _message.isOutbound || (_message.contentType != MessageContentType.ipfs);
        bool fileDownloaded = (_message.contentType == MessageContentType.ipfs) && (state == MessageOptions.ipfsStateYes);
        if (_message.isContentFile && (fileNative || fileDownloaded)) {
          File file = _message.content as File;
          Map<String, dynamic>? item = MediaScreen.createMediasItemByImagePath(_message.msgId, file.path);
          if (item != null) {
            onTap = () {
              MediaScreen.go(context, [item], target: _message.targetId, leftMsgId: _message.msgId);
            };
          }
        } else if (state == MessageOptions.ipfsStateNo) {
          onTap = () {
            chatCommon.startIpfsDownload(_message);
          };
        } else if (state == MessageOptions.ipfsStateIng) {
          // FUTURE:GG cancel download and update UI
        }
        break;
      case MessageContentType.audio:
        // just audio, no ipfs_audio
        if (_message.isContentFile) {
          double? durationS = MessageOptions.getMediaDuration(_message.options);
          int? durationMs = (durationS == null) ? null : ((durationS * 1000).round());
          File file = _message.content as File;
          onTap = () {
            audioHelper.playStart(_message.msgId, file.path, durationMs: durationMs);
          };
        }
        break;
      case MessageContentType.video:
        // just ipfs_video, no video
        int state = MessageOptions.getIpfsState(_message.options);
        bool fileNative = _message.isOutbound || (_message.contentType != MessageContentType.ipfs);
        bool fileDownloaded = (_message.contentType == MessageContentType.ipfs) && (state == MessageOptions.ipfsStateYes);
        if (_message.isContentFile && (fileNative || fileDownloaded)) {
          File file = _message.content as File;
          Map<String, dynamic>? item = MediaScreen.createMediasItemByVideoPath(_message.msgId, file.path, _thumbnailPath);
          if (item != null) {
            onTap = () {
              MediaScreen.go(context, [item], target: _message.targetId, leftMsgId: _message.msgId);
            };
          }
        } else if (state == MessageOptions.ipfsStateNo) {
          onTap = () {
            chatCommon.startIpfsDownload(_message);
          };
        } else if (state == MessageOptions.ipfsStateIng) {
          // FUTURE:GG cancel download and update UI
        }
        break;
      case MessageContentType.file:
        // just ipfs_file, no file
        int state = MessageOptions.getIpfsState(_message.options);
        bool fileNative = _message.isOutbound || (_message.contentType != MessageContentType.ipfs);
        bool fileDownloaded = (_message.contentType == MessageContentType.ipfs) && (state == MessageOptions.ipfsStateYes);
        if (_message.isContentFile && (fileNative || fileDownloaded)) {
          File file = _message.content as File;
          onTap = () {
            try {
              OpenFilex.open(file.path);
            } catch (e, st) {
              handleError(e, st);
            }
          };
        } else if (state == MessageOptions.ipfsStateNo) {
          onTap = () {
            chatCommon.startIpfsDownload(_message);
          };
        } else if (state == MessageOptions.ipfsStateIng) {
          // FUTURE:GG delete download and update UI
        }
        break;
    }
    return onTap;
  }

  List<Widget> _buildMenuChildren(bool includeCopy) {
    List<Widget> children = [];
    Widget buildItem({required String keyName, required String label, required IconData icon, required VoidCallback onPressed, Color? textColor, Color? iconColor}) {
      return Semantics(
        label: keyName,
        button: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: _menuMinWidth),
          child: MenuItemButton(
            key: ValueKey(keyName),
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(label, style: TextStyle(color: textColor ?? application.theme.fontLightColor)),
                ),
                SizedBox(width: 12),
                Icon(icon, size: 18, color: iconColor ?? application.theme.fontLightColor),
              ],
            ),
          ),
        ),
      );
    }
    void addDivider() {
      children.add(Divider(height: 1, thickness: 0.5, color: application.theme.lineColor));
    }
    if (includeCopy) {
      children.add(buildItem(
        keyName: 'chat_bubble_menu_copy',
        label: Settings.locale((s) => s.copy, ctx: context),
        icon: Icons.copy_outlined,
        onPressed: () {
          Util.copyText(_message.content?.toString() ?? "");
        },
      ));
      addDivider();
    }

    if (_message.isOutbound) {
      children.add(buildItem(
        keyName: 'chat_bubble_menu_revoke',
        label: Settings.locale((s) => s.revoke, ctx: context),
        icon: Icons.undo,
        onPressed: () {
          ModalDialog.of(Settings.appContext).confirm(
            title: Settings.locale((s) => s.tip, ctx: context),
            content: Settings.locale((s) => s.confirm_revoke, ctx: context),
            agree: Button(
              width: double.infinity,
              text: Settings.locale((s) => s.revoke, ctx: context),
              backgroundColor: application.theme.strongColor,
              onPressed: () async {
                bool ok = await chatOutCommon.sendRevoke(_message.msgId);
                if (ok) await messageCommon.messageDelete(_message, notify: true);
                if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
              },
            ),
            reject: Button(
              width: double.infinity,
              text: Settings.locale((s) => s.cancel, ctx: context),
              fontColor: application.theme.fontColor2,
              backgroundColor: application.theme.backgroundLightColor,
              onPressed: () {
                if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
              },
            ),
          );
        },
      ));
      addDivider();
    }
    children.add(buildItem(
      keyName: 'chat_bubble_menu_delete',
      label: Settings.locale((s) => s.delete, ctx: context),
      icon: Icons.delete_outline,
      textColor: application.theme.fallColor,
      iconColor: application.theme.fallColor,
      onPressed: () {
        ModalDialog.of(Settings.appContext).confirm(
          title: Settings.locale((s) => s.delete_message_confirm_title, ctx: context),
          agree: Button(
            width: double.infinity,
            text: Settings.locale((s) => s.delete, ctx: context),
            backgroundColor: application.theme.strongColor,
            onPressed: () async {
              await messageCommon.messageDelete(_message, notify: true);
              if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            },
          ),
          reject: Button(
            width: double.infinity,
            text: Settings.locale((s) => s.cancel, ctx: context),
            fontColor: application.theme.fontColor2,
            backgroundColor: application.theme.backgroundLightColor,
            onPressed: () {
              if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            },
          ),
        );
      },
    ));
    return children;
  }

  void _openMenu() {
    if (!mounted) return;
    try {
      RenderBox? box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final Offset global = box.localToGlobal(Offset.zero);
        final double anchorTop = global.dy;
        final double anchorHeight = box.size.height;
        final double anchorBottom = anchorTop + anchorHeight;
        double visibleTop;
        double visibleBottom;
        final scrollable = Scrollable.of(context);
        if (scrollable != null) {
          final RenderBox? vpBox = scrollable.context.findRenderObject() as RenderBox?;
          final double vpTop = vpBox?.localToGlobal(Offset.zero).dy ?? 0;
          final double vpBottom = vpTop + scrollable.position.viewportDimension;
          visibleTop = vpTop;
          visibleBottom = vpBottom;
        } else {
          final media = MediaQuery.of(context);
          visibleTop = media.padding.top;
          visibleBottom = media.size.height - media.viewInsets.bottom;
        }

        // Estimate menu height
        final int itemsCount = 1 /*delete*/ + (_message.isOutbound ? 1 : 0) + ((_message.contentType == MessageContentType.text || _message.contentType == MessageContentType.textExtension) ? 1 : 0);
        final double estimatedMenuHeight = itemsCount * 48.0;
        final double gap = 8.0;
        final double spaceBelow = visibleBottom - anchorBottom;
        final double spaceAbove = anchorTop - visibleTop;

        Offset nextOffset = Offset.zero;
        final double needed = estimatedMenuHeight + gap;
        if (spaceBelow < needed) {
          if (spaceAbove >= needed) {
            nextOffset = Offset(0, -needed);
          } else {
            nextOffset = Offset(0, -max(0.0, spaceAbove - gap));
          }
        }
        if (nextOffset != _menuAlignmentOffset) {
          setState(() {
            _menuAlignmentOffset = nextOffset;
          });
        }
      }
    } catch (_) {
      // ignore
    }
    if (!_menuController.isOpen) {
      _menuController.open();
    }
  }

  Widget _widgetBubbleInfoBottom() {
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    String sendTime = Time.formatChatTime(DateTime.fromMillisecondsSinceEpoch(_message.sendAt));
    bool isSending = _message.status == MessageStatus.Sending;

    bool showTime = isSending || widget.showTimeAndStatus;
    bool showBurn = _message.canBurning && (_message.deleteAt != null) && (_message.deleteAt != 0);
    bool showStatus = (isSending || widget.showTimeAndStatus) && _message.isOutbound;

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
              showBurn ? _widgetBurning() : SizedBox.shrink(),
              ((showTime || showBurn) && showStatus) ? SizedBox(width: 4) : SizedBox.shrink(),
              showStatus ? _widgetSendingInfo() : SizedBox.shrink(),
            ],
          )
        : SizedBox(height: 3);
  }

  Widget _widgetBurning() {
    double iconSize = 10;
    double borderSize = iconSize / 10;
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    int? burnAfterSeconds = MessageOptions.getOptionsBurningDeleteSec(_message.options);
    int deleteAfterMs = (burnAfterSeconds ?? 1) * 1000;

    int deleteAt = _message.deleteAt ?? DateTime.now().millisecondsSinceEpoch;
    int nowAt = DateTime.now().millisecondsSinceEpoch;

    double percent = (deleteAfterMs - (deleteAt - nowAt)) / deleteAfterMs;
    percent = (percent >= 0) ? (percent <= 1 ? percent : 1) : 0;

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

  Widget _widgetSendingInfo() {
    double iconSize = 10;
    double borderSize = iconSize / 10;
    Color color = _message.isOutbound ? application.theme.fontLightColor.withAlpha(178) : application.theme.fontColor2.withAlpha(178);

    bool isSending = _message.status == MessageStatus.Sending;
    bool isSendSuccess = _message.status == MessageStatus.Success;
    bool isSendReceipt = _message.status == MessageStatus.Receipt;
    bool isSendRead = _message.status == MessageStatus.Read;

    bool showProgress = isSending && _message.isContentFile && (_fetchProgress < 1) && (_fetchProgress > 0);
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
          value: _fetchProgress,
        ),
      );
    } else if (isSendSuccess) {
      return Icon(FontAwesomeIcons.circleCheck, size: iconSize, color: color);
    } else if (isSendReceipt || isSendRead) {
      return Container(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: iconSize / 2 + borderSize,
              top: borderSize,
              child: Icon(
                isSendReceipt ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.solidCircleCheck,
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
                    isSendReceipt ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.solidCircleCheck,
                    size: iconSize,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  List<Widget> _widgetBubbleText() {
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

  List<Widget> _widgetBubbleImage() {
    double iconSize = min(Settings.screenWidth() * 0.1, Settings.screenHeight() * 0.06);

    double maxWidth = Settings.screenWidth() * 0.55;
    double maxHeight = Settings.screenHeight() * 0.3;
    double minWidth = maxWidth / 2;
    double minHeight = maxHeight / 2;

    List<double> realWH = MessageOptions.getMediaWH(_message.options);
    List<double?> ratioWH = _getPlaceholderWH([maxWidth, maxHeight], realWH);
    double placeholderWidth = ratioWH[0] ?? minWidth;
    double placeholderHeight = ratioWH[1] ?? minHeight;

    Widget child;
    Color? color;
    if (_thumbnailPath != null) {
      child = Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
        cacheWidth: ratioWH[0]?.toInt(),
        cacheHeight: ratioWH[1]?.toInt(),
      );
      color = Colors.black;
    } else {
      if ((_message.isOutbound == false) && (_message.contentType == MessageContentType.ipfs)) {
        int state = MessageOptions.getIpfsState(_message.options);
        if ((state == MessageOptions.ipfsStateYes) && _message.isContentFile) {
          File file = _message.content as File;
          child = Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: ratioWH[0]?.toInt(),
            cacheHeight: ratioWH[1]?.toInt(),
          );
        } else {
          child = SizedBox(
            width: placeholderWidth,
            height: placeholderHeight,
          );
        }
      } else if (_message.isContentFile) {
        File file = _message.content as File;
        child = Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: ratioWH[0]?.toInt(),
          cacheHeight: ratioWH[1]?.toInt(),
        );
      } else {
        child = SizedBox(
          width: placeholderWidth,
          height: placeholderHeight,
        );
      }
      color = Colors.black;
    }
    Widget body = Container(
      width: ratioWH[0],
      height: ratioWH[1],
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      color: color,
      child: child,
    );

    if ((_message.isOutbound == false) && (_message.contentType == MessageContentType.ipfs)) {
      int _size = MessageOptions.getFileSize(_message.options) ?? 0;
      String? fileSize = _size > 0 ? Format.flowSize(_size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'], decimalDigits: 0) : null;
      int state = MessageOptions.getIpfsState(_message.options);

      if (state == MessageOptions.ipfsStateNo || state == MessageOptions.ipfsStateIng) {
        bool showProgress = (_fetchProgress < 1) && (_fetchProgress > 0);
        return [
          Stack(
            alignment: Alignment.center,
            children: [
              body,
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
              (state == MessageOptions.ipfsStateNo)
                  ? Container(
                      width: placeholderWidth,
                      height: placeholderHeight,
                      child: Icon(
                        CupertinoIcons.arrow_down_circle,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    )
                  : Container(
                      width: placeholderWidth,
                      height: placeholderHeight,
                      alignment: Alignment.center,
                      child: Container(
                        width: iconSize * 0.66,
                        height: iconSize * 0.66,
                        child: showProgress
                            ? CircularProgressIndicator(
                                backgroundColor: application.theme.fontColor4.withAlpha(80),
                                color: Colors.white,
                                strokeWidth: 3,
                                value: _fetchProgress,
                              )
                            : SpinKitRing(
                                color: Colors.white,
                                lineWidth: 3,
                                size: iconSize,
                              ),
                      ),
                    ),
            ],
          ),
        ];
      } else {
        // file is exits
      }
    }
    return [body];
  }

  List<Widget> _widgetBubbleAudio() {
    bool isPlaying = (_playProgress > 0) && (_playProgress < 1);

    Color iconColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.primaryColor.withAlpha(200);
    Color textColor = _message.isOutbound ? Colors.white.withAlpha(200) : application.theme.fontColor2.withAlpha(200);
    Color progressBgColor = _message.isOutbound ? Colors.white.withAlpha(230) : application.theme.primaryColor.withAlpha(30);
    Color progressValueColor = _message.isOutbound ? application.theme.backgroundColor4.withAlpha(127) : application.theme.primaryColor.withAlpha(200);

    double? durationS = MessageOptions.getMediaDuration(_message.options);
    double maxDurationS = Settings.durationAudioRecordMaxS;
    double durationRatio = ((durationS ?? (maxDurationS / 2)) > maxDurationS ? maxDurationS : (durationS ?? (maxDurationS / 2))) / maxDurationS;
    double minWidth = Settings.screenWidth() * 0.05;
    double maxWidth = Settings.screenWidth() * 0.35;
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
                  FontAwesomeIcons.circlePause,
                  size: 25,
                  color: iconColor,
                )
              : Icon(
                  FontAwesomeIcons.circlePlay,
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

  List<Widget> _widgetBubbleVideo() {
    double iconSize = min(Settings.screenWidth() * 0.1, Settings.screenHeight() * 0.06);

    double maxWidth = Settings.screenWidth() * 0.55;
    double maxHeight = Settings.screenHeight() * 0.3;
    double minWidth = maxWidth / 2;
    double minHeight = maxHeight / 2;

    List<double> realWH = MessageOptions.getMediaWH(_message.options);
    List<double?> ratioWH = _getPlaceholderWH([maxWidth, maxHeight], realWH);
    double placeholderWidth = ratioWH[0] ?? minWidth;
    double placeholderHeight = ratioWH[1] ?? minHeight;

    double? duration = MessageOptions.getMediaDuration(_message.options);
    String? durationText;
    if ((duration != null) && (duration >= 0)) {
      int min = duration ~/ 60;
      int sec = (duration % 60).toInt();
      String minText = (min >= 10) ? "$min" : "0$min";
      String secText = (sec >= 10) ? "$sec" : "0$sec";
      durationText = "$minText:$secText";
    }

    int state = MessageOptions.getIpfsState(_message.options);
    bool showProgress = (_fetchProgress < 1) && (_fetchProgress > 0);

    return [
      Stack(
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
            color: Colors.black,
            child: (_thumbnailPath != null)
                ? Image.file(
                    File(_thumbnailPath!),
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
                                    value: _fetchProgress,
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
    ];
  }

  List<Widget> _widgetBubbleFile() {
    double iconSize = min(Settings.screenWidth() * 0.1, Settings.screenHeight() * 0.06);

    double labelWidth = Settings.screenWidth() * 0.35;

    String fileName = MessageOptions.getFileName(_message.options) ?? "---";
    int _size = MessageOptions.getFileSize(_message.options) ?? 0;
    String fileSize = _size > 0 ? Format.flowSize(_size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'], decimalDigits: 0) : "--";

    int state = MessageOptions.getIpfsState(_message.options);
    bool showProgress = (_fetchProgress < 1) && (_fetchProgress > 0);

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
                                        value: _fetchProgress,
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
          topRight: Radius.circular(widget.hideTopMargin ? 1 : 12),
          bottomRight: Radius.circular(widget.hideBotMargin ? 1 : (widget.hideTopMargin ? 12 : 2)),
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: _getBgColor(),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.hideTopMargin ? 1 : (widget.hideBotMargin ? 12 : 2)),
          bottomLeft: Radius.circular(widget.hideBotMargin ? 1 : 12),
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

  _widgetMessageDebugInfo() {
    // common
    // String _msgId = _message.msgId;
    // String msgId = "id● ${(_msgId.length > 5) ? _msgId.substring(0, 4) : _msgId}";
    int _successTimes = MessageOptions.getSuccessTimes(_message.options) ?? 0;
    String times = "\ntimes● $_successTimes";
    String _deviceId = _message.deviceId;
    String queueID = (_message.queueId > 0) ? "\nsync● ${_message.queueId}.${(_deviceId.length > 10) ? _deviceId.substring(0, 9) : _deviceId}" : "";
    String _firstQueueIDs = MessageOptions.getFirstMessageQueueIds(_message.options) ?? "";
    String firstQueueIDs = _firstQueueIDs.isNotEmpty ? "\nsync● ${(_firstQueueIDs.length > 25) ? _firstQueueIDs.substring(0, 24) : _firstQueueIDs}" : "";
    String _queueIds = MessageOptions.getMessageQueueIds(_message.options) ?? "";
    String queueIDs = _queueIds.isNotEmpty ? "\nsync● ${(_queueIds.length > 25) ? _queueIds.substring(0, 24) : _queueIds}" : "";

    String sendAt = "\nsend● ${DateFormat("H:m s", Settings.language == 'zh' ? 'zh' : 'en').format(DateTime.fromMillisecondsSinceEpoch(_message.sendAt))}";
    int _receiveAt = _message.receiveAt ?? 0;
    String receiveAt = (_receiveAt > 0) ? "\nack● ${DateFormat("H:m s", Settings.language == 'zh' ? 'zh' : 'en').format(DateTime.fromMillisecondsSinceEpoch(_receiveAt))}" : "";

    // out
    int _sendSuccessAt = MessageOptions.getSendSuccessAt(_message.options) ?? 0;
    String sendSuccessAt = (_sendSuccessAt > 0) ? "\nsend_ok● ${DateFormat("H:m s", Settings.language == 'zh' ? 'zh' : 'en').format(DateTime.fromMillisecondsSinceEpoch(_receiveAt))}" : "";
    int _resendOk = MessageOptions.getResendMuteAt(_message.options) ?? 0;
    String resendMuteAt = (_resendOk > 0) ? "\nresend_ok● ${DateFormat("H:m s", Settings.language == 'zh' ? 'zh' : 'en').format(DateTime.fromMillisecondsSinceEpoch(_resendOk))}" : "";
    String _pushNotifyId = MessageOptions.getPushNotifyId(_message.options) ?? "";
    String pushNotifyId = _pushNotifyId.isNotEmpty ? "\nnotifyID● ${(_pushNotifyId.length > 5) ? _pushNotifyId.substring(0, 4) : _pushNotifyId}" : "";

    // text
    String text = "$times$queueID$firstQueueIDs$queueIDs$sendAt$receiveAt";
    if (_message.isOutbound) {
      text += "$sendSuccessAt$resendMuteAt$pushNotifyId";
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Label(
          text,
          type: LabelType.bodySmall,
          height: 1,
          fontSize: application.theme.iconTextFontSize,
        ),
      ],
    );
  }
}
