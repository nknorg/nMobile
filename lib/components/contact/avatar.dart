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
    Key key,
    this.contact,
    this.radius,
    this.placeHolder = false,
  }) : super(key: key);

  @override
  _ContactAvatarState createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<ContactAvatar> {
  bool _avatarFileExits = false;

  @override
  void initState() {
    super.initState();
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    String avatarPath = widget.contact?.getDisplayAvatarPath;
    bool exists = await File(avatarPath).exists();
    if (_avatarFileExits != exists) {
      setState(() {
        _avatarFileExits = exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String name = widget.contact?.getDisplayName ?? "";
    String avatarPath = widget.contact?.getDisplayAvatarPath;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      File avatarFile = File(avatarPath);
      if (_avatarFileExits) {
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
          fontSize: radius / 3 * 2,
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
