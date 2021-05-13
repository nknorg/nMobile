import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactItem extends StatelessWidget {
  final Widget body;
  final ContactSchema contact;

  ContactItem({
    this.body,
    this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: ContactAvatar(
            contact: contact,
          ),
        ),
        Expanded(
          flex: 1,
          child: body,
        )
      ],
    );
  }
}
