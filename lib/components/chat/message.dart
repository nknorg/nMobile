import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/schema/message.dart';

class ChatMessage extends StatefulWidget {
  MessageSchema message;
  MessageSchema prveMessage;
  MessageSchema nextMessage;

  ChatMessage({this.message, this.prveMessage, this.nextMessage});

  @override
  _ChatMessageState createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  @override
  Widget build(BuildContext context) {
    switch (widget.message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        return ChatBubble(
          message: widget.message,
        );
    }
  }
}
