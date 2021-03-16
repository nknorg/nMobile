import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

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
  final String text;
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

  Label(this.text,
      {this.fontSize,
      this.type = LabelType.label,
      this.maxLines,
      this.color,
      this.dark = false,
      this.textAlign,
      this.fontWeight,
      this.height,
      this.overflow,
      this.softWrap = false}) {
    overflow ??= softWrap ? null : TextOverflow.ellipsis;
  }

  buildTextStyle(
      {double fontSize,
      Color color,
      double letterSpacing,
      FontWeight fontWeight}) {
    if (dark) color = DefaultTheme.fontLightColor;
    return TextStyle(
        fontSize: fontSize,
        height: this.height ?? 1.2,
        color: this.color ?? color,
        letterSpacing: letterSpacing,
        fontWeight: this.fontWeight ?? fontWeight);
  }

  @override
  Widget build(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    switch (type) {
      case LabelType.h1:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: DefaultTheme.h1FontSize, fontWeight: FontWeight.bold),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.h2:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: DefaultTheme.h2FontSize, fontWeight: FontWeight.bold),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.h3:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: DefaultTheme.h3FontSize, fontWeight: FontWeight.bold),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.h4:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.h4FontSize,
              fontWeight: FontWeight.bold),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.display:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.displayFontSize),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.bodyLarge:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.bodyLargeFontSize,
              color: DefaultTheme.fontColor2),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.bodyRegular:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.bodyRegularFontSize,
              color: DefaultTheme.fontColor2),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.bodySmall:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.bodySmallFontSize,
              color: DefaultTheme.fontColor2),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      case LabelType.label:
        return Text(
          text,
          textScaleFactor: 1.0,
          style: buildTextStyle(
              fontSize: fontSize ?? DefaultTheme.labelFontSize,
              color: DefaultTheme.fontColor2),
          textAlign: this.textAlign,
          overflow: this.overflow,
          softWrap: softWrap,
          maxLines: maxLines ?? defaultTextStyle.maxLines,
        );
      default:
        break;
    }
  }
}
