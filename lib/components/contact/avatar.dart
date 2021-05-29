import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/asset.dart';

class ContactAvatar extends StatefulWidget {
  final ContactSchema contact;
  final double? radius;
  final bool? placeHolder;

  ContactAvatar({
    required this.contact,
    this.radius,
    this.placeHolder = false,
  });

  @override
  _ContactAvatarState createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<ContactAvatar> {
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _checkAvatarFileExists();
  }

  @override
  void didUpdateWidget(covariant ContactAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAvatarFileExists();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _checkAvatarFileExists() async {
    File? avatarFile = await widget.contact.getDisplayAvatarFile;
    if (mounted) {
      if (_avatarFile?.path != avatarFile?.path) {
        setState(() {
          _avatarFile = avatarFile;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String name = widget.contact.getDisplayName;

    if (_avatarFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(this._avatarFile!),
      );
    }
    if (widget.placeHolder == null || !widget.placeHolder!) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: widget.contact.options?.backgroundColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.contact.options?.color ?? application.theme.fontLightColor,
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
