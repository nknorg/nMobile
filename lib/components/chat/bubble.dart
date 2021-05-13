import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/message.dart';

enum BubbleStyle { SendSuccess, SendFailed, Received }

class ChatBubble extends StatefulWidget {
  BubbleStyle style;
  MessageSchema message;
  ValueChanged<String> onChanged;
  ValueChanged<String> resendMessage;

  ChatBubble({
    this.message,
    this.style,
    this.onChanged,
    this.resendMessage,
  }) {
    if (message.messageStatus == MessageStatus.MessageSendFail) {
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
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Label(widget.message.content),
    );
  }
}
