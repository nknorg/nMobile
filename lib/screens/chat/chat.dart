import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/assets.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final dynamic arguments;

  ChatScreen({this.arguments}) {
    assert(this.arguments != null);
  }

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isChannelChat = false;

  _bindData() {
    if (widget.arguments is TopicSchema) {
      _isChannelChat = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _bindData();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;
    return Layout(
      headerColor: _theme.headBarColor2,
      header: Header(
        backgroundColor: _theme.headBarColor2,
        titleChild: Container(
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red,
                  child: Label(
                    'HR',
                    type: LabelType.bodyLarge,
                    color: Colors.yellow,
                  ),
                ),
              ),
              // TODO: header
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: assetIcon('notification-bell', color: Colors.white, width: 24),
              onPressed: () {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: assetIcon('more', color: Colors.white, width: 24),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Container(),
    );
  }
}
