import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/session_item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';

class ChatSessionListLayout extends StatefulWidget {
  @override
  _ChatSessionListLayoutState createState() => _ChatSessionListLayoutState();
}

class _ChatSessionListLayoutState extends State<ChatSessionListLayout> with AutomaticKeepAliveClientMixin {
  ContactStorage _contactStorage = ContactStorage();
  TopicStorage _topicStorage = TopicStorage();
  ScrollController _scrollController = ScrollController();
  // StreamSubscription? _statusStreamSubscription;
  late StreamSubscription _onMessageStreamSubscription;
  MessageStorage _messageStorage = MessageStorage();
  List<SessionSchema> _sessionList = [];

  bool loading = false;
  int _skip = 0;
  int _limit = 20;

  _sortMessages() {
    setState(() {
      _sessionList.sort((a, b) => a.isTop ? (b.isTop ? -1 : -1) : (b.isTop ? 1 : (b.lastReceiveTime ?? DateTime.now()).compareTo((a.lastReceiveTime ?? DateTime.now()))));
    });
  }

  _updateMessage(SessionSchema? model) {
    if (model == null) return;
    int replaceIndex = -1;
    for (int i = 0; i < _sessionList.length; i++) {
      SessionSchema item = _sessionList[i];
      if (model.targetId == item.targetId) {
        _sessionList.removeAt(i);
        _sessionList.insert(i, model);
        replaceIndex = i;
        break;
      }
    }
    if (replaceIndex < 0) {
      _sessionList.insert(0, model);
    }
    _sortMessages();
  }

  _loadMore() async {
    _skip = _sessionList.length;
    var messages = await _messageStorage.getLastSession(_skip, _limit);
    _sessionList = _sessionList + messages;
    _sortMessages();
  }

  initAsync() async {
    _loadMore();
  }

  @override
  void initState() {
    super.initState();
    initAsync();

    _onMessageStreamSubscription = receiveMessage.onSavedStream.listen((event) {
      String targetId = event.topic ?? event.from;
      _messageStorage.getUpdateSession(targetId).then((value) {
        _updateMessage(value);
      });
    });
    receiveMessage.onSavedStreamSubscriptions.add(_onMessageStreamSubscription);

    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;

      if (offsetFromBottom < 50 && !loading) {
        loading = true;
        _loadMore().then((v) {
          loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _onMessageStreamSubscription.cancel();
    // _statusStreamSubscription?.cancel();
    super.dispose();
  }

  _showItemMenu(SessionSchema item, int index) {
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
                if (item.topic != null) {
                  bool flag = await _topicStorage.setTop(item.targetId!, top);
                  if (flag) {
                    item.isTop = top;
                    _sortMessages();
                  }
                } else {
                  bool flag = await _contactStorage.setTop(item.targetId, top);
                  if (flag) {
                    item.isTop = top;
                    _sortMessages();
                  }
                }
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
                if (item.targetId == null) return;
                int delCount = await _messageStorage.deleteTargetChat(item.targetId!);
                if (delCount > 0) {
                  _sessionList.remove(item);
                  _sortMessages();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 72),
      controller: _scrollController,
      itemCount: _sessionList.length,
      itemBuilder: (BuildContext context, int index) {
        var item = _sessionList[index];
        Widget widget = createSessionWidget(context, item);

        return Column(
          children: [
            InkWell(
              onTap: () async {
                await ChatMessagesScreen.go(context, item.contact);
                _messageStorage.getUpdateSession(item.targetId).then((value) {
                  _updateMessage(value);
                });
              },
              onLongPress: () {
                _showItemMenu(item, index);
              },
              child: widget,
            ),
            Divider(color: item.isTop ? application.theme.backgroundColor3 : application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
