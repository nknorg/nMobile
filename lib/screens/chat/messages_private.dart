import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
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

class ChatMessagesPrivateLayout extends BaseStateFulWidget {
  final ContactSchema contact;

  ChatMessagesPrivateLayout({required this.contact});

  @override
  _ChatMessagesPrivateLayoutState createState() => _ChatMessagesPrivateLayoutState();
}

class _ChatMessagesPrivateLayoutState extends BaseStateFulWidgetState<ChatMessagesPrivateLayout> with Tag {
  StreamController<Map<String, String>> _onInputChangeController = StreamController<Map<String, String>>.broadcast();
  StreamSink<Map<String, String>> get _onInputChangeSink => _onInputChangeController.sink;
  Stream<Map<String, String>> get _onInputChangeStream => _onInputChangeController.stream; // .distinct((prev, next) => prev == next);

  late StreamSubscription _onContactUpdateStreamSubscription;
  late StreamSubscription _onMessageReceiveStreamSubscription;
  late StreamSubscription _onMessageSendStreamSubscription;
  late StreamSubscription _onMessageUpdateStreamSubscription;

  late ContactSchema _contact;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<MessageSchema> _messages = <MessageSchema>[];

  bool _showBottomMenu = false;

  @override
  void onRefreshArguments() async {
    this._contact = widget.contact;
  }

  @override
  void initState() {
    super.initState();
    // contact
    _onContactUpdateStreamSubscription = contactCommon.updateStream.where((event) => event.id == _contact.id).listen((ContactSchema event) {
      setState(() {
        _contact = event;
      });
    });

    // messages
    _onMessageReceiveStreamSubscription = receiveMessage.onSavedStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageSendStreamSubscription = sendMessage.onSavedStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageUpdateStreamSubscription = sendMessage.onUpdateStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
      setState(() {
        _messages = _messages.map((MessageSchema e) => (e.msgId == event.msgId) ? event : e).toList();
      });
    });

    // loadMore
    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50 && !_moreLoading) {
        _moreLoading = true;
        _getDataMessages(false).then((v) {
          _moreLoading = false;
        });
      }
    });

    // messages
    _getDataMessages(true);

    // read
    sessionCommon.setUnReadCount(_contact.clientAddress.toString(), 0, notify: true); // await
  }

  @override
  void dispose() {
    _onInputChangeController.close();
    _onContactUpdateStreamSubscription.cancel();
    _onMessageReceiveStreamSubscription.cancel();
    _onMessageSendStreamSubscription.cancel();
    _onMessageUpdateStreamSubscription.cancel();
    super.dispose();
  }

  _getDataMessages(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _messages = [];
    } else {
      _offset = _messages.length;
    }
    var messages = await chatCommon.queryListAndReadByTargetId(_contact.clientAddress, offset: _offset, limit: 20);
    setState(() {
      _messages = _messages + messages;
    });
  }

  _insertMessage(MessageSchema? schema) async {
    if (schema == null) return;
    if (!schema.isOutbound) {
      // read
      schema = await receiveMessage.read(schema);
      sessionCommon.setUnReadCount(_contact.clientAddress.toString(), 0, notify: true);
    }
    setState(() {
      logger.d("$TAG - messages insert 0:$schema");
      _messages.insert(0, schema!);
    });
  }

  _toggleBottomMenu() async {
    FocusScope.of(context).requestFocus(FocusNode());
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
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  reverse: true,
                  padding: const EdgeInsets.only(bottom: 8, top: 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    return ChatMessageItem(
                      message: _messages[index],
                      contact: _contact,
                      showProfile: false,
                      prevMessage: (index - 1) >= 0 ? _messages[index - 1] : null,
                      nextMessage: (index + 1) < _messages.length ? _messages[index + 1] : null,
                      onLonePress: (ContactSchema contact, _) {
                        _onInputChangeSink.add({"type": ChatSendBar.ChangeTypeAppend, "content": ' @${contact.fullName} '});
                      },
                      onResend: (String msgId) async {
                        MessageSchema? find;
                        this.setState(() {
                          _messages = _messages.where((e) {
                            if (e.msgId != msgId) return true;
                            find = e;
                            return false;
                          }).toList();
                        });
                        await sendMessage.resend(find);
                      },
                    );
                  },
                ),
              ),
              Divider(height: 1, color: _theme.backgroundColor2),
              ChatSendBar(
                targetId: _contact.clientAddress,
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
                onSendPress: (String content) async {
                  return await sendMessage.sendText(_contact.clientAddress, content);
                },
                onChangeStream: _onInputChangeStream,
              ),
              ChatBottomMenu(
                show: _showBottomMenu,
                onPickedImage: (File picked) async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  return await sendMessage.sendImage(_contact.clientAddress, picked);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
