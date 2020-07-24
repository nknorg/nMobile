import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/utils/extensions.dart';

class ButtonIcon extends StatefulWidget {
  final String text;
  final Widget icon;
  final Color fontColor;
  final EdgeInsets padding;
  final double width;
  final double height;
  final VoidCallback onPressed;

  ButtonIcon({this.text, this.icon, this.fontColor, this.padding, this.width, this.height, this.onPressed});

  @override
  _ButtonIconState createState() => _ButtonIconState();
}

class _ButtonIconState extends State<ButtonIcon> {
  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      padding: widget.padding ?? 8.pad(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: widget.text == null
            ? [widget.icon]
            : [
                widget.icon,
                Text(
                  widget.text,
                  softWrap: false,
                  style: TextStyle(fontSize: DefaultTheme.iconTextFontSize, color: widget.fontColor),
                )
              ],
      ),
      onPressed: widget.onPressed ??
          () {
            // Can't be null.
          },
      shape: CircleBorder(),
    ).sized(w: widget.width, h: widget.height);
  }
}
