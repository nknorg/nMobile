import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/common/media.dart';

class ContactAvatarEditable extends BaseStateFulWidget {
  final ContactSchema contact;
  final double? radius;
  final bool? placeHolder;
  final Function? onSelect;
  final Function? onDrop;

  ContactAvatarEditable({
    required this.contact,
    this.radius,
    this.placeHolder = false,
    this.onSelect,
    this.onDrop,
  });

  @override
  _ContactAvatarEditableState createState() => _ContactAvatarEditableState();
}

class _ContactAvatarEditableState extends BaseStateFulWidgetState<ContactAvatarEditable> {
  File? _avatarFile;

  bool canDrop = false;

  @override
  void onRefreshArguments() {
    bool remarkExists = widget.contact.remarkAvatarLocalPath?.isNotEmpty == true;
    bool onDropEnable = widget.onDrop != null;
    canDrop = remarkExists && onDropEnable;
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    File? avatarFile = await widget.contact.displayAvatarFile;
    if (_avatarFile?.path != avatarFile?.path) {
      setState(() {
        _avatarFile = avatarFile;
      });
    }
  }

  _onPressEdit() {
    if (canDrop) {
      ModalDialog.of(Global.appContext).confirm(
        title: Global.locale((s) => s.confirm_delete_remark_avatar),
        agree: Button(
          width: double.infinity,
          text: Global.locale((s) => s.ok),
          backgroundColor: application.theme.strongColor,
          onPressed: () async {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            widget.onDrop?.call();
          },
        ),
        reject: Button(
          width: double.infinity,
          text: Global.locale((s) => s.cancel),
          fontColor: application.theme.fontColor2,
          backgroundColor: application.theme.backgroundLightColor,
          onPressed: () {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          },
        ),
      );
    } else {
      _selectAvatarFile();
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
              child: Icon(
                canDrop ? CupertinoIcons.clear : CupertinoIcons.camera_fill,
                color: application.theme.backgroundLightColor,
                size: canDrop ? radius / 3 : radius / 4,
              ),
              onPressed: () {
                _onPressEdit();
              },
            ),
          )
        ],
      ),
    );
  }
}
