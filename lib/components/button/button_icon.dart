import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class ButtonIcon extends StatefulWidget {
  final double? width;
  final double? height;
  final Widget icon;
  final String? text;
  final EdgeInsets? padding;
  final VoidCallback? onPressed;
  final Color? fontColor;

  ButtonIcon({
    this.width,
    this.height,
    required this.icon,
    this.text,
    this.padding,
    this.onPressed,
    this.fontColor,
  });

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
                    widget.text ?? "",
                    softWrap: false,
                    style: TextStyle(fontSize: application.theme.iconTextFontSize, color: widget.fontColor),
                  )
                ],
        ),
        onPressed: widget.onPressed,
        shape: CircleBorder(),
      ),
    );
  }
}
