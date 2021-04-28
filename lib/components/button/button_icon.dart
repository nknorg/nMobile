import 'package:flutter/material.dart';
import 'package:nmobile/theme/theme.dart';

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
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RawMaterialButton(
        padding: widget.padding ?? EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widget.text == null
              ? [widget.icon]
              : [
                  widget.icon,
                  Text(
                    widget.text,
                    softWrap: false,
                    style: TextStyle(fontSize: SkinTheme.iconTextFontSize, color: widget.fontColor),
                  )
                ],
        ),
        onPressed: widget.onPressed,
        shape: CircleBorder(),
      ),
    );
  }
}
