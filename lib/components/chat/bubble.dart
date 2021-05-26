import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/theme/popup_menu.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/utils.dart';

import '../markdown.dart';

enum BubbleStyle { SendSuccess, SendFailed, Received }

class ChatBubble extends StatefulWidget {
  BubbleStyle style;
  MessageSchema message;
  ContactSchema contact;
  ValueChanged<String> onChanged;
  ValueChanged<String> resendMessage;

  ChatBubble({
    this.message,
    this.contact,
    this.style,
    this.onChanged,
    this.resendMessage,
  }) {
    if (MessageStatus.get(message) == MessageStatus.SendFail) {
      style = BubbleStyle.SendFailed;
    } else if (message.isOutbound) {
      style = BubbleStyle.SendSuccess;
    } else {
      style = BubbleStyle.Received;
    }
  }

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  GlobalKey popupMenuKey = GlobalKey();
  MessageSchema _message;
  ContactSchema _contact;

  // TODO
  _textPopupMenuShow() {
    PopupMenu popupMenu = PopupMenu(
      context: context,
      maxColumn: 4,
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
    popupMenu.show(widgetKey: popupMenuKey);
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    _message = widget.message;
    _contact = widget.contact;

    BoxDecoration decoration;
    Widget timeWidget;
    Widget burnWidget = Container();
    String timeFormat = formatChatTime(_message.sendTime);
    List<Widget> contentsWidget = <Widget>[];
    bool dark = false;
    if (widget.style == BubbleStyle.SendSuccess) {
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
    } else if (widget.style == BubbleStyle.SendFailed) {
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
    contentsWidget.add(
      Markdown(
        data: _message.content,
        dark: dark,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 0,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: ContactAvatar(
                key: ValueKey(_contact?.getDisplayAvatarPath ?? ''),
                contact: _contact,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Label(
                    _contact.getDisplayName,
                    type: LabelType.h3,
                    color: application.theme.primaryColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: decoration,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 272),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: contentsWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
