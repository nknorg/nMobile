import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/format.dart';

class ChatMessagesItem extends StatefulWidget {
  MessageSchema message;
  ContactSchema contact;
  MessageSchema prveMessage;
  MessageSchema nextMessage;
  bool showTime;

  ChatMessagesItem({this.message, this.contact, this.prveMessage, this.nextMessage, this.showTime});

  @override
  _ChatMessagesItemState createState() => _ChatMessagesItemState();
}

class _ChatMessagesItemState extends State<ChatMessagesItem> {
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
