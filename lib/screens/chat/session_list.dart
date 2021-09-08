import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/chat/session_item.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class ChatSessionListLayout extends BaseStateFulWidget {
  ContactSchema current;

  ChatSessionListLayout(this.current);

  @override
  _ChatSessionListLayoutState createState() => _ChatSessionListLayoutState();
}

class _ChatSessionListLayoutState extends BaseStateFulWidgetState<ChatSessionListLayout> {
  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _contactCurrentUpdateSubscription;
  StreamSubscription? _sessionAddSubscription;
  StreamSubscription? _sessionDeleteSubscription;
  StreamSubscription? _sessionUpdateSubscription;
  StreamSubscription? _onTopicUpdateStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;

  ContactSchema? _current;

  bool _moreLoading = false;
  ScrollController _scrollController = ScrollController();
  List<SessionSchema> _sessionList = [];

  bool _isLoaded = false;
  bool _isShowTip = false;

  @override
  void onRefreshArguments() {
    bool sameUser = _current?.id == widget.current.id;
    _current = widget.current;
    if (!sameUser) {
      _getDataSessions(true);
    }
  }

  @override
  void initState() {
    super.initState();

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.where((event) => event[0] != event[1]).listen((List<AppLifecycleState> states) {
      if (states.length > 0) {
        if (states[states.length - 1] == AppLifecycleState.resumed) {
          _refreshBadge();
        }
      }
    });

    // session
    _sessionAddSubscription = sessionCommon.addStream.listen((SessionSchema event) {
      if (_sessionList.where((element) => element.targetId == event.targetId).toList().isEmpty) {
        _sessionList.insert(0, event);
      }
      _sortMessages();
    });
    _sessionDeleteSubscription = sessionCommon.deleteStream.listen((String event) {
      setState(() {
        _sessionList = _sessionList.where((element) => element.targetId != event).toList();
      });
    });
    _sessionUpdateSubscription = sessionCommon.updateStream.listen((SessionSchema event) {
      if (chatCommon.currentChatTargetId == event.targetId) {
        event.unReadCount = 0;
      }
      var finds = _sessionList.where((element) => element.targetId == event.targetId).toList();
      if (finds.isEmpty) {
        _sessionList.insert(0, event);
      } else {
        _sessionList = _sessionList.map((SessionSchema e) => e.targetId != event.targetId ? e : event).toList();
      }
      _sortMessages();
    });

    // topic
    _onTopicUpdateStreamSubscription = topicCommon.updateStream.listen((TopicSchema event) {
      // if (!event.joined) {
      //   setState(() {
      //     _sessionList = _sessionList.where((element) => element.targetId != event.topic).toList();
      //   });
      // }
    });

    // message
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((String msgId) {
      onMessageDelete(msgId);
    });

    // scroll
    _scrollController.addListener(() {
      if (_moreLoading) return;
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50) {
        _moreLoading = true;
        _getDataSessions(false).then((v) {
          _moreLoading = false;
        });
      }
    });

    // tip
    SettingsStorage.getSettings(SettingsStorage.CHAT_TIP_STATUS).then((value) {
      bool dismiss = (value.toString() == "true") || (value == true);
      setState(() {
        _isShowTip = !dismiss;
      });
    });

    // unread
    _refreshBadge();
  }

  @override
  void dispose() {
    _appLifeChangeSubscription?.cancel();
    _contactCurrentUpdateSubscription?.cancel();
    _sessionAddSubscription?.cancel();
    _sessionDeleteSubscription?.cancel();
    _sessionUpdateSubscription?.cancel();
    _onTopicUpdateStreamSubscription?.cancel();
    _onMessageDeleteStreamSubscription?.cancel();
    super.dispose();
  }

  _refreshBadge() async {
    int unread = await chatCommon.unreadCount();
    Badge.refreshCount(count: unread);
  }

  _getDataSessions(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _sessionList = [];
    } else {
      _offset = _sessionList.length;
    }
    var messages = await sessionCommon.queryListRecent(offset: _offset, limit: 20);
    setState(() {
      _isLoaded = true;
      _sessionList += messages;
    });
  }

  Future onMessageDelete(String msgId) async {
    var findIndex = -1;
    for (var i = 0; i < _sessionList.length; i++) {
      SessionSchema session = _sessionList[i];
      if (session.lastMessageOptions != null && session.lastMessageOptions!["msg_id"] == msgId) {
        findIndex = i;
        break;
      }
    }
    if (findIndex >= 0 && findIndex < _sessionList.length) {
      // find
      SessionSchema session = _sessionList[findIndex];
      MessageSchema oldLastMsg = MessageSchema.fromMap(session.lastMessageOptions!);
      List<MessageSchema> history = await chatCommon.queryMessagesByTargetIdVisible(session.targetId, offset: 0, limit: 1);
      MessageSchema? newLastMsg = history.isNotEmpty ? history[0] : null;
      // update
      if (newLastMsg == null) {
        await sessionCommon.setLastMessageAndUnReadCount(session.targetId, null, session.unReadCount, sendAt: oldLastMsg.sendAt, notify: true);
      } else {
        newLastMsg.sendAt = oldLastMsg.sendAt; // for sort
        session.lastMessageAt = newLastMsg.sendAt;
        session.lastMessageOptions = newLastMsg.toMap();
        int unreadCount = oldLastMsg.canRead ? session.unReadCount - 1 : session.unReadCount;
        session.unReadCount = unreadCount >= 0 ? unreadCount : 0;
        if ((findIndex > (_sessionList.length - 1)) || (_sessionList[findIndex].targetId != session.targetId)) {
          logger.i("ChatSessionListLayout - onMessageDelete - sessions sync again - msgId:$msgId - session:$session");
          return await onMessageDelete(msgId); // sync with sessions lock
        }
        setState(() {
          _sessionList[findIndex] = session;
        });
        await sessionCommon.setLastMessageAndUnReadCount(session.targetId, newLastMsg, session.unReadCount, notify: false);
      }
    }
  }

  _sortMessages() {
    setState(() {
      _sessionList.sort((a, b) => a.isTop ? (b.isTop ? (b.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch).compareTo((a.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch)) : -1) : (b.isTop ? 1 : (b.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch).compareTo((a.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch))));
    });
  }

  _popItemMenu(SessionSchema item, int index) {
    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
          children: [
            SimpleDialogOption(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(item.isTop ? Icons.vertical_align_bottom : Icons.vertical_align_top),
                    ),
                    Label(item.isTop ? S.of(context).top_cancel : S.of(context).top),
                  ],
                ),
              ),
              onPressed: () async {
                Navigator.pop(this.context);
                bool top = !item.isTop;
                sessionCommon.setTop(item.targetId, top, notify: true);
              },
            ),
            SimpleDialogOption(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.delete_outline),
                    ),
                    Label(S.of(context).delete),
                  ],
                ),
              ),
              onPressed: () async {
                Navigator.pop(this.context);
                ModalDialog.of(this.context).confirm(
                  content: S.of(context).delete_contact_confirm_title,
                  hasCloseButton: true,
                  agree: Button(
                    width: double.infinity,
                    text: S.of(context).delete_contact,
                    backgroundColor: application.theme.strongColor,
                    onPressed: () async {
                      Navigator.pop(this.context);
                      await sessionCommon.delete(item.targetId, notify: true);
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _sessionList.isEmpty) {
      return ChatNoMessageLayout();
    }
    return Column(
      children: [
        _getClientStatusView(),
        _isShowTip ? _getTipView() : SizedBox.shrink(),
        Expanded(
          child: _sessionListView(),
        ),
      ],
    );
  }

  _getClientStatusView() {
    return StreamBuilder<bool>(
      stream: clientCommon.connectingVisibleStream,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data == false) {
          return SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          height: Global.screenWidth() / 25 + 20,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: application.theme.backgroundColor6.withAlpha(150), width: 0.5))),
          // color: application.theme.backgroundColor6,
          child: SpinKitThreeBounce(
            color: application.theme.backgroundColor5.withAlpha(100),
            size: Global.screenWidth() / 25,
          ),
        );
      },
    );
  }

  _getTipView() {
    return Container(
      margin: const EdgeInsets.only(top: 25, bottom: 8, left: 20, right: 20),
      padding: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(color: application.theme.backgroundColor2, borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Color(0x190F6EFF), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Asset.iconSvg('lock', width: 24, color: application.theme.primaryColor)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Label(
                        S.of(context).private_messages,
                        type: LabelType.h3,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Label(
                        S.of(context).private_messages_desc,
                        type: LabelType.bodyRegular,
                        softWrap: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: () {
                          launchUrl('https://nmobile.nkn.org/');
                        },
                        child: Label(
                          S.of(context).learn_more,
                          type: LabelType.bodySmall,
                          color: application.theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            child: InkWell(
              onTap: () {
                SettingsStorage.setSettings(SettingsStorage.CHAT_TIP_STATUS, true);
                setState(() {
                  _isShowTip = false;
                });
              },
              child: Asset.iconSvg(
                'close',
                width: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionListView() {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 60),
      controller: _scrollController,
      itemCount: _sessionList.length,
      itemBuilder: (BuildContext context, int index) {
        var session = _sessionList[index];
        return Column(
          children: [
            ChatSessionItem(
              session: session,
              onTap: (who) async {
                await ChatMessagesScreen.go(context, who);
              },
              onLongPress: (who) {
                _popItemMenu(session, index);
              },
            ),
            Divider(color: session.isTop ? application.theme.backgroundColor3 : application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }
}
