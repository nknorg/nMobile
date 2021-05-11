import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

class ContactItem extends StatelessWidget {
  final Widget body;
  final ContactSchema contact;

  ContactItem({
    this.body,
    this.contact,
  });

  @override
  Widget build(BuildContext context) {
    String name = contact.getDisplayName;
    return Flex(
      direction: Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: contact.options.backgroundColor.withAlpha(19),
            child: Label(
              name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
              type: LabelType.h4,
              color: contact.options.color,
            ),
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
