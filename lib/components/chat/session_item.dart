import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';

Widget _unReadWidget(SessionSchema item) {
  String countStr = item.notReadCount.toString();
  if (item.notReadCount > 999) {
    countStr = '999+';
  }
  return Container(
    padding: const EdgeInsets.only(left: 4, right: 4),
    constraints: BoxConstraints(minWidth: 25),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.5),
      color: application.theme.badgeColor,
    ),
    height: 25,
    child: Center(
      child: Label(
        countStr,
        type: LabelType.bodySmall,
        dark: true,
      ),
    ),
  );
}

Widget createSessionWidget(BuildContext context, SessionSchema model) {
  S _localizations = S.of(context);
  Widget contentWidget;
  String draft; // TODO: draft
  if (draft != null && draft.length > 0) {
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
  } else if (model.contentType == ContentType.nknImage || model.contentType == ContentType.media) {
    contentWidget = Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Row(
        children: <Widget>[
          Asset.iconSvg('image', width: 16, color: application.theme.fontColor2),
        ],
      ),
    );
  } else if (model.contentType == ContentType.audio) {
    contentWidget = Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Row(
        children: <Widget>[
          Asset.iconSvg('microphone', width: 16, color: application.theme.fontColor2),
        ],
      ),
    );
  } else if (model.contentType == ContentType.channelInvitation) {
    contentWidget = Label(
      _localizations.channel_invitation,
      maxLines: 1,
      type: LabelType.bodyRegular,
      overflow: TextOverflow.ellipsis,
    );
  } else if (model.contentType == ContentType.eventSubscribe) {
    contentWidget = Label(
      _localizations.joined_channel,
      maxLines: 1,
      type: LabelType.bodyRegular,
      overflow: TextOverflow.ellipsis,
    );
  } else {
    contentWidget = Label(
      model.content,
      type: LabelType.bodyRegular,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
  if (model.topic != null) {
    List<Widget> topicNameWidget = [
      Label(
        model.topic.topicName,
        type: LabelType.h3,
        fontWeight: FontWeight.bold,
      ),
    ];
    
    if(model.topic.topicType == TopicType.privateTopic) {
      topicNameWidget.insert(0, Asset.iconSvg('lock', width: 18, color: application.theme.primaryColor));
    }
    
    return Container(
      color: model.isTop ? application.theme.backgroundColor1:Colors.transparent,
      padding: const EdgeInsets.only(left: 12, right: 12),
      height: 72,
      child: Flex(
        direction: Axis.horizontal,
        children: [
          Expanded(
            flex: 1,
            child: TopicItem(
              topic: model.topic,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: topicNameWidget,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: contentWidget,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 0,
            child: Container(
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 0, bottom: 6),
                        child: Label(
                          timeFormat(model.lastReceiveTime),
                          type: LabelType.bodyRegular,
                        ),
                      ),
                      model.notReadCount > 0
                          ? Padding(
                        padding: const EdgeInsets.only(right: 0),
                        child: _unReadWidget(SessionSchema(notReadCount: model.notReadCount)),
                      )
                          : SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } else {
    return Container(
      color: model.isTop ? application.theme.backgroundColor1:Colors.transparent,
      padding: const EdgeInsets.only(left: 12, right: 12),
      height: 72,
      child: Flex(
        direction: Axis.horizontal,
        children: [
          Expanded(
            flex: 1,
            child: ContactItem(
              contact: model.contact,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Label(
                    model.contact?.getDisplayName ?? '',
                    type: LabelType.h3,
                    fontWeight: FontWeight.bold,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: contentWidget,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 0,
            child: Container(
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 0, bottom: 6),
                        child: Label(
                          timeFormat(model.lastReceiveTime),
                          type: LabelType.bodyRegular,
                        ),
                      ),
                      model.notReadCount > 0
                          ? Padding(
                              padding: const EdgeInsets.only(right: 0),
                              child: _unReadWidget(SessionSchema(notReadCount: model.notReadCount)),
                            )
                          : SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
