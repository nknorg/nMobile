import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
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
import 'package:nmobile/components/private_group/header.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/topic/header.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/common/media.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/screens/private_group/profile.dart';
import 'package:nmobile/screens/private_group/subscribers.dart';
import 'package:nmobile/screens/topic/profile.dart';
import 'package:nmobile/screens/topic/subscribers.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart' as Path2;
import 'package:nmobile/utils/time.dart';

class ChatMessagesScreen extends BaseStateFulWidget {
  static const String routeName = '/chat/messages';
  static final String argWho = "who";

  static Future go(BuildContext? context, dynamic who) {
    if (context == null) return Future.value(null);
    if (who == null || !(who is ContactSchema || who is PrivateGroupSchema || who is TopicSchema)) return Future.value(null);
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

  String? targetId;
  ContactSchema? _contact;
  TopicSchema? _topic;
  PrivateGroupSchema? _privateGroup;
  bool? _isJoined;

  bool isClientOk = clientCommon.isClientCreated;

  StreamController<Map<String, String>> _onInputChangeController = StreamController<Map<String, String>>.broadcast();
  StreamSink<Map<String, String>> get _onInputChangeSink => _onInputChangeController.sink;
  Stream<Map<String, String>> get _onInputChangeStream => _onInputChangeController.stream; // .distinct((prev, next) => prev == next);

  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusSubscription;

  StreamSubscription? _onContactUpdateStreamSubscription;
  StreamSubscription? _onTopicUpdateStreamSubscription;
  StreamSubscription? _onPrivateGroupUpdateStreamSubscription;
  StreamSubscription? _onPrivateGroupItemUpdateStreamSubscription;

  // StreamSubscription? _onTopicDeleteStreamSubscription;
  StreamSubscription? _onSubscriberAddStreamSubscription;
  StreamSubscription? _onSubscriberUpdateStreamSubscription;

  StreamSubscription? _onMessageReceiveStreamSubscription;
  StreamSubscription? _onMessageSendStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;
  StreamSubscription? _onMessageUpdateStreamSubscription;

  StreamSubscription? _onFetchMediasSubscription;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  ParallelQueue _fetchMsgQueue = ParallelQueue("messages_fetch", onLog: (log, error) => error ? logger.w(log) : null);
  int _pageLimit = 30;
  List<MessageSchema> _messages = <MessageSchema>[];

  Timer? _delRefreshTimer;

  bool _showBottomMenu = false;

  bool _showRecordLock = false;
  bool _showRecordLockLocked = false;

  // bool isPopIng = false;

  @override
  void onRefreshArguments() {
    dynamic who = widget.arguments?[ChatMessagesScreen.argWho];
    if (who is TopicSchema) {
      this._privateGroup = null;
      this._topic = widget.arguments?[ChatMessagesScreen.argWho] ?? _topic;
      this._isJoined = this._topic?.joined == true;
      this._contact = null;
      this.targetId = this._topic?.topic;
    } else if (who is PrivateGroupSchema) {
      this._privateGroup = widget.arguments?[ChatMessagesScreen.argWho] ?? _privateGroup;
      this._topic = null;
      this._isJoined = this._privateGroup?.joined == true;
      this._contact = null;
      this.targetId = this._privateGroup?.groupId;
    } else if (who is ContactSchema) {
      this._privateGroup = null;
      this._topic = null;
      this._isJoined = null;
      this._contact = widget.arguments?[ChatMessagesScreen.argWho] ?? _contact;
      this.targetId = this._contact?.clientAddress;
    }
  }

  @override
  void initState() {
    super.initState();
    chatCommon.currentChatTargetId = this.targetId;
    _moreLoading = false;

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.listen((List<AppLifecycleState> states) {
      if (application.isFromBackground(states)) {
        _readMessages(true, true); // await
      } else if (application.isGoBackground(states)) {
        audioHelper.playerRelease(); // await
        audioHelper.recordRelease(); // await
      }
    });

    // client
    _clientStatusSubscription = clientCommon.statusStream.listen((int status) {
      Future.delayed(Duration(milliseconds: 100), () {
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
      //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
      //   return;
      // }
      setState(() {
        _topic = event;
      });
      _refreshTopicJoined();
      _refreshTopicSubscribers();
    });
    // _onTopicDeleteStreamSubscription = topicCommon.deleteStream.where((event) => event == _topic?.topic).listen((String topic) {
    //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    // });

    // subscriber
    _onSubscriberAddStreamSubscription = subscriberCommon.addStream.where((event) => event.topic == _topic?.topic).listen((SubscriberSchema schema) {
      if (schema.clientAddress == clientCommon.address) {
        _refreshTopicJoined();
      }
      _refreshTopicSubscribers();
    });
    _onSubscriberUpdateStreamSubscription = subscriberCommon.updateStream.where((event) => event.topic == _topic?.topic).listen((event) {
      if (event.clientAddress == clientCommon.address) {
        _refreshTopicJoined();
      } else {
        _refreshTopicSubscribers();
      }
    });

    // privateGroup
    _onPrivateGroupUpdateStreamSubscription = privateGroupCommon.updateGroupStream.where((event) => event.groupId == _privateGroup?.groupId).listen((event) {
      setState(() {
        _privateGroup = event;
        _isJoined = event.joined;
      });
    });
    _onPrivateGroupItemUpdateStreamSubscription = privateGroupCommon.updateGroupItemStream.where((event) => event.groupId == _privateGroup?.groupId).listen((event) {
      // nothing
    });

    // messages
    _onMessageReceiveStreamSubscription = chatInCommon.onSavedStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageSendStreamSubscription = chatOutCommon.onSavedStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
      _insertMessage(event);
    });
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((event) {
      var messages = _messages.where((element) => element.msgId != event).toList();
      setState(() {
        _messages = messages;
      });
      if ((messages.length < (_pageLimit / 2)) && !_moreLoading) {
        _delRefreshTimer?.cancel();
        _delRefreshTimer = null;
        _delRefreshTimer = Timer(Duration(milliseconds: 500), () {
          _moreLoading = true;
          _getDataMessages(false).then((v) {
            _moreLoading = false;
          });
        });
      }
    });
    _onMessageUpdateStreamSubscription = chatCommon.onUpdateStream.where((MessageSchema event) => event.targetId == this.targetId).listen((MessageSchema event) {
      setState(() {
        _messages = _messages.map((MessageSchema e) => (e.msgId == event.msgId) ? event : e).toList();
      });
    });

    // media_screen
    _onFetchMediasSubscription = MediaScreen.onFetchStream.listen((response) async {
      if (response.isEmpty || response[0].isEmpty) return;
      String type = response[0]["type"]?.toString() ?? "";
      if (type != "request") return;
      String target = response[0]["target"]?.toString() ?? "";
      if (target != targetId) return;
      bool isLeft = response[0]["isLeft"] ?? true;
      String msgId = response[0]["msgId"]?.toString() ?? "";
      // medias
      int limit = 10;
      List<MessageSchema> messages = [];
      List<Map<String, dynamic>> medias = [];
      while (medias.length < limit) {
        List<MessageSchema> msgList = await _getMediasMessages(limit, isLeft, msgId);
        if (msgList.isEmpty) break;
        if (isLeft || messages.isEmpty) {
          messages.addAll(msgList);
        } else {
          messages.insertAll(0, msgList);
        }
        msgId = isLeft ? messages.last.msgId : messages.first.msgId;
        medias = _getMediasData(messages);
      }
      if (medias.isEmpty) return; // no return
      // response
      List<Map<String, dynamic>>? request = MediaScreen.createFetchResponse(target, isLeft, msgId, medias);
      if (request != null) MediaScreen.onFetchSink.add(request);
    });

    // loadMore
    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      // logger.d("$TAG - scroll_listen ->>> offsetBottom:$offsetFromBottom = maxScrollExtent:${_scrollController.position.maxScrollExtent} - pixels:${_scrollController.position.pixels}");
      if ((offsetFromBottom < 50) && !_moreLoading) {
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

    // privateGroup
    _checkPrivateGroupVersion();

    // read
    _readMessages(true, true); // await

    // ping
    if ((this._contact != null) && (this._topic == null) && (this._privateGroup == null)) {
      chatOutCommon.sendPing([this.targetId ?? ""], true); // await
      chatOutCommon.sendPing([this.targetId ?? ""], false); // await
    } else if ((this._topic != null) && (this._contact == null) && (this._privateGroup == null)) {
      // chatCommon.setMsgStatusCheckTimer(this.targetId, true, filterSec: 5 * 60); // await
    } else if ((this._privateGroup != null) && (this._contact == null) && (this._topic == null)) {
      // chatCommon.setMsgStatusCheckTimer(this.targetId, true, filterSec: 5 * 60); // await
    }

    // test
    // Future.delayed(Duration(seconds: 1), () => _debugSendText(maxTimes: 1000, delayMS: 100));
  }

  @override
  void dispose() {
    audioHelper.playerRelease(); // await
    audioHelper.recordRelease(); // await

    _appLifeChangeSubscription?.cancel();
    _clientStatusSubscription?.cancel();

    _onContactUpdateStreamSubscription?.cancel();
    _onTopicUpdateStreamSubscription?.cancel();
    _onPrivateGroupUpdateStreamSubscription?.cancel();
    _onPrivateGroupItemUpdateStreamSubscription?.cancel();
    // _onTopicDeleteStreamSubscription?.cancel();
    _onSubscriberAddStreamSubscription?.cancel();
    _onSubscriberUpdateStreamSubscription?.cancel();

    _onInputChangeController.close();
    _onMessageReceiveStreamSubscription?.cancel();
    _onMessageSendStreamSubscription?.cancel();
    _onMessageDeleteStreamSubscription?.cancel();
    _onMessageUpdateStreamSubscription?.cancel();

    _onFetchMediasSubscription?.cancel();

    chatCommon.currentChatTargetId = null;

    super.dispose();
  }

  _getDataMessages(bool refresh) async {
    Function func = () async {
      int _offset = 0;
      if (refresh) {
        _messages = [];
      } else {
        _offset = _messages.length;
      }
      var messages = await chatCommon.queryMessagesByTargetIdVisible(this.targetId, _topic?.topic, _privateGroup?.groupId, offset: _offset, limit: _pageLimit);
      _messages = _messages + messages;
      setState(() {});
    };
    await _fetchMsgQueue.add(() => func());
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
    Future.delayed(Duration(milliseconds: 100), () => _tipNotificationOpen()); // await
  }

  _refreshTopicJoined() async {
    if (_topic == null || !clientCommon.isClientCreated || clientCommon.clientClosing) return;
    bool isJoined = await topicCommon.isSubscribed(_topic?.topic, clientCommon.address);
    if (isJoined && (_topic?.isPrivate == true)) {
      SubscriberSchema? _me = await subscriberCommon.queryByTopicChatId(_topic?.topic, clientCommon.address);
      isJoined = _me?.status == SubscriberStatus.Subscribed;
    }
    if (_isJoined != isJoined) {
      setState(() {
        _isJoined = isJoined;
      });
    }
  }

  _refreshTopicSubscribers({bool fetch = false}) async {
    String? topic = _topic?.topic;
    if (_topic == null || topic == null || topic.isEmpty) return;
    int count = await subscriberCommon.getSubscribersCount(topic, _topic?.isPrivate == true);
    if (_topic?.count != count) {
      await topicCommon.setCount(_topic?.id, count, notify: true);
    }
    // fetch
    if (!clientCommon.isClientCreated || clientCommon.clientClosing) return;
    bool topicCountEmpty = (_topic?.count ?? 0) <= 2;
    bool topicCountSmall = (_topic?.count ?? 0) <= TopicSchema.minRefreshCount;
    if (fetch || topicCountEmpty || topicCountSmall) {
      int lastRefreshAt = topicsCheck[topic] ?? 0;
      if (topicCountEmpty) {
        logger.d("$TAG - _refreshTopicSubscribers - continue by topicCountEmpty");
      } else if ((DateTime.now().millisecondsSinceEpoch - lastRefreshAt) < (1 * 60 * 60 * 1000)) {
        logger.d("$TAG - _refreshTopicSubscribers - between:${DateTime.now().millisecondsSinceEpoch - lastRefreshAt}");
        return;
      }
      topicsCheck[topic] = DateTime.now().millisecondsSinceEpoch;
      await Future.delayed(Duration(milliseconds: 500));
      logger.i("$TAG - _refreshTopicSubscribers - start");
      await subscriberCommon.refreshSubscribers(topic, ownerPubKey: _topic?.ownerPubKey, meta: _topic?.isPrivate == true);
      // refresh again
      int count2 = await subscriberCommon.getSubscribersCount(topic, _topic?.isPrivate == true);
      if (count != count2) {
        await topicCommon.setCount(_topic?.id, count2, notify: true);
      }
    }
  }

  _checkPrivateGroupVersion() async {
    if (_privateGroup == null || clientCommon.address == null) return;
    if (privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.address)) return;
    int nowAt = DateTime.now().millisecondsSinceEpoch;
    bool needOptionsMembers = false;
    int timeOptionsPast = nowAt - (_privateGroup?.optionsRequestAt ?? 0);
    if (_privateGroup?.version?.isNotEmpty == true) {
      if (timeOptionsPast < 1 * 24 * 60 * 60 * 1000) {
        logger.d('$TAG - _checkPrivateGroupVersion - version exist - time < 1d - past:$timeOptionsPast');
        needOptionsMembers = false;
      } else {
        logger.i('$TAG - _checkPrivateGroupVersion - version exist - time > 1d - past:$timeOptionsPast');
        needOptionsMembers = true;
      }
    } else {
      if (timeOptionsPast < 5 * 60 * 1000) {
        logger.d('$TAG - _checkPrivateGroupVersion - version null - time < 5m - past:$timeOptionsPast');
        needOptionsMembers = false;
      } else {
        logger.i('$TAG - _checkPrivateGroupVersion - version null - time > 5m - past:$timeOptionsPast');
        needOptionsMembers = true;
      }
    }
    if (needOptionsMembers) {
      await chatOutCommon.sendPrivateGroupOptionRequest(_privateGroup?.ownerPublicKey, _privateGroup?.groupId).then((version) async {
        _privateGroup?.setOptionsRequestAt(nowAt);
        _privateGroup?.setOptionsRequestedVersion(version);
        await privateGroupCommon.updateGroupData(_privateGroup?.groupId, _privateGroup?.data);
      });
    }
  }

  _readMessages(bool sessionUnreadClear, bool badgeRefresh) async {
    if (sessionUnreadClear) {
      // count not up in chatting
      int type = _topic != null
          ? SessionType.TOPIC
          : _privateGroup != null
              ? SessionType.PRIVATE_GROUP
              : SessionType.CONTACT;
      await sessionCommon.setUnReadCount(this.targetId, type, 0, notify: true);
    }
    if (badgeRefresh) {
      // count not up in chatting
      chatCommon.unReadCountByTargetId(targetId, this._topic?.topic, this._privateGroup?.groupId).then((value) {
        Badge.onCountDown(value); // await
      }).then((value) {
        // set read
        chatCommon.readMessagesBySelf(this.targetId, this._topic?.topic, this._privateGroup?.groupId, this._contact?.clientAddress); // await
      });
    } else {
      // set read
      chatCommon.readMessagesBySelf(this.targetId, this._topic?.topic, this._privateGroup?.groupId, this._contact?.clientAddress); // await
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
    if (this._topic != null || this._privateGroup != null || this._contact == null) return;
    if (chatCommon.currentChatTargetId == null) return;
    bool? isOpen = _topic?.options?.notificationOpen ?? _privateGroup?.options?.notificationOpen ?? _contact?.options?.notificationOpen;
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
    ModalDialog.of(Global.appContext).confirm(
      title: Global.locale((s) => s.tip_open_send_device_token),
      hasCloseButton: true,
      agree: Button(
        width: double.infinity,
        text: Global.locale((s) => s.ok),
        backgroundColor: application.theme.primaryColor,
        onPressed: () {
          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          _toggleNotificationOpen();
        },
      ),
    );
    await SettingsStorage.setNeedTipNotificationOpen(clientCommon.address ?? "", this.targetId);
  }

  _toggleNotificationOpen() async {
    if (this._topic != null) {
      // FUTURE:GG topic notificationOpen
    } else if (this._privateGroup != null) {
      // FUTURE:GG group notificationOpen
    } else {
      bool nextOpen = !(_contact?.options?.notificationOpen ?? false);
      DeviceInfoSchema? _deviceInfo = await deviceInfoCommon.queryLatest(_contact?.clientAddress);
      String? deviceToken = nextOpen ? (await DeviceToken.get(platform: _deviceInfo?.platform, appVersion: _deviceInfo?.appVersion)) : null;
      bool noMobile = false; // (_deviceInfo == null) || (_deviceInfo.appName != Settings.appName);
      bool tokenNull = (deviceToken == null) || deviceToken.isEmpty;
      if (nextOpen && (noMobile || tokenNull)) {
        Toast.show(Global.locale((s) => s.unavailable_device));
        return;
      }
      setState(() {
        _contact?.options?.notificationOpen = nextOpen;
      });
      // inside update
      contactCommon.setNotificationOpen(_contact, nextOpen, notify: true); // await
      // outside update
      await chatOutCommon.sendContactOptionsToken(_contact?.clientAddress, deviceToken);
      SettingsStorage.setNeedTipNotificationOpen(clientCommon.address ?? "", this.targetId); // await
    }
  }

  Future<List<MessageSchema>> _getMediasMessages(int limit, bool isLeft, String msgId) async {
    List<MessageSchema> result = [];
    for (int offset = 0; true; offset += limit) {
      List<MessageSchema> msgList = await chatCommon.queryMessagesByTargetIdWithTypeNotDel(
        targetId,
        _topic?.topic,
        _privateGroup?.groupId,
        [MessageContentType.ipfs, MessageContentType.media, MessageContentType.image, MessageContentType.video],
        offset: offset,
        limit: limit,
      );
      if (msgList.isEmpty) break;
      int index = msgList.indexWhere((element) => element.msgId == msgId);
      if (index >= 0) {
        if (isLeft) {
          offset = offset + index + 1;
        } else {
          offset = offset - limit + index;
          if (offset < 0) {
            offset = 0;
            limit = index;
          }
        }
        result = await chatCommon.queryMessagesByTargetIdWithTypeNotDel(
          targetId,
          _topic?.topic,
          _privateGroup?.groupId,
          [MessageContentType.ipfs, MessageContentType.media, MessageContentType.image, MessageContentType.video],
          offset: offset,
          limit: limit,
        );
        break;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _getMediasData(List<MessageSchema> messages) {
    List<Map<String, dynamic>> medias = [];
    for (var i = 0; i < messages.length; i++) {
      MessageSchema element = messages[i];
      String? path;
      if (element.content is File) {
        if ((element.content as File).existsSync()) {
          path = element.content.path;
        }
      } else if (element.content is String) {
        path = element.content;
      }
      if (path == null || path.isEmpty) continue;
      String contentType = element.contentType;
      if (contentType == MessageContentType.ipfs) {
        int? type = MessageOptions.getFileType(element.options);
        if (type == MessageOptions.fileTypeImage) {
          contentType = MessageContentType.image;
        } else if (type == MessageOptions.fileTypeVideo) {
          contentType = MessageContentType.video;
        }
      }
      Map<String, dynamic>? media;
      if (contentType == MessageContentType.image || contentType == MessageContentType.media) {
        media = MediaScreen.createMediasItemByImagePath(element.msgId, path);
      } else if (contentType == MessageContentType.video) {
        String? thumbnail = MessageOptions.getMediaThumbnailPath(element.options);
        media = MediaScreen.createMediasItemByVideoPath(element.msgId, path, thumbnail);
      }
      if (media != null) medias.add(media);
    }
    return medias;
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;
    int deleteAfterSeconds = (_topic != null ? _topic?.options?.deleteAfterSeconds : (_privateGroup != null ? _privateGroup?.options?.deleteAfterSeconds : _contact?.options?.deleteAfterSeconds)) ?? 0;
    Color notifyBellColor = ((_topic != null ? _topic?.options?.notificationOpen : (_privateGroup != null ? _privateGroup?.options?.notificationOpen : _contact?.options?.notificationOpen)) ?? false) ? application.theme.primaryColor : Colors.white38;

    String? disableTip;
    if (_topic != null && _isJoined == false) {
      if (_topic?.isSubscribeProgress() == true) {
        disableTip = Global.locale((s) => s.subscribing, ctx: context);
      } else if (_topic?.isPrivate == true) {
        disableTip = Global.locale((s) => s.tip_ask_group_owner_permission, ctx: context);
      } else {
        disableTip = Global.locale((s) => s.need_re_subscribe, ctx: context);
      }
    } else if (_privateGroup != null) {
      if ((_privateGroup?.version == null) || (_privateGroup?.version?.isEmpty == true)) {
        disableTip = Global.locale((s) => s.data_synchronization, ctx: context);
      } else if (!(_isJoined == true)) {
        disableTip = Global.locale((s) => s.contact_invite_group_tip, ctx: context);
      }
    }
    if (!isClientOk) {
      disableTip = Global.locale((s) => s.d_chat_not_login, ctx: context);
    }

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
                                Time.formatDuration(Duration(seconds: deleteAfterSeconds)),
                                type: LabelType.bodySmall,
                                color: _theme.backgroundLightColor,
                              ),
                            ],
                          )
                        : Label(
                            "${_topic?.count ?? "--"} ${Global.locale((s) => s.channel_members, ctx: context)}",
                            type: LabelType.h4,
                            color: _theme.fontColor2,
                          ),
                  ),
                )
              : _privateGroup != null
                  ? PrivateGroupHeader(
                      privateGroup: _privateGroup!,
                      onTap: () {
                        PrivateGroupProfileScreen.go(context, groupId: _privateGroup?.groupId);
                      },
                      body: Container(
                        padding: EdgeInsets.only(top: 3),
                        child: deleteAfterSeconds > 0
                            ? Row(
                                children: [
                                  Icon(Icons.alarm_on, size: 16, color: _theme.backgroundLightColor),
                                  SizedBox(width: 4),
                                  Label(
                                    Time.formatDuration(Duration(seconds: deleteAfterSeconds)),
                                    type: LabelType.bodySmall,
                                    color: _theme.backgroundLightColor,
                                  ),
                                ],
                              )
                            : Label(
                                "${_privateGroup?.count ?? "--"} ${Global.locale((s) => s.channel_members, ctx: context)}",
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
                                    Time.formatDuration(Duration(seconds: deleteAfterSeconds)),
                                    type: LabelType.bodySmall,
                                    color: _theme.backgroundLightColor,
                                  ),
                                ],
                              )
                            : Label(
                                Global.locale((s) => s.click_to_settings, ctx: context),
                                type: LabelType.h4,
                                color: _theme.fontColor2,
                              ),
                      ),
                    ),
        ),
        actions: [
          _topic != null || _privateGroup != null
              ? SizedBox.shrink() // FUTURE:GG topic notificationOpen
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
                : _privateGroup != null
                    ? IconButton(
                        icon: Asset.iconSvg('group', color: Colors.white, width: 24),
                        onPressed: () {
                          PrivateGroupSubscribersScreen.go(context, schema: _privateGroup);
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
                        if (index < 0 || index >= _messages.length) return SizedBox.shrink();
                        MessageSchema msg = _messages[index];
                        return ChatMessageItem(
                          message: msg,
                          // contact: _contact,
                          // topic: _topic,
                          // privateGroup: _privateGroup,
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
                            await chatOutCommon.resend(find);
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
                disableTip: disableTip,
                onMenuPressed: () {
                  _toggleBottomMenu();
                },
                onSendPress: (String content) async {
                  return await chatOutCommon.sendText(_topic ?? _privateGroup ?? _contact, content);
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
                      Toast.show(Global.locale((s) => s.failure, ctx: context));
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
                      Toast.show(Global.locale((s) => s.failure, ctx: context));
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
                    logger.d("$TAG - onRecordTap - saveFileSize:${Format.flowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
                    if (size <= MessageSchema.piecesMaxSize) {
                      return chatOutCommon.sendAudio(_topic ?? _privateGroup ?? _contact, content, durationMs / 1000); // await
                    } else {
                      return chatOutCommon.saveIpfs(_topic ?? _privateGroup ?? _contact, {
                        "path": savePath,
                        "size": size,
                        "name": "",
                        "fileExt": Path2.Path.getFileExt(content, FileHelper.DEFAULT_AUDIO_EXT),
                        "mimeType": "audio",
                        "duration": durationMs / 1000,
                      }); // await
                    }
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
                      target: targetId,
                      show: _showBottomMenu,
                      onPicked: (List<Map<String, dynamic>> results) async {
                        if (mounted) FocusScope.of(context).requestFocus(FocusNode());
                        if (results.isEmpty) return;
                        for (var i = 0; i < results.length; i++) {
                          Map<String, dynamic> result = results[i];
                          String path = result["path"] ?? "";
                          int size = int.tryParse(result["size"]?.toString() ?? "") ?? File(path).lengthSync();
                          String? mimeType = result["mimeType"];
                          double durationS = double.tryParse(result["duration"]?.toString() ?? "") ?? 0;
                          if (path.isEmpty) continue;
                          // no message_type(video/file), and result no mime_type from file_picker
                          // so big_file and video+file go with type_ipfs
                          if ((mimeType?.contains("image") == true) && (size <= MessageSchema.piecesMaxSize)) {
                            chatOutCommon.sendImage(_topic ?? _privateGroup ?? _contact, File(path)); // await
                          } else if ((mimeType?.contains("audio") == true) && (size <= MessageSchema.piecesMaxSize)) {
                            chatOutCommon.sendAudio(_topic ?? _privateGroup ?? _contact, File(path), durationS); // await
                          } else {
                            chatOutCommon.saveIpfs(_topic ?? _privateGroup ?? _contact, result); // await
                          }
                        }
                      },
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
