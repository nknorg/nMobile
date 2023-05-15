import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

class SubscriberItem extends BaseStateFulWidget {
  final SubscriberSchema subscriber;
  final TopicSchema? topic;
  final Widget? body;
  final String? bodyTitle;
  final String? bodyDesc;
  final Function(ContactSchema?)? onTap;
  final bool onTapWave;
  final Color? bgColor;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final Widget? tail;

  SubscriberItem({
    required this.topic,
    required this.subscriber,
    this.body,
    this.bodyTitle,
    this.bodyDesc,
    this.onTap,
    this.onTapWave = true,
    this.bgColor,
    this.radius,
    this.padding,
    this.tail,
  });

  @override
  _SubscriberItemState createState() => _SubscriberItemState();
}

class _SubscriberItemState extends BaseStateFulWidgetState<SubscriberItem> {
  StreamSubscription? _updateContactSubscription;

  ContactSchema? contact;

  @override
  void onRefreshArguments() {
    _refreshContact();
  }

  @override
  void initState() {
    super.initState();
    // listen
    _updateContactSubscription = contactCommon.updateStream.where((event) => event.address == contact?.address).listen((ContactSchema event) {
      widget.subscriber.temp?["contact"] = event;
      setState(() {
        contact = event;
      });
    });
  }

  void _refreshContact() {
    String? address = widget.subscriber.clientAddress;
    if ((contact?.address.isNotEmpty == true) && (contact?.address == address)) return;
    if (widget.subscriber.temp?["contact"] == null) {
      contactCommon.query(address).then((result) async {
        if (result == null) {
          result = await contactCommon.addByType(address, ContactType.none, fetchWalletAddress: false, notify: true);
        }
        if ((address == result?.address) && (address == widget.subscriber.clientAddress)) {
          if (widget.subscriber.temp == null) widget.subscriber.temp = Map();
          widget.subscriber.temp?["contact"] = result;
          setState(() {
            contact = result;
          });
        }
      }); // await
    } else {
      contact = widget.subscriber.temp?["contact"];
    }
  }

  @override
  void dispose() {
    _updateContactSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this.widget.onTap != null
        ? this.widget.onTapWave
            ? Material(
                color: this.widget.bgColor,
                elevation: 0,
                borderRadius: this.widget.radius,
                child: InkWell(
                  borderRadius: this.widget.radius,
                  onTap: () {
                    this.widget.onTap?.call(this.contact);
                  },
                  child: _getItemBody(),
                ),
              )
            : InkWell(
                borderRadius: this.widget.radius,
                onTap: () {
                  this.widget.onTap?.call(this.contact);
                },
                child: _getItemBody(),
              )
        : _getItemBody();
  }

  Widget _getItemBody() {
    return Container(
      decoration: BoxDecoration(
        color: (this.widget.onTap != null && this.widget.onTapWave) ? null : this.widget.bgColor,
        borderRadius: this.widget.radius,
      ),
      padding: this.widget.padding ?? EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: this.contact != null
                ? ContactAvatar(
                    radius: 24,
                    contact: this.contact!,
                  )
                : SizedBox(width: 24, height: 24),
          ),
          Expanded(
            child: this.widget.body != null
                ? this.widget.body!
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      this.widget.bodyTitle != null
                          ? Label(
                              this.widget.bodyTitle ?? "",
                              type: LabelType.h3,
                              fontWeight: FontWeight.bold,
                            )
                          : _getNameLabels(this.widget.topic, this.widget.subscriber, this.contact),
                      SizedBox(height: 6),
                      Label(
                        this.widget.bodyDesc ?? this.widget.subscriber.clientAddress,
                        maxLines: 1,
                        type: LabelType.bodyRegular,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          this.widget.tail ?? _getTailAction(this.widget.topic, this.widget.subscriber, this.contact),
        ],
      ),
    );
  }

  Widget _getNameLabels(TopicSchema? topic, SubscriberSchema subscriber, ContactSchema? contact) {
    String displayName = contact?.displayName ?? " ";
    String clientAddress = subscriber.clientAddress;
    int? status = subscriber.status;

    // _mark
    List<String> marks = [];
    if (clientAddress == clientCommon.address) {
      marks.add(Settings.locale((s) => s.you));
    }
    if (topic?.isOwner(clientAddress) == true) {
      marks.add(Settings.locale((s) => s.owner));
    } else if (topic?.isOwner(clientCommon.address) == true) {
      if (status == SubscriberStatus.InvitedSend) {
        marks.add(Settings.locale((s) => s.invitation_sent));
      } else if (status == SubscriberStatus.InvitedReceipt) {
        marks.add(Settings.locale((s) => s.invite_and_send_success));
      } else if (status == SubscriberStatus.Subscribed) {
        marks.add(Settings.locale((s) => s.accepted));
      } else if (status == SubscriberStatus.Unsubscribed) {
        marks.add(Settings.locale((s) => s.has_left_the_group));
      } else {
        marks.add(Settings.locale((s) => s.join_but_not_invite));
      }
    }
    String marksText = marks.isNotEmpty ? "(${marks.join(", ")})" : " ";

    Color textColor;
    if (topic?.isPrivate == true) {
      if (status == SubscriberStatus.InvitedSend) {
        textColor = application.theme.fontColor1;
      } else if (status == SubscriberStatus.InvitedReceipt) {
        textColor = application.theme.primaryColor;
      } else if (status == SubscriberStatus.Subscribed) {
        textColor = application.theme.successColor;
      } else if (status == SubscriberStatus.Unsubscribed) {
        textColor = application.theme.fallColor;
      } else {
        textColor = application.theme.fontColor2;
      }
    } else {
      textColor = application.theme.successColor;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Label(displayName, type: LabelType.h4, overflow: TextOverflow.ellipsis),
        SizedBox(width: 4),
        Expanded(
          child: Label(
            marksText,
            type: LabelType.bodySmall,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _getTailAction(TopicSchema? topic, SubscriberSchema subscriber, ContactSchema? contact) {
    if (topic == null || !topic.isPrivate) return SizedBox.shrink();
    if (!clientCommon.isClientOK) return SizedBox.shrink();
    if (subscriber.clientAddress == clientCommon.address) return SizedBox.shrink();
    if (!topic.isOwner(clientCommon.address)) return SizedBox.shrink();

    return SizedBox(
      width: 20 + 16 + 6,
      height: 20 + 16 + 6,
      child: InkWell(
        child: Padding(
          padding: EdgeInsets.only(left: 6, right: 16),
          child: subscriber.canBeKick
              ? Icon(
                  Icons.block,
                  size: 20,
                  color: application.theme.fallColor,
                )
              : Asset.image(
                  'chat/invisit-blue.png',
                  width: 20,
                  height: double.infinity,
                  color: application.theme.successColor,
                ),
        ),
        onTap: () async {
          if (subscriber.canBeKick) {
            ModalDialog.of(Settings.appContext).confirm(
              title: Settings.locale((s) => s.reject_user_tip),
              contentWidget: contact != null
                  ? ContactItem(
                      contact: contact,
                      bodyTitle: contact.displayName,
                      bodyDesc: contact.address,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    )
                  : SizedBox.shrink(),
              agree: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.ok),
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  double? fee = await topicCommon.getTopicSubscribeFee(this.context);
                  if (fee == null) return;
                  await topicCommon.kick(
                    topic.topic,
                    topic.isPrivate,
                    topic.isOwner(clientCommon.address),
                    subscriber.clientAddress,
                    fee: fee,
                    toast: true,
                  );
                },
              ),
              reject: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.cancel),
                fontColor: application.theme.fontColor2,
                backgroundColor: application.theme.backgroundLightColor,
                onPressed: () {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                },
              ),
            );
          } else {
            double? fee = 0.0;
            if (topic.isPrivate == true) {
              fee = await topicCommon.getTopicSubscribeFee(this.context);
              if (fee == null) return;
            }
            await topicCommon.invitee(
              topic.topic,
              topic.isPrivate,
              topic.isOwner(clientCommon.address),
              subscriber.clientAddress,
              fee: fee,
              toast: true,
              sendMsg: true,
            );
          }
        },
      ),
    );
  }
}
