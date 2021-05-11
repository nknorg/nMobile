import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/contact/contact_item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/message_list_item.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/format.dart';

Widget _unReadWidget(MessageListItem item) {
  String countStr = item.notReadCount.toString();
  if (item.notReadCount > 999) {
    countStr = '999+';
  }
  return Container(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12.5),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        color: application.theme.badgeColor,
        height: 25,
        child: Center(
          child: Label(
            countStr,
            type: LabelType.bodySmall,
            dark: true,
          ),
        ),
      ),
    ),
  );
}

Widget createMessageListItemWidget(BuildContext context, MessageListItem model) {
  S _localizations = S.of(context);
  Widget contentWidget;
  String draft; // TODO: draft
  if (draft != null && draft.length > 0) {
    contentWidget = Row(
      children: <Widget>[
        Label(
          _localizations.placeholder_draft,
          type: LabelType.bodySmall,
          color: Colors.red,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(width: 5),
        Label(
          draft,
          type: LabelType.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  } else if (model.contentType == ContentType.nknImage || model.contentType == ContentType.media) {
    contentWidget = Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Row(
        children: <Widget>[
          assetIcon('image', width: 16, color: application.theme.fontColor2),
        ],
      ),
    );
  } else if (model.contentType == ContentType.audio) {
    contentWidget = Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Row(
        children: <Widget>[
          assetIcon('microphone', width: 16, color: application.theme.fontColor2),
        ],
      ),
    );
  } else if (model.contentType == ContentType.channelInvitation) {
    contentWidget = Label(
      _localizations.channel_invitation,
      maxLines: 1,
      type: LabelType.bodySmall,
      overflow: TextOverflow.ellipsis,
    );
  } else if (model.contentType == ContentType.eventSubscribe) {
    contentWidget = Label(
      _localizations.joined_channel,
      maxLines: 1,
      type: LabelType.bodySmall,
      overflow: TextOverflow.ellipsis,
    );
  } else {
    contentWidget = Label(
      model.content,
      type: LabelType.bodySmall,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
  if (model.topic != null) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 12, right: 12),
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              // TODO: create contact avatar
              radius: 24,
              backgroundColor: Colors.red,
              child: Label(
                'HR',
                type: LabelType.bodyLarge,
                color: Colors.yellow,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 1, color: application.theme.dividerColor))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            //TODO: create topic widget
                          ],
                        ),
                        contentWidget,
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 0, bottom: 6),
                        child: Label(
                          timeFormat(model.lastReceiveTime),
                          type: LabelType.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 0),
                        child: _unReadWidget(MessageListItem(notReadCount: model.notReadCount)),
                      ),
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
      color: Colors.transparent,
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
                    model.contact.getDisplayName,
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 1, color: application.theme.dividerColor))),
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
                          type: LabelType.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 0),
                        child: _unReadWidget(MessageListItem(notReadCount: model.notReadCount)),
                      ),
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
