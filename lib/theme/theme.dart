import 'package:flutter/material.dart';

abstract class SkinTheme {
  Brightness brightness;
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
  TextStyle get bodyText3;
  ThemeData get themeData;
  Color get backgroundColor => backgroundColor1;
  Color get navBackgroundColor => backgroundLightColor;
  Color get headBarColor1 => primaryColor;
  Color get headBarColor2 => backgroundColor4;
  Color get unselectedWidgetColor => fontColor2;
  Color get disabledColor => backgroundColor2;
  Color dividerColor;
  Color backgroundLightColor;
  Color backgroundColor1;
  Color backgroundColor2;
  Color backgroundColor3;
  Color backgroundColor4;
  Color backgroundColor5;
  Color backgroundColor6;
  Color strongColor;
  Color lineColor;
  Color logoBackground;
  Color nknLogoColor;
  Color ethLogoBackground;
  Color ethLogoColor;
  Color successColor;
  Color notificationBackgroundColor;
  Color badgeColor;

  double iconTextFontSize;
  double buttonFontSize;

  double headerHeight = 114;
  double bottomNavHeight = 70;
  Color loadingColor = Color(0xFFFFFFFF);
  Color riseColor = Color(0xFF00CC96);
  Color fallColor = Color(0xFFFC5D68);

  List<Color> randomBackgroundColorList;
  List<Color> randomColorList;
}
