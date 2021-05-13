import 'package:flutter/material.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';

import 'chat_private.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final dynamic arguments;

  ChatScreen({this.arguments}) {
    assert(this.arguments != null);
    assert(this.arguments is ContactSchema || this.arguments is TopicSchema);
  }

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
      return ChatPrivate(
        contact: _contact,
      );
    } else {
      return Container();
    }
  }
}
