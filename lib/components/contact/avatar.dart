import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

class ContactAvatar extends StatefulWidget {
  final ContactSchema contact;
  final double radius;

  ContactAvatar({
    this.contact,
    this.radius,
  });

  @override
  _ContactAvatarState createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<ContactAvatar> {
  @override
  Widget build(BuildContext context) {
    String name = widget.contact?.getDisplayName ?? "";
    String avatarPath = widget.contact?.getDisplayAvatarPath;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CircleAvatar(
        radius: this.widget.radius ?? 24,
        backgroundImage: FileImage(File(avatarPath)),
      );
    } else {
      return CircleAvatar(
        radius: this.widget.radius ?? 24,
        backgroundColor: widget.contact?.options?.backgroundColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.contact?.options?.color ?? application.theme.fontLightColor,
          type: LabelType.h3,
        ),
      );
    }
  }
}
