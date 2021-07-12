import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactHeader extends StatelessWidget {
  final ContactSchema contact;
  final Widget body;
  final GestureTapCallback? onTap;

  ContactHeader({
    required this.contact,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String name = this.contact.displayName;
    return GestureDetector(
      onTap: () {
        if (this.onTap != null) this.onTap!();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ContactAvatar(
              contact: this.contact,
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Label(name, type: LabelType.h3, dark: true),
                this.body,
              ],
            ),
          )
        ],
      ),
    );
  }
}
