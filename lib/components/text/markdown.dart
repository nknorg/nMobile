import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/util.dart';

class Markdown extends StatelessWidget {
  final String data;
  final bool dark;

  Markdown({
    required this.data,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;
    TextStyle textStyle;
    if (dark) {
      textStyle = TextStyle(color: _theme.fontLightColor, height: 1.25);
    } else {
      textStyle = TextStyle(color: _theme.fontColor1, height: 1.25);
    }
    TextStyle linkStyle;
    if (dark) {
      linkStyle = TextStyle(color: _theme.successColor);
    } else {
      linkStyle = TextStyle(color: _theme.primaryColor);
    }
    return MarkdownBody(
      data: data,
      onTapLink: (text, href, title) => Util.launchUrl(href),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        code: textStyle,
        p: textStyle.copyWith(fontSize: _theme.bodyText1.fontSize),
        a: linkStyle,
        h1: textStyle.copyWith(fontSize: _theme.headline1.fontSize),
        h2: textStyle.copyWith(fontSize: _theme.headline2.fontSize),
        h3: textStyle.copyWith(fontSize: _theme.headline3.fontSize),
        h4: textStyle.copyWith(fontSize: _theme.headline4.fontSize),
        h5: textStyle.copyWith(fontSize: _theme.headline4.fontSize),
        em: textStyle,
        listBullet: TextStyle(height: 1.25),
      ),
    );
  }
}
