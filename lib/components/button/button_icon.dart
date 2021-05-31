import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class ButtonIcon extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: this.width,
      height: this.height,
      child: RawMaterialButton(
        padding: this.padding ?? EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: this.text == null
              ? [this.icon]
              : [
                  this.icon,
                  Text(
                    this.text ?? "",
                    softWrap: false,
                    style: TextStyle(fontSize: application.theme.iconTextFontSize, color: this.fontColor),
                  )
                ],
        ),
        onPressed: this.onPressed,
        shape: CircleBorder(),
      ),
    );
  }
}
