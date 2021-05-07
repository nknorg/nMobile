import 'dart:ui';

import 'package:flutter/material.dart';
import './theme.dart';

class LightTheme implements SkinTheme {
  @override
  Brightness brightness = Brightness.light;
  @override
  Color primaryColor = Color(0xFF0F6EFF);
  @override
  Color fontColor1 = Color(0xFF2D2D2D);
  @override
  Color fontColor2 = Color(0xFF8F92A1);
  @override
  Color fontColor3 = Color(0xFF9c9c9c);
  @override
  Color fontColor4 = Color(0xFFb1b1b1);
  @override
  Color fontLightColor = Color(0xFFFFFFFF);

  @override
  TextStyle get bodyText1 => TextStyle(fontWeight: FontWeight.normal, fontSize: 16, height: 1.5, color: fontColor2);

  @override
  TextStyle get bodyText2 => TextStyle(fontWeight: FontWeight.normal, fontSize: 14, height: 1.5, color: fontColor2);

  @override
  TextStyle get bodyText3 => TextStyle(fontWeight: FontWeight.normal, fontSize: 12, height: 1.5, color: fontColor2);

  @override
  TextStyle get headline1 => TextStyle(fontWeight: FontWeight.bold, fontSize: 30, height: 1.2, color: fontColor1);

  @override
  TextStyle get headline2 => TextStyle(fontWeight: FontWeight.bold, fontSize: 22, height: 1.2, color: fontColor1);

  @override
  TextStyle get headline3 => TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: fontColor1);

  @override
  TextStyle get headline4 => TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2, color: fontColor1);

  @override
  TextStyle get display => TextStyle(fontWeight: FontWeight.normal, fontSize: 14, height: 1.2, color: fontColor1);

  @override
  ThemeData get themeData => ThemeData(
        brightness: brightness,
        primaryColor: primaryColor,
        // primarySwatch: primaryColor,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: navBackgroundColor,
          type: BottomNavigationBarType.fixed,
          unselectedItemColor: fontColor2,
          selectedItemColor: primaryColor,
        ),
        textTheme: TextTheme(
          headline1: headline1,
          headline2: headline2,
          headline3: headline3,
          headline4: headline4,
          headline5: display,
          bodyText1: bodyText1,
          bodyText2: bodyText2,
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          buttonColor: primaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) => primaryColor),
            textStyle: MaterialStateProperty.resolveWith((states) => TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        sliderTheme: SliderThemeData(
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
          trackHeight: 8,
          tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 0),
          // thumbShape: SliderThemeShape(),
        ),
        unselectedWidgetColor: unselectedWidgetColor,
      );

  @override
  Color get backgroundColor => backgroundColor1;

  @override
  Color get headBarColor1 => primaryColor;

  @override
  Color get headBarColor2 => backgroundColor4;

  @override
  Color get navBackgroundColor => backgroundLightColor;

  @override
  Color get unselectedWidgetColor => fontColor2;

  @override
  Color get disabledColor => backgroundColor5;

  @override
  Color get dividerColor => backgroundColor2;

  @override
  Color backgroundColor1 = Color(0xFFF6F7FB);

  @override
  Color backgroundColor2 = Color(0xFFEFF2F9);

  @override
  Color backgroundColor3 = Color(0xFFE5E5E5);

  @override
  Color backgroundColor4 = Color(0xFF11163C);

  @override
  Color backgroundColor5 = Color(0xFF2D2D2D);

  @override
  Color backgroundColor6 = Color(0xFFEDEDED);

  @override
  Color backgroundLightColor = Color(0xFFFFFFFF);

  @override
  Color strongColor = Color(0xFFFC5D68);

  @override
  Color lineColor = Color(0xFFEFF2F9);

  @override
  Color logoBackground = Color(0xFFF1F4FF);

  @override
  Color ethLogoBackground = Color(0xFF5F7AE3);

  @override
  Color ethLogoColor = Color(0xFF253A7E);

  @override
  Color nknLogoColor = Color(0xFF5F7AE3);

  @override
  Color notificationBackgroundColor = Color(0xFF00CC96);

  @override
  Color successColor = Color(0xFF00CC96);

  @override
  Color badgeColor = Color(0xFF5458F7);

  @override
  double iconTextFontSize = 12;

  @override
  double buttonFontSize = 16;
}
