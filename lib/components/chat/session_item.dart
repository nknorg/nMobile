import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/item.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/time.dart';

class ChatSessionItem extends BaseStateFulWidget {
  final SessionSchema session;
  final Function(dynamic)? onTap;
  final Function(dynamic)? onLongPress;

  ChatSessionItem({
    Key? key,
    required this.session,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  _ChatSessionItemState createState() => _ChatSessionItemState();
}

class _ChatSessionItemState extends BaseStateFulWidgetState<ChatSessionItem> {
  StreamSubscription? _updateTopicSubscription;
  StreamSubscription? _updateContactSubscription;
  StreamSubscription? _updateDraftSubscription;

  TopicSchema? _topic;
  ContactSchema? _contact;
  MessageSchema? _lastMsg;
  ContactSchema? _topicSender;

  bool loaded = false;

  @override
  void onRefreshArguments() {
    loaded = false;
    if (widget.session.isTopic) {
      if (_topic == null || (widget.session.targetId != _topic?.topic)) {
        topicCommon.queryByTopic(widget.session.targetId).then((value) {
          setState(() {
            loaded = true;
            _topic = value;
            _contact = null;
          });
        });
      } else {
        loaded = true;
      }
    } else {
      if (_contact == null || (widget.session.targetId != _contact?.clientAddress)) {
        contactCommon.queryByClientAddress(widget.session.targetId).then((value) {
          setState(() {
            loaded = true;
            _topic = null;
            _contact = value;
          });
        });
      } else {
        loaded = true;
      }
    }

    // lastMsg + topicSender
    MessageSchema? lastMsg = widget.session.lastMessageOptions != null ? MessageSchema.fromMap(widget.session.lastMessageOptions!) : null;
    if (_lastMsg?.msgId == null || _lastMsg?.msgId != lastMsg?.msgId) {
      if (widget.session.isTopic && (_topicSender?.clientAddress == null || _topicSender?.clientAddress != lastMsg?.from)) {
        lastMsg?.getSender(emptyAdd: true).then((ContactSchema? value) {
          setState(() {
            _lastMsg = lastMsg;
            _topicSender = value;
          });
        });
      } else {
        setState(() {
          _lastMsg = lastMsg;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // topic
    _updateTopicSubscription = topicCommon.updateStream.where((event) => event.id == _topic?.id).listen((event) {
      setState(() {
        _topic = event;
      });
    });
    // contact
    _updateContactSubscription = contactCommon.updateStream.where((event) => event.id == _contact?.id).listen((event) {
      setState(() {
        _contact = event;
      });
    });
    // draft
    _updateDraftSubscription = memoryCache.draftUpdateStream.where((event) => event == widget.session.targetId).listen((String event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTopicSubscription?.cancel();
    _updateContactSubscription?.cancel();
    _updateDraftSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_topic == null && _contact == null && loaded) {
      sessionCommon.delete(widget.session.targetId, widget.session.type);
      return SizedBox.shrink();
    }
    SessionSchema session = widget.session;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: () => widget.onTap?.call(_topic ?? _contact),
        onLongPress: () => widget.onLongPress?.call(_topic ?? _contact),
        child: Container(
          color: session.isTop ? application.theme.backgroundColor1 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _topic != null
                    ? TopicItem(
                        topic: _topic!,
                        body: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _topic?.isPrivate == true
                                    ? Asset.iconSvg(
                                        'lock',
                                        width: 18,
                                        color: application.theme.primaryColor,
                                      )
                                    : SizedBox.shrink(),
                                Expanded(
                                  child: Label(
                                    _topic?.topicShort ?? " ",
                                    type: LabelType.h3,
                                    color: (_topic?.joined == true) ? null : application.theme.fontColor3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _contentWidget(session),
                            ),
                          ],
                        ),
                        onTapWave: false,
                      )
                    : (_contact != null
                        ? ContactItem(
                            contact: _contact!,
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Label(
                                  _contact?.displayName ?? " ",
                                  type: LabelType.h3,
                                  fontWeight: FontWeight.bold,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: _contentWidget(session),
                                ),
                              ],
                            ),
                            onTapWave: false,
                          )
                        : SizedBox(width: 24 * 2, height: 24 * 2)),
              ),
              Container(
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 0, bottom: 6),
                          child: Label(
                            Time.formatTime(DateTime.fromMillisecondsSinceEpoch(session.lastMessageAt ?? DateTime.now().millisecondsSinceEpoch)),
                            type: LabelType.bodyRegular,
                          ),
                        ),
                        (session.unReadCount) > 0
                            ? Padding(
                                padding: const EdgeInsets.only(right: 0),
                                child: _unReadWidget(session),
                              )
                            : SizedBox.shrink(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentWidget(SessionSchema session) {
    String? draft = memoryCache.getDraft(session.targetId);

    String? msgType = _lastMsg?.contentType;
    if (_lastMsg?.contentType == MessageContentType.ipfs) {
      int? fileType = MessageOptions.getFileType(_lastMsg?.options);
      if (fileType == MessageOptions.fileTypeImage) {
        msgType = MessageContentType.image;
      } else if (fileType == MessageOptions.fileTypeVideo) {
        msgType = MessageContentType.video;
      } else {
        // ipfs_file + ipfs_audio
        msgType = MessageContentType.file;
      }
    }

    String topicSenderName = _topicSender?.displayName ?? " ";
    String prefix = session.isTopic ? ((_lastMsg?.isOutbound == true) ? "" : "$topicSenderName: ") : "";

    Widget contentWidget;
    if (draft != null && draft.length > 0) {
      // draft
      contentWidget = Row(
        children: <Widget>[
          Label(
            Global.locale((s) => s.placeholder_draft, ctx: context),
            type: LabelType.bodyRegular,
            color: Colors.red,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 5),
          Label(
            draft,
            type: LabelType.bodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (msgType == MessageContentType.contactOptions) {
      Map<String, dynamic> optionData = _lastMsg?.content ?? Map<String, dynamic>();
      Map<String, dynamic> content = optionData['content'] ?? Map<String, dynamic>();
      if (content.keys.length <= 0) return SizedBox.shrink();
      String? optionType = optionData['optionType']?.toString();
      String? deviceToken = content['deviceToken'] as String?;
      int? deleteAfterSeconds = content['deleteAfterSeconds'] as int?;

      bool isBurn = (optionType == '0') || (deleteAfterSeconds != null);
      bool isBurnOpen = deleteAfterSeconds != null && deleteAfterSeconds > 0;

      bool isDeviceToken = (optionType == '1') || (deviceToken?.isNotEmpty == true);
      bool isDeviceTokenOPen = deviceToken?.isNotEmpty == true;

      String who = (_lastMsg?.isOutbound == true) ? Global.locale((s) => s.you, ctx: context) : (_lastMsg?.isTopic == true ? topicSenderName : (_contact?.displayName ?? " "));

      if (isBurn) {
        String burnDecs = ' ${isBurnOpen ? Global.locale((s) => s.update_burn_after_reading, ctx: context) : Global.locale((s) => s.close_burn_after_reading, ctx: context)} ';
        contentWidget = Label(
          who + burnDecs,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else if (isDeviceToken) {
        String deviceDesc = isDeviceTokenOPen ? ' ${Global.locale((s) => s.setting_accept_notification, ctx: context)}' : ' ${Global.locale((s) => s.setting_deny_notification, ctx: context)}';
        contentWidget = Label(
          who + deviceDesc,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        contentWidget = SizedBox.shrink();
      }
    } else if (msgType == MessageContentType.media || msgType == MessageContentType.image) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(prefix, type: LabelType.bodyRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
            Asset.iconSvg('image', width: 16, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == MessageContentType.audio) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(prefix, type: LabelType.bodyRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
            Asset.iconSvg('microphone', width: 16, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == MessageContentType.video) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(prefix, type: LabelType.bodyRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
            Icon(CupertinoIcons.video_camera, size: 18, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == MessageContentType.file) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(prefix, type: LabelType.bodyRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
            Icon(CupertinoIcons.doc, size: 16, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == MessageContentType.topicSubscribe) {
      contentWidget = Label(
        prefix + Global.locale((s) => s.joined_channel, ctx: context),
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (msgType == MessageContentType.topicInvitation) {
      contentWidget = Label(
        prefix + Global.locale((s) => s.channel_invitation, ctx: context),
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (_lastMsg?.content is String?) {
      contentWidget = Label(
        prefix + ((_lastMsg?.content as String?)?.trim() ?? " "),
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      contentWidget = Label(
        prefix + " ",
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return contentWidget;
  }

  Widget _unReadWidget(SessionSchema session) {
    String countStr = session.unReadCount.toString();
    if ((session.unReadCount) > 999) {
      countStr = '999+';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: application.theme.badgeColor,
      ),
      child: Center(
        child: Label(
          countStr,
          type: LabelType.bodySmall,
          dark: true,
        ),
      ),
    );
  }
}
