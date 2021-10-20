import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/chat/bottom_menu.dart';
import 'package:nmobile/components/chat/message_item.dart';
import 'package:nmobile/components/chat/send_bar.dart';
import 'package:nmobile/components/contact/header.dart';
import 'package:nmobile/components/dialog/modal.dart';
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
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:uuid/uuid.dart';

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
  static final Map<String, int> topicsCheck = Map();

  TopicSchema? _topic;
  bool? _isJoined;
  ContactSchema? _contact;
  String? targetId;

  bool isClientOk = clientCommon.isClientCreated;

  StreamController<Map<String, String>> _onInputChangeController = StreamController<Map<String, String>>.broadcast();
  StreamSink<Map<String, String>> get _onInputChangeSink => _onInputChangeController.sink;
  Stream<Map<String, String>> get _onInputChangeStream => _onInputChangeController.stream; // .distinct((prev, next) => prev == next);

  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusSubscription;

  StreamSubscription? _onContactUpdateStreamSubscription;
  StreamSubscription? _onTopicUpdateStreamSubscription;
  // StreamSubscription? _onTopicDeleteStreamSubscription;
  StreamSubscription? _onSubscriberAddStreamSubscription;
  StreamSubscription? _onSubscriberUpdateStreamSubscription;

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

  // bool isPopIng = false;

  @override
  void onRefreshArguments() {
    dynamic who = widget.arguments![ChatMessagesScreen.argWho];
    if (who is TopicSchema) {
      this._topic = widget.arguments![ChatMessagesScreen.argWho] ?? _topic;
      this._isJoined = this._topic?.joined == true;
      this._contact = null;
      this.targetId = this._topic?.topic;
    } else if (who is ContactSchema) {
      this._topic = null;
      this._isJoined = null;
      this._contact = widget.arguments![ChatMessagesScreen.argWho] ?? _contact;
      this.targetId = this._contact?.clientAddress;
    }
  }

  @override
  void initState() {
    super.initState();
    chatCommon.currentChatTargetId = this.targetId;

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
      if (application.isFromBackground(states)) {
        _readMessages(true, true); // await
      }
    });

    // client
    _clientStatusSubscription = clientCommon.statusStream.listen((int status) {
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          isClientOk = clientCommon.isClientCreated;
        });
      });
    });

    // contact
    _onContactUpdateStreamSubscription = contactCommon.updateStream.where((event) => event.id == _contact?.id).listen((ContactSchema event) {
      setState(() {
        _contact = event;
      });
    });

    // topic
    // isPopIng = false;
    _onTopicUpdateStreamSubscription = topicCommon.updateStream.where((event) => event.id == _topic?.id).listen((event) {
      // if (!event.joined && !isPopIng) {
      //   isPopIng = true;
      //   Navigator.pop(this.context);
      //   return;
      // }
      setState(() {
        _topic = event;
      });
      _refreshTopicJoined();
      _refreshTopicSubscribers(fetch: false);
    });
    // _onTopicDeleteStreamSubscription = topicCommon.deleteStream.where((event) => event == _topic?.topic).listen((String topic) {
    //   Navigator.pop(this.context);
    // });

    // subscriber
    _onSubscriberAddStreamSubscription = subscriberCommon.addStream.where((event) => event.topic == _topic?.topic).listen((SubscriberSchema schema) {
      _refreshTopicSubscribers(fetch: false);
    });
    _onSubscriberUpdateStreamSubscription = subscriberCommon.updateStream.where((event) => event.topic == _topic?.topic).listen((event) {
      if (event.clientAddress == clientCommon.address) {
        _refreshTopicJoined();
      } else {
        _refreshTopicSubscribers(fetch: false);
      }
    });

    // messages
    _onMessageReceiveStreamSubscription = chatInCommon.onSavedStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageSendStreamSubscription = chatOutCommon.onSavedStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((event) {
      setState(() {
        _messages = _messages.where((element) => element.msgId != event).toList();
      });
    });
    _onMessageUpdateStreamSubscription = chatCommon.onUpdateStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
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
    _refreshTopicSubscribers(); // await

    // read
    _readMessages(true, true); // await

    // ping
    if (this._contact != null && this._topic == null) {
      chatOutCommon.sendPing([this.targetId ?? ""], true); // await
      chatOutCommon.sendPing([this.targetId ?? ""], false); // await
    } else if (this._topic != null && this._contact == null) {
      chatCommon.setMsgStatusCheckTimer(this.targetId, true, refresh: true, filterSec: 5 * 60); // await
    }

    // test
    // Future.delayed(Duration(seconds: 1), () => _debugSendText());
  }

  @override
  void dispose() {
    chatCommon.currentChatTargetId = null;

    audioHelper.playerRelease(); // await
    audioHelper.recordRelease(); // await

    _appLifeChangeSubscription?.cancel();
    _clientStatusSubscription?.cancel();

    _onContactUpdateStreamSubscription?.cancel();
    _onTopicUpdateStreamSubscription?.cancel();
    // _onTopicDeleteStreamSubscription?.cancel();
    _onSubscriberAddStreamSubscription?.cancel();
    _onSubscriberUpdateStreamSubscription?.cancel();

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
    var messages = await chatCommon.queryMessagesByTargetIdVisible(this.targetId, offset: _offset, limit: 20);
    setState(() {
      _messages = _messages + messages;
    });
  }

  _insertMessage(MessageSchema? added) {
    if (added == null) return;
    // read
    if (!added.isOutbound && application.appLifecycleState == AppLifecycleState.resumed) {
      _readMessages(false, false); // await
    }
    // state
    setState(() {
      logger.i("$TAG - messages insert 0 - added:$added");
      _messages.insert(0, added);
    });
    // tip
    Future.delayed(Duration(milliseconds: 500), () => _tipNotificationOpen()); // await
  }

  _refreshTopicJoined() async {
    if (_topic == null || clientCommon.address == null || clientCommon.address!.isEmpty) return;
    bool joined = await topicCommon.isJoined(_topic?.topic, clientCommon.address);
    if (joined && (_topic?.isPrivate == true)) {
      SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(_topic?.topic, clientCommon.address);
      logger.i("$TAG - _refreshTopicJoined - expire ok and subscriber me is - me:$_me");
      joined = _me?.status == SubscriberStatus.Subscribed;
    }
    if (!joined && mounted) {
      topicCommon.checkExpireAndSubscribe(_topic?.topic, refreshSubscribers: false).then((value) {
        Future.delayed(Duration(seconds: 3), () => _refreshTopicJoined());
      });
    }
    if (_isJoined != joined) {
      setState(() {
        _isJoined = joined;
      });
    }
  }

  _refreshTopicSubscribers({bool fetch = true}) async {
    if (_topic == null || clientCommon.address == null || clientCommon.address!.isEmpty) return;
    bool topicCountEmpty = (_topic?.count ?? 0) <= 1;
    // refresh count
    int count = await subscriberCommon.getSubscribersCount(_topic?.topic, _topic?.isPrivate == true);
    if (_topic?.count != count) {
      await topicCommon.setCount(_topic?.id, count, notify: true);
    }
    // fetch
    if (fetch || topicCountEmpty) {
      int lastRefreshAt = topicsCheck[_topic!.topic] ?? 0;
      if (topicCountEmpty) {
        logger.d("$TAG - _refreshTopicSubscribers - continue by topicCountError");
      } else if ((DateTime.now().millisecondsSinceEpoch - lastRefreshAt) < (1 * 60 * 60 * 1000)) {
        logger.d("$TAG - _refreshTopicSubscribers - between:${DateTime.now().millisecondsSinceEpoch - lastRefreshAt}");
        return;
      }
      topicsCheck[_topic!.topic] = DateTime.now().millisecondsSinceEpoch;
      await Future.delayed(Duration(milliseconds: 500));
      logger.i("$TAG - _refreshTopicSubscribers - start");
      await subscriberCommon.refreshSubscribers(_topic?.topic, ownerPubKey: _topic?.ownerPubKey, meta: _topic?.isPrivate == true);
      // refresh again
      int count2 = await subscriberCommon.getSubscribersCount(_topic?.topic, _topic?.isPrivate == true);
      if (count != count2) {
        await topicCommon.setCount(_topic?.id, count2, notify: true);
      }
    }
  }

  _readMessages(bool sessionUnreadClear, bool badgeRefresh) async {
    if (sessionUnreadClear) {
      // count not up in chatting
      await sessionCommon.setUnReadCount(this.targetId, 0, notify: true);
    }
    if (badgeRefresh) {
      // count not up in chatting
      chatCommon.unReadCountByTargetId(targetId).then((value) {
        Badge.onCountDown(value); // await
      }).then((value) {
        // set read
        chatCommon.readMessagesBySelf(this.targetId, this._contact?.clientAddress); // await
      });
    } else {
      // set read
      chatCommon.readMessagesBySelf(this.targetId, this._contact?.clientAddress); // await
    }
  }

  _toggleBottomMenu() async {
    if (mounted) FocusScope.of(context).requestFocus(FocusNode());
    setState(() {
      _showBottomMenu = !_showBottomMenu;
    });
  }

  _hideAll() {
    if (mounted) FocusScope.of(context).requestFocus(FocusNode());
    setState(() {
      _showBottomMenu = false;
    });
  }

  _tipNotificationOpen() async {
    if (this._topic != null || this._contact == null) return;
    bool? isOpen = _topic?.options?.notificationOpen ?? _contact?.options?.notificationOpen;
    if (isOpen == null || isOpen == true) return;
    bool need = await SettingsStorage.isNeedTipNotificationOpen(clientCommon.address ?? "", this.targetId);
    if (!need) return;
    // check
    int sendCount = 0, receiveCount = 0;
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].isOutbound) {
        sendCount++;
      } else {
        receiveCount++;
      }
      if (sendCount >= 3 && receiveCount >= 3) break;
    }
    logger.i("$TAG - _tipNotificationOpen - sendCount:$sendCount - receiveCount:$receiveCount");
    if ((sendCount < 3) || (receiveCount < 3) || !mounted) return;
    // tip dialog
    ModalDialog.of(this.context).confirm(
      title: S.of(context).tip_open_send_device_token,
      hasCloseButton: true,
      agree: Button(
        width: double.infinity,
        text: S.of(context).ok,
        backgroundColor: application.theme.primaryColor,
        onPressed: () {
          Navigator.pop(this.context);
          _toggleNotificationOpen();
        },
      ),
    );
    await SettingsStorage.setNeedTipNotificationOpen(clientCommon.address ?? "", this.targetId);
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
                            "${_topic?.count ?? "--"} ${_localizations.channel_members}",
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
                targetId: this.targetId,
                disableTip: (_isJoined == false) ? S.of(this.context).tip_ask_group_owner_permission : (!isClientOk ? S.of(this.context).d_chat_not_login : null),
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
                onSendPress: (String content) async {
                  return await chatOutCommon.sendText(content, topic: _topic, contact: _contact);
                },
                onInputFocus: (bool focus) {
                  if (focus && _showBottomMenu) {
                    setState(() {
                      _showBottomMenu = false;
                    });
                  }
                },
                onRecordTap: (bool visible, bool complete, int durationMs) async {
                  if (visible) {
                    String? savePath = await audioHelper.recordStart(
                      this.targetId ?? "",
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
                    int size = await content.length();
                    logger.w("$TAG - onRecordTap - saveFileSize:${formatFlowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
                    if (size >= ChatOutCommon.maxBodySize) {
                      Toast.show(S.of(context).file_too_big);
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
              isClientOk && (_isJoined != false)
                  ? ChatBottomMenu(
                      show: _showBottomMenu,
                      onPickedImage: (File picked) async {
                        if (mounted) FocusScope.of(context).requestFocus(FocusNode());
                        // save
                        if (clientCommon.publicKey == null || clientCommon.publicKey!.isEmpty) return null;
                        String? imagePath = Path.getCompleteFile(Path.createLocalFile(
                          hexEncode(clientCommon.publicKey!),
                          SubDirType.chat,
                          "${Uuid().v4()}.${Path.getFileExt(picked) ?? "jpg"}",
                          chatTarget: this.targetId ?? "",
                        ));
                        if (imagePath == null || imagePath.isEmpty) return null;
                        var outputFile = File(imagePath);
                        if (await outputFile.exists()) {
                          await outputFile.delete();
                        }
                        outputFile = await outputFile.create(recursive: true);
                        outputFile = await picked.copy(outputFile.path);
                        picked.delete(); // await
                        logger.i("$TAG - onPickedImage - create chat file - path:${outputFile.path}");
                        // send message
                        return await chatOutCommon.sendImage(outputFile, topic: _topic, contact: _contact);
                      },
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  // _debugSendText({int maxTimes = 100}) async {
  //   for (var i = 0; i < maxTimes; i++) {
  //     String text = "${i + 1} _ ${Uuid().v4()}";
  //     chatOutCommon.sendText(text, topic: _topic, contact: _contact);
  //   }
  // }

  // _debugSendPing({int maxTimes = 100}) async {
  //   if (_topic != null) return;
  //   for (var i = 0; i < maxTimes; i++) {
  //     if (clientCommon.address != null) {
  //       chatOutCommon.sendPing([clientCommon.address!], true);
  //     }
  //   }
  // }

  // _debugSubscribersAdd({int maxCount = 2000}) async {
  //   if (_topic == null) return;
  //   for (var i = 0; i < maxCount; i++) {
  //     Wallet nkn = await Wallet.create(null, config: WalletConfig(password: "12345"));
  //     if (nkn.address.isEmpty || nkn.keystore.isEmpty || nkn.seed.isEmpty) {
  //       logger.w("$TAG - _debugSubscribersAdd - wallet create fail - nkn:${nkn.toString()}");
  //       continue;
  //     }
  //     logger.i("$TAG - _debugSubscribersAdd - wallet create success - nkn:${nkn.toString()}");
  //     Client client = await Client.create(nkn.seed);
  //     String topicHash = await client.subscribe(
  //       topic: genTopicHash(_topic!.topic),
  //       duration: Global.topicDefaultSubscribeHeight,
  //     );
  //     logger.i("$TAG - _debugSubscribersAdd - subscribe success - topicName:${_topic!.topic} - topicHash:$topicHash");
  //     await subscriberCommon.onSubscribe(_topic!.topic, client.address, 0);
  //   }
  // }
}
