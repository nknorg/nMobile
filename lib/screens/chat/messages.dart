import 'package:flutter/material.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/logger.dart';

import 'messages_private.dart';

class ChatMessagesScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/messages';
  static final String argWho = "who";

  static Future go(BuildContext context, dynamic who) {
    logger.d("ChatMessagesScreen - go - $who");
    if (who == null || !(who is ContactSchema || who is TopicSchema)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argWho: who,
    });
  }

  final Map<String, dynamic>? arguments;

  const ChatMessagesScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ChatMessagesScreenState createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends BaseStateFulWidgetState<ChatMessagesScreen> {
  bool loading = false;
  ContactSchema? _contact;
  TopicSchema? _topic;

  @override
  void onRefreshArguments() {
    dynamic who = widget.arguments![ChatMessagesScreen.argWho];
    if (who is TopicSchema) {
    } else if (who is ContactSchema) {
      this._contact = widget.arguments![ChatMessagesScreen.argWho];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (this._contact != null) {
      return ChatMessagesPrivateLayout(
        contact: _contact!,
      );
    } else {
      return Container();
    }
  }
}
