import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
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
    _updateContactSubscription = contactCommon.updateStream.where((event) => event.id == contact?.id).listen((ContactSchema event) {
      setState(() {
        contact = event;
      });
    });
  }

  _refreshContact() async {
    if (contact?.clientAddress == null || contact?.clientAddress.isEmpty == true || contact?.clientAddress != widget.subscriber.clientAddress) {
      ContactSchema? _contact = await widget.subscriber.getContact(emptyAdd: true);
      setState(() {
        contact = _contact;
      });
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
          this.widget.tail != null ? this.widget.tail! : _getTailAction(this.widget.topic, this.widget.subscriber, this.contact),
        ],
      ),
    );
  }

  Widget _getNameLabels(TopicSchema? topic, SubscriberSchema subscriber, ContactSchema? contact) {
    S _localizations = S.of(context);

    String displayName = contact?.displayName ?? " ";
    String clientAddress = subscriber.clientAddress;
    int? status = subscriber.status;

    // _mark
    List<String> marks = [];
    if (clientAddress == clientCommon.address) {
      marks.add(_localizations.you);
    }
    if (topic?.isOwner(clientAddress) == true) {
      marks.add(_localizations.owner);
    } else if (topic?.isOwner(clientCommon.address) == true) {
      if (status == SubscriberStatus.InvitedSend) {
        marks.add(_localizations.invitation_sent);
      } else if (status == SubscriberStatus.InvitedReceipt) {
        marks.add(_localizations.invite_and_send_success);
      } else if (status == SubscriberStatus.Subscribed) {
        marks.add(_localizations.accepted);
      } else if (status == SubscriberStatus.Unsubscribed) {
        marks.add(_localizations.rejected);
      } else {
        marks.add(_localizations.join_but_not_invite);
      }
    }
    String marksText = marks.isNotEmpty ? "(${marks.join(", ")})" : " ";

    Color textColor = !(topic?.isPrivate == true) ? application.theme.successColor : ((status == SubscriberStatus.InvitedSend || status == SubscriberStatus.InvitedReceipt || status == SubscriberStatus.Subscribed) ? application.theme.successColor : ((status == SubscriberStatus.Unsubscribed) ? application.theme.fallColor : application.theme.fontColor2));

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
    if (clientCommon.address == null || clientCommon.address!.isEmpty) return SizedBox.shrink();
    if (subscriber.clientAddress == clientCommon.address) return SizedBox.shrink();
    if (!topic.isOwner(clientCommon.address)) return SizedBox.shrink();

    return InkWell(
      child: Padding(
        padding: EdgeInsets.only(left: 6, right: 16),
        child: subscriber.canBeKick
            ? Icon(
                Icons.block,
                size: 20,
                color: application.theme.fallColor,
              )
            : Asset.iconSvg(
                'check',
                width: 20,
                height: double.infinity,
                color: application.theme.successColor,
              ),
      ),
      onTap: () async {
        if (subscriber.canBeKick) {
          Loading.show();
          await topicCommon.kick(
            topic.topic,
            subscriber.clientAddress,
            topic.isPrivate,
            topic.isOwner(clientCommon.address),
          );
          Loading.dismiss();
          Toast.show(S.of(context).rejected);
        } else {
          Loading.show();
          await topicCommon.invitee(
            topic.topic,
            subscriber.clientAddress,
            topic.isPrivate,
            topic.isOwner(clientCommon.address),
          );
          Loading.dismiss();
          Toast.show(S.of(context).invitation_sent);
        }
      },
    );
  }
}
