import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/asset.dart';

class ContactAvatar extends BaseStateFulWidget {
  final ContactSchema contact;
  final double radius;
  final bool placeHolder;

  ContactAvatar({
    required this.contact,
    this.radius = 24,
    this.placeHolder = false,
  });

  @override
  _ContactAvatarState createState() => _ContactAvatarState();
}

class _ContactAvatarState extends BaseStateFulWidgetState<ContactAvatar> {
  bool _fileError = false;
  // File? _avatarFile;

  @override
  void onRefreshArguments() {
    _fileError = false;
    // _checkAvatarFileExists();
  }

  // _checkAvatarFileExists() async {
  //   File? avatarFile = await widget.contact.displayAvatarFile;
  //   if (_avatarFile?.path != avatarFile?.path) {
  //     setState(() {
  //       _avatarFile = avatarFile;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius;
    String name = widget.contact.displayName;
    String? path = widget.contact.displayAvatarPath;

    if (_fileError || path?.isNotEmpty == true) {
      // _avatarFile != null
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path!)),
        onBackgroundImageError: (Object exception, StackTrace? stackTrace) {
          if (!_fileError) {
            setState(() {
              _fileError = true;
            });
          }
        },
      );
    }
    if (widget.placeHolder == true) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: application.theme.backgroundColor2,
        child: Asset.iconSvg('user', color: application.theme.fontColor2),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: widget.contact.options?.avatarBgColor ?? application.theme.primaryColor.withAlpha(19),
      child: Label(
        name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
        color: widget.contact.options?.avatarNameColor ?? application.theme.fontLightColor,
        type: LabelType.h3,
        fontSize: radius / 3 * 2,
      ),
    );
  }
}
