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
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool softWrap;
  TextOverflow? overflow;
  final bool dark;
  final double? height;
  final TextDecoration? decoration;
  final FontStyle? fontStyle;
  final double? textScaleFactor;
  final double? maxWidth;

  Label(
    this.text, {
    this.type = LabelType.label,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.softWrap = false,
    this.overflow,
    this.dark = false,
    this.height,
    this.decoration,
    this.fontStyle,
    this.textScaleFactor = 1.0,
    this.maxWidth,
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

    if (fontSize != null) {
      textStyle = textStyle.copyWith(fontSize: fontSize);
    }

    if (fontWeight != null) {
      textStyle = textStyle.copyWith(fontWeight: fontWeight);
    }

    if (dark) {
      textStyle = textStyle.copyWith(color: theme.fontLightColor);
    }

    if (height != null) {
      textStyle = textStyle.copyWith(height: height);
    }

    if (decoration != null) {
      textStyle = textStyle.copyWith(decoration: decoration);
    }

    if (fontStyle != null) {
      textStyle = textStyle.copyWith(fontStyle: fontStyle);
    }

    return this.maxWidth != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: this.maxWidth!),
            child: Text(
              text,
              style: textStyle,
              textAlign: textAlign,
              maxLines: maxLines ?? defaultTextStyle.maxLines,
              softWrap: softWrap,
              overflow: overflow,
              textScaleFactor: textScaleFactor,
            ),
          )
        : Text(
            text,
            style: textStyle,
            textAlign: textAlign,
            maxLines: maxLines ?? defaultTextStyle.maxLines,
            softWrap: softWrap,
            overflow: overflow,
            textScaleFactor: textScaleFactor,
          );
  }
}
