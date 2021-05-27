import 'package:flutter/material.dart';

abstract class SkinTheme {
  late Brightness brightness;
  late Color primaryColor;
  late Color fontColor1;
  late Color fontColor2;
  late Color fontColor3;
  late Color fontColor4;
  late Color fontLightColor;

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
  late Color dividerColor;
  late Color backgroundLightColor;
  late Color backgroundColor1;
  late Color backgroundColor2;
  late Color backgroundColor3;
  late Color backgroundColor4;
  late Color backgroundColor5;
  late Color backgroundColor6;
  late Color strongColor;
  late Color lineColor;
  late Color logoBackground;
  late Color nknLogoColor;
  late Color ethLogoBackground;
  late Color ethLogoColor;
  late Color successColor;
  late Color notificationBackgroundColor;
  late Color badgeColor;

  late double iconTextFontSize;
  late double buttonFontSize;

  double headerHeight = 114;
  double bottomNavHeight = 70;
  Color loadingColor = Color(0xFFFFFFFF);
  Color riseColor = Color(0xFF00CC96);
  Color fallColor = Color(0xFFFC5D68);

  late List<Color> randomBackgroundColorList;
  late List<Color> randomColorList;
}
