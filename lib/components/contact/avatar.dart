import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/asset.dart';

class ContactAvatar extends StatefulWidget {
  final ContactSchema contact;
  final double radius;
  final bool placeHolder;

  ContactAvatar({
    this.contact,
    this.radius,
    this.placeHolder = false,
  });

  @override
  _ContactAvatarState createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<ContactAvatar> {
  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String name = widget.contact?.getDisplayName ?? "";
    String avatarPath = widget.contact?.getDisplayAvatarPath;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      File avatarFile = File(avatarPath);
      if (avatarFile != null && avatarFile.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(avatarFile),
        );
      }
    }
    if (widget.placeHolder == null || !widget.placeHolder) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: widget.contact?.options?.backgroundColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.contact?.options?.color ?? application.theme.fontLightColor,
          type: LabelType.h3,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: application.theme.backgroundColor2,
      child: Asset.iconSvg('user', color: application.theme.fontColor2),
    );
  }
}
