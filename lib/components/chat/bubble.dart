import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/text/markdown.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/format.dart';

import '../text/markdown.dart';

class ChatBubble extends BaseStateFulWidget {
  final MessageSchema message;
  final ContactSchema contact;
  final bool showTime;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? resendMessage;

  ChatBubble({
    required this.message,
    required this.contact,
    this.showTime = false,
    this.onChanged,
    this.resendMessage,
  });

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends BaseStateFulWidgetState<ChatBubble> {
  GlobalKey _popupMenuKey = GlobalKey();

  late MessageSchema _message;
  late ContactSchema _contact;

  @override
  void onRefreshArguments() {
    _message = widget.message;
    _contact = widget.contact;
  }

  // TODO:GG popMenu
  // _textPopupMenuShow() {
  //   PopupMenu popupMenu = PopupMenu(
  //     context: context,
  //     maxColumn: 4,
  //     items: [
  //       MenuItem(
  //         userInfo: 0,
  //         title: S.of(context).copy,
  //         textStyle: TextStyle(color: application.theme.fontLightColor, fontSize: 12),
  //       ),
  //     ],
  //     onClickMenu: (MenuItemProvider item) {
  //       var index = (item as MenuItem).userInfo;
  //       switch (index) {
  //         case 0:
  //           copyText(_message.content, context: context);
  //           break;
  //       }
  //     },
  //   );
  //   popupMenu.show(widgetKey: popupMenuKey);
  // }

  @override
  Widget build(BuildContext context) {
    bool isSendOut = _message.isOutbound;

    List styles = _getStyles();
    BoxDecoration decoration = styles[0];
    bool dark = styles[1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  _getContent(decoration, dark),
                ],
              ),
            ),
          ),
          isSendOut ? _getAvatar(isSendOut) : SizedBox.shrink(),
        ],
      ),
    );
  }

  // TODO:GG time
  Widget _getTime() {
    Widget timeWidget;
    String timeFormat = formatChatTime(_message.sendTime);
    return SizedBox.shrink();
  }

  Widget _getAvatar(bool self) {
    if (self) {
      return contactCommon.currentUser != null ? ContactAvatar(contact: contactCommon.currentUser!, radius: 24) : SizedBox(width: 24 * 2);
    }
    return ContactAvatar(contact: _contact, radius: 24);
  }

  Widget _getName(bool self) {
    return Label(
      self ? (contactCommon.currentUser?.getDisplayName ?? "") : _contact.getDisplayName,
      type: LabelType.h3,
      color: application.theme.primaryColor,
    );
  }

  Widget _getContent(BoxDecoration decoration, bool dark) {
    double maxWidth = MediaQuery.of(context).size.width - 12 * 2 * 2 - (24 * 2) * 2 - 8 * 2;

    Widget _body = SizedBox.shrink();
    switch (_message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        _body = _getContentTextBody(dark);
        break;
      case ContentType.image:
        _body = _getContentImageBody();
        break;
      // TODO:GG contentTypeView
    }
    // TODO:GG burn
    Widget burnWidget = SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(10),
      decoration: decoration,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _body,
            burnWidget,
          ],
        ),
      ),
    );
  }

  Widget _getContentTextBody(bool dark) {
    return Markdown(data: _message.content, dark: dark);
  }

  Widget _getContentImageBody() {
    return Image.file(_message.content as File);
  }

  List<dynamic> _getStyles() {
    SkinTheme _theme = application.theme;
    int msgStatus = MessageStatus.get(_message);

    BoxDecoration decoration;
    bool dark = false;
    if (msgStatus == MessageStatus.Sending || msgStatus == MessageStatus.SendSuccess) {
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
    } else if (msgStatus == MessageStatus.SendWithReceipt) {
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
    } else if (msgStatus == MessageStatus.SendFail) {
      decoration = BoxDecoration(
        color: _theme.fallColor.withAlpha(178),
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
