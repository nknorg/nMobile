import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

enum LabelType {
  h1,
  h2,
  h3,
  h4,
  display,
  bodyLarge,
  bodyRegular,
  bodySmall,
  label,
}

class Label extends StatelessWidget {
  String text;
  final LabelType type;
  final Color color;
  final bool dark;
  final bool softWrap;
  final TextAlign textAlign;
  final FontWeight fontWeight;
  final double height;
  TextOverflow overflow;
  final int maxLines;
  final double fontSize;
  final TextDecoration decoration;
  final FontStyle fontStyle;

  Label(
    this.text, {
    this.fontSize,
    this.type = LabelType.label,
    this.maxLines,
    this.color,
    this.dark = false,
    this.textAlign,
    this.fontWeight,
    this.height,
    this.overflow,
    this.softWrap = false,
    this.decoration,
    this.fontStyle,
  }) {
    overflow ??= softWrap ? null : TextOverflow.ellipsis;
  }

  @override
  Widget build(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    final theme = application.theme;
    TextStyle textStyle = defaultTextStyle.style;
    switch (type) {
      case LabelType.h1:
        textStyle = textStyle.merge(theme.headline1);
        break;
      case LabelType.h2:
        textStyle = textStyle.merge(theme.headline2);
        break;
      case LabelType.h3:
        textStyle = textStyle.merge(theme.headline3);
        break;
      case LabelType.h4:
        textStyle = textStyle.merge(theme.headline4);
        break;
      case LabelType.display:
        textStyle = textStyle.merge(theme.display);
        break;
      case LabelType.bodyLarge:
        textStyle = textStyle.merge(theme.bodyText1);
        break;
      case LabelType.bodyRegular:
        textStyle = textStyle.merge(theme.bodyText2);
        break;
      case LabelType.bodySmall:
        textStyle = textStyle.merge(theme.bodyText3);
        break;
      case LabelType.label:
        text = text.toUpperCase();
        textStyle = textStyle.merge(theme.display).copyWith(fontWeight: FontWeight.bold);
        break;
      default:
        break;
    }

    if (color != null) {
      textStyle = textStyle.copyWith(color: color);
    }

    if (fontWeight != null) {
      textStyle = textStyle.copyWith(fontWeight: fontWeight);
    }

    return Text(
      text,
      textScaleFactor: 1.0,
      style: textStyle,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
      maxLines: maxLines ?? defaultTextStyle.maxLines,
    );
  }
}
