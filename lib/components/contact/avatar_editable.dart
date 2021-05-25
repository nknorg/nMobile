import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/screens/common/photo.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:path/path.dart';

import 'avatar.dart';

class ContactAvatarEditable extends StatefulWidget {
  final ContactSchema contact;
  final double radius;
  final bool placeHolder;
  final Function onSelect;

  ContactAvatarEditable({
    Key key,
    this.contact,
    this.radius,
    this.placeHolder = false,
    this.onSelect,
  }) : super(key: key);

  @override
  _ContactAvatarEditableState createState() => _ContactAvatarEditableState();
}

class _ContactAvatarEditableState extends State<ContactAvatarEditable> {
  _updateAvatar() async {
    if (widget.onSelect != null) widget.onSelect();
  }

  _photoShow(BuildContext context) {
    String avatarPath = join(Global.applicationRootDirectory.path, widget.contact?.getDisplayAvatarPath);
    PhotoScreen.go(context, filePath: avatarPath);
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String avatarPath = this.widget.contact?.getDisplayAvatarPath ?? "";

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              if (avatarPath != null && avatarPath.isNotEmpty) {
                _photoShow(context);
              } else {
                _updateAvatar();
              }
            },
            child: ContactAvatar(
              key: ValueKey(avatarPath),
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
                _updateAvatar();
              },
            ),
          )
        ],
      ),
    );
  }
}
