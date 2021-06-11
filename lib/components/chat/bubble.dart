import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/text/markdown.dart';
import 'package:nmobile/components/tip/popup_menu.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/chat.dart';
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

class _ChatBubbleState extends BaseStateFulWidgetState<ChatBubble> {
  GlobalKey _contentKey = GlobalKey();
  StreamSubscription? _onPieceOutStreamSubscription;

  late MessageSchema _message;
  ContactSchema? _contact;
  late int _msgStatus;

  double _uploadProgress = 1;

  @override
  void initState() {
    super.initState();
    // pieces
    _onPieceOutStreamSubscription = sendMessage.onPieceOutStream.listen((Map<String, dynamic> event) {
      String? msgId = event["msg_id"];
      double? percent = event["percent"];
      if (msgId == null || msgId != this._message.msgId || percent == null) return;
      if (_msgStatus != MessageStatus.Sending) return;
      if (!(_message.content is File)) return;
      if (_uploadProgress >= 1) return;
      this.setState(() {
        _uploadProgress = percent;
      });
    });
  }

  @override
  void onRefreshArguments() {
    _message = widget.message;
    _contact = widget.contact;
    _msgStatus = MessageStatus.get(_message);
    _uploadProgress = ((_message.content is File) && (_msgStatus == MessageStatus.Sending)) ? 0 : 1;
  }

  @override
  void dispose() {
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
    bool shoProgress = isSending && hasProgress && _uploadProgress < 1;
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
          shoProgress
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
    }
    // TODO:GG  burn
    Widget burnWidget = SizedBox.shrink();

    // int? burnAfterSeconds = MessageOptions.getDeleteAfterSeconds(schema);
    // if (schema.deleteTime == null && burnAfterSeconds != null) {
    //   schema.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
    //   await _messageStorage.updateDeleteTime(schema.msgId, schema.deleteTime); // await
    // }

    // if (list.isNotEmpty && handleBurn) {
    //   for (var i = 0; i < list.length; i++) {
    //     MessageSchema messageItem = list[i];
    //     int? burnAfterSeconds = MessageOptions.getDeleteAfterSeconds(messageItem);
    //     if (messageItem.deleteTime == null && burnAfterSeconds != null) {
    //       messageItem.deleteTime = DateTime.now().add(Duration(seconds: burnAfterSeconds));
    //       _messageStorage.updateDeleteTime(messageItem.msgId, messageItem.deleteTime); // await
    //     }
    //   }
    // }
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
              burnWidget,
            ],
          ),
        ),
      ),
    );
  }

  // Widget getBurnTimeView() {
  //   if (contactInfo?.options != null && contactInfo?.options?.deleteAfterSeconds != null) {
  //     return Row(
  //       children: [
  //         Icon(Icons.alarm_on, size: 16, color: DefaultTheme.backgroundLightColor).pad(r: 4),
  //         Label(
  //           Format.durationFormat(Duration(seconds: contactInfo?.options?.deleteAfterSeconds)),
  //           type: LabelType.bodySmall,
  //           color: DefaultTheme.backgroundLightColor,
  //         ),
  //       ],
  //     ).pad(t: 2);
  //   } else {
  //     return Label(
  //       NL10ns.of(context).click_to_settings,
  //       type: LabelType.bodySmall,
  //       color: DefaultTheme.backgroundLightColor,
  //     );
  //   }
  // }

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
    double maxWidth = MediaQuery.of(context).size.width * 0.5;
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
