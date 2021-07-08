import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/chat/bottom_menu.dart';
import 'package:nmobile/components/chat/message_item.dart';
import 'package:nmobile/components/chat/send_bar.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
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

  StreamSubscription? _onMessageReceiveStreamSubscription;
  StreamSubscription? _onMessageSendStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;
  StreamSubscription? _onMessageUpdateStreamSubscription;

  late ContactSchema _contact;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<MessageSchema> _messages = <MessageSchema>[];

  bool _showBottomMenu = false;

  bool _showRecordLock = false;
  bool _showRecordLockLocked = false;

  @override
  void onRefreshArguments() {
    this._contact = widget.contact;
  }

  @override
  void initState() {
    super.initState();
    // messages
    _onMessageReceiveStreamSubscription = chatInCommon.onSavedStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageSendStreamSubscription = chatOutCommon.onSavedStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((event) {
      setState(() {
        _messages = _messages.where((element) => element.msgId != event).toList();
      });
    });
    _onMessageUpdateStreamSubscription = chatCommon.onUpdateStream.where((MessageSchema event) => event.targetId == _contact.clientAddress).listen((MessageSchema event) {
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
    audioHelper.playerRelease(); // await
    audioHelper.recordRelease(); // await
    _onInputChangeController.close();
    _onMessageReceiveStreamSubscription?.cancel();
    _onMessageSendStreamSubscription?.cancel();
    _onMessageDeleteStreamSubscription?.cancel();
    _onMessageUpdateStreamSubscription?.cancel();
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
      schema = await chatCommon.updateMessageStatus(schema, MessageStatus.ReceivedRead);
      sessionCommon.setUnReadCount(_contact.clientAddress.toString(), 0, notify: true);
      if (schema.canDisplayAndRead) Badge.onCountDown(1);
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

  _toggleNotificationOpen() async {
    S _localizations = S.of(this.context);
    bool nextOpen = !_contact.notificationOpen;
    String? deviceToken = nextOpen ? await DeviceToken.get() : null;
    if (nextOpen && (deviceToken == null || deviceToken.isEmpty)) {
      Toast.show(_localizations.unavailable_device);
      return;
    }
    setState(() {
      _contact.notificationOpen = nextOpen;
    });
    // inside update
    contactCommon.setNotificationOpen(_contact.id, _contact.notificationOpen, notify: true);
    // outside update
    await chatOutCommon.sendContactOptionsToken(_contact.clientAddress, deviceToken ?? "");
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;
    int deleteAfterSeconds = _contact.options?.deleteAfterSeconds ?? 0;
    Color notifyBellColor = _contact.notificationOpen ? application.theme.primaryColor : Colors.white38;

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
            body: Container(
              padding: EdgeInsets.only(top: 3),
              child: deleteAfterSeconds > 0
                  ? Row(
                      children: [
                        Icon(Icons.alarm_on, size: 16, color: _theme.backgroundLightColor),
                        SizedBox(width: 4),
                        Label(
                          durationFormat(Duration(seconds: deleteAfterSeconds)),
                          type: LabelType.bodySmall,
                          color: _theme.backgroundLightColor,
                        ),
                      ],
                    )
                  : Label(
                      _localizations.click_to_settings,
                      type: LabelType.h4,
                      color: _theme.fontColor2,
                    ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Asset.iconSvg('notification-bell', color: notifyBellColor, width: 24),
              onPressed: () {
                _toggleNotificationOpen();
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
                child: Stack(
                  children: [
                    ListView.builder(
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
                            await chatOutCommon.resend(find, contact: _contact);
                          },
                        );
                      },
                    ),
                    _showRecordLock
                        ? Positioned(
                            width: ChatSendBar.LockActionSize,
                            height: ChatSendBar.LockActionSize,
                            right: ChatSendBar.LockActionMargin,
                            bottom: ChatSendBar.LockActionMargin,
                            child: Container(
                              width: ChatSendBar.LockActionSize,
                              height: ChatSendBar.LockActionSize,
                              decoration: BoxDecoration(
                                color: _showRecordLockLocked ? Colors.red : Colors.white,
                                borderRadius: BorderRadius.all(Radius.circular(ChatSendBar.LockActionSize / 2)),
                              ),
                              child: UnconstrainedBox(
                                child: Asset.iconSvg(
                                  'lock',
                                  width: ChatSendBar.LockActionSize / 2,
                                  color: _showRecordLockLocked ? Colors.white : Colors.red,
                                ),
                              ),
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ),
              Divider(height: 1, color: _theme.backgroundColor2),
              ChatSendBar(
                targetId: _contact.clientAddress,
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
                onSendPress: (String content) async {
                  return await chatOutCommon.sendText(_contact.clientAddress, content, contact: _contact);
                },
                onRecordTap: (bool visible, bool complete, int durationMs) async {
                  if (visible) {
                    String? savePath = await audioHelper.recordStart(_contact.clientAddress, maxDurationS: AudioHelper.MessageRecordMaxDurationS);
                    if (savePath == null || savePath.isEmpty) {
                      Toast.show(S.of(context).failure);
                      await audioHelper.recordStop();
                      return false;
                    }
                    return true;
                  } else {
                    if (durationMs < AudioHelper.MessageRecordMinDurationS * 1000) {
                      await audioHelper.recordStop();
                      return null;
                    }
                    String? savePath = await audioHelper.recordStop();
                    if (savePath == null || savePath.isEmpty) {
                      Toast.show(S.of(context).failure);
                      await audioHelper.recordStop();
                      return null;
                    }
                    File content = File(savePath);
                    if (!complete) {
                      if (await content.exists()) {
                        await content.delete();
                      }
                      await audioHelper.recordStop();
                      return null;
                    }
                    return await chatOutCommon.sendAudio(_contact.clientAddress, content, durationMs / 1000, contact: _contact);
                  }
                },
                onRecordLock: (bool visible, bool lock) {
                  if (_showRecordLock != visible || _showRecordLockLocked != lock) {
                    setState(() {
                      _showRecordLock = visible;
                      _showRecordLockLocked = lock;
                    });
                  }
                  return true;
                },
                onChangeStream: _onInputChangeStream,
              ),
              ChatBottomMenu(
                show: _showBottomMenu,
                onPickedImage: (File picked) async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  return await chatOutCommon.sendImage(_contact.clientAddress, picked, contact: _contact);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
