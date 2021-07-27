import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/client/client.dart';
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
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/utils.dart';

class ChatSessionListLayout extends BaseStateFulWidget {
  ContactSchema current;

  ChatSessionListLayout(this.current);

  @override
  _ChatSessionListLayoutState createState() => _ChatSessionListLayoutState();
}

class _ChatSessionListLayoutState extends BaseStateFulWidgetState<ChatSessionListLayout> {
  SettingsStorage _settingsStorage = SettingsStorage();
  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _clientStatusChangeSubscription;
  StreamSubscription? _contactCurrentUpdateSubscription;
  StreamSubscription? _sessionAddSubscription;
  StreamSubscription? _sessionDeleteSubscription;
  StreamSubscription? _sessionUpdateSubscription;
  StreamSubscription? _onTopicDeleteStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;

  ContactSchema? _current;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<SessionSchema> _sessionList = [];

  bool _isShowTip = true;
  bool checked = false;

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
    _appLifeChangeSubscription = application.appLifeStream.listen((List<AppLifecycleState> states) {
      // do something
    });

    // client
    _clientStatusChangeSubscription = clientCommon.statusStream.listen((int status) {
      if (status == ClientConnectStatus.connected) {
        topicCommon.checkAllTopics(subscribers: !checked);
        checked = true;
      }
    });

    // session
    _sessionAddSubscription = sessionCommon.addStream.listen((SessionSchema event) {
      _sessionList.insert(0, event);
      _sortMessages();
    });
    _sessionDeleteSubscription = sessionCommon.deleteStream.listen((String event) {
      setState(() {
        _sessionList = _sessionList.where((element) => element.targetId != event).toList();
      });
    });
    _sessionUpdateSubscription = sessionCommon.updateStream.listen((SessionSchema event) {
      var finds = _sessionList.where((element) => element.targetId == event.targetId).toList();
      if (finds.isEmpty) {
        _sessionList.insert(0, event);
      } else {
        _sessionList = _sessionList.map((SessionSchema e) => e.targetId != event.targetId ? e : event).toList();
      }
      _sortMessages();
    });

    // topic
    _onTopicDeleteStreamSubscription = topicCommon.deleteStream.listen((String topic) {
      setState(() {
        _sessionList = _sessionList.where((element) => element.targetId != topic).toList();
      });
    });

    // message
    _onMessageDeleteStreamSubscription = chatCommon.onDeleteStream.listen((String msgId) {
      setState(() {
        _sessionList.forEach((SessionSchema element) async {
          if (element.lastMessageOptions != null && element.lastMessageOptions!["msg_id"] == msgId) {
            MessageSchema oldLastMsg = MessageSchema.fromMap(element.lastMessageOptions!);
            MessageSchema? lastMessage = await sessionCommon.findLastMessage(element);
            if (lastMessage == null) {
              sessionCommon.delete(element.targetId, notify: true);
              return;
            }
            lastMessage.sendTime = oldLastMsg.sendTime; // for sort
            element.lastMessageTime = lastMessage.sendTime;
            element.lastMessageOptions = lastMessage.toMap();
            int unreadCount = oldLastMsg.canDisplayAndRead ? element.unReadCount - 1 : element.unReadCount;
            element.unReadCount = unreadCount > 0 ? unreadCount : 0;
            sessionCommon.setLastMessageAndUnReadCount(element.targetId, lastMessage, element.unReadCount, notify: true);
          }
        });
      });
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
    _settingsStorage.getSettings(SettingsStorage.CHAT_TIP_STATUS).then((value) {
      bool showed = value != null && value != "false" && value != false;
      setState(() {
        _isShowTip = !showed;
      });
    });

    // badge
    Badge.refreshCount();

    // TODO:GG auth
  }

  @override
  void dispose() {
    _appLifeChangeSubscription?.cancel();
    _clientStatusChangeSubscription?.cancel();
    _contactCurrentUpdateSubscription?.cancel();
    _sessionAddSubscription?.cancel();
    _sessionDeleteSubscription?.cancel();
    _sessionUpdateSubscription?.cancel();
    _onTopicDeleteStreamSubscription?.cancel();
    _onMessageDeleteStreamSubscription?.cancel();
    super.dispose();
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
      _sessionList += messages;
    });
  }

  _sortMessages() {
    setState(() {
      _sessionList.sort((a, b) => a.isTop ? (b.isTop ? (b.lastMessageTime ?? DateTime.now()).compareTo((a.lastMessageTime ?? DateTime.now())) : -1) : (b.isTop ? 1 : (b.lastMessageTime ?? DateTime.now()).compareTo((a.lastMessageTime ?? DateTime.now()))));
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
                Navigator.of(context).pop();
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
                Navigator.of(context).pop();
                ModalDialog.of(context).confirm(
                  content: S.of(context).delete_contact_confirm_title, // TODO:GG locale delete session
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
    if (_sessionList.isEmpty) {
      return ChatNoMessageLayout();
    }
    if (_isShowTip) {
      return Column(
        children: [
          _getTipView(),
          Expanded(
            child: _sessionListView(),
          ),
        ],
      );
    } else {
      return _sessionListView();
    }
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
                _settingsStorage.setSettings(SettingsStorage.CHAT_TIP_STATUS, true);
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
