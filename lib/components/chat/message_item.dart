import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/chat/bubble.dart';
import 'package:nmobile/components/contact/avatar.dart';
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
  final MessageSchema? prevMessage;
  final MessageSchema? nextMessage;
  final bool lastMessageHasReceipt;
  final Function(ContactSchema, MessageSchema)? onAvatarPress;
  final Function(ContactSchema, MessageSchema)? onAvatarLonePress;
  final Function(String)? onResend;

  ChatMessageItem({
    required this.message,
    this.prevMessage,
    this.nextMessage,
    this.lastMessageHasReceipt = false,
    this.onAvatarPress,
    this.onAvatarLonePress,
    this.onResend,
  });

  @override
  _ChatMessageItemState createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends BaseStateFulWidgetState<ChatMessageItem> {
  StreamSubscription? _contactUpdateStreamSubscription;

  ContactSchema? _sender;

  @override
  void initState() {
    super.initState();
    // contact
    _contactUpdateStreamSubscription = contactCommon.updateStream.where((event) => event.address == _sender?.address).listen((event) {
      widget.message.temp?["sender"] = event;
      setState(() {
        _sender = event;
      });
    });
  }

  @override
  void onRefreshArguments() {
    _refreshSender();
  }

  void _refreshSender() {
    if ((_sender?.address.isNotEmpty == true) && (_sender?.address == widget.message.sender)) return;
    if (widget.message.temp?["sender"] == null) {
      _sender = null;
      contactCommon.query(widget.message.sender).then((sender) {
        if (widget.message.sender == sender?.address) {
          if (widget.message.temp == null) widget.message.temp = Map();
          widget.message.temp?["sender"] = sender;
          setState(() {
            _sender = sender;
          });
        } else {
          sender = ContactSchema.create(widget.message.sender, ContactType.none);
          setState(() {
            _sender = sender;
          });
        }
      }); // await
    } else {
      _sender = widget.message.temp?["sender"];
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
    bool sameUserBot = widget.message.sender == widget.prevMessage?.sender;
    bool sameUserTop = widget.message.sender == widget.nextMessage?.sender;
    // isOutbound
    bool sameReceiveBot = (widget.message.isOutbound == false) && (widget.message.isOutbound == widget.prevMessage?.isOutbound);
    bool sameReceiveTop = (widget.message.isOutbound == false) && (widget.message.isOutbound == widget.nextMessage?.isOutbound);
    // status
    bool sameStatusBot = (sameUserBot && sameReceiveBot) ? true : widget.message.status == widget.prevMessage?.status;
    bool sameStatusTop = (sameUserTop && sameReceiveTop) ? true : widget.message.status == widget.nextMessage?.status;
    // type
    bool visibleBot = widget.prevMessage?.canBurning == true;
    bool visibleSelf = widget.message.canBurning == true;
    bool visibleTop = widget.nextMessage?.canBurning == true;
    // time
    int? timeBot = widget.prevMessage?.sendAt;
    int timeSelf = widget.message.sendAt;
    int? timeTop = widget.nextMessage?.sendAt;

    // group
    bool isGroupHead = false;
    if (widget.nextMessage == null) {
      isGroupHead = true;
    } else if ((timeSelf == null) || (timeSelf == 0)) {
      isGroupHead = true;
    } else if ((timeTop == null) || (timeTop == 0)) {
      isGroupHead = true;
    } else if (!sameUserTop) {
      isGroupHead = true;
    } else if (!sameStatusTop) {
      isGroupHead = true;
    } else if (!visibleTop) {
      isGroupHead = true;
    } else {
      int curSec = timeSelf ~/ 1000;
      int nextSec = timeTop ~/ 1000;
      if ((curSec - nextSec) >= Settings.gapMessagesGroupSec) {
        isGroupHead = true;
      }
    }
    bool isGroupTail = false;
    if (widget.prevMessage == null) {
      isGroupTail = true;
    } else if (timeSelf == null || timeSelf == 0) {
      isGroupTail = true;
    } else if (timeBot == null || timeBot == 0) {
      isGroupTail = true;
    } else if (!sameUserBot) {
      isGroupTail = true;
    } else if (!sameStatusBot) {
      isGroupTail = true;
    } else if (!visibleBot) {
      isGroupTail = true;
    } else {
      int prevSec = timeBot ~/ 1000;
      int curSec = timeSelf ~/ 1000;
      if ((prevSec - curSec) >= Settings.gapMessagesGroupSec) {
        isGroupTail = true;
      }
    }
    bool isGroupBody = true;
    if (isGroupHead || isGroupTail) {
      isGroupBody = false;
    } else if (!sameUserBot || !sameUserTop) {
      isGroupBody = false;
    } else if (!sameStatusBot || !sameStatusTop) {
      isGroupBody = false;
    } else if (!visibleBot || !visibleTop) {
      isGroupBody = false;
    }

    // profile
    bool leftBigMargin = visibleSelf && !widget.message.isOutbound && (widget.message.isTargetTopic || widget.message.isTargetGroup);

    List<Widget> contentsWidget = <Widget>[];
    switch (this.widget.message.contentType) {
      case MessageContentType.text:
      case MessageContentType.textExtension:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.ipfs:
        contentsWidget.add(_widgetBubbleRoot(
          leftBigMargin,
          leftBigMargin && !isGroupHead,
          leftBigMargin && isGroupHead,
          isGroupTail,
          isGroupBody || (isGroupTail && !isGroupHead),
          isGroupBody || (isGroupHead && !isGroupTail),
        ));
        break;
      case MessageContentType.contactOptions:
        contentsWidget.add(_widgetContactOptions(context));
        break;
      case MessageContentType.topicSubscribe:
        contentsWidget.add(_widgetTopicSubscribe(context));
        break;
      case MessageContentType.topicInvitation:
        contentsWidget.add(_widgetTopicInvited(context));
        break;
      case MessageContentType.privateGroupInvitation:
        contentsWidget.add(_widgetPrivateGroupInvited(context));
        break;
      case MessageContentType.privateGroupSubscribe:
        contentsWidget.add(_widgetPrivateGroupSubscribe(context));
        break;
    }
    return Column(children: contentsWidget);
  }

  Widget _widgetBubbleRoot(
    bool avatarVisible,
    bool avatarTrans,
    bool nameVisible,
    bool showTimeAndStatus,
    bool hideTopMargin,
    bool hideBotMargin,
  ) {
    bool isSendOut = widget.message.isOutbound;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: hideTopMargin ? 0.5 : (isSendOut ? 4 : 8),
        bottom: hideBotMargin ? 0.5 : (isSendOut ? 4 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSendOut ? SizedBox.shrink() : _widgetBubbleAvatar(avatarVisible, avatarTrans),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: isSendOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                SizedBox(height: hideTopMargin ? 0 : 4),
                _widgetBubbleName(nameVisible),
                SizedBox(height: nameVisible ? 4 : 0),
                ChatBubble(
                  message: this.widget.message,
                  showTimeAndStatus: showTimeAndStatus,
                  hideTopMargin: hideTopMargin,
                  hideBotMargin: hideBotMargin,
                  lastMessageHasReceipt: this.widget.lastMessageHasReceipt,
                  onResend: this.widget.onResend,
                ),
                SizedBox(height: hideBotMargin ? 0 : 4),
              ],
            ),
          ),
          SizedBox(width: 8),
          isSendOut ? _widgetBubbleAvatar(avatarVisible, avatarTrans) : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _widgetBubbleAvatar(bool visible, bool trans) {
    return visible
        ? Opacity(
            opacity: trans ? 0 : 1,
            child: GestureDetector(
              onTap: () async {
                if (!trans) this.widget.onAvatarPress?.call(_sender!, widget.message);
              },
              onLongPress: () {
                if (!trans) this.widget.onAvatarLonePress?.call(_sender!, widget.message);
              },
              child: (_sender != null)
                  ? ContactAvatar(
                      contact: _sender!,
                      radius: 20,
                    )
                  : SizedBox(width: 20 * 2, height: 20 * 2),
            ),
          )
        : SizedBox.shrink();
  }

  Widget _widgetBubbleName(bool visible) {
    return visible
        ? Label(
            _sender?.displayName ?? " ",
            maxWidth: Settings.screenWidth() * 0.5,
            type: LabelType.h3,
            color: application.theme.primaryColor,
          )
        : SizedBox.shrink();
  }

  Widget _widgetContactOptions(BuildContext context) {
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
                    widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : (this._sender?.displayName ?? " "),
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
                  final String peerAddress = widget.message.isOutbound ? widget.message.targetId : widget.message.sender;
                  ContactProfileScreen.go(context, address: peerAddress);
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
                    widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : (this._sender?.displayName ?? " "),
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
                  ContactProfileScreen.go(context, schema: this._sender);
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

  Widget _widgetTopicSubscribe(BuildContext context) {
    String who = widget.message.isOutbound ? Settings.locale((s) => s.you, ctx: context) : _sender?.displayName ?? widget.message.sender.substring(0, 6);
    String content = who + ' ' + Settings.locale((s) => s.joined_channel, ctx: context);

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

  Widget _widgetTopicInvited(BuildContext context) {
    String receiver = (widget.message.targetId.length > 6) ? widget.message.targetId.substring(0, 6) : " ";
    String sender = widget.message.sender.length > 6 ? widget.message.sender.substring(0, 6) : " ";
    String inviteDesc = widget.message.isOutbound ? Settings.locale((s) => s.invites_desc_other(receiver), ctx: context) : Settings.locale((s) => s.invites_desc_me(sender), ctx: context);

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
                TopicSchema(topicId: widget.message.content?.toString() ?? " ").topicNameShort,
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
                      double? fee = await topicCommon.getTopicSubscribeFee(Settings.appContext);
                      if (fee == null) return;
                      Loading.show();
                      bool isJustNow = (DateTime.now().millisecondsSinceEpoch - widget.message.sendAt) < Settings.gapTxPoolUpdateDelayMs;
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

  Widget _widgetPrivateGroupInvited(BuildContext context) {
    String receiver = (widget.message.targetId.length > 6) ? widget.message.targetId.substring(0, 6) : " ";
    String sender = widget.message.sender.length > 6 ? widget.message.sender.substring(0, 6) : " ";
    String inviteDesc = widget.message.isOutbound ? Settings.locale((s) => s.invites_desc_other(receiver), ctx: context) : Settings.locale((s) => s.invites_desc_me(sender), ctx: context);

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
                            groupSchema = await privateGroupCommon.addPrivateGroup(groupSchema, notify: true);
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

  Widget _widgetPrivateGroupSubscribe(BuildContext context) {
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
