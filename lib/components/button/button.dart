import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Button extends StatefulWidget {
  final Widget? child;
  final String? text;
  final double? fontSize;
  final Color? fontColor;
  final FontWeight? fontWeight;
  final bool outline;
  final bool disabled;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  Button({
    this.child,
    this.text,
    this.fontSize,
    this.fontColor,
    this.fontWeight,
    this.onPressed,
    this.outline = false,
    this.disabled = false,
    this.padding = const EdgeInsets.symmetric(vertical: 15),
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  _ButtonState createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  Widget _getButton() {
    Widget child = widget.child != null
        ? widget.child!
        : Text(
            widget.text ?? "",
            style: TextStyle(
              fontSize: widget.fontSize ?? application.theme.buttonFontSize,
              color: widget.disabled ? application.theme.fontColor2 : (widget.fontColor ?? application.theme.fontLightColor),
              fontWeight: widget.fontWeight ?? FontWeight.bold,
            ),
          );

    var btnStyle = ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => widget.padding ?? EdgeInsets.all(0)),
      shape: MaterialStateProperty.resolveWith((states) => StadiumBorder()),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (widget.disabled) {
          return application.theme.backgroundColor2;
        }
        return widget.backgroundColor ?? (widget.outline ? null : application.theme.primaryColor);
      }),
    );

    if (widget.borderColor != null) {
      Color color = widget.disabled ? application.theme.backgroundColor2 : widget.borderColor!;
      btnStyle = btnStyle.copyWith(side: MaterialStateProperty.resolveWith((state) => BorderSide(color: color)));
    }

    return widget.outline
        ? OutlinedButton(
            child: child,
            onPressed: widget.disabled ? null : widget.onPressed,
            style: btnStyle,
          )
        : TextButton(
            child: child,
            onPressed: widget.disabled ? null : widget.onPressed,
            style: btnStyle,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.width == null && widget.height == null) {
      return _getButton();
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _getButton(),
    );
  }
}
