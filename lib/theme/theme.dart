import 'package:flutter/material.dart';

abstract class SkinTheme {
  Color primaryColor;
  Color fontColor1;
  Color fontColor2;
  Color fontColor3;
  Color fontColor4;
  Color fontLightColor;

  TextStyle get headline1;
  TextStyle get headline2;
  TextStyle get headline3;
  TextStyle get headline4;
  TextStyle get display;
  TextStyle get bodyText1;
  TextStyle get bodyText2;
  ThemeData get themeData;
  Color get backgroundColor => backgroundColor1;
  Color get navBackgroundColor => backgroundLightColor;
  Color get headBarColor1 => primaryColor;
  Color get headBarColor2 => backgroundColor4;
  Color get unselectedWidgetColor => fontColor2;
  Color get disabledColor => backgroundColor2;

  Color backgroundLightColor;

  Color backgroundColor1;
  Color backgroundColor2;
  Color backgroundColor3;
  Color backgroundColor4;
  Color backgroundColor5;
  Color backgroundColor6;

  static const Color notificationBackgroundColor = Color(0xFF00CC96);

  static const Color logoBackground = Color(0xFFF1F4FF);
  static const Color nknLogoColor = Color(0xFF253A7E);
  static const Color ethLogoColor = Color(0xFF5F7AE3);

  static final double h1FontSize = 32;
  static final double h2FontSize = 24;
  static final double h3FontSize = 18;
  static final double h4FontSize = 16;
  static final double displayFontSize = h4FontSize;
  static final double bodyLargeFontSize = h3FontSize;
  static final double bodyRegularFontSize = h4FontSize;
  static final double bodySmallFontSize = 14;
  static final double labelFontSize = bodySmallFontSize;
  static final double chatTimeSize = bodySmallFontSize;
  static final double iconTextFontSize = 12;

  static final double headerHeight = 114;
  static final double bottomNavHeight = 70;

  static const Color loadingColor = Color(0xFFFFFFFF);
  static const Color strongColor = Color(0xFFFC5D68);
  static const Color successColor = Color(0xFF00CC96);

  static const Color riseColor = Color(0xFF00CC96);
  static const Color fallColor = Color(0xFFFC5D68);
  static const Color lineColor = Color(0xFFEFF2F9);
}
