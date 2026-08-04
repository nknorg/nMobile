import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/badge.dart' as Badge;
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/chat/session_item.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/chat/no_message.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/util.dart';

import '../../components/text/fixed_text_field.dart';

class ChatSessionListLayout extends BaseStateFulWidget {
  ContactSchema current;

  ChatSessionListLayout(this.current);

  @override
  _ChatSessionListLayoutState createState() => _ChatSessionListLayoutState();
}

class _ChatSessionListLayoutState extends BaseStateFulWidgetState<ChatSessionListLayout> {
  StreamSubscription? _clientStatusChangeSubscription;
  StreamSubscription? _appLifeChangeSubscription;
  StreamSubscription? _contactCurrentUpdateSubscription;
  StreamSubscription? _sessionAddSubscription;
  StreamSubscription? _sessionDeleteSubscription;
  StreamSubscription? _sessionUpdateSubscription;
  StreamSubscription? _onMessageUpdateStreamSubscription;
  StreamSubscription? _onMessageDeleteStreamSubscription;

  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();

  ContactSchema? _current;

  ParallelQueue _queue = ParallelQueue("session_list", onLog: (log, error) => error ? logger.w(log) : null);

  bool _moreLoading = false;
  ScrollController _scrollController = ScrollController();
  List<SessionSchema> _sessionList = [];
  List<SessionSchema> _filteredSessionList = [];
  String _searchQuery = "";

  int clientConnectStatus = ClientConnectStatus.connecting;
  bool clientConnectingVisible = false;

  bool _isLoaded = false;
  bool _isShowTip = false;

  @override
  void onRefreshArguments() {
    bool sameUser = _current?.id == widget.current.id;
    _current = widget.current;
    if (_current == null || !sameUser) {
      _getDataSessions(true);
    }

    _searchFocusNode.unfocus();
  }

  @override
  void initState() {
    super.initState();

    // clientStatus
    _clientStatusChangeSubscription = clientCommon.statusStream.distinct((prev, next) => prev == next).listen((int status) {
      clientConnectStatus = status;
      if ((clientConnectStatus == ClientConnectStatus.connecting) || (clientConnectStatus == ClientConnectStatus.connectPing)) {
        Future.delayed(Duration(seconds: 10)).then((value) {
          setState(() {
            clientConnectingVisible = (clientConnectStatus == ClientConnectStatus.connecting) || (clientConnectStatus == ClientConnectStatus.connectPing);
          });
        });
      } else {
        setState(() {
          clientConnectingVisible = false;
        });
      }
    });

    // appLife
    _appLifeChangeSubscription = application.appLifeStream.listen((bool inBackground) {
      if (inBackground) {
        _refreshBadge(delayMs: 0);
      } else {
        _refreshBadge(delayMs: 1000);
      }
    });

    // session
    _sessionAddSubscription = sessionCommon.addStream.listen((SessionSchema event) {
      _sessionSet(event).then((_) {
        setState(() {});
      });
    });
    _sessionDeleteSubscription = sessionCommon.deleteStream.listen((values) {
      _sessionDel(values[0], values[1]).then((_) {
        setState(() {});
      });
    });
    _sessionUpdateSubscription = sessionCommon.updateStream.listen((SessionSchema event) {
      _sessionSet(event).then((_) {
        setState(() {});
      });
    });

    // message
    _onMessageUpdateStreamSubscription = messageCommon.onUpdateStream.listen((message) {
      _onMessageUpdate(message);
    });
    _onMessageDeleteStreamSubscription = messageCommon.onDeleteStream.listen((String msgId) {
      _onMessageDelete(msgId);
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
    _refreshBadge(delayMs: 1000);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  void activate() {
    super.activate();

    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _clientStatusChangeSubscription?.cancel();
    _appLifeChangeSubscription?.cancel();
    _contactCurrentUpdateSubscription?.cancel();
    _sessionAddSubscription?.cancel();
    _sessionDeleteSubscription?.cancel();
    _sessionUpdateSubscription?.cancel();
    _onMessageUpdateStreamSubscription?.cancel();
    _onMessageDeleteStreamSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  _refreshBadge({int? delayMs}) async {
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    int unread = await sessionCommon.totalUnReadCount();
    Badge.Badge.refreshCount(count: unread);
  }

  _getDataSessions(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _sessionList = [];
    } else {
      _offset = _sessionList.length;
    }
    var sessions = await sessionCommon.queryListRecent(offset: _offset, limit: 20);
    setState(() {
      _isLoaded = true;
      _sessionList += sessions;
    });
    _performSearch(_searchQuery);
  }

  Future _onMessageUpdate(MessageSchema msg) async {
    SessionSchema? session = await _sessionQuery(msg.msgId);
    if (session == null) return;
    await sessionCommon.update(session.targetId, session.type, lastMsg: msg);
  }

  Future _onMessageDelete(String msgId) async {
    SessionSchema? session = await _sessionQuery(msgId);
    if (session == null) return;
    await sessionCommon.update(session.targetId, session.type, lastMsgAt: session.lastMessageAt);
  }

  Future _sessionSet(SessionSchema s) async {
    await _queue.add(() async {
      if (_sessionList.where((element) => (element.targetId == s.targetId) && (element.type == s.type)).toList().isEmpty) {
        _sessionList.insert(0, s);
      } else {
        _sessionList = _sessionList.map((SessionSchema e) => ((e.targetId == s.targetId) && (e.type == s.type)) ? s : e).toList();
      }
      _sessionList.sort((a, b) => a.isTop ? (b.isTop ? (b.lastMessageAt).compareTo((a.lastMessageAt)) : -1) : (b.isTop ? 1 : b.lastMessageAt.compareTo(a.lastMessageAt)));
    });
    _performSearch(_searchQuery);
  }

  Future _sessionDel(String targetId, int targetType) async {
    await _queue.add(() async {
      _sessionList = _sessionList.where((element) => !((element.targetId == targetId) && (element.type == targetType))).toList();
    });

    _performSearch(_searchQuery);
  }

  Future<SessionSchema?> _sessionQuery(String msgId) async {
    return await _queue.add(() async {
      SessionSchema? session;
      for (var i = 0; i < _sessionList.length; i++) {
        SessionSchema index = _sessionList[i];
        if ((index.lastMessageOptions != null) && (index.lastMessageOptions!["msg_id"] == msgId)) {
          session = index;
          break;
        }
      }
      return session;
    });
  }

  Future _clearUnreadAndBadge(String targetId, int targetType) async {
    await sessionCommon.setUnReadCount(targetId, targetType, 0, notify: true);
    SessionSchema? session = await sessionCommon.query(targetId, targetType);
    Badge.Badge.onCountDown(session?.unReadCount ?? 0); // await
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredSessionList = List.from(_sessionList);
      });
      return;
    }

    List<SessionSchema> filtered = await sessionCommon.queryListBySearch(query);
    setState(() {
      _filteredSessionList = filtered;
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
                    Label(item.isTop ? Settings.locale((s) => s.top_cancel, ctx: context) : Settings.locale((s) => s.top, ctx: context)),
                  ],
                ),
              ),
              onPressed: () async {
                if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                bool top = !item.isTop;
                sessionCommon.setTop(item.targetId, item.type, top, notify: true);
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
                    Label(Settings.locale((s) => s.delete, ctx: context)),
                  ],
                ),
              ),
              onPressed: () async {
                if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                ModalDialog.of(Settings.appContext).confirm(
                  content: Settings.locale((s) => s.delete_session_confirm_title, ctx: context),
                  hasCloseButton: true,
                  agree: Button(
                    width: double.infinity,
                    text: Settings.locale((s) => s.delete_session, ctx: context),
                    backgroundColor: application.theme.strongColor,
                    onPressed: () async {
                      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                      // Delete session
                      await sessionCommon.delete(item.targetId, item.type, notify: true);
                      await _clearUnreadAndBadge(item.targetId, item.type); // await
                      _refreshBadge();
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          _getClientStatusView(),
          _isShowTip ? _getTipView() : SizedBox.shrink(),
          Expanded(
            child: _sessionListView(),
          ),
        ],
      ),
    );
  }

  _getClientStatusView() {
    if (!clientConnectingVisible) return SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: Settings.screenWidth() / 25 + 20,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: application.theme.backgroundColor6.withAlpha(150), width: 0.5))),
      // color: application.theme.backgroundColor6,
      child: SpinKitThreeBounce(
        color: application.theme.backgroundColor5.withAlpha(100),
        size: Settings.screenWidth() / 25,
      ),
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
                        Settings.locale((s) => s.private_messages, ctx: context),
                        type: LabelType.h3,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Label(
                        Settings.locale((s) => s.private_messages_desc, ctx: context),
                        type: LabelType.bodyRegular,
                        softWrap: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: () {
                          Util.launchUrl('https://nmobile.nkn.org/');
                        },
                        child: Label(
                          Settings.locale((s) => s.learn_more, ctx: context),
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 80 + Settings.screenHeight() * 0.05),
        controller: _scrollController,
        itemCount: _filteredSessionList.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: application.theme.backgroundColor2,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Asset.iconSvg(
                        'search',
                        color: application.theme.fontColor2,
                      ),
                    ),
                    Expanded(
                      child: FixedTextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) {
                          _searchQuery = val;
                          _performSearch(val);
                          setState(() {});
                        },
                        style: TextStyle(fontSize: 14, height: 1.5),
                        decoration: InputDecoration(
                          hintText: Settings.locale((s) => s.search, ctx: context),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? SizedBox(
                                  height: 38,
                                  child: IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchQuery = "";
                                        _performSearch("");
                                        _searchFocusNode.unfocus();
                                        setState(() {});
                                      },
                                      icon: Asset.iconSvg(
                                        'close',
                                        width: 16,
                                        color: application.theme.fontColor2,
                                      )),
                                )
                              : null,
                          suffixIconConstraints: BoxConstraints(minHeight: 24, minWidth: 24),
                          border: UnderlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          int sessionIndex = index - 1;
          if (sessionIndex < 0 || sessionIndex >= _filteredSessionList.length) return SizedBox.shrink();
          var session = _filteredSessionList[sessionIndex];
          return Column(
            children: [
              ChatSessionItem(
                session: session,
                onTap: (who) async {
                  FocusScope.of(context).unfocus();
                  ChatMessagesScreen.go(context, who).then((value) {
                    _refreshBadge(delayMs: 0);
                  });
                },
                onLongPress: (who) {
                  _popItemMenu(session, sessionIndex);
                },
              ),
              Divider(color: session.isTop ? application.theme.backgroundColor3.withAlpha(120) : application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
            ],
          );
        },
      ),
    );
  }
}
