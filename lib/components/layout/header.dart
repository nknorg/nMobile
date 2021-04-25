import 'package:flutter/material.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget titleChild;
  final Color backgroundColor;
  final List<Widget> actions;
  final Widget leading;
  final Brightness brightness;
  Header({
    this.title,
    this.titleChild,
    this.backgroundColor,
    this.actions,
    this.leading,
    this.brightness = Brightness.dark,
  }) {
    _header = AppBar(
      brightness: this.brightness,
      backgroundColor: backgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: leading,
      elevation: 0,
      title: Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: (titleChild ??
                Text(
                  title?.toUpperCase() ?? '',
                  textAlign: TextAlign.start,
                  // todo
                  // style: TextStyle(fontSize: SkinTheme.labelFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  maxLines: 1,
                )),
          ),
          // Expanded(flex: 0, child: notBackedUpTip != null ? notBackedUpTip : Space.empty)
        ],
      ),
      actions: actions,
    );
  }

  AppBar _header;

  @override
  Widget build(BuildContext context) {
    return _header;
  }

  @override
  Size get preferredSize => _header.preferredSize;
}
