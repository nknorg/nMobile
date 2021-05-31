import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/utils/asset.dart';

import 'avatar.dart';

class ContactAvatarEditable extends BaseStateFulWidget {
  final ContactSchema contact;
  final double? radius;
  final bool? placeHolder;
  final Function? onSelect;

  ContactAvatarEditable({
    required this.contact,
    this.radius,
    this.placeHolder = false,
    this.onSelect,
  });

  @override
  _ContactAvatarEditableState createState() => _ContactAvatarEditableState();
}

class _ContactAvatarEditableState extends BaseStateFulWidgetState<ContactAvatarEditable> {
  File? _avatarFile;

  @override
  void onRefreshArguments() {
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    File? avatarFile = await widget.contact.getDisplayAvatarFile;
    if (_avatarFile?.path != avatarFile?.path) {
      setState(() {
        _avatarFile = avatarFile;
      });
    }
  }

  _selectAvatarFile() async {
    widget.onSelect?.call();
  }

  _photoShow(BuildContext context) {
    PhotoScreen.go(context, filePath: _avatarFile?.path);
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              if (this._avatarFile != null) {
                _photoShow(context);
              } else {
                _selectAvatarFile();
              }
            },
            child: ContactAvatar(
              contact: widget.contact,
              radius: radius,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Button(
              padding: const EdgeInsets.all(0),
              width: radius / 2,
              height: radius / 2,
              backgroundColor: application.theme.primaryColor,
              child: Asset.iconSvg(
                'camera',
                color: application.theme.backgroundLightColor,
                width: radius / 5,
              ),
              onPressed: () {
                _selectAvatarFile();
              },
            ),
          )
        ],
      ),
    );
  }
}
