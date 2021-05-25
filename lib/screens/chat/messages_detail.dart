import 'package:flutter/material.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';

import 'chat_private.dart';

class ChatMessagesDetailScreen extends StatefulWidget {
  static const String routeName = '/chat/messages_detail';

  final dynamic arguments;

  ChatMessagesDetailScreen({this.arguments}) {
    assert(this.arguments != null);
    assert(this.arguments is ContactSchema || this.arguments is TopicSchema);
  }

  @override
  _ChatMessagesDetailScreenState createState() => _ChatMessagesDetailScreenState();
}

class _ChatMessagesDetailScreenState extends State<ChatMessagesDetailScreen> {
  bool _isPrivateChat = true;
  ContactSchema _contact;
  bool loading = false;

  _bindData() {
    if (widget.arguments is TopicSchema) {
      _isPrivateChat = false;
    } else if (widget.arguments is ContactSchema) {
      _isPrivateChat = true;
      _contact = widget.arguments;
    }
  }

  @override
  void initState() {
    super.initState();
    _bindData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPrivateChat) {
      return ChatPrivateLayout(
        contact: _contact,
      );
    } else {
      return Container();
    }
  }
}
