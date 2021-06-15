import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
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
  StreamSubscription? _onContactUpdateStreamSubscription;

  ContactSchema? _contact;
  TopicSchema? _topic;

  @override
  void onRefreshArguments() {
    dynamic who = widget.arguments![ChatMessagesScreen.argWho];
    if (who is TopicSchema) {
      _topic = widget.arguments![ChatMessagesScreen.argWho];
      // _targetId = _topic!.topic;
    } else if (who is ContactSchema) {
      this._contact = widget.arguments![ChatMessagesScreen.argWho];
      // _targetId = _contact!.clientAddress;
    }
  }

  @override
  void initState() {
    super.initState();
    // contact
    _onContactUpdateStreamSubscription = contactCommon.updateStream.where((event) => event.id == _contact?.id).listen((ContactSchema event) {
      setState(() {
        _contact = event;
      });
    });
    // TODO:GG messages topic refresh
  }

  @override
  void dispose() {
    _onContactUpdateStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (this._contact != null) {
      return ChatMessagesPrivateLayout(
        contact: _contact!,
      );
    } else if (_topic != null) {
      // TODO:GG messages topic page
      return SizedBox.shrink();
    } else {
      return SizedBox.shrink();
    }
  }
}
