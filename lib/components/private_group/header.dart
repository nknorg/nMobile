import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/private_group/avatar.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/utils/asset.dart';

// TODO:GG PG check
class PrivateGroupHeader extends StatelessWidget {
  final PrivateGroupSchema privateGroup;
  final Widget body;
  final double avatarRadius;
  final bool dark;
  final GestureTapCallback? onTap;

  PrivateGroupHeader({
    required this.privateGroup,
    required this.body,
    this.avatarRadius = 24,
    this.dark = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String name = this.privateGroup.name;
    return GestureDetector(
      onTap: () {
        if (this.onTap != null) this.onTap!();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: PrivateGroupAvatar(
              privateGroup: this.privateGroup,
              radius: this.avatarRadius,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Asset.iconSvg(
                      'lock',
                      width: 18,
                      color: application.theme.successColor,
                    ),
                    Expanded(
                      child: Label(
                        name,
                        type: LabelType.h3,
                        fontWeight: FontWeight.bold,
                        dark: this.dark,
                      ),
                    ),
                  ],
                ),
                this.body,
              ],
            ),
          )
        ],
      ),
    );
  }
}
