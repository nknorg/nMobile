import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/chat/bottom_menu.dart';
import 'package:nmobile/components/chat/message.dart';
import 'package:nmobile/components/chat/send_bar.dart';
import 'package:nmobile/components/contact/contact_header.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/assets.dart';

class ChatPrivate extends StatefulWidget {
  final ContactSchema contact;

  ChatPrivate({this.contact});

  @override
  _ChatPrivateState createState() => _ChatPrivateState();
}

class _ChatPrivateState extends State<ChatPrivate> {
  ContactSchema _contact;
  MessageStorage _messageStorage = MessageStorage();
  List<MessageSchema> _messages = <MessageSchema>[];
  StreamSubscription _onMessageStreamSubscription;
  ScrollController _scrollController = ScrollController();
  bool _showBottomMenu = false;

  bool loading = false;
  int _skip = 0;
  int _limit = 20;

  _bindData() {
    _contact = widget.contact;
  }


  _loadMore() async {
    _skip = _messages.length;
    var messages = await _messageStorage.getAndReadTargetMessages(_contact.clientAddress, skip: _skip, limit: _limit);
    if (messages != null) {
      setState(() {
        _messages = _messages + messages;
      });
    }
  }

  initAsync() async {
    _loadMore();
  }

  @override
  void initState() {
    super.initState();
    _bindData();
    initAsync();

    _onMessageStreamSubscription = chat.onReceivedMessage.where((event) => event.from == _contact.clientAddress).listen((event) {
      setState(() {
        _messages.insert(0, event);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _onMessageStreamSubscription?.cancel();
  }

  _toggleBottomMenu() async {
    setState(() {
      _showBottomMenu = !_showBottomMenu;
    });
  }

  _hideAll() {
    FocusScope.of(context).requestFocus(FocusNode());
    setState(() {
      _showBottomMenu = false;
    });
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
          child: ContactHeader(
            contact: _contact,
            body: Label(
              _localizations.click_to_settings,
              type: LabelType.h4,
              color: _theme.fontColor2,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: assetIcon('notification-bell', color: Colors.white, width: 24),
              onPressed: () {
                // TODO
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: assetIcon('more', color: Colors.white, width: 24),
              onPressed: () {
                // TODO
              },
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          _hideAll();
        },
        child: SafeArea(
          child: Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 16, top: 4),
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    controller: _scrollController,
                    itemCount: _messages.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      MessageSchema message = _messages[index];

                      bool showTime;
                      bool hideHeader = false;
                      if (index + 1 >= _messages.length) {
                        showTime = true;
                      } else {
                        // TODO
                        //   showTime = (currentMessage.timestamp.isAfter(preMessage
                        //       .timestamp
                        //       .add(Duration(minutes: 3))));
                        // } else {
                        //   showTime = true;
                        // }
                      }

                      return ChatMessage(
                        message: message,
                      );
                    },
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: _theme.backgroundColor2,
              ),
              ChatSendBar(
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
              ),
              ChatBottomMenu(show: _showBottomMenu),
            ],
          ),
        ),
      ),
    );
  }
}
