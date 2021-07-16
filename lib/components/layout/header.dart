import 'package:flutter/material.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  static double height = 68;

  final String? title;
  final Widget? titleChild;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? childLead;
  final Widget? childTail;
  final Color? backgroundColor;
  final Brightness? brightness;
  final PreferredSizeWidget? bottom;

  Header({
    this.title,
    this.titleChild,
    this.leading,
    this.actions,
    this.childLead,
    this.childTail,
    this.backgroundColor,
    this.brightness = Brightness.dark,
    this.bottom,
  }) {
    _header = AppBar(
      brightness: this.brightness,
      backgroundColor: backgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: leading,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          this.childLead ?? SizedBox.shrink(),
          Expanded(
            child: (titleChild ??
                Text(
                  title?.toUpperCase() ?? '',
                  textAlign: TextAlign.start,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  maxLines: 1,
                )),
          ),
          this.childTail ?? SizedBox.shrink(),
          // Expanded(flex: 0, child: notBackedUpTip != null ? notBackedUpTip : Space.empty)
        ],
      ),
      actions: actions,
      bottom: this.bottom,
    );
  }

  late AppBar _header;

  @override
  Widget build(BuildContext context) {
    return _header;
  }

  @override
  // Size get preferredSize => _header.preferredSize;
  Size get preferredSize => Size.fromHeight(height);
}
