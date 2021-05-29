import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactHeader extends StatefulWidget {
  final ContactSchema contact;
  final Widget body;
  final GestureTapCallback? onTap;
  final bool syncData;

  ContactHeader({
    required this.contact,
    required this.body,
    this.onTap,
    this.syncData = true,
  });

  @override
  _ContactHeaderState createState() => _ContactHeaderState();
}

class _ContactHeaderState extends State<ContactHeader> {
  StreamSubscription? _updateContactSubscription;
  late ContactSchema _contact;

  @override
  void initState() {
    super.initState();
    this._contact = widget.contact;
  }

  @override
  void didUpdateWidget(covariant ContactHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    this._contact = widget.contact;
  }

  @override
  void dispose() {
    super.dispose();
    _updateContactSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    String name = _contact.getDisplayName;
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ContactAvatar(
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
