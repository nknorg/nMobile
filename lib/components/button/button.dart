import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/theme/theme.dart';

class Button extends StatefulWidget {
  final String text;
  final Widget child;
  final Color fontColor;
  final Color backgroundColor;
  final Color outlineBorderColor;
  final double width;
  final double height;
  final VoidCallback onPressed;
  final bool disabled;
  final bool outline;
  final EdgeInsets padding;

  Button({
    this.outline = false,
    this.text,
    this.child,
    this.width,
    this.onPressed,
    this.disabled = false,
    this.height,
    this.fontColor,
    this.backgroundColor,
    this.outlineBorderColor,
    this.padding,
  });

  @override
  _ButtonState createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  @override
  Widget build(BuildContext context) {
    var child = widget.text != null
        ? Text(
            widget.text,
            style: TextStyle(fontSize: SkinTheme.buttonFontSize, fontWeight: FontWeight.bold, color: widget.fontColor),
          )
        : widget.child;
    var height = widget.height ?? 52;
    return SizedBox(
      width: widget.width == null ? double.infinity : widget.width,
      height: height,
      child: widget.outline
          ? OutlinedButton(
              style: ButtonStyle(
                padding: MaterialStateProperty.resolveWith((states) => widget.padding ?? EdgeInsets.all(0)),
                shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2))),
                backgroundColor: MaterialStateProperty.resolveWith((states) => widget.backgroundColor),
              ),
              child: child,
              onPressed: widget.disabled ? null : widget.onPressed,
            )
          : TextButton(
              style: ButtonStyle(
                padding: MaterialStateProperty.resolveWith((states) => widget.padding ?? EdgeInsets.all(0)),
                shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2))),
                backgroundColor: MaterialStateProperty.resolveWith((states) => widget.backgroundColor),
              ),
              child: child,
              onPressed: widget.disabled ? null : widget.onPressed,
            ),
    );
  }
}
