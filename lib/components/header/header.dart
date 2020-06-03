import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/utils/extensions.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget titleChild;
  final Color backgroundColor;
  final Widget action;
  final Widget leading;
  final Widget notBackedUpTip;
  bool hasBack;

  Header({this.title, this.titleChild, this.backgroundColor, this.action, this.leading, this.notBackedUpTip, this.hasBack = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: hasBack,
      backgroundColor: backgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: leading,
      title: Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: (titleChild ??
                    Text(
                      title ?? '',
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: DefaultTheme.labelFontSize),
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      maxLines: 1,
                    ))
                .pad(l: 4),
          ),
          Expanded(flex: 0, child: notBackedUpTip != null ? notBackedUpTip : Space.empty)
        ],
      ),
      actions: action.padd(5.symm()).toList,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(60);
}
