import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';

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

  TopicSchema? _topic;
  ContactSchema? _contact;
  MessageSchema? _lastMsg;

  @override
  void onRefreshArguments() {
    if (widget.session.isTopic) {
      if (_topic == null || widget.session.targetId != _topic?.id?.toString()) {
        topicCommon.queryByTopic(widget.session.targetId).then((value) {
          setState(() {
            _topic = value;
          });
        });
      }
    } else {
      if (_contact == null || widget.session.targetId != _contact?.id?.toString()) {
        contactCommon.queryByClientAddress(widget.session.targetId).then((value) {
          setState(() {
            _contact = value;
          });
        });
      }
    }
    _lastMsg = widget.session.lastMessageOptions != null ? MessageSchema.fromMap(widget.session.lastMessageOptions!) : null;
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
  }

  @override
  void dispose() {
    _updateTopicSubscription?.cancel();
    _updateContactSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                flex: 1,
                child: session.isTopic
                    ? (_topic != null
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
                                    Label(
                                      _topic?.topicShort ?? " ",
                                      type: LabelType.h3,
                                      fontWeight: FontWeight.bold,
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
                        : SizedBox.shrink())
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
                        : SizedBox.shrink()),
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
                            timeFormat(session.lastMessageTime),
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
    S _localizations = S.of(context);
    String? msgType = _lastMsg?.contentType;
    String? draft = memoryCache.getDraft(session.targetId);

    Widget contentWidget;
    if (draft != null && draft.length > 0) {
      // draft
      contentWidget = Row(
        children: <Widget>[
          Label(
            _localizations.placeholder_draft,
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
    } else if (msgType == ContentType.media || msgType == ContentType.image || msgType == ContentType.nknImage) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Asset.iconSvg('image', width: 16, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == ContentType.audio) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Asset.iconSvg('microphone', width: 16, color: application.theme.fontColor2),
          ],
        ),
      );
    } else if (msgType == ContentType.contactOptions) {
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

      String who = (_lastMsg?.isOutbound == true) ? _localizations.you : (_lastMsg?.isTopic == true ? "???" : (_contact?.displayName ?? " ")); // TODO:GG lastMsg contact?

      if (isBurn) {
        String burnDecs = ' ${isBurnOpen ? _localizations.update_burn_after_reading : _localizations.close_burn_after_reading} ';
        contentWidget = Label(
          who + burnDecs,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else if (isDeviceToken) {
        String deviceDesc = isDeviceTokenOPen ? ' ${_localizations.setting_accept_notification}' : ' ${_localizations.setting_deny_notification}';
        contentWidget = Label(
          who + deviceDesc,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        contentWidget = SizedBox.shrink();
      }
    } else if (msgType == ContentType.topicSubscribe) {
      contentWidget = Label(
        _localizations.joined_channel,
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (msgType == ContentType.topicInvitation) {
      contentWidget = Label(
        _localizations.channel_invitation,
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      contentWidget = Label(
        _lastMsg?.content ?? " ",
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
