import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bottom_menu.dart';
import 'package:nmobile/components/chat/message_item.dart';
import 'package:nmobile/components/chat/send_bar.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class ChatMessagesPrivateLayout extends StatefulWidget {
  final ContactSchema contact;

  ChatMessagesPrivateLayout({required this.contact});

  @override
  _ChatMessagesPrivateLayoutState createState() => _ChatMessagesPrivateLayoutState();
}

class _ChatMessagesPrivateLayoutState extends State<ChatMessagesPrivateLayout> {
  final int _messagesLimit = 20;
  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;

  late ContactSchema _contact;

  late StreamSubscription _onContactUpdateStreamSubscription;
  late StreamSubscription _onMessageReceiveStreamSubscription;
  late StreamSubscription _onMessageSendStreamSubscription;
  late StreamSubscription _onMessageUpdateStreamSubscription;

  List<MessageSchema> _messages = <MessageSchema>[];

  bool _showBottomMenu = false;

  @override
  void initState() {
    super.initState();
    this._contact = widget.contact;

    // contact
    _onContactUpdateStreamSubscription = contactCommon.updateStream.listen((List<ContactSchema> list) {
      if (list.isEmpty) return;
      List result = list.where((element) => element.id == _contact.id).toList();
      if (result.isNotEmpty) {
        if (mounted) {
          setState(() {
            _contact = result[0];
          });
        }
      }
    });
    // onReceive + OnSaveSqlite
    _onMessageReceiveStreamSubscription = receiveMessage.onSavedStream.where((MessageSchema event) => event.getTargetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    // onSaveSqlite (no_send_success)
    _onMessageSendStreamSubscription = sendMessage.onSavedStream.where((MessageSchema event) => event.getTargetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    // onStatusUpdate (success + fail + receipt)
    _onMessageUpdateStreamSubscription = sendMessage.onUpdateStream.where((MessageSchema event) => event.getTargetId == _contact.clientAddress).listen((MessageSchema event) {
      if (mounted) {
        setState(() {
          _messages = _messages.map((MessageSchema e) => (e.msgId == event.msgId) ? event : e).toList();
        });
      }
    });

    // loadMore
    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50 && !_moreLoading) {
        _moreLoading = true;
        _loadMore().then((v) {
          _moreLoading = false;
        });
      }
    });

    // init
    initDataAsync();
  }

  @override
  void dispose() {
    super.dispose();
    _onContactUpdateStreamSubscription.cancel();
    _onMessageReceiveStreamSubscription.cancel();
    _onMessageSendStreamSubscription.cancel();
    _onMessageUpdateStreamSubscription.cancel();
  }

  initDataAsync() async {
    await _loadMore();
  }

  _insertMessage(MessageSchema? schema) async {
    if (schema == null) return;
    if (!schema.isOutbound) {
      // read
      schema = await receiveMessage.read(schema);
    }
    if (mounted) {
      setState(() {
        logger.i("messages insert 0:$schema");
        _messages.insert(0, schema!);
      });
    }
  }

  _loadMore() async {
    int _offset = _messages.length;
    var messages = await chatCommon.queryListAndReadByTargetId(_contact.clientAddress, offset: _offset, limit: _messagesLimit);
    setState(() {
      _messages = _messages + messages;
    });
  }

  _toggleBottomMenu() async {
    setState(() {
      _showBottomMenu = !_showBottomMenu;
    });
  }

  // TODO:GG refactor
  _send(String content) async {
    if (chatCommon.id == null) return;
    MessageSchema send = MessageSchema.fromSend(
      uuid.v4(),
      chatCommon.id!,
      ContentType.text,
      to: _contact.clientAddress,
      content: content,
    );
    await sendMessage.sendMessage(send);
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
            onTap: () {
              ContactProfileScreen.go(context, contactId: _contact.id);
            },
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
              icon: Asset.iconSvg('notification-bell', color: Colors.white, width: 24),
              onPressed: () {
                // TODO:GG notification
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Asset.iconSvg('more', color: Colors.white, width: 24),
              onPressed: () {
                ContactProfileScreen.go(context, contactId: _contact.id);
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
                  padding: const EdgeInsets.only(left: 12, right: 16),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    reverse: true,
                    padding: const EdgeInsets.only(bottom: 8, top: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      MessageSchema message = _messages[index];
                      ContactSchema contact = _contact;

                      // Fixme: show time
                      bool showTime = false;
                      if (index >= _messages.length - 1) {
                        showTime = true;
                      } else {
                        if (index + 1 < _messages.length) {
                          // TODO:GG refactor
                          var targetMessage = _messages[index + 1];
                          // if (message.sendTime.isAfter(targetMessage.sendTime?.add(Duration(minutes: 3)))) {
                          //   showTime = true;
                          // }
                        }
                      }

                      return ChatMessageItem(
                        message: message,
                        contact: contact,
                        showTime: showTime,
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
                onSendPress: (String content) {
                  _send(content);
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
