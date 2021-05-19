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

  OptionsSchema.fromMap(Map map) {
    this.deleteAfterSeconds = map['deleteAfterSeconds'];
    this.updateBurnAfterTime = map['updateTime'];
    this.backgroundColor = Color(map['backgroundColor']);
    this.color = Color(map['color']);
    this.notificationEnabled = map['notificationEnabled'] ? true : false;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['backgroundColor'] = backgroundColor.value;
    map['color'] = color.value;
    map['updateTime'] = updateBurnAfterTime;
    map['notificationEnabled'] = notificationEnabled ? true : false;
    return map;
  }

  String toJson() {
    return jsonEncode(toMap() ?? {});
  }

  @override
  String toString() {
    return 'OptionsSchema{deleteAfterSeconds: $deleteAfterSeconds, updateBurnAfterTime: $updateBurnAfterTime, backgroundColor: $backgroundColor, color: $color, notificationEnabled: $notificationEnabled}';
  }
}
