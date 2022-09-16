import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/crypto.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/time.dart';

class ChatMessageItem extends StatefulWidget {
  final MessageSchema message;
  // final TopicSchema? topic;
  // final PrivateGroupSchema? privateGroup;
  final ContactSchema? contact;
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final Function(ContactSchema, MessageSchema)? onAvatarLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    // required this.topic,
    // required this.privateGroup,
    required this.contact,
    this.prevMessage,
    this.nextMessage,
    this.onAvatarLonePress,
    this.onResend,
  });

  @override
  State<ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  ContactSchema? _contact;

  @override
  void initState() {
    widget.message.getSender(emptyAdd: true).then((ContactSchema? value) {
      setState(() {
        _contact = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isDelete) {
      return SizedBox.shrink();
    } else if (widget.message.canBurning && (widget.message.content == null)) {
      return SizedBox.shrink();
    }
    // if (message.contentType == MessageContentType.topicUnsubscribe) {
    //   return SizedBox.shrink();
    // }

    // user
    bool isOneUserWithPrev = widget.message.from == widget.prevMessage?.from;
    bool isOneUserWithNext = widget.message.from == widget.nextMessage?.from;

    // status
    bool isSameStatusWithPrev = widget.message.status == widget.prevMessage?.status;
    bool isSameStatusWithNext = widget.message.status == widget.nextMessage?.status;

    // type
    bool canShowProfileByPrevType = widget.prevMessage?.canBurning == true;
    bool canShowProfileByCurrType = widget.message.canBurning == true;
    bool canShowProfileByNextType = widget.nextMessage?.canBurning == true;

    // sendAt
    int? prevSendAt = (widget.prevMessage?.isOutbound == true) ? widget.prevMessage?.sendAt : (widget.prevMessage?.sendAt ?? MessageOptions.getInAt(widget.prevMessage?.options));
    int? currSendAt = (widget.message.isOutbound == true) ? widget.message.sendAt : (widget.message.sendAt ?? MessageOptions.getInAt(widget.message.options));
    int? nextSendAt = (widget.nextMessage?.isOutbound == true) ? widget.nextMessage?.sendAt : (widget.nextMessage?.sendAt ?? MessageOptions.getInAt(widget.nextMessage?.options));

    // group
    int oneGroupSeconds = 2 * 60; // 2m

    bool isGroupHead = false;
    if (widget.nextMessage == null) {
      isGroupHead = true;
    } else if (currSendAt == null || currSendAt == 0) {
      isGroupHead = true;
    } else if (nextSendAt == null || nextSendAt == 0) {
      isGroupHead = true;
    } else if (!isOneUserWithNext) {
      isGroupHead = true;
    } else if (!isSameStatusWithNext) {
      isGroupHead = true;
    } else if (!canShowProfileByNextType) {
      isGroupHead = true;
    } else {
      int curSec = currSendAt ~/ 1000;
      int nextSec = nextSendAt ~/ 1000;
      if ((curSec - nextSec) >= oneGroupSeconds) {
        isGroupHead = true;
      }
    }

    bool isGroupTail = false;
    if (widget.prevMessage == null) {
      isGroupTail = true;
    } else if (currSendAt == null || currSendAt == 0) {
      isGroupTail = true;
    } else if (prevSendAt == null || prevSendAt == 0) {
      isGroupTail = true;
    } else if (!isOneUserWithPrev) {
      isGroupTail = true;
    } else if (!isSameStatusWithPrev) {
      isGroupTail = true;
    } else if (!canShowProfileByPrevType) {
      isGroupTail = true;
    } else {
      int prevSec = prevSendAt ~/ 1000;
      int curSec = currSendAt ~/ 1000;
      if ((prevSec - curSec) >= oneGroupSeconds) {
        isGroupTail = true;
      }
    }

    bool isGroupBody = true;
    if (isGroupHead || isGroupTail) {
      isGroupBody = false;
    } else if (!isOneUserWithPrev || !isOneUserWithNext) {
      isGroupBody = false;
    } else if (!isSameStatusWithPrev || !isSameStatusWithNext) {
      isGroupBody = false;
    } else if (!canShowProfileByPrevType || !canShowProfileByNextType) {
      isGroupBody = false;
    }

    // profile
    bool showProfile = canShowProfileByCurrType && !widget.message.isOutbound && (widget.message.isTopic || widget.message.isPrivateGroup);
    bool hideProfile = showProfile && !isGroupHead;

    List<Widget> contentsWidget = <Widget>[];

    // if (isGroupHead) {
    //   contentsWidget.add(
    //     Padding(
    //       padding: const EdgeInsets.only(top: 12, bottom: 6),
    //       child: Label(
    //         formatChatTime(DateTime.fromMillisecondsSinceEpoch(this.message.sendAt ?? DateTime.now().millisecondsSinceEpoch)),
    //         type: LabelType.bodySmall,
    //         fontSize: application.theme.bodyText2.fontSize ?? 14,
    //       ),
    //     ),
    //   );
    // }

    switch (this.widget.message.contentType) {
      // case MessageContentType.ping:
      // case MessageContentType.receipt:
      // case MessageContentType.read:
      // case MessageContentType.msgStatus:
      // case MessageContentType.contact:
      case MessageContentType.contactOptions:
        contentsWidget.add(_contactOptionsWidget(context));
        break;
      // case MessageContentType.deviceRequest:
      // case MessageContentType.deviceInfo:
      case MessageContentType.text:
      case MessageContentType.textExtension:
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.ipfs:
        contentsWidget.add(
          ChatBubble(
            message: this.widget.message,
            contact: this.widget.contact,
            showProfile: showProfile,
            hideProfile: hideProfile,
            showTimeAndStatus: isGroupTail,
            // timeFormatBetween: false,
            hideTopMargin: isGroupBody || (isGroupTail && !isGroupHead),
            hideBotMargin: isGroupBody || (isGroupHead && !isGroupTail),
            onAvatarLonePress: this.widget.onAvatarLonePress,
            onResend: this.widget.onResend,
          ),
        );
        break;
      // case MessageContentType.nknOnePiece:
      case MessageContentType.topicSubscribe:
        contentsWidget.add(_topicSubscribeWidget(context));
        break;
      // case MessageContentType.topicUnsubscribe:
      case MessageContentType.topicInvitation:
      // case MessageContentType.topicKickOut:
      case MessageContentType.privateGroupInvitation:
        contentsWidget.add(_privateGroupInvitedWidget(context));
        break;
      case MessageContentType.privateGroupAccept:
        contentsWidget.add(_privateGroupAcceptWidget(context));
        break;
      // TODO:GG PG 还没想好
      case MessageContentType.privateGroupSubscribe:
        contentsWidget.add(_topicInvitedWidget(context));
        break;
    }

    return Column(children: contentsWidget);
  }

  Widget _contactOptionsWidget(BuildContext context) {
    Map<String, dynamic> optionData = this.widget.message.content ?? Map<String, dynamic>();
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
                          Time.formatDuration(Duration(seconds: deleteAfterSeconds)),
                          type: LabelType.bodySmall,
                        )
                      : Label(
                          Global.locale((s) => s.off, ctx: context),
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
                    widget.message.isOutbound ? Global.locale((s) => s.you, ctx: context) : (this.widget.contact?.displayName ?? " "),
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    ' ${isBurnOpen ? Global.locale((s) => s.update_burn_after_reading, ctx: context) : Global.locale((s) => s.close_burn_after_reading, ctx: context)} ',
                    maxWidth: Global.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  Global.locale((s) => s.click_to_change, ctx: context),
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this.widget.contact);
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
                    widget.message.isOutbound ? Global.locale((s) => s.you, ctx: context) : (this.widget.contact?.displayName ?? " "),
                    maxWidth: Global.screenWidth() * 0.3,
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    isDeviceTokenOpen ? ' ${Global.locale((s) => s.setting_accept_notification, ctx: context)}' : ' ${Global.locale((s) => s.setting_deny_notification, ctx: context)}',
                    maxWidth: Global.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  Global.locale((s) => s.click_to_change, ctx: context),
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this.widget.contact);
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
    String who = widget.message.isOutbound ? Global.locale((s) => s.you, ctx: context) : _contact?.displayName ?? widget.message.from.substring(0, 6);
    String content = who + Global.locale((s) => s.joined_channel, ctx: context);

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
    String to = (widget.message.to.length > 6) ? widget.message.to.substring(0, 6) : " ";
    String from = widget.message.from.length > 6 ? widget.message.from.substring(0, 6) : " ";
    String inviteDesc = widget.message.isOutbound ? Global.locale((s) => s.invites_desc_other(to), ctx: context) : Global.locale((s) => s.invites_desc_me(from), ctx: context);

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
                TopicSchema(topic: widget.message.content?.toString() ?? " ").topicShort,
                maxWidth: Global.screenWidth() * 0.5,
                type: LabelType.bodyRegular,
                fontWeight: FontWeight.bold,
                color: application.theme.fontColor1,
              ),
            ],
          ),
          widget.message.isOutbound
              ? SizedBox.shrink()
              : InkWell(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                    child: Label(
                      Global.locale((s) => s.accept, ctx: context),
                      type: LabelType.bodyRegular,
                      fontWeight: FontWeight.bold,
                      color: application.theme.primaryColor,
                    ),
                  ),
                  onTap: () async {
                    String? topic = await BottomDialog.of(Global.appContext).showInput(
                      title: Global.locale((s) => s.accept_invitation, ctx: context),
                      desc: inviteDesc,
                      value: widget.message.content?.toString() ?? " ",
                      actionText: Global.locale((s) => s.accept_invitation, ctx: context),
                      enable: false,
                    );
                    if (topic?.isNotEmpty == true) {
                      double? fee = await BottomDialog.of(Global.appContext).showTransactionSpeedUp();
                      if (fee == null) return;
                      Loading.show();
                      int sendAt = widget.message.sendAt ?? MessageOptions.getInAt(widget.message.options) ?? 0;
                      bool isJustNow = (DateTime.now().millisecondsSinceEpoch - sendAt) < Global.txPoolDelayMs;
                      TopicSchema? result = await topicCommon.subscribe(topic, fetchSubscribers: true, justNow: isJustNow, fee: fee);
                      Loading.dismiss();
                      if (result != null) Toast.show(Global.locale((s) => s.subscribed, ctx: context));
                    }
                  },
                )
        ],
      ),
    );
  }

  // TODO:GG PG 代码整理
  Widget _privateGroupInvitedWidget(BuildContext context) {
    String to = (widget.message.to.length > 6) ? widget.message.to.substring(0, 6) : " ";
    String from = widget.message.from.length > 6 ? widget.message.from.substring(0, 6) : " ";
    String inviteDesc = widget.message.isOutbound ? Global.locale((s) => s.invites_desc_other(to), ctx: context) : Global.locale((s) => s.invites_desc_me(from), ctx: context);
    Map content = Map();
    String groupId = '';
    String groupName = '';
    Widget expiresWidget = SizedBox.shrink();
    if (widget.message.content != null) {
      content = widget.message.content as Map;
      groupId = content['groupId']?.toString() ?? "";
      groupName = content['name']?.toString() ?? "";
      Map<String, dynamic>? data = content['item'];
      if (data != null) {
        DateTime? expiresAt = DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] ?? 0);
        String inviter = data['inviter']?.toString() ?? "";
        if (expiresAt.isBefore(DateTime.now())) {
          expiresWidget = Label(
            Global.locale((s) => s.expired, ctx: context),
            color: application.theme.fontColor2,
            type: LabelType.bodyRegular,
          );
        } else {
          expiresWidget = widget.message.isOutbound
              ? Label(
                  Global.locale((s) => s.expiration, ctx: context) + ': ' + Time.formatTimeFromNow(expiresAt),
                  color: application.theme.fontColor2,
                  type: LabelType.bodyRegular,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Label(
                      Global.locale((s) => s.expiration, ctx: context) + ': ' + Time.formatTimeFromNow(expiresAt),
                      color: application.theme.fontColor2,
                      type: LabelType.bodyRegular,
                    ),
                    InkWell(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                        child: Label(
                          Global.locale((s) => s.accept, ctx: context),
                          type: LabelType.bodyRegular,
                          fontWeight: FontWeight.bold,
                          color: application.theme.primaryColor,
                        ),
                      ),
                      onTap: () async {
                        String? name = await BottomDialog.of(Global.appContext).showInput(
                          title: Global.locale((s) => s.accept_invitation, ctx: context),
                          desc: inviteDesc,
                          value: groupName,
                          actionText: Global.locale((s) => s.accept_invitation, ctx: context),
                          enable: false,
                        );
                        Uint8List? ownerSeed = clientCommon.client?.seed;
                        if ((name?.isNotEmpty == true) && (ownerSeed != null)) {
                          Loading.show();
                          Uint8List ownerPrivateKey = await Crypto.getPrivateKeyFromSeed(ownerSeed);
                          PrivateGroupItemSchema? groupItemSchema = PrivateGroupItemSchema.fromRawData(data);
                          groupItemSchema = await privateGroupCommon.acceptInvitation(groupItemSchema, ownerPrivateKey, toast: true);
                          if (groupItemSchema != null) {
                            // TODO:GG PG 防止频发的机制
                            await chatOutCommon.sendPrivateGroupAccept(inviter, groupItemSchema);
                            PrivateGroupSchema? groupSchema = PrivateGroupSchema.create(groupId, groupName);
                            if (groupSchema != null) await privateGroupCommon.addPrivateGroup(groupSchema, notify: true);
                          }
                          Loading.dismiss();
                          if (groupItemSchema != null) Toast.show(Global.locale((s) => s.subscribed, ctx: context));
                        }
                      },
                    ),
                  ],
                );
        }
      }
    }

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
                groupName,
                maxWidth: Global.screenWidth() * 0.5,
                type: LabelType.bodyRegular,
                fontWeight: FontWeight.bold,
                color: application.theme.fontColor1,
              ),
            ],
          ),
          expiresWidget
        ],
      ),
    );
  }

  // TODO:GG PG 代码整理
  Widget _privateGroupAcceptWidget(BuildContext context) {
    String to = (widget.message.to.length > 6) ? widget.message.to.substring(0, 6) : " ";
    String from = widget.message.from.length > 6 ? widget.message.from.substring(0, 6) : " ";
    String acceptedDesc = widget.message.isOutbound ? Global.locale((s) => s.accepted_already, ctx: context) : Global.locale((s) => s.other_accepted_already(from));

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Label(
                '$acceptedDesc. ${Global.locale((s) => s.waiting_for_sync_data, ctx: context)}.',
                type: LabelType.bodyRegular,
                color: application.theme.fontColor2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
