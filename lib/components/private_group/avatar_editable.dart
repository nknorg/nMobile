import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/private_group/avatar.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/screens/common/media.dart';
import 'package:nmobile/utils/asset.dart';

class PrivateGroupSchemaEditable extends BaseStateFulWidget {
  final PrivateGroupSchema privateGroup;
  final double? radius;
  final bool? placeHolder;
  final Function? onSelect;

  PrivateGroupSchemaEditable({
    required this.privateGroup,
    this.radius,
    this.placeHolder = false,
    this.onSelect,
  });

  @override
  _PrivateGroupSchemaEditableState createState() => _PrivateGroupSchemaEditableState();
}

class _PrivateGroupSchemaEditableState extends BaseStateFulWidgetState<PrivateGroupSchemaEditable> {
  File? _avatarFile;

  @override
  void onRefreshArguments() {
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    File? avatarFile = await widget.privateGroup.displayAvatarFile;
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
    Map<String, dynamic>? item = MediaScreen.createMediasItemByImagePath(_avatarFile?.path);
    if (item != null) MediaScreen.go(context, [item]);
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
            child: PrivateGroupAvatar(
              privateGroup: widget.privateGroup,
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
