import 'dart:convert';

import 'dart:math';

import 'package:nmobile/consts/theme.dart';

class OptionsSchema {
  int deleteAfterSeconds;
  int backgroundColor;
  int color;
  int updateBurnAfterTime;

  OptionsSchema({
    this.deleteAfterSeconds,
    this.backgroundColor,
    this.color,
    this.updateBurnAfterTime,
  });

  String toJson() {
    Map<String, dynamic> map = {};
    if (deleteAfterSeconds != null)
      map['deleteAfterSeconds'] = deleteAfterSeconds;
    if (backgroundColor != null) map['backgroundColor'] = backgroundColor;
    if (color != null) map['color'] = color;
    if (updateBurnAfterTime != null) map['updateTime'] = updateBurnAfterTime;
    return jsonEncode(map);
  }

  static OptionsSchema random({int themeId}) {
    final random =
        themeId ?? Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    return OptionsSchema(
      backgroundColor: DefaultTheme.headerBackgroundColor[random],
      color: DefaultTheme.headerColor[random],
    );
  }

  static OptionsSchema parseEntity(Map<String, dynamic> map) {
    return OptionsSchema(
      deleteAfterSeconds: map['deleteAfterSeconds'],
      backgroundColor: map['backgroundColor'],
      color: map['color'],
      updateBurnAfterTime: map['updateTime'],
    );
  }
}
