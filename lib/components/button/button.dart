import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Button extends StatefulWidget {
  final String text;
  final Widget child;
  final double fontSize;
  final Color fontColor;
  final FontWeight fontWeight;
  final double width;
  final double height;
  final bool outline;
  final bool disabled;
  final VoidCallback onPressed;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;

  Button({
    this.text,
    this.child,
    this.fontSize,
    this.fontColor,
    this.fontWeight,
    this.width,
    this.height,
    this.outline = false,
    this.disabled = false,
    this.onPressed,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  _ButtonState createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  @override
  Widget build(BuildContext context) {
    var width = widget.width ?? double.infinity;
    var height = widget.height ?? 52;

    var child = widget.text != null
        ? Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize ?? application.theme.buttonFontSize,
              color: widget.disabled ? application.theme.fontColor2 : (widget.fontColor ?? application.theme.fontLightColor),
              fontWeight: widget.fontWeight ?? FontWeight.bold,
            ),
          )
        : widget.child;

    var btnStyle = ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => widget.padding ?? EdgeInsets.all(0)),
      shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2))),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (widget.disabled) {
          return application.theme.backgroundColor2;
        }
        return widget.backgroundColor ?? (widget.outline ? null : application.theme.primaryColor);
      }),
    );

    if (widget.borderColor != null) {
      btnStyle = btnStyle.copyWith(side: MaterialStateProperty.resolveWith((state) => BorderSide(color: widget.disabled ? application.theme.backgroundColor2 : widget.borderColor)));
    }

    return SizedBox(
      width: width,
      height: height,
      child: widget.outline
          ? OutlinedButton(
              child: child,
              onPressed: widget.disabled ? null : widget.onPressed,
              style: btnStyle,
            )
          : TextButton(
              child: child,
              onPressed: widget.disabled ? null : widget.onPressed,
              style: btnStyle,
            ),
    );
  }
}
