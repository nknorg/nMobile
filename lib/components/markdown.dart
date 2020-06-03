import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/utils.dart';

class Markdown extends StatelessWidget {
  final String data;
  final bool dark;
  Markdown({this.data, this.dark = false});

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle;
    if (dark) {
      textStyle = TextStyle(color: DefaultTheme.fontLightColor, height: 1.25);
    } else {
      textStyle = TextStyle(color: DefaultTheme.fontColor1, height: 1.25);
    }
    TextStyle linkStyle;
    if (dark) {
      linkStyle = TextStyle(color: DefaultTheme.successColor);
    } else {
      linkStyle = TextStyle(color: DefaultTheme.primaryColor);
    }

    return MarkdownBody(
      data: data,
      onTapLink: (href) {
        launchURL(href);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(code: textStyle, p: textStyle.copyWith(fontSize: DefaultTheme.bodyRegularFontSize), a: linkStyle, h1: textStyle.copyWith(fontSize: DefaultTheme.h1FontSize), h2: textStyle.copyWith(fontSize: DefaultTheme.h2FontSize), h3: textStyle.copyWith(fontSize: DefaultTheme.h3FontSize), h4: textStyle.copyWith(fontSize: DefaultTheme.h4FontSize), h5: textStyle.copyWith(fontSize: DefaultTheme.h5FontSize), em: textStyle, listBullet: TextStyle(height: 1.25)),
    );
  }
}
