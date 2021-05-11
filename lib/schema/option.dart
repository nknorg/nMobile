import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:nmobile/common/locator.dart';

class OptionsSchema {
  int deleteAfterSeconds;
  int updateBurnAfterTime;
  Color backgroundColor;
  Color color;
  bool notificationEnabled;

  OptionsSchema({
    this.deleteAfterSeconds,
    this.updateBurnAfterTime,
    this.backgroundColor,
    this.color,
    this.notificationEnabled = false,
  }) {
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    if (backgroundColor == null) {
      backgroundColor = application.theme.randomBackgroundColorList[random];
    }
    if (color == null) {
      color = application.theme.randomColorList[random];
    }
  }

  String toJson() {
    Map<String, dynamic> map = {};
    if (deleteAfterSeconds != null) map['deleteAfterSeconds'] = deleteAfterSeconds;
    if (backgroundColor != null) map['backgroundColor'] = backgroundColor.value;
    if (color != null) map['color'] = color.value;
    if (updateBurnAfterTime != null) map['updateTime'] = updateBurnAfterTime;
    map['notificationEnabled'] = notificationEnabled ? true : false;
    return jsonEncode(map);
  }

  static OptionsSchema parseEntity(Map<String, dynamic> map) {
    return OptionsSchema(
      deleteAfterSeconds: map['deleteAfterSeconds'],
      updateBurnAfterTime: map['updateTime'],
      backgroundColor: Color(map['backgroundColor']),
      color: Color(map['color']),
      notificationEnabled: map['notificationEnabled'] ? true : false,
    );
  }
}
