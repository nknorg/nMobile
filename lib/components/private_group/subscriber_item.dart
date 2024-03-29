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
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';

class SubscriberItem extends BaseStateFulWidget {
  final PrivateGroupSchema? privateGroup;
  final PrivateGroupItemSchema privateGroupItem;
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
    required this.privateGroup,
    required this.privateGroupItem,
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
      widget.privateGroupItem.temp?["contact"] = event;
      setState(() {
        contact = event;
      });
    });
  }

  void _refreshContact() {
    String? address = widget.privateGroupItem.invitee;
    if ((contact?.address.isNotEmpty == true) && (contact?.address == address)) return;
    if (widget.privateGroupItem.temp?["contact"] == null) {
      contactCommon.query(address).then((result) async {
        if (result == null) {
          result = await contactCommon.addByType(address, ContactType.none, fetchWalletAddress: false, notify: true);
        }
        if ((address == result?.address) && (address == widget.privateGroupItem.invitee)) {
          if (widget.privateGroupItem.temp == null) widget.privateGroupItem.temp = Map();
          widget.privateGroupItem.temp?["contact"] = result;
          setState(() {
            contact = result;
          });
        }
      }); // await
    } else {
      contact = widget.privateGroupItem.temp?["contact"];
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
                          : _getNameLabels(this.widget.privateGroup, this.widget.privateGroupItem, this.contact),
                      SizedBox(height: 6),
                      Label(
                        this.widget.bodyDesc ?? this.widget.privateGroupItem.invitee ?? "",
                        maxLines: 1,
                        type: LabelType.bodyRegular,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          this.widget.tail ?? _getTailAction(this.widget.privateGroup, this.widget.privateGroupItem, this.contact),
        ],
      ),
    );
  }

  Widget _getNameLabels(PrivateGroupSchema? privateGroup, PrivateGroupItemSchema privateGroupItem, ContactSchema? contact) {
    String displayName = contact?.displayName ?? " ";
    String clientAddress = privateGroupItem.invitee!;
    // int? permission = privateGroupItem.permission;

    // _mark
    List<String> marks = [];
    if (clientAddress == clientCommon.address) {
      marks.add(Settings.locale((s) => s.you));
    }
    if (privateGroupCommon.isOwner(privateGroup?.ownerPublicKey, clientAddress)) {
      marks.add(Settings.locale((s) => s.owner));
    } else if (privateGroupCommon.isOwner(privateGroup?.ownerPublicKey, clientAddress)) {
      // FUTURE:GG PG admin
    }
    String marksText = marks.isNotEmpty ? "(${marks.join(", ")})" : " ";

    Color textColor = application.theme.fontColor1;

    if (privateGroupItem.inviteeSignature?.isNotEmpty == true) {
      textColor = application.theme.successColor;
    } else {
      textColor = application.theme.fontColor2;
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

  Widget _getTailAction(PrivateGroupSchema? privateGroup, PrivateGroupItemSchema privateGroupItem, ContactSchema? contact) {
    if (privateGroup == null) return SizedBox.shrink();
    if (!clientCommon.isClientOK) return SizedBox.shrink();
    if (privateGroupItem.invitee == clientCommon.address) return SizedBox.shrink();
    if (!privateGroupCommon.isOwner(privateGroup.ownerPublicKey, clientCommon.getPublicKey())) return SizedBox.shrink();

    return SizedBox(
      width: 20 + 16 + 6,
      height: 20 + 16 + 6,
      child: InkWell(
        child: Padding(
          padding: EdgeInsets.only(left: 6, right: 16),
          child: Icon(
            Icons.block,
            size: 20,
            color: application.theme.fallColor,
          ),
        ),
        onTap: () async {
          // subscriber.canBeKick
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
                bool success = await privateGroupCommon.kickOut(
                  this.widget.privateGroup?.groupId,
                  this.widget.privateGroupItem.invitee,
                  notify: true,
                  toast: true,
                );
                if (success) Toast.show(Settings.locale((s) => s.rejected));
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
        },
      ),
    );
  }
}
