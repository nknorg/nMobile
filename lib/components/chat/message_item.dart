import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/format.dart';

class ChatMessageItem extends StatefulWidget {
  final MessageSchema message;
  final ContactSchema contact;
  final MessageSchema prevMessage;
  final MessageSchema nextMessage;
  final bool showTime;

  ChatMessageItem({this.message, this.contact, this.prevMessage, this.nextMessage, this.showTime});

  @override
  _ChatMessageItemState createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  @override
  Widget build(BuildContext context) {
    String timeFormat = formatChatTime(widget.message.timestamp);
    Widget timeWidget = Label(
      timeFormat,
      type: LabelType.bodySmall,
      fontSize: application.theme.bodyText2.fontSize,
    );

    List<Widget> contentsWidget = <Widget>[];
    if (widget.showTime) contentsWidget.add(timeWidget);

    switch (widget.message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        contentsWidget.add(ChatBubble(
          message: widget.message,
          contact: widget.contact,
        ));
    }

    return Column(
      children: contentsWidget,
    );
  }
}
