import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/format.dart';

class ChatMessageItem extends StatelessWidget {
  final MessageSchema message;
  final ContactSchema contact;
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final bool showTime;
  final Function(String)? onResend;

  ChatMessageItem({required this.message, required this.contact, this.prevMessage, this.nextMessage, this.showTime = false, this.onResend});

  @override
  Widget build(BuildContext context) {
    String timeFormat = formatChatTime(this.message.sendTime);
    Widget timeWidget = Label(
      timeFormat,
      type: LabelType.bodySmall,
      fontSize: application.theme.bodyText2.fontSize ?? 14,
    );

    List<Widget> contentsWidget = <Widget>[];
    if (this.showTime) contentsWidget.add(timeWidget);

    switch (this.message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
      case ContentType.media:
      case ContentType.nknImage:
        contentsWidget.add(
          ChatBubble(
            message: this.message,
            contact: this.contact,
            onResend: this.onResend,
          ),
        );
        break;
      case ContentType.system:
        // TODO
        break;
    }

    return Column(
      children: contentsWidget,
    );
  }
}
