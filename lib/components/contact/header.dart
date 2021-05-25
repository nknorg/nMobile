import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactHeader extends StatefulWidget {
  final Widget body;
  final ContactSchema contact;
  final GestureTapCallback onTap;
  final bool syncData;

  ContactHeader({
    this.body,
    this.contact,
    this.onTap,
    this.syncData = true,
  });

  @override
  _ContactHeaderState createState() => _ContactHeaderState();
}

class _ContactHeaderState extends State<ContactHeader> {
  StreamSubscription _updateContactSubscription;
  ContactSchema _contact;

  @override
  void initState() {
    super.initState();
    this._contact = widget.contact;

    // listen
    if (widget.syncData != null && widget.syncData) {
      _updateContactSubscription = contact.updateStream.listen((List<ContactSchema> list) {
        if (list == null || list.isEmpty) return;
        List result = list.where((element) => (element != null) && (element?.id == _contact?.id)).toList();
        if (result != null && result.isNotEmpty) {
          if (mounted) {
            setState(() {
              _contact = result[0];
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _updateContactSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    String name = _contact?.getDisplayName ?? "";
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ContactAvatar(
              key: ValueKey(_contact?.getDisplayAvatarPath ?? ""),
              contact: _contact,
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Label(name, type: LabelType.h3, dark: true),
                widget.body,
              ],
            ),
          )
        ],
      ),
    );
  }
}
