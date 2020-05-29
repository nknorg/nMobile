import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/consts/theme.dart';

class Button extends StatefulWidget {
  final String text;
  final Widget child;
  final double size;
  final double width;
  final EdgeInsetsGeometry padding;
  final Color fontColor;
  final Color backgroundColor;
  final bool dark;
  final TextAlign textAlign;
  final double height;
  final VoidCallback onPressed;
  bool disabled;
  final bool icon;
  final bool outline;
  Button({
    this.text,
    this.child,
    this.width,
    this.size,
    this.padding,
    this.onPressed,
    this.disabled = false,
    this.height,
    this.fontColor,
    this.backgroundColor = DefaultTheme.primaryColor,
    this.dark = true,
    this.textAlign,
    this.icon = false,
    this.outline = false,
  });

  @override
  _ButtonState createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  @override
  Widget build(BuildContext context) {
    if (widget.icon) {
      List<Widget> children = <Widget>[
        widget.child,
      ];
      if (widget.text != null) {
        children.add(SizedBox(height: 5.h));
        children.add(Text(
          widget.text,
          style: TextStyle(fontSize: 11.sp, color: widget.fontColor),
        ));
      }
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: RawMaterialButton(
          padding: widget.padding ?? const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
          onPressed: widget.disabled ? null : widget.onPressed,
          shape: CircleBorder(),
        ),
      );
    } else if (widget.outline) {
      return SizedBox(
        width: widget.width,
        child: OutlineButton(
          borderSide: new BorderSide(color: widget.dark ? DefaultTheme.backgroundLightColor : widget.fontColor),
          padding: widget.padding ?? const EdgeInsets.only(top: 16, bottom: 16),
          disabledTextColor: DefaultTheme.fontColor2,
          color: widget.backgroundColor,
          child: Text(
            widget.text,
            style: TextStyle(fontSize: DefaultTheme.h3FontSize, fontWeight: FontWeight.bold, color: widget.dark ? DefaultTheme.fontLightColor : widget.fontColor),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          onPressed: widget.disabled ? null : widget.onPressed,
        ),
      );
    } else {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: FlatButton(
          padding: widget.padding ?? const EdgeInsets.only(top: 16, bottom: 16),
          disabledColor: DefaultTheme.backgroundColor2,
          disabledTextColor: DefaultTheme.fontColor2,
          color: widget.backgroundColor,
          colorBrightness: widget.dark ? Brightness.dark : Brightness.light,
          child: widget.text != null
              ? Text(
                  widget.text,
                  style: TextStyle(fontSize: DefaultTheme.h3FontSize, fontWeight: FontWeight.bold, color: widget.fontColor),
                )
              : widget.child,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          onPressed: widget.disabled ? null : widget.onPressed,
        ),
      );
    }
  }
}
