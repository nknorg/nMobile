import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget titleChild;
  final Color backgroundColor;
  final Widget action;
  final Widget leading;
  bool hasBack;
  Header({this.title, this.titleChild, this.backgroundColor, this.action, this.leading, this.hasBack = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: hasBack,
      backgroundColor: backgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: leading,
      title: titleChild != null
          ? Padding(
              padding: const EdgeInsets.only(left: 4),
              child: titleChild,
            )
          : Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                title ?? '',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: DefaultTheme.labelFontSize,
                ),
                overflow: TextOverflow.fade,
                softWrap: false,
                maxLines: 1,
              ),
            ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: action,
        ),
      ],
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(60);
}
