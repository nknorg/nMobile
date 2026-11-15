import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/plain_circle_avatar.dart';
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
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius;
    String name = widget.contact.displayName;
    String? path = widget.contact.displayAvatarPath;
    Widget fallback;
    if (widget.placeHolder == true) {
      fallback = CircleAvatar(
        radius: radius,
        backgroundColor: application.theme.backgroundColor2,
        child: Asset.iconSvg('user', color: application.theme.fontColor2),
      );
    } else {
      fallback = CircleAvatar(
        radius: radius,
        backgroundColor: widget.contact.options.avatarBgColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.contact.options.avatarNameColor ?? application.theme.fontLightColor,
          type: LabelType.h3,
          fontSize: radius / 3 * 2,
        ),
      );
    }
    if (path == null || path.isEmpty) return fallback;
    return PlainCircleAvatar(path: path, radius: radius, fallback: fallback);
  }
}
