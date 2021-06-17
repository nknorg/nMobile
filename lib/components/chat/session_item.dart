import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/text/label.dart';
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
  StreamSubscription? _updateContactSubscription;

  TopicSchema? _topic;
  ContactSchema? _contact;
  MessageSchema? _lastMsg;

  @override
  void onRefreshArguments() async {
    if (widget.session.isTopic) {
      if (_topic == null || widget.session.targetId != _topic?.id?.toString()) {
        _topic = null; // TODO:GG topic session get
      }
    } else {
      if (_contact == null || widget.session.targetId != _contact?.id?.toString()) {
        _contact = await contactCommon.queryByClientAddress(widget.session.targetId);
      }
    }
    _lastMsg = widget.session.lastMessageOptions != null ? MessageSchema.fromMap(widget.session.lastMessageOptions!) : null;
    setState(() {}); // async need
  }

  @override
  void initState() {
    super.initState();
    // contact
    _updateContactSubscription = contactCommon.updateStream.where((event) => event.id == _contact?.id).listen((event) {
      setState(() {
        _contact = event;
      });
    });
    // topic TODO:GG topic session update
  }

  @override
  void dispose() {
    _updateContactSubscription?.cancel();
    super.dispose();
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
    } else if (msgType == ContentType.nknImage || msgType == ContentType.media || msgType == ContentType.image) {
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
    } else if (msgType == ContentType.eventContactOptions) {
      Map<String, dynamic> optionData = _lastMsg?.content ?? Map<String, dynamic>();
      Map<String, dynamic> content = optionData['content'] ?? Map<String, dynamic>();
      if (content.keys.length <= 0) return SizedBox.shrink();
      String? deviceToken = content['deviceToken'] as String?;
      int? deleteAfterSeconds = content['deleteAfterSeconds'] as int?;

      bool isDeviceToken = deviceToken != null;
      bool isBurn = deleteAfterSeconds != null;

      String who = (_lastMsg?.isOutbound == true) ? _localizations.you : (_contact?.displayName ?? " ");

      // SUPPORT:START
      isBurn = isBurn || !isDeviceToken;
      if (isBurn) deleteAfterSeconds = deleteAfterSeconds ?? 0;
      // SUPPORT:END

      if (isDeviceToken) {
        String deviceDesc = deviceToken.length == 0 ? ' ${_localizations.setting_deny_notification}' : ' ${_localizations.setting_accept_notification}';
        contentWidget = Label(
          who + deviceDesc,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        String burnDecs = ' ${deleteAfterSeconds != null && deleteAfterSeconds > 0 ? _localizations.update_burn_after_reading : _localizations.close_burn_after_reading} ';
        contentWidget = Label(
          who + burnDecs,
          type: LabelType.bodyRegular,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    } else if (msgType == ContentType.eventSubscribe) {
      contentWidget = Label(
        _localizations.joined_channel,
        type: LabelType.bodyRegular,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (msgType == ContentType.eventChannelInvitation) {
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

  Widget _topicWidget(SessionSchema session) {
    // TODO:GG topic session item
    return SizedBox.shrink();
    //   List<Widget> topicNameWidget = [
    //     Label(
    //       model.topic!.topicName ?? "",
    //       type: LabelType.h3,
    //       fontWeight: FontWeight.bold,
    //     ),
    //   ];
    //
    //   if (model.topic!.topicType == TopicType.privateTopic) {
    //     topicNameWidget.insert(0, Asset.iconSvg('lock', width: 18, color: application.theme.primaryColor));
    //   }
    //
    //   return Container(
    //     color: model.isTop ? application.theme.backgroundColor1 : Colors.transparent,
    //     padding: const EdgeInsets.only(left: 12, right: 12),
    //     height: 72,
    //     child: Flex(
    //       direction: Axis.horizontal,
    //       children: [
    //         Expanded(
    //           flex: 1,
    //           child: TopicItem(
    //             topic: model.topic!,
    //             body: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               mainAxisAlignment: MainAxisAlignment.center,
    //               children: [
    //                 Row(
    //                   children: topicNameWidget,
    //                 ),
    //                 Padding(
    //                   padding: const EdgeInsets.only(top: 6),
    //                   child: contentWidget,
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //         Expanded(
    //           flex: 0,
    //           child: Container(
    //             child: Row(
    //               children: [
    //                 Column(
    //                   mainAxisAlignment: MainAxisAlignment.center,
    //                   crossAxisAlignment: CrossAxisAlignment.end,
    //                   children: [
    //                     Padding(
    //                       padding: const EdgeInsets.only(right: 0, bottom: 6),
    //                       child: Label(
    //                         timeFormat(model.lastReceiveTime),
    //                         type: LabelType.bodyRegular,
    //                       ),
    //                     ),
    //                     (model.notReadCount ?? 0) > 0
    //                         ? Padding(
    //                             padding: const EdgeInsets.only(right: 0),
    //                             child: _unReadWidget(SessionSchema(notReadCount: model.notReadCount)),
    //                           )
    //                         : SizedBox.shrink(),
    //                   ],
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
  }

  Widget _contactWidget(SessionSchema session) {
    return Container(
      color: session.isTop ? application.theme.backgroundColor1 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: _contact != null
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
                : SizedBox.shrink(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    SessionSchema session = widget.session;
    Widget contentWidget = session.isTopic ? _topicWidget(session) : _contactWidget(session);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: () => widget.onTap?.call(_contact ?? _topic),
        onLongPress: () => widget.onLongPress?.call(_contact ?? _topic),
        child: contentWidget,
      ),
    );
  }
}
