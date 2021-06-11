import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/format.dart';

class ChatMessageItem extends StatelessWidget {
  final MessageSchema message;
  final ContactSchema? contact;
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final bool showProfile;
  final Function(ContactSchema, MessageSchema)? onLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    required this.contact,
    this.prevMessage,
    this.nextMessage,
    this.showProfile = false,
    this.onResend,
    this.onLonePress,
  });

  @override
  Widget build(BuildContext context) {
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
      case ContentType.text:
      case ContentType.media:
      case ContentType.image:
      case ContentType.nknImage:
        contentsWidget.add(
          ChatBubble(
            message: this.message,
            contact: this.contact,
            showProfile: this.showProfile,
            onResend: this.onResend,
            onLonePress: this.onLonePress,
          ),
        );
        break;
      case ContentType.eventContactOptions:
        contentsWidget.add(_contactOptionsWidget(context));
        break;
      case ContentType.system:
      case ContentType.receipt:
      case ContentType.contact:
      case ContentType.piece:
      case ContentType.textExtension:
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
      case ContentType.eventChannelInvitation:
        // TODO:GG messageItem contentType
        break;
    }

    return Column(children: contentsWidget);
  }

  Widget _contactOptionsWidget(BuildContext context) {
    S _localizations = S.of(context);

    Map<String, dynamic> optionData = this.message.content ?? Map<String, dynamic>();
    Map<String, dynamic> content = optionData['content'] ?? Map<String, dynamic>();
    if (content.keys.length <= 0) return SizedBox.shrink();
    String? deviceToken = content['deviceToken'] as String?;
    int? deleteAfterSeconds = content['deleteAfterSeconds'] as int?;

    bool isDeviceToken = deviceToken != null;
    bool isBurn = deleteAfterSeconds != null;

    // SUPPORT:START
    isBurn = isBurn || !isDeviceToken;
    if (isBurn) deleteAfterSeconds = deleteAfterSeconds ?? 0;
    // SUPPORT:END

    if (isDeviceToken) {
      String deviceDesc = "";
      if (deviceToken.length == 0) {
        deviceDesc = ' ${_localizations.setting_deny_notification}';
      } else {
        deviceDesc = ' ${_localizations.setting_accept_notification}';
      }
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
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label('$deviceDesc', type: LabelType.bodyRegular),
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
    } else if (isBurn) {
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
                  deleteAfterSeconds! > 0 ? Icon(Icons.alarm_off, size: 16, color: application.theme.fontColor2) : Icon(Icons.alarm_on, size: 16, color: application.theme.fontColor2),
                  SizedBox(width: 4),
                  deleteAfterSeconds > 0 ? Label(durationFormat(Duration(seconds: deleteAfterSeconds)), type: LabelType.bodySmall) : Label(_localizations.off, type: LabelType.bodySmall, fontWeight: FontWeight.bold),
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
                    ' ${deleteAfterSeconds > 0 ? _localizations.update_burn_after_reading : _localizations.close_burn_after_reading} ',
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
    } else {
      return SizedBox.shrink();
    }
  }
}
