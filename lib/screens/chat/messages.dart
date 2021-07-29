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
import 'package:nmobile/components/topic/header.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/screens/topic/profile.dart';
import 'package:nmobile/screens/topic/subscribers.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';

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

class _ChatMessagesScreenState extends BaseStateFulWidgetState<ChatMessagesScreen> with Tag {
  TopicSchema? _topic;
  bool? _isJoined;
  ContactSchema? _contact;

  StreamController<Map<String, String>> _onInputChangeController = StreamController<Map<String, String>>.broadcast();
  StreamSink<Map<String, String>> get _onInputChangeSink => _onInputChangeController.sink;
  Stream<Map<String, String>> get _onInputChangeStream => _onInputChangeController.stream; // .distinct((prev, next) => prev == next);

  StreamSubscription? _onTopicUpdateStreamSubscription;
  StreamSubscription? _onTopicDeleteStreamSubscription;
  StreamSubscription? _onSubscriberUpdateStreamSubscription;
  StreamSubscription? _onContactUpdateStreamSubscription;

  StreamSubscription? _onMessageReceiveStreamSubscription;
  StreamSubscription? _onMessageSendStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;
  StreamSubscription? _onMessageUpdateStreamSubscription;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<MessageSchema> _messages = <MessageSchema>[];

  bool _showBottomMenu = false;

  bool _showRecordLock = false;
  bool _showRecordLockLocked = false;

  @override
  void onRefreshArguments() {
    dynamic who = widget.arguments![ChatMessagesScreen.argWho];
    if (who is TopicSchema) {
      this._topic = widget.arguments![ChatMessagesScreen.argWho] ?? _topic;
      this._contact = null;
    } else if (who is ContactSchema) {
      this._topic = null;
      this._contact = widget.arguments![ChatMessagesScreen.argWho] ?? _contact;
    }
  }

  @override
  void initState() {
    super.initState();
    chatCommon.currentChatTargetId = _topic?.topic ?? _contact?.clientAddress;

    // topic
    _onTopicUpdateStreamSubscription = topicCommon.updateStream.where((event) => event.id == _topic?.id).listen((event) {
      setState(() {
        _topic = event;
      });
      _refreshTopicJoined();
    });
    _onTopicDeleteStreamSubscription = topicCommon.deleteStream.where((event) => event == _topic?.topic).listen((String topic) {
      Navigator.of(context).pop();
    });

    // subscriber
    _onSubscriberUpdateStreamSubscription = subscriberCommon.updateStream.where((event) => (event.topic == _topic?.topic) && (_topic?.topic.isNotEmpty == true)).listen((event) {
      subscriberCommon.refreshSubscribers(_topic?.topic, meta: _topic?.isPrivate == true).then((value) {
        _refreshTopicJoined();
      });
    });

    // contact
    _onContactUpdateStreamSubscription = contactCommon.updateStream.where((event) => event.id == _contact?.id).listen((ContactSchema event) {
      setState(() {
        _contact = event;
      });
    });

    // messages
    _onMessageReceiveStreamSubscription = chatInCommon.onSavedStream.where((MessageSchema event) => (event.targetId == _topic?.topic) || (event.targetId == _contact?.clientAddress)).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageSendStreamSubscription = chatOutCommon.onSavedStream.where((MessageSchema event) => (event.targetId == _topic?.topic) || (event.targetId == _contact?.clientAddress)).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((event) {
      setState(() {
        _messages = _messages.where((element) => element.msgId != event).toList();
      });
    });
    _onMessageUpdateStreamSubscription = chatCommon.onUpdateStream.where((MessageSchema event) => (event.targetId == _topic?.topic) || (event.targetId == _contact?.clientAddress)).listen((MessageSchema event) {
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

    // topic
    _refreshTopicJoined(); // await

    // read
    sessionCommon.setUnReadCount(_topic?.topic ?? _contact?.clientAddress, 0, notify: true); // await
  }

  @override
  void dispose() {
    chatCommon.currentChatTargetId = null;

    audioHelper.playerRelease(); // await
    audioHelper.recordRelease(); // await

    _onTopicUpdateStreamSubscription?.cancel();
    _onTopicDeleteStreamSubscription?.cancel();
    _onSubscriberUpdateStreamSubscription?.cancel();
    _onContactUpdateStreamSubscription?.cancel();

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
    var messages = await chatCommon.queryListAndReadByTargetId(_topic?.topic ?? _contact?.clientAddress, offset: _offset, limit: 20);
    setState(() {
      _messages = _messages + messages;
    });
  }

  _insertMessage(MessageSchema? schema) {
    if (schema == null) return;
    if (!schema.isOutbound) {
      // read
      schema = chatCommon.updateMessageStatus(schema, MessageStatus.ReceivedRead);
      sessionCommon.setUnReadCount(_topic?.topic ?? _contact?.clientAddress, 0, notify: true); // await
      if (schema.canDisplayAndRead) Badge.onCountDown(1);
    }
    setState(() {
      logger.d("$TAG - messages insert 0:$schema");
      _messages.insert(0, schema!);
    });
  }

  _refreshTopicJoined() async {
    if (_topic == null || clientCommon.address == null || clientCommon.address!.isEmpty) return;
    bool joined = await topicCommon.isJoined(_topic?.topic, clientCommon.address);
    if (joined && (_topic?.isPrivate == true)) {
      SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(_topic?.topic, clientCommon.address);
      joined = _me?.status == SubscriberStatus.Subscribed;
      if (!joined) {
        logger.i("$TAG - _refreshTopicJoined expire ok but status wrong - me:$_me");
        subscriberCommon.refreshSubscribers(_topic?.topic, meta: _topic?.isPrivate == true).then((value) async {
          await Future.delayed(Duration(seconds: 2), () {
            _refreshTopicJoined();
          });
        });
      }
    }
    if (_isJoined != joined) {
      setState(() {
        _isJoined = joined;
      });
    }
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
    if (this._topic != null) {
      // FUTURE: topic notificationOpen
    } else {
      bool nextOpen = !(_contact?.options?.notificationOpen ?? false);
      String? deviceToken = nextOpen ? await DeviceToken.get() : null;
      if (nextOpen && (deviceToken == null || deviceToken.isEmpty)) {
        Toast.show(_localizations.unavailable_device);
        return;
      }
      setState(() {
        _contact?.options?.notificationOpen = nextOpen;
      });
      // inside update
      contactCommon.setNotificationOpen(_contact, nextOpen, notify: true);
      // outside update
      await chatOutCommon.sendContactOptionsToken(_contact?.clientAddress, deviceToken ?? "");
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;
    int deleteAfterSeconds = (_topic != null ? _topic?.options?.deleteAfterSeconds : _contact?.options?.deleteAfterSeconds) ?? 0;
    Color notifyBellColor = ((_topic != null ? _topic?.options?.notificationOpen : _contact?.options?.notificationOpen) ?? false) ? application.theme.primaryColor : Colors.white38;

    return Layout(
      headerColor: _theme.headBarColor2,
      header: Header(
        backgroundColor: _theme.headBarColor2,
        titleChild: Container(
          child: _topic != null
              ? TopicHeader(
                  topic: _topic!,
                  onTap: () {
                    TopicProfileScreen.go(context, topicId: _topic?.id);
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
                            _localizations.click_to_settings, // TODO:GG topic + locale
                            type: LabelType.h4,
                            color: _theme.fontColor2,
                          ),
                  ),
                )
              : ContactHeader(
                  contact: _contact!,
                  onTap: () {
                    ContactProfileScreen.go(context, contactId: _contact?.id);
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
          _topic != null
              ? SizedBox.shrink() // FUTURE: topic notificationOpen
              : Padding(
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
            child: _topic != null
                ? IconButton(
                    icon: Asset.iconSvg('group', color: Colors.white, width: 24),
                    onPressed: () {
                      TopicSubscribersScreen.go(context, schema: _topic);
                    },
                  )
                : IconButton(
                    icon: Asset.iconSvg('more', color: Colors.white, width: 24),
                    onPressed: () {
                      ContactProfileScreen.go(context, contactId: _contact?.id);
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
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 8, top: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int index) {
                        MessageSchema msg = _messages[index];
                        return ChatMessageItem(
                          message: msg,
                          topic: _topic,
                          contact: _contact,
                          showProfile: !msg.isOutbound && msg.isTopic,
                          prevMessage: (index - 1) >= 0 ? _messages[index - 1] : null,
                          nextMessage: (index + 1) < _messages.length ? _messages[index + 1] : null,
                          onAvatarLonePress: (ContactSchema contact, _) {
                            _onInputChangeSink.add({"type": ChatSendBar.ChangeTypeAppend, "content": ' @${contact.fullName} '});
                          },
                          onResend: (String msgId) async {
                            MessageSchema? find;
                            var messages = _messages.where((e) {
                              if (e.msgId != msgId) return true;
                              find = e;
                              return false;
                            }).toList();
                            if (find != null) messages.insert(0, find!);
                            this.setState(() {
                              _messages = messages;
                            });
                            await chatOutCommon.resend(find, topic: _topic, contact: _contact);
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
                targetId: _topic?.topic ?? _contact?.clientAddress,
                enable: _isJoined,
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
                onSendPress: (String content) async {
                  return await chatOutCommon.sendText(content, topic: _topic, contact: _contact);
                },
                onRecordTap: (bool visible, bool complete, int durationMs) async {
                  if (visible) {
                    String? savePath = await audioHelper.recordStart(
                      _topic?.topic ?? _contact?.clientAddress ?? "",
                      maxDurationS: AudioHelper.MessageRecordMaxDurationS,
                    );
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
                    return await chatOutCommon.sendAudio(content, durationMs / 1000, topic: _topic, contact: _contact);
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
                  return await chatOutCommon.sendImage(picked, topic: _topic, contact: _contact);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
