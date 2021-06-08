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
  final bool showProfile;
  final Function(ContactSchema, MessageSchema)? onLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    required this.contact,
    this.prevMessage,
    this.nextMessage,
    this.showProfile = false,
    this.onResend,
    this.onLonePress,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> contentsWidget = <Widget>[];

    bool showTime = false;
    if (nextMessage == null) {
      showTime = true;
    } else {
      if (message.sendTime != null && nextMessage?.sendTime != null) {
        int curSec = message.sendTime!.millisecondsSinceEpoch ~/ 1000;
        int nextSec = nextMessage!.sendTime!.millisecondsSinceEpoch ~/ 1000;
        if (curSec - nextSec > 60 * 2) {
          showTime = true;
        }
      }
    }

    if (showTime) {
      contentsWidget.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Label(
            formatChatTime(this.message.sendTime),
            type: LabelType.bodySmall,
            fontSize: application.theme.bodyText2.fontSize ?? 14,
          ),
        ),
      );
    }

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
            onLonePress: this.onLonePress,
          ),
        );
        break;
      // TODO:GG contentType
    }

    return Column(
      children: contentsWidget,
    );
  }
}
