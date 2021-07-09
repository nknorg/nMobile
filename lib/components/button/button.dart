import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Button extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (this.width == null && this.height == null) {
      return _getButton();
    }
    return SizedBox(
      width: this.width,
      height: this.height,
      child: _getButton(),
    );
  }

  Widget _getButton() {
    Widget child = this.child != null
        ? this.child!
        : Text(
            this.text ?? "",
            style: TextStyle(
              fontSize: this.fontSize ?? application.theme.buttonFontSize,
              color: this.disabled ? application.theme.fontColor2 : (this.fontColor ?? application.theme.fontLightColor),
              fontWeight: this.fontWeight ?? FontWeight.bold,
            ),
          );

    var btnStyle = ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => this.padding ?? EdgeInsets.all(0)),
      shape: MaterialStateProperty.resolveWith((states) => StadiumBorder()),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (this.disabled) {
          return application.theme.backgroundColor2;
        }
        return this.backgroundColor ?? (this.outline ? null : application.theme.primaryColor);
      }),
    );

    if (this.borderColor != null) {
      Color color = this.disabled ? application.theme.backgroundColor2 : this.borderColor!;
      btnStyle = btnStyle.copyWith(side: MaterialStateProperty.resolveWith((state) => BorderSide(color: color)));
    }

    return this.outline
        ? OutlinedButton(
            child: child,
            onPressed: this.disabled ? null : this.onPressed,
            style: btnStyle,
          )
        : TextButton(
            child: child,
            onPressed: this.disabled ? null : this.onPressed,
            style: btnStyle,
          );
  }
}
