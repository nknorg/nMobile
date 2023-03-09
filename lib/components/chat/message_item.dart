import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/time.dart';

class ChatMessageItem extends BaseStateFulWidget {
  final MessageSchema message;
  // final ContactSchema? contact;
  // final TopicSchema? topic;
  // final PrivateGroupSchema? privateGroup;
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final Function(ContactSchema, MessageSchema)? onAvatarLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    // required this.contact,
    // required this.topic,
    // required this.privateGroup,
    this.prevMessage,
    this.nextMessage,
    this.onAvatarLonePress,
    this.onResend,
  });

  @override
  _ChatMessageItemState createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends BaseStateFulWidgetState<ChatMessageItem> {
  StreamSubscription? _contactUpdateStreamSubscription;

  ContactSchema? _contact;

  @override
  void initState() {
    super.initState();
    // contact TODO:GG 头像闪烁，是不是没改回去？以前也闪吗？
    _contactUpdateStreamSubscription = contactCommon.updateStream.listen((event) {
      if (_contact?.id == event.id) {
        setState(() {
          _contact = event;
        });
      }
    });
  }

  @override
  void onRefreshArguments() {
    // topic/group no contact TODO:GG 头像闪烁，是不是没改回去？以前也闪吗？
    if ((_contact == null) || (_contact?.clientAddress != widget.message.from)) {
      contactCommon.queryByClientAddress(widget.message.from).then((contact) async {
        bool existsErr = (_contact == null) || (_contact?.clientAddress != widget.message.from);
        bool newRight = (contact != null) || (contact?.clientAddress == widget.message.from);
        if (existsErr && newRight) {
          setState(() {
            _contact = contact;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _contactUpdateStreamSubscription?.cancel();
    super.dispose();
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
    int? prevSendAt = widget.prevMessage?.reallySendAt;
    int? currSendAt = widget.message.reallySendAt;
    int? nextSendAt = widget.nextMessage?.reallySendAt;

    // group
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
      if ((curSec - nextSec) >= Settings.gapMessagesGroupSec) {
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
      if ((prevSec - curSec) >= Settings.gapMessagesGroupSec) {
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
            contact: _contact,
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
        contentsWidget.add(_topicInvitedWidget(context));
        break;
      // case MessageContentType.topicKickOut:
      case MessageContentType.privateGroupInvitation:
        contentsWidget.add(_privateGroupInvitedWidget(context));
        break;
      // case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupSubscribe:
        contentsWidget.add(_privateGroupSubscribeWidget(context));
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
                          Settings.locale((s) => s.off, ctx: context),
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
                    widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : (this._contact?.displayName ?? " "),
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    ' ${isBurnOpen ? Settings.locale((s) => s.update_burn_after_reading, ctx: context) : Settings.locale((s) => s.close_burn_after_reading, ctx: context)} ',
                    maxWidth: Settings.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  Settings.locale((s) => s.click_to_change, ctx: context),
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this._contact);
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
                    widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : (this._contact?.displayName ?? " "),
                    maxWidth: Settings.screenWidth() * 0.3,
                    type: LabelType.bodyRegular,
                    fontWeight: FontWeight.bold,
                  ),
                  Label(
                    isDeviceTokenOpen ? ' ${Settings.locale((s) => s.setting_accept_notification, ctx: context)}' : ' ${Settings.locale((s) => s.setting_deny_notification, ctx: context)}',
                    maxWidth: Settings.screenWidth() * 0.7,
                    type: LabelType.bodyRegular,
                  ),
                ],
              ),
              SizedBox(height: 4),
              InkWell(
                child: Label(
                  Settings.locale((s) => s.click_to_change, ctx: context),
                  color: application.theme.primaryColor,
                  type: LabelType.bodyRegular,
                ),
                onTap: () {
                  ContactProfileScreen.go(context, schema: this._contact);
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
    String who = widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : _contact?.displayName ?? widget.message.from.substring(0, 6);
    String content = who + Settings.locale((s) => s.joined_channel, ctx: context);

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
    String inviteDesc = widget.message.isOutbound ? Settings.locale((s) => s.invites_desc_other(to), ctx: context) : Settings.locale((s) => s.invites_desc_me(from), ctx: context);

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
                maxWidth: Settings.screenWidth() * 0.5,
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
                      Settings.locale((s) => s.accept, ctx: context),
                      type: LabelType.bodyRegular,
                      fontWeight: FontWeight.bold,
                      color: application.theme.primaryColor,
                    ),
                  ),
                  onTap: () async {
                    String? topic = await BottomDialog.of(Settings.appContext).showInput(
                      title: Settings.locale((s) => s.accept_invitation, ctx: context),
                      desc: inviteDesc,
                      value: widget.message.content?.toString() ?? " ",
                      actionText: Settings.locale((s) => s.accept_invitation, ctx: context),
                      enable: false,
                    );
                    if (topic?.isNotEmpty == true) {
                      double? fee = await BottomDialog.of(Settings.appContext).showTransactionSpeedUp();
                      if (fee == null) return;
                      Loading.show();
                      int sendAt = widget.message.sendAt ?? 0;
                      bool isJustNow = (DateTime.now().millisecondsSinceEpoch - sendAt) < Settings.gapTxPoolUpdateMs;
                      TopicSchema? result = await topicCommon.subscribe(topic, fetchSubscribers: true, justNow: isJustNow, fee: fee);
                      Loading.dismiss();
                      if (result != null) Toast.show(Settings.locale((s) => s.subscribed, ctx: context));
                    }
                  },
                )
        ],
      ),
    );
  }

  Widget _privateGroupInvitedWidget(BuildContext context) {
    String to = (widget.message.to.length > 6) ? widget.message.to.substring(0, 6) : " ";
    String from = widget.message.from.length > 6 ? widget.message.from.substring(0, 6) : " ";
    String inviteDesc = widget.message.isOutbound ? Settings.locale((s) => s.invites_desc_other(to), ctx: context) : Settings.locale((s) => s.invites_desc_me(from), ctx: context);

    Map content = (widget.message.content != null) ? (widget.message.content as Map) : Map();
    String groupId = content['groupId']?.toString() ?? "";
    String groupName = content['name']?.toString() ?? "";
    int type = int.tryParse(content['type']?.toString() ?? "0") ?? PrivateGroupType.normal;
    Map<String, dynamic> itemData = content['item'] ?? Map();
    int expiresAt = int.tryParse(itemData['expiresAt']?.toString() ?? "0") ?? 0;
    String inviter = itemData['inviter']?.toString() ?? "";
    if (content.isEmpty || itemData.isEmpty) return SizedBox.shrink();

    Widget expiresWidget;
    if (expiresAt < DateTime.now().millisecondsSinceEpoch) {
      expiresWidget = Label(
        Settings.locale((s) => s.expired, ctx: context),
        color: application.theme.fontColor2,
        type: LabelType.bodyRegular,
      );
    } else {
      expiresWidget = widget.message.isOutbound
          ? Label(
              Settings.locale((s) => s.expiration, ctx: context) + ': ' + Time.formatTimeFromNow(DateTime.fromMillisecondsSinceEpoch(expiresAt)),
              color: application.theme.fontColor2,
              type: LabelType.bodyRegular,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Label(
                  Settings.locale((s) => s.expiration, ctx: context) + ': ' + Time.formatTimeFromNow(DateTime.fromMillisecondsSinceEpoch(expiresAt)),
                  color: application.theme.fontColor2,
                  type: LabelType.bodyRegular,
                ),
                InkWell(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                    child: Label(
                      Settings.locale((s) => s.accept, ctx: context),
                      type: LabelType.bodyRegular,
                      fontWeight: FontWeight.bold,
                      color: application.theme.primaryColor,
                    ),
                  ),
                  onTap: () async {
                    String? value = await BottomDialog.of(Settings.appContext).showInput(
                      title: Settings.locale((s) => s.accept_invitation, ctx: context),
                      desc: inviteDesc,
                      value: groupName,
                      actionText: Settings.locale((s) => s.accept_invitation, ctx: context),
                      enable: false,
                    );
                    if (value?.isNotEmpty == true) {
                      Loading.show();
                      PrivateGroupSchema? groupSchema;
                      PrivateGroupItemSchema? groupItemSchema = PrivateGroupItemSchema.fromRawData(itemData);
                      groupItemSchema = await privateGroupCommon.acceptInvitation(groupItemSchema, toast: true);
                      if (groupItemSchema != null) {
                        if (await chatOutCommon.sendPrivateGroupAccept(inviter, groupItemSchema)) {
                          groupSchema = PrivateGroupSchema.create(groupId, groupName, type: type);
                          if (groupSchema != null) {
                            groupSchema = await privateGroupCommon.addPrivateGroup(groupSchema, notify: true, checkDuplicated: false);
                          }
                          if (groupSchema != null) {
                            await sessionCommon.add(groupSchema.groupId, SessionType.PRIVATE_GROUP, lastMsgAt: DateTime.now().millisecondsSinceEpoch, unReadCount: 0);
                          }
                        }
                      }
                      Loading.dismiss();
                      if (groupSchema != null) Toast.show(Settings.locale((s) => s.waiting_for_data_to_sync, ctx: context));
                    }
                  },
                ),
              ],
            );
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
                maxWidth: Settings.screenWidth() * 0.5,
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

  Widget _privateGroupSubscribeWidget(BuildContext context) {
    String invitee = widget.message.content?.toString() ?? "";
    if (invitee.isEmpty) return SizedBox.shrink();
    String inviteeDisplay = (invitee.length > 6) ? invitee.substring(0, 6) : invitee;
    String who = ((clientCommon.address == invitee) ? Settings.locale((s) => s.you, ctx: context) : "$inviteeDisplay: ");
    String content = who + Settings.locale((s) => s.joined_channel, ctx: context);
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
}
