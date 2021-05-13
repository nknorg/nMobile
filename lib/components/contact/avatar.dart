import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

class ContactAvatar extends StatelessWidget {
  final ContactSchema contact;
  ContactAvatar({this.contact});
  @override
  Widget build(BuildContext context) {
    String name = contact.getDisplayName;
    return CircleAvatar(
      radius: 24,
      backgroundColor: contact.options.backgroundColor.withAlpha(19),
      child: Label(
        name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
        type: LabelType.h4,
        color: contact.options.color,
      ),
    );
  }
}
