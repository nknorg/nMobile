import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/format.dart';

class ChatMessageItem extends StatelessWidget {
  final MessageSchema message;
  final TopicSchema? topic;
  final ContactSchema? contact;
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final bool showProfile;
  final Function(ContactSchema, MessageSchema)? onAvatarLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    required this.topic,
    required this.contact,
    this.prevMessage,
    this.nextMessage,
    this.showProfile = false,
    this.onAvatarLonePress,
    this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    if (message.contentType == MessageContentType.topicUnsubscribe) {
      return SizedBox.shrink();
    }

    List<Widget> contentsWidget = <Widget>[];

    bool showTime = false;
    if (nextMessage == null) {
      showTime = true;
    } else {
      if (message.sendTime != null && nextMessage?.sendTime != null) {
        int curSec = message.sendTime!.millisecondsSinceEpoch ~/ 1000;
        int nextSec = nextMessage!.sendTime!.millisecondsSinceEpoch ~/ 1000;
        if (curSec - nextSec > 60 * 2) {
          showTime = true;
        }
      }
    }

    if (showTime) {
      contentsWidget.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Label(
            formatChatTime(this.message.sendTime),
            type: LabelType.bodySmall,
            fontSize: application.theme.bodyText2.fontSize ?? 14,
          ),
        ),
      );
    }

    switch (this.message.contentType) {
      // case ContentType.receipt:
      // case ContentType.contact:
      case MessageContentType.contactOptions:
        contentsWidget.add(_contactOptionsWidget(context));
        break;
      // case ContentType.deviceRequest:
      // case ContentType.deviceInfo:
      case MessageContentType.text:
      case MessageContentType.textExtension:
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.nknImage:
      case MessageContentType.audio:
        contentsWidget.add(
          ChatBubble(
            message: this.message,
            contact: this.contact,
            showProfile: this.showProfile,
            onAvatarLonePress: this.onAvatarLonePress,
            onResend: this.onResend,
          ),
        );
        break;
      // case ContentType.piece:
      case MessageContentType.topicSubscribe:
        contentsWidget.add(_topicSubscribeWidget(context));
        break;
      // case MessageContentType.topicUnsubscribe:
      case MessageContentType.topicInvitation:
        contentsWidget.add(_topicInvitedWidget(context));
        break;
      // case MessageContentType.topicKickOut:
    }

    return Column(children: contentsWidget);
  }

  Widget _contactOptionsWidget(BuildContext context) {
    S _localizations = S.of(context);

    Map<String, dynamic> optionData = this.message.content ?? Map<String, dynamic>();
    Map<String, dynamic> content = optionData['content'] ?? Map<String, dynamic>();
    if (content.keys.length <= 0) return SizedBox.shrink();
    String? optionType = optionData['optionType']?.toString();
    String? deviceToken = content['deviceToken'] as String?;
    int? deleteAfterSeconds = content['deleteAfterSeconds'] as int?;

    bool isBurn = (optionType == '0') || (deleteAfterSeconds != null);
    bool isBurnOpen = deleteAfterSeconds != null && deleteAfterSeconds > 0;

    bool isDeviceToken = (optionType == '1') || (deviceToken?.isNotEmpty == true);
    bool isDeviceTokenOpen = deviceToken?.isNotEmpty == true;

    if (isBurn) {
      return Center(
        child: Container(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isBurnOpen
                      ? Icon(
                          Icons.alarm_off,
                          size: 16,
                          color: application.theme.fontColor2,
                        )
                      : Icon(
                          Icons.alarm_on,
                          size: 16,
                          color: application.theme.fontColor2,
                        ),
                  SizedBox(width: 4),
                  isBurnOpen
                      ? Label(
                          durationFormat(Duration(seconds: deleteAfterSeconds)),
                          type: LabelType.bodySmall,
                        )
                      : Label(
                          _localizations.off,
                          type: LabelType.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Label(
                    message.isOutbound ? _localizations.you : (this.contact?.displayName ?? " "),
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    ' ${isBurnOpen ? _localizations.update_burn_after_reading : _localizations.close_burn_after_reading} ',
                    maxWidth: Global.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  _localizations.click_to_change,
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this.contact);
                },
              ),
            ],
          ),
        ),
      );
    } else if (isDeviceToken) {
      return Center(
        child: Container(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Label(
                    message.isOutbound ? _localizations.you : (this.contact?.displayName ?? " "),
                    maxWidth: Global.screenWidth() * 0.3,
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    isDeviceTokenOpen ? ' ${_localizations.setting_accept_notification}' : ' ${_localizations.setting_deny_notification}',
                    maxWidth: Global.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  _localizations.click_to_change,
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this.contact);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _topicSubscribeWidget(BuildContext context) {
    S _localizations = S.of(context);
    String who = message.isOutbound ? _localizations.you : message.from.substring(0, 6);
    String content = who + _localizations.joined_channel;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: Label(
        content,
        type: LabelType.bodyRegular,
        color: application.theme.fontColor2,
      ),
    );
  }

  Widget _topicInvitedWidget(BuildContext context) {
    S _localizations = S.of(context);

    String inviteDesc = message.isOutbound ? _localizations.invites_desc_other(message.to?.substring(0, 6) ?? " ") : _localizations.invites_desc_me(message.from.substring(0, 6));

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Label(
                inviteDesc,
                type: LabelType.bodyRegular,
                color: application.theme.fontColor2,
              ),
              SizedBox(width: 2),
              Label(
                TopicSchema(topic: message.content?.toString() ?? " ").topicShort,
                maxWidth: Global.screenWidth() * 0.5,
                type: LabelType.bodyRegular,
                fontWeight: FontWeight.bold,
                color: application.theme.fontColor1,
              ),
            ],
          ),
          message.isOutbound
              ? SizedBox.shrink()
              : InkWell(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                    child: Label(
                      _localizations.accept,
                      type: LabelType.bodyRegular,
                      fontWeight: FontWeight.bold,
                      color: application.theme.primaryColor,
                    ),
                  ),
                  onTap: () async {
                    String? topic = await BottomDialog.of(context).showInput(
                      title: _localizations.accept_invitation,
                      desc: inviteDesc,
                      value: message.content?.toString() ?? "",
                      actionText: _localizations.accept_invitation,
                      enable: false,
                    );
                    if (topic?.isNotEmpty == true) {
                      Loading.show();
                      TopicSchema? result = await topicCommon.subscribe(topic);
                      Loading.dismiss();
                      if (result != null) Toast.show(_localizations.subscribed);
                    }
                  },
                )
        ],
      ),
    );
  }
}
